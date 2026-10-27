"""Disabled Civ13 v3 source mailbox with explicit v2 compatibility.

The game initiates authenticated exchanges. A controller can only propose one
action for the current assignment/epoch/observation. The game revalidates it.
"""
from __future__ import annotations

import argparse
import copy
from collections import OrderedDict
import hashlib
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
from pathlib import Path
import re
import secrets
import time
from catalog import (CAPABILITIES, RECIPES, REASONS, STATES, TERMINAL, WIRE_FINAL,
                     CONTROL_FIELDS, QUERY_FIELDS, ENVELOPE_FIELDS, action_error, discovery)
from observations import ObservationHistory

LIMIT = 32768
LEASE_SECONDS = 15
IDENT = re.compile(r"[A-Za-z0-9_-]{1,64}\Z")


class Rejected(ValueError):
    pass


def require(condition, code):
    if not condition:
        raise Rejected(code)


def identifier(value):
    return isinstance(value, str) and bool(IDENT.fullmatch(value))


def integer(value, minimum=0):
    return type(value) is int and minimum <= value <= 2**31 - 1


def exact(value, keys):
    require(type(value) is dict and set(value) == set(keys), "schema")


def text(value, maximum):
    return isinstance(value, str) and len(value) <= maximum and all(
        ord(c) >= 32 and ord(c) != 127 for c in value
    )


def action_valid(action):
    error = action_error(action)
    require(error is None, error)
    return action["type"]


def observation_valid(obs):
    require(type(obs) is dict, "schema")
    version = obs.get("version")
    require(type(version) is int and version in (2, 3), "version")
    try:
        require(len(json.dumps(obs, ensure_ascii=True, allow_nan=False).encode()) <= 24576, "size")
    except (ValueError, TypeError, RecursionError) as error:
        if isinstance(error, Rejected):
            raise
        raise Rejected("schema") from error
    if version == 3:
        require(set(obs) == {"version", "assignment", "epoch", "observation_seq", "next_action_seq",
                            "capabilities", "status", "entities", "inventory", "messages", "laws",
                            "complete", "limit_reason"}, "schema")
        require(type(obs["complete"]) in (bool, int) and obs["complete"] in (0, 1), "completeness")
        require(obs["limit_reason"] in ("none", "entity_limit", "visit_limit", "output_limit"), "completeness")
        require(bool(obs["complete"]) == (obs["limit_reason"] == "none"), "completeness")
        require(type(obs["inventory"]) is list and len(obs["inventory"]) <= 2, "inventory")
        obs = {k: v for k, v in obs.items() if k not in ("complete", "limit_reason")}
        obs["version"] = 2  # Validate the explicitly shared legacy public fields.
    exact(obs, {"version", "assignment", "epoch", "observation_seq", "next_action_seq",
                "capabilities", "status", "entities", "inventory", "messages", "laws"})
    require(obs["version"] == 2 and type(obs["version"]) is int, "version")
    require(identifier(obs["assignment"]) and identifier(obs["epoch"]), "scope")
    require(integer(obs["observation_seq"], 1) and integer(obs["next_action_seq"], 1), "sequence")
    caps = obs["capabilities"]
    require(type(caps) is list and len(caps) <= 15 and all(isinstance(c, str) and c in CAPABILITIES for c in caps), "capabilities")
    exact(obs["status"], {"conscious", "mobile", "hungry", "thirsty"})
    # DreamDaemon JSON encodes DM flags as numeric 0/1.
    require(all(type(v) in (bool, int) and v in (0, 1) for v in obs["status"].values()), "status")
    require(type(obs["entities"]) is list and len(obs["entities"]) <= 128, "entities")
    require(type(obs["inventory"]) is list and len(obs["inventory"]) <= 16, "inventory")
    ids = set()
    for entity in obs["entities"] + obs["inventory"]:
        exact(entity, {"id", "name", "kind", "dx", "dy", "actions", "recipes"})
        require(identifier(entity["id"]) and entity["id"] not in ids, "entity_id")
        ids.add(entity["id"])
        require(text(entity["name"], 80) and entity["kind"] in ("tile", "entity", "item", "person"), "entity")
        require(type(entity["dx"]) is int and -3 <= entity["dx"] <= 3 and type(entity["dy"]) is int and -3 <= entity["dy"] <= 3, "range")
        require(type(entity["actions"]) is list and len(entity["actions"]) <= 6 and all(isinstance(a, str) and a in CAPABILITIES for a in entity["actions"]), "entity_actions")
        require(type(entity["recipes"]) is list and len(entity["recipes"]) <= 3 and all(isinstance(r, str) and r in RECIPES for r in entity["recipes"]), "recipes")
    require(type(obs["messages"]) is list and len(obs["messages"]) <= 8, "messages")
    last_event = 0
    for message in obs["messages"]:
        exact(message, {"event_seq", "text"})
        require(integer(message["event_seq"], 1) and message["event_seq"] > last_event and text(message["text"], 256), "message")
        last_event = message["event_seq"]
    # Reserved law hook: player v1 has no laws and no station privileges.
    require(obs["laws"] is None, "laws_unsupported")


