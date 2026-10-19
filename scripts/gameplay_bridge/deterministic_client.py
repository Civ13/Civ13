"""Deterministic v3 controller client. Importing never performs network work.

One immutable action per invocation; no model, assignment or gameplay shortcuts.
Use only after separate source/runtime/auth/client allocation and explicit --send.
"""
import argparse
import copy
import json
import math
import os
from pathlib import Path
import re
import socket
import time

from bridge import (LIMIT, Rejected, action_valid, decode, exact, identifier,
                    integer, observation_valid, text)
from catalog import CONTROL_FIELDS, ENVELOPE_FIELDS, REASONS, STATES, WIRE_FINAL

PATHS = frozenset(("/v1/observation", "/v1/action", "/v1/stop"))
ADDRESS = ("127.0.0.1", 9847)
TOKEN_ENV = "CIV13_GAMEPLAY_CONTROLLER_TOKEN"
MAX_SECONDS = 120
RESERVE = 2
MAX_CALLS = 128


class Failure(Exception):
    """Only fixed local codes are emitted, never exception text or peer data."""


def need(condition, code):
    if not condition:
        raise Failure(code)


def encode(value):
    try:
        raw = json.dumps(value, ensure_ascii=True, allow_nan=False).encode("ascii")
        need(0 < len(raw) <= LIMIT, "json_bound")
        decode(raw)
        return raw
    except (Rejected, ValueError, TypeError, RecursionError):
        raise Failure("invalid_json") from None


def credential(value):
    need(isinstance(value, str) and 32 <= len(value) <= 256 and
         all(33 <= ord(c) <= 126 for c in value), "credential_unavailable")
    return value


def load_token(path=None):
    # Read an operator-supplied existing credential; never create or print one.
    try:
        if path is None:
            return credential(os.environ.get(TOKEN_ENV, ""))
        with Path(path).open("rb") as stream:
            raw = stream.read(259)
        need(len(raw) <= 258, "credential_unavailable")
        return credential(raw.rstrip(b"\r\n").decode("ascii"))
    except (OSError, UnicodeError):
        raise Failure("credential_unavailable") from None


def wire_post(path, raw, token, deadline, clock=time.monotonic):
    """Fixed loopback, no proxy/redirect, bounded HTTP/JSON and absolute deadline.

    Every socket operation uses remaining time; incremental header/body reads
    cannot renew the overall budget by dribbling bytes. Tests replace the socket.
    """
    need(path in PATHS and type(raw) is bytes and 0 < len(raw) <= LIMIT, "endpoint_or_bound")
    credential(token)
    def remaining():
        left = deadline - clock()
        need(math.isfinite(left) and left > 0, "deadline")
        return min(8, left)
    connection = None
    try:
        connection = socket.create_connection(ADDRESS, timeout=remaining())
        connection.settimeout(remaining())
        headers = ("POST "+path+" HTTP/1.0\r\nHost: 127.0.0.1:9847\r\n"
                   "Content-Type: application/json\r\nAuthorization: Bearer "+token+
                   "\r\nContent-Length: "+str(len(raw))+"\r\nConnection: close\r\n\r\n")
        connection.sendall(headers.encode("ascii")+raw)
        remaining()
        data = b""
        while b"\r\n\r\n" not in data:
            connection.settimeout(remaining())
            part = connection.recv(1024)
            remaining()
            need(part, "http_framing")
            data += part
            need(len(data) <= 4096+1024, "http_header_bound")
        header, body = data.split(b"\r\n\r\n", 1)
        need(len(header) <= 4096, "http_header_bound")
        lines = header.decode("ascii").split("\r\n")
        need(bool(re.fullmatch(r"HTTP/1\.[01] 200(?: [ -~]*)?", lines[0])), "http_status")
        need(len(lines) <= 33, "http_header_bound")
        fields = {}
        for line in lines[1:]:
            need(":" in line and not line.startswith((" ", "\t")), "http_framing")
            key, value = line.split(":", 1)
            key, value = key.lower(), value.strip()
            need(re.fullmatch(r"[a-z-]+", key) and key not in fields, "http_framing")
            fields[key] = value
        need("transfer-encoding" not in fields and fields.get("content-type") == "application/json"
             and re.fullmatch(r"[0-9]{1,5}", fields.get("content-length", "")), "http_framing")
        length = int(fields["content-length"])
        need(0 < length <= LIMIT and len(body) <= length, "json_bound")
        while len(body) < length:
            connection.settimeout(remaining())
            part = connection.recv(min(4096, length-len(body)))
            remaining()
            need(part, "http_framing")
            body += part
        return body
    except (OSError, UnicodeError, ValueError):
        raise Failure("transport_or_framing") from None
    finally:
        if connection is not None:
            connection.close()


