"""Fail-closed autopilot action receipts. No sockets, credentials, or game rules here."""

import concurrent.futures
import json
import threading
import time
import uuid
from pathlib import Path

from civ13_agent import AgentError, ContractError, READ_ONLY_ACTIONS


def _integer(value):
    return type(value) is int and value > 0


def _flag(value):
    return type(value) in (bool, int) and value in (0, 1)


class QueueClient:
    """One accepted queue per character. Ambiguous writes require operator reconciliation.

    Observations refresh single-use server guards. Receipt checks run before the
    senses cache sees the observation; the actual world rules still own execution.
    """

    def __init__(self, client, pause_file=""):
        self.client = client
        self.agent = client.agent
        self.pause_file = Path(pause_file) if pause_file else None
        self.guards = {}
        self.pending = {}
        self.uncertain = {}
        self.halted = False
        self.lock = threading.Lock()

    def paused(self):
        return self.pause_file is not None and self.pause_file.exists()

    def request(self, action, args=None):
        if not self.lock.acquire(blocking=False):
            raise ContractError("another request is pending")
        try:
            return self._request(action, dict(args or {}))
        finally:
            self.lock.release()

    def _request(self, action, args):
        character = args.get("character")
        mutation = action not in READ_ONLY_ACTIONS
        cancelling = action == "character_queue" and args.get("clear") is True and not args.get("actions")
        if mutation and not cancelling and action != "character_release":
            if self.halted:
                raise ContractError("previous action outcome is uncertain; reconcile before restarting")
            if self.paused():
                raise ContractError("operator pause requested")
        if action == "character_observe" and character in self.pending:
            # Never advance past a running low-id step when a cancelled suffix
            # has already produced higher-id receipts.
            args["queue_since"] = min(self.pending[character]["ids"]) - 1
        if action == "character_queue":
            if cancelling:
                pending = self.pending.get(character, {})
                target = pending.get("request_id") or self.uncertain.get(character)
                if not target:
                    return {"ok": True, "result": {"state": "accepted", "queued": []}}
                args["cancel_request_id"] = target
            if character in self.pending and not cancelling:
                raise ContractError("an accepted action is still pending")
            guard = self.guards.pop(character, None)
            if not isinstance(guard, str) or not guard:
                raise ContractError("a fresh observation is required before a queue mutation")
            args["guard"] = guard
        try:
            reply = self.client.request(action, args)
            if not isinstance(reply, dict):
                raise ContractError("malformed response")
            if mutation and not reply.get("ok") and reply.get("error") in ("runtime_error", "response_too_large"):
                raise ContractError("mutation reply cannot establish its outcome")
            if reply.get("ok") and action == "character_queue":
                self._accepted(character, args, reply, cancelling)
            elif reply.get("ok") and action == "character_observe":
                self._observed(character, reply.get("result"))
                reply["operator_paused"] = self.paused()
            return reply
        except KeyboardInterrupt:
            if action == "character_queue" and not cancelling:
                self.halted = True
                self.uncertain[character] = self.client.last_request_id
            raise
        except (OSError, AgentError, ValueError, TypeError, KeyError) as exc:
            if mutation or character in self.pending:
                self.halted = True
            if action == "character_queue" and not cancelling:
                self.uncertain[character] = self.client.last_request_id
            if self.halted and not isinstance(exc, ContractError):
                raise ContractError("action outcome is uncertain; reconcile before restarting") from exc
            raise

    def _accepted(self, character, args, reply, cancelling):
        result = reply.get("result")
        ids = result.get("queued") if isinstance(result, dict) else None
        request_id = reply.get("request_id")
        actions = args.get("actions") or []
        if (not isinstance(result, dict) or not request_id or result.get("request_id") != request_id or result.get("state") != "accepted"
                or not isinstance(ids, list) or len(ids) != len(actions)
                or any(not _integer(i) for i in ids) or ids != sorted(set(ids))):
            raise ContractError("malformed acceptance receipt; outcome is uncertain")
        if cancelling:
            # Cancellation acknowledges pending removal, not rollback of in-flight game work.
            self.pending.pop(character, None)
            self.uncertain.pop(character, None)
        elif ids:
            self.pending[character] = {"request_id": request_id, "ids": ids,
                                       "actions": [a["do"] for a in actions], "results": {}}

    def _observed(self, character, result):
        queue = result.get("queue") if isinstance(result, dict) else None
        if (not isinstance(queue, dict) or not isinstance(queue.get("pending"), list)
                or not isinstance(queue.get("results"), list) or not _flag(queue.get("running"))
                or not isinstance(result.get("self"), dict)):
            raise ContractError("malformed queue observation")
        guard = queue.get("guard")
        if not isinstance(guard, str) or len(guard) != 32:
            raise ContractError("server lacks guarded queue support")
        self.guards[character] = guard
        pending = self.pending.get(character)
        if not pending:
            return
        rows = queue["results"]
        seen = set()
        last = 0
        for row in rows:
            if not isinstance(row, dict) or not _integer(row.get("id")) or row["id"] in seen or row["id"] <= last:
                raise ContractError("duplicate, malformed or out-of-order completion receipt")
            seen.add(row["id"])
            last = row["id"]
            if row["id"] not in pending["ids"]:
                continue
            index = pending["ids"].index(row["id"])
            if (row.get("request_id") != pending["request_id"] or row.get("state") != "completed"
                    or row.get("do") != pending["actions"][index] or not _flag(row.get("ok"))
                    or not isinstance(row.get("detail"), str)):
                raise ContractError("completion does not match the accepted action")
            old = pending["results"].get(row["id"])
            if old is not None and old != row:
                raise ContractError("completion receipt changed after publication")
            pending["results"][row["id"]] = dict(row)
        queue["results"] = [pending["results"][i] for i in pending["ids"] if i in pending["results"]]
        if not queue["pending"] and not queue["running"] and not result["self"].get("busy"):
            if len(pending["results"]) != len(pending["ids"]):
                raise ContractError("queue ended without every completion receipt; outcome is uncertain")
            del self.pending[character]