def decode(raw):
    require(len(raw) <= LIMIT, "size")
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, "duplicate_key")
            result[key] = value
        return result
    try:
        result = json.loads(raw, object_pairs_hook=pairs,
                            parse_constant=lambda _: (_ for _ in ()).throw(Rejected("number")))
        pending = [(result, 0)]
        while pending:
            item, depth = pending.pop()
            require(depth <= 16, "json")
            if isinstance(item, (dict, list)):
                pending.extend((value, depth + 1) for value in (item.values() if isinstance(item, dict) else item))
        return result
    except Rejected:
        raise
    except (UnicodeError, ValueError, RecursionError) as error:
        raise Rejected("json") from error


class Broker:
    """Single assignment, one pending action, bounded idempotency records.

    HTTPServer serializes handlers. No background workers, sockets, subprocesses,
    persistent files, game references or model APIs are used by this class.
    """
    def __init__(self, assignment, game_token, controller_token, *, clock=time.monotonic, audit=None):
        require(identifier(assignment), "assignment")
        require(all(isinstance(t, str) and 32 <= len(t) <= 256 and t.isascii()
                    and all(33 <= ord(c) <= 126 for c in t) for t in (game_token, controller_token)), "credential")
        require(game_token != controller_token, "credential_separation")
        self.assignment = assignment
        self.tokens = {"game": game_token, "controller": controller_token}
        self.clock = clock
        self.audit = audit or (lambda event: None)
        self.observation = None
        self.updated = float("-inf")
        self.pending = None
        self.inflight = None
        self.records = OrderedDict()
        self.stopped = False
        self.last_submit = float("-inf")
        self.history = ObservationHistory()
        self.cancel_id = None
        self.dispatched_at = None
        self.control_scope = None

    def authorized(self, role, authorization):
        return isinstance(authorization, str) and secrets.compare_digest(
            authorization.encode(), ("Bearer " + self.tokens[role]).encode())

    def emit(self, decision, request=None):
        # Hash model-chosen identifiers as well; never log text, observations or tokens.
        event = {"decision": decision}
        if request:
            event["request_hash"] = hashlib.sha256(request.encode()).hexdigest()[:16]
        self.audit(event)

    def remember(self, key, digest, response):
        self.records[key] = (digest, response)
        while len(self.records) > 64:
            self.records.popitem(last=False)

    def exchange(self, packet):
        exact(packet, {"observation", "receipt"})
        obs = packet["observation"]
        observation_valid(obs)
        require(obs["assignment"] == self.assignment, "scope")
        previous = self.observation
        previous_time = self.updated
        if previous:
            require(obs["version"] == previous["version"], "version")
            require(obs["epoch"] == previous["epoch"], "epoch_requires_restart")
            require(obs["observation_seq"] >= previous["observation_seq"] and
                    obs["next_action_seq"] >= previous["next_action_seq"], "replay")
            if obs["observation_seq"] == previous["observation_seq"]:
                require(obs == previous, "snapshot_conflict")
        receipt = packet["receipt"]
        if receipt is not None:
            modern = obs["version"] == 3
            exact(receipt, {"request_id", "status", "detail", "reason"} if modern else {"request_id", "status", "detail"})
            require(identifier(receipt["request_id"]) and receipt["status"] in
                    (WIRE_FINAL if modern else ("executed", "blocked", "cancelled", "stale", "unsupported", "invalid")) and text(receipt["detail"], 512), "receipt")
            if modern:
                require(isinstance(receipt["reason"], str) and receipt["reason"] in REASONS, "receipt")
                require((receipt["status"] == "completed") == (receipt["reason"] == "none"), "receipt")
            record = self.records.get(receipt["request_id"])
            require(record is not None and self.inflight == receipt["request_id"], "receipt_scope")
            if record:
                record[1]["status"] = receipt["status"]
                record[1]["detail"] = receipt["detail"]
                if modern:
                    record[1]["reason"] = receipt["reason"]
            if self.inflight == receipt["request_id"]:
                self.inflight = None
                self.cancel_id = None
                self.dispatched_at = None
        self.observation = copy.deepcopy(obs)
        self.control_scope = (obs["version"], obs["assignment"], obs["epoch"])
        if obs["version"] == 3:
            self.history.remember(obs)
        if not previous or obs["observation_seq"] != previous["observation_seq"]:
            self.updated = self.clock()
        request, self.pending = self.pending, None
        if self.stopped:
            return self.reply(True, None)
        # Repeated identical snapshots permit bounded local-model inference;
        # they never extend the original lease. The game revalidates live state.
        if request and previous and self.clock() - previous_time <= LEASE_SECONDS and request["observation_seq"] == previous["observation_seq"]:
            self.inflight = request["request_id"]
            self.dispatched_at = self.clock()
            if obs["version"] == 3:
                self.records[self.inflight][1].update(status="dispatched", reason="none")
            return self.reply(False, request)
        if request:
            self.records[request["request_id"]][1]["status"] = "stale"
            if obs["version"] == 3:
                self.records[request["request_id"]][1].update(status="denied", reason="stale_observation")
        return self.reply(False, None)

    def reply(self, stop, action):
        result = {"stop": stop, "action": action}
        if self.observation["version"] == 3:
            result["cancel"] = self.cancel_id
        return result

    def current(self):
        require(not self.stopped, "stopped")
        require(self.observation is not None and self.clock() - self.updated <= LEASE_SECONDS, "unavailable")
        return {"observation": self.observation}

    def submit(self, request):
        exact(request, ENVELOPE_FIELDS)
        require(type(request["version"]) is int and request["version"] in (2, 3), "version")
        require(identifier(request["assignment"]) and identifier(request["epoch"]) and identifier(request["request_id"]), "scope")
        require(integer(request["observation_seq"], 1) and integer(request["action_seq"], 1), "sequence")
        kind = action_valid(request["action"])
        require(request["assignment"] == self.assignment, "scope")
        require(not self.stopped, "stopped")
        digest = hashlib.sha256(json.dumps(request, sort_keys=True).encode()).hexdigest()
        key = request["request_id"]
        if key in self.records:
            saved, response = self.records[key]
            require(saved == digest, "request_id_conflict")
            return response
        obs = self.current()["observation"]
        require(request["version"] == obs["version"], "version")
        require(request["epoch"] == obs["epoch"] and request["observation_seq"] == obs["observation_seq"]
                and request["action_seq"] == obs["next_action_seq"], "stale")
        require(kind in obs["capabilities"], "capability")
        require(self.pending is None, "busy")
        require(self.inflight is None, "busy")
        require(self.clock() - self.last_submit >= 1, "rate")
        if kind in ("use", "examine", "pickup", "drop", "consume", "equip", "gather", "refill", "drink", "craft"):
            entity = next((e for e in obs["entities"] + obs["inventory"] if e["id"] == request["action"]["target"]), None)
            require(entity is not None, "target")
            require(kind in entity["actions"], "unsupported_target")
            if kind == "craft":
                require(request["action"]["recipe"] in entity["recipes"], "unavailable_recipe")
        self.pending = copy.deepcopy(request)
        self.last_submit = self.clock()
        response = {"request_id": key, "status": "queued"}
        if request["version"] == 3:
            response.update(reason="none", detail="")
        self.remember(key, digest, response)
        self.emit("queued", key)
        return response

    def stop(self):
        self.stopped = True
        if self.pending:
            self.records[self.pending["request_id"]][1]["status"] = "cancelled"
            if self.pending["version"] == 3:
                self.records[self.pending["request_id"]][1]["reason"] = "cancelled"
        if self.inflight:
            self.cancel_id = self.inflight
            self.records[self.inflight][1].update(status="cancel_requested", reason="cancel_requested")
        self.pending = None
        self.observation = None
        self.emit("stopped")
        return {"status": "stopped"}

    def control(self, request):
        exact(request, CONTROL_FIELDS)
        require(type(request["version"]) is int and request["version"] == 3, "version")
        require(self.control_scope is not None and self.control_scope[0] == 3, "unavailable")
        require(identifier(request["assignment"]) and identifier(request["epoch"]), "scope")
        require((request["version"], request["assignment"], request["epoch"]) == self.control_scope, "scope")
        require(identifier(request["request_id"]), "target")
        require(request["operation"] in ("status", "cancel"), "operation")
        record = self.records.get(request["request_id"])
        require(record is not None, "receipt_expired")
        result = record[1]
        if request["operation"] == "cancel" and (result["status"] not in TERMINAL or self.inflight == request["request_id"]):
            if self.pending and self.pending["request_id"] == request["request_id"]:
                self.pending = None
                result.update(status="cancelled", reason="cancelled")
            elif self.inflight == request["request_id"]:
                self.cancel_id = request["request_id"]
                result.update(status="cancel_requested", reason="cancel_requested")
        if self.inflight == request["request_id"] and self.dispatched_at is not None and self.clock() - self.dispatched_at > 30:
            # Uncertainty must never free the worker slot or imply cancellation.
            result.update(status="unknown", reason="transport_uncertain")
        return dict(result)

    def route(self, path, authorization, packet, *, origin=None):
        require(origin is None, "browser_origin")
        role = "game" if path == "/v1/game/exchange" else "controller"
        require(self.authorized(role, authorization), "unauthorized")
        if path == "/v1/game/exchange":
            return self.exchange(packet)
        if path == "/v1/action":
            if type(packet) is dict and "operation" in packet:
                return self.control(packet)
            return self.submit(packet)
        if path == "/v1/observation" and packet:
            exact(packet, QUERY_FIELDS)
            require(type(packet["version"]) is int and packet["version"] == 3, "version")
            require(identifier(packet["epoch"]) and integer(packet["base_seq"], 1), "sequence")
            obs = self.current()["observation"]
            require(obs["version"] == 3, "version")
            return self.history.project(obs, packet["epoch"], packet["base_seq"])
        exact(packet, set())
        if path == "/v1/observation":
            return self.current()
        if path == "/v1/stop":
            return self.stop()
        raise Rejected("route")


