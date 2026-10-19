"""Bounded snapshot/delta projection; accepts already validated public rows only."""
from collections import OrderedDict
import copy
import json


class ObservationHistory:
    def __init__(self):
        self.epoch = None
        self.assignment = None
        self.rows = OrderedDict()

    def remember(self, obs):
        scope = (obs["assignment"], obs["epoch"])
        if scope != (self.assignment, self.epoch):
            self.rows.clear()
            self.assignment, self.epoch = scope
        # Round-trip ownership: callers cannot mutate retained observations.
        self.rows[obs["observation_seq"]] = copy.deepcopy(obs)
        while len(self.rows) > 4 or sum(len(json.dumps(v, ensure_ascii=True).encode()) for v in self.rows.values()) > 131072:
            self.rows.popitem(last=False)

    def project(self, obs, epoch, base):
        full = {"version": 3, "kind": "snapshot", "reset_required": True,
                "observation": copy.deepcopy(obs)}
        if epoch != self.epoch or base not in self.rows or base > obs["observation_seq"]:
            return full
        old = self.rows[base]
        # A limited set cannot assert which unvisited entities disappeared.
        if not old["complete"] or not obs["complete"]:
            return full
        before = {e["id"]: e for e in old["entities"] + old["inventory"]}
        after = {e["id"]: e for e in obs["entities"] + obs["inventory"]}
        changed = {key for key in after if before.get(key) != after[key]}
        result = {"version": 3, "kind": "delta", "reset_required": False,
                  "assignment": obs["assignment"], "epoch": self.epoch,
                  "base_seq": base, "observation_seq": obs["observation_seq"],
                  "removed": sorted(set(before) - set(after)),
                  "entities": [copy.deepcopy(e) for e in obs["entities"] if e["id"] in changed or e["id"] not in {x["id"] for x in old["entities"]}],
                  "inventory": [copy.deepcopy(e) for e in obs["inventory"] if e["id"] in changed or e["id"] not in {x["id"] for x in old["inventory"]}],
                  "status": copy.deepcopy(obs["status"]), "messages": copy.deepcopy(obs["messages"]),
                  "capabilities": list(obs["capabilities"]), "next_action_seq": obs["next_action_seq"],
                  "complete": True, "limit_reason": "none", "laws": None}
        # No caller may turn a small request into an oversized response.
        return result if len(json.dumps(result, ensure_ascii=True).encode()) <= 32768 else full