def action_request(value):
    try:
        exact(value, ENVELOPE_FIELDS)
        need(type(value["version"]) is int and value["version"] == 3, "version")
        need(all(identifier(value[k]) for k in ("assignment", "epoch", "request_id")), "scope")
        need(all(integer(value[k], 1) for k in ("observation_seq", "action_seq")), "sequence")
        action_valid(value["action"])
        encode(value)
        return copy.deepcopy(value)
    except (Rejected, KeyError, TypeError):
        raise Failure("invalid_action") from None


def control_request(value, operation=None):
    try:
        exact(value, CONTROL_FIELDS)
        need(type(value["version"]) is int and value["version"] == 3 and
             all(identifier(value[k]) for k in ("assignment", "epoch", "request_id")) and
             value["operation"] in ("status", "cancel") and
             (operation is None or value["operation"] == operation), "invalid_control")
        return copy.deepcopy(value)
    except (Rejected, KeyError, TypeError):
        raise Failure("invalid_control") from None


def receipt(value, request_id):
    try:
        exact(value, {"request_id", "status", "reason", "detail"})
        need(value["request_id"] == request_id and value["status"] in STATES and
             value["reason"] in REASONS and text(value["detail"], 512), "invalid_receipt")
        expected = {"completed":"none", "queued":"none", "dispatched":"none", "running":"none",
                    "cancel_requested":"cancel_requested", "cancelled":"cancelled", "unknown":"transport_uncertain"}
        need(value["reason"] == expected[value["status"]] if value["status"] in expected
             else value["reason"] != "none", "invalid_receipt")
        return {k:value[k] for k in ("request_id", "status", "reason")}
    except (Rejected, KeyError, TypeError):
        raise Failure("invalid_receipt") from None


class Client:
    def __init__(self, token, *, seconds=30, transport=wire_post, clock=time.monotonic, sleep=time.sleep):
        self._token = credential(token)
        need(type(seconds) is int and 5 <= seconds <= MAX_SECONDS, "budget")
        self.clock, self.sleep, self.transport = clock, sleep, transport
        self.last = self.now()
        self.deadline = self.last+seconds
        self.work_deadline = self.deadline-RESERVE
        self.calls = 0

    def now(self):
        value = self.clock()
        need(type(value) in (float,int) and math.isfinite(value) and
             value >= getattr(self, "last", value), "clock")
        self.last = value
        return value

    def call(self, path, value, *, reserve=False):
        deadline = self.deadline if reserve else self.work_deadline
        need(self.now() < deadline and self.calls < MAX_CALLS, "deadline")
        self.calls += 1
        raw = self.transport(path, encode(value), self._token, deadline, self.now)
        need(self.now() < deadline and type(raw) is bytes and len(raw) <= LIMIT, "deadline_or_bound")
        try:
            result = decode(raw)
            need(type(result) is dict and "error" not in result, "peer_rejected")
            return result
        except Rejected:
            raise Failure("invalid_json") from None

    def observe(self):
        value = self.call("/v1/observation", {})
        try:
            exact(value, {"observation"})
            obs = value["observation"]
            observation_valid(obs)
            need(obs["version"] == 3, "version")
            return copy.deepcopy(obs)
        except (Rejected, KeyError, TypeError):
            raise Failure("invalid_observation") from None

    def control(self, request, *, reserve=False):
        request = control_request(request)
        return receipt(self.call("/v1/action", request, reserve=reserve), request["request_id"])

    def stop(self):
        value = self.call("/v1/stop", {})
        need(value == {"status":"stopped"}, "invalid_stop")
        return dict(status="stopped", worker_quiescence_verified=False)

    def action(self, request, *, cancel_after=None):
        request = action_request(request)
        need(cancel_after is None or (type(cancel_after) in (int,float) and
             math.isfinite(cancel_after) and 0 <= cancel_after <= 30), "cancel_budget")
        control = {k:request[k] for k in ("version", "assignment", "epoch", "request_id")}
        control["operation"] = "status"
        attempted = False
        known = False
        result = dict(status="not_submitted", reason="local_precondition", terminal_receipt=False)
        try:
            obs = self.observe()
            need(obs["complete"] and obs["status"]["conscious"] and obs["status"]["mobile"], "observation_incomplete_or_blocked")
            need(all(request[k] == obs[k] for k in ("assignment", "epoch", "observation_seq")) and
                 request["action_seq"] == obs["next_action_seq"], "stale_scope")
            action = request["action"]
            need(action["type"] in obs["capabilities"], "capability")
            if "target" in action:
                target = next((r for r in obs["entities"]+obs["inventory"] if r["id"] == action["target"]), None)
                need(target is not None and action["type"] in target["actions"], "target_unavailable")
                if action["type"] == "craft":
                    need(action["recipe"] in target["recipes"], "recipe_unavailable")
            if action["type"] == "move":
                dx,dy = {"north":(0,1),"south":(0,-1),"east":(1,0),"west":(-1,0)}[action["direction"]]
                need(any(r["kind"] == "tile" and (r["dx"],r["dy"]) == (dx,dy) and
                         "move" in r["actions"] for r in obs["entities"]), "target_unavailable")
            # Mark uncertainty BEFORE send: a transport exception may follow delivery.
            attempted = True
            started = self.now()
            state = receipt(self.call("/v1/action", request), request["request_id"])
            cancelled = False
            for _ in range(64):
                if state["status"] in WIRE_FINAL:
                    known = True
                    result = dict(state, terminal_receipt=True)
                    break
                if cancel_after is not None and not cancelled and self.now()-started >= cancel_after:
                    state = self.control(dict(control,operation="cancel"))
                    cancelled = True
                    continue
                need(self.now()+1 < self.work_deadline, "deadline")
                self.sleep(1)
                state = self.control(control)
            else:
                raise Failure("poll_bound")
        except (Failure, Rejected, OSError, KeyError, TypeError):
            result = dict(status="unknown" if attempted else "not_submitted",
                          reason="transport_uncertain" if attempted else "local_precondition", terminal_receipt=False)
        if attempted and not known:
            # Scope-safe cancellation only; never automatically STOP a new epoch.
            try:
                state = self.control(dict(control,operation="cancel"), reserve=True)
                if state["status"] in WIRE_FINAL:
                    known = True
                    result = dict(state,terminal_receipt=True)
                else:
                    result["cancel_acknowledged"] = True
            except (Failure, Rejected, OSError, KeyError, TypeError):
                result["cancel_acknowledged"] = False
            if not known:
                result["pending_control"] = control
        result["network_requests"] = self.calls
        return result