def decision_state(observation):
    """Stable action context, excluding naturally ticking needs and observation cursors."""
    me = observation.get("self") or {}
    keys = ("ref", "x", "y", "z", "stat", "can_move", "busy", "intent", "active_hand",
            "left_hand", "right_hand", "carried", "worn", "items")
    return json.dumps({key: me.get(key) for key in keys}, sort_keys=True, separators=(",", ":"))


def targets_current(plan, before, after):
    def rows(observation):
        return {r.get("ref"): r for key in ("nearby", "terrain") for r in observation.get(key, []) if isinstance(r, dict)}
    old, new = rows(before), rows(after)
    own = (before.get("self") or {}).get("ref")
    for step in plan:
        for key in ("target", "onto"):
            ref = step.get(key)
            if not ref or ref == own:
                continue
            if ref not in old or ref not in new:
                return False
            # Safety and availability metadata matters too. A lit oven burns
            # fuel continuously, so positive fuel drift alone is not a new target.
            # Losing its usable fuel is a material change. Expansion uses the
            # fresh row rather than the old fuel amount in either case.
            left, right = dict(old[ref]), dict(new[ref])
            for row in (left, right):
                fuel = row.get("fuel")
                if type(fuel) in (int, float):
                    row["fuel"] = "available" if fuel > 0 else "empty"
            if left != right:
                return False
    return True


class DecisionSlot:
    """A model answer belongs to one observation and may be consumed only once."""

    def __init__(self, clock=time.monotonic):
        self.clock = clock
        self.pending = None

    def begin(self, observation, timeout):
        if self.pending is not None:
            raise ContractError("a model decision is already pending")
        ident = uuid.uuid4().hex
        self.pending = (ident, self.clock() + timeout, decision_state(observation))
        return ident

    def complete(self, ident, observation):
        pending = self.pending
        if pending is None or pending[0] != ident:
            raise ContractError("unsolicited, duplicate or out-of-order model decision")
        self.pending = None
        return self.clock() <= pending[1] and decision_state(observation) == pending[2]

    def cancel(self):
        self.pending = None


class ModelWorker:
    """One inference-only daemon thread; cancellation never waits for a hung HTTP call.

    A timed-out worker is not reused. It has no game client and cannot apply late
    answers. The daemon may finish its HTTP request, but cannot hold process exit.
    """

    def __init__(self):
        self.future = None

    def submit(self, function, *args, **kwargs):
        if self.future is not None and not self.future.done():
            raise ContractError("an inference call is already pending")
        future = concurrent.futures.Future()
        self.future = future

        def invoke():
            if not future.set_running_or_notify_cancel():
                return
            try:
                future.set_result(function(*args, **kwargs))
            except BaseException as exc:
                future.set_exception(exc)

        threading.Thread(target=invoke, name="civ13-model", daemon=True).start()
        return future