def handler_for(broker):
    class Handler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.0"

        def setup(self):
            super().setup()
            self.connection.settimeout(2)

        def log_message(self, *args):
            pass

        def do_POST(self):
            try:
                require(self.client_address[0] == "127.0.0.1", "local_only")
                require(len(self.headers.get_all("Authorization", [])) == 1, "unauthorized")
                require(self.headers.get("Origin") is None, "browser_origin")
                require(self.headers.get("Transfer-Encoding") is None, "encoding")
                require(self.headers.get("Content-Type") == "application/json", "content_type")
                lengths = self.headers.get_all("Content-Length", [])
                require(len(lengths) == 1 and lengths[0].isdigit(), "size")
                length = int(lengths[0])
                require(0 < length <= LIMIT, "size")
                raw = self.rfile.read(length)
                require(len(raw) == length, "size")
                result = broker.route(self.path, self.headers.get("Authorization"), decode(raw))
                status = 200
            except (Rejected, TimeoutError, OSError, OverflowError) as error:
                result = {"error": str(error) if isinstance(error, Rejected) else "transport"}
                status = 403 if result["error"] == "unauthorized" else 400
            body = json.dumps(result, ensure_ascii=True).encode()
            if len(body) > LIMIT:
                status, body = 400, b'{"error":"output_limited"}'
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
    return Handler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["discover"], nargs="?")
    parser.add_argument("--config", type=Path)
    args = parser.parse_args()
    if args.command == "discover":
        print(json.dumps(discovery(), sort_keys=True))
        return
    require(args.config is not None, "config")
    cfg = decode(args.config.read_bytes())
    exact(cfg, {"enabled", "assignment", "game_token_env", "controller_token_env"})
    require(cfg["enabled"] is True, "disabled")
    require(identifier(cfg["game_token_env"]) and identifier(cfg["controller_token_env"]), "credential_env")
    broker = Broker(cfg["assignment"], os.environ.get(cfg["game_token_env"], ""),
                    os.environ.get(cfg["controller_token_env"], ""), audit=lambda e: print(json.dumps(e), flush=True))
    # Deliberately fixed loopback endpoint; no configurable host, URL or proxy.
    with HTTPServer(("127.0.0.1", 9847), handler_for(broker)) as server:
        server.serve_forever(poll_interval=0.5)


if __name__ == "__main__":
    main()