def public_observation(obs):
    # Own-session metadata only. Names, messages, detail and arbitrary peer text
    # are never printed; this output is private, not a sanitized public bundle.
    result = {k:obs[k] for k in ("version", "assignment", "epoch", "observation_seq",
              "next_action_seq", "complete", "limit_reason", "capabilities", "status")}
    for section in ("entities", "inventory"):
        result[section] = [{k:r[k] for k in ("id", "kind", "dx", "dy", "actions", "recipes")} for r in obs[section]]
    return result


class Parser(argparse.ArgumentParser):
    def error(self, message):
        raise Failure("invalid_cli")


def main(argv=None):
    try:
        parser = Parser(description=__doc__,allow_abbrev=False)
        parser.add_argument("command", choices=("observe", "action", "status", "cancel", "stop"))
        parser.add_argument("--input", type=Path)
        parser.add_argument("--token-file", type=Path)
        parser.add_argument("--seconds", type=int, default=30)
        parser.add_argument("--cancel-after", type=float)
        parser.add_argument("--send", action="store_true")
        args = parser.parse_args(argv)
        value = None
        need(5 <= args.seconds <= MAX_SECONDS, "budget")
        need(args.cancel_after is None or (math.isfinite(args.cancel_after) and
             0 <= args.cancel_after <= 30), "cancel_budget")
        need((args.command in ("action","status","cancel")) == (args.input is not None), "invalid_cli")
        need(args.cancel_after is None or args.command == "action", "invalid_cli")
        if args.input is not None:
            with args.input.open("rb") as stream:
                value = decode(stream.read(LIMIT+1))
            value = action_request(value) if args.command == "action" else control_request(value,args.command)
        if not args.send:
            output = dict(mode="offline_validation_only",network_requests=0)
        else:
            client = Client(load_token(args.token_file),seconds=args.seconds)
            if args.command == "observe":output = public_observation(client.observe())
            elif args.command == "action":output = client.action(value,cancel_after=args.cancel_after)
            elif args.command == "stop":output = client.stop()
            else:
                output = client.control(value)
                output["terminal_receipt"] = output["status"] in WIRE_FINAL
        print(encode(output).decode("ascii"))
        if args.send and args.command == "action" and not (
                output["terminal_receipt"] and output["status"] in ("completed", "cancelled")):
            return 3
        return 0
    except (Failure, Rejected, OSError, KeyError, TypeError, ValueError):
        print('{"error":"unavailable_or_invalid_input","network_or_gameplay_success":false}')
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
