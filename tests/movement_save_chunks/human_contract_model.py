"""Proposed human group contract. Offline model only; this is not DM execution.

Admission explicitly requires capabilities production does not yet provide.
The model does not claim to observe production serializer references.
"""
from copy import deepcopy


class Refused(Exception):
    pass


class MovementDenied(Exception):
    pass


class HumanCapture:
    def __init__(self, humans, inventory, *, capabilities):
        self.humans = deepcopy(humans)
        self.inventory = deepcopy(inventory)
        self.capabilities = set(capabilities)
        self.roster = tuple(humans)
        self.admitted = False
        self.records = {}
        self.item_groups = {}
        self.prior_entries = set()
        self.spatial = {}
        self.failed = False
        self.marker = None
        self.previous = {"marker": "old", "bytes": b"previous complete generation"}
        self.working = False

    def refuse(self, reason):
        self.failed = True
        self.working = False
        raise Refused(reason)

    def admit(self):
        # Evidence of these capabilities is a prerequisite, not a feature flag.
        if not {"hooks_audited", "reference_fence", "all_player_paths"} <= self.capabilities:
            self.refuse("missing audited capture capability")
        if len(self.humans) > 8192:
            self.refuse("roster bound")
        self.admitted = True

    def capture(self, root, *, during_capture=None):
        if not self.admitted or self.failed or root not in self.humans:
            self.refuse("missing root")
        if root in self.records:
            return
        human = self.humans[root]
        if not human.get("direct_turf") or human.get("coupled") or human.get("inflight"):
            self.refuse("unsupported human")
        ids = set(human["owned"])
        if len(ids) > 128 or root in ids:
            self.refuse("group bound or cycle")
        if any(item not in self.inventory for item in ids):
            self.refuse("missing item")
        if ids & self.prior_entries:
            self.refuse("member captured before group")
        if any(item in self.item_groups and self.item_groups[item] != root for item in ids):
            self.refuse("member already captured by another group")
        if any(self.inventory[item]["owner"] not in ids | {root} for item in ids):
            self.refuse("external owner")
        for item in ids:
            seen = set()
            parent = item
            while parent != root:
                if parent in seen or parent not in ids:
                    self.refuse("cycle or escaping owner")
                seen.add(parent)
                parent = self.inventory[parent]["owner"]
        if any(item is not None and (item not in ids or self.inventory[item]["owner"] != root)
               for item in human["slots"].values()):
            self.refuse("slot and containment differ")
        before = deepcopy((human, {item: self.inventory[item] for item in ids}))
        self.working = True
        try:
            if during_capture:
                during_capture(self)
        except Exception:
            self.failed = True
            self.working = False
            raise
        if before != (self.humans.get(root), {item: self.inventory.get(item) for item in ids}):
            self.refuse("capture changed or yielded")
        self.records[root] = before
        for item in ids:
            self.item_groups[item] = root
        self.working = False

    def move(self, root, turf, z):
        if z != self.humans[root]["z"]:
            raise MovementDenied("cross-level movement")
        self.humans[root]["turf"] = turf

    def transfer(self, item, new_owner):
        """Model live mutation; detection happens on subsequent export edges."""
        self.inventory[item]["owner"] = new_owner

    def observe_item(self, item, source_root, *, traversal=False):
        """A field reference across captured groups fails; turf rediscovery skips."""
        group = self.item_groups.get(item)
        if group is None:
            self.prior_entries.add(item)
            return True
        if group != source_root:
            if traversal:
                return False
            self.refuse("cross-group field reference")
        return True

    def finish(self):
        if not self.admitted or self.failed:
            self.refuse("already failed")
        if set(self.humans) != set(self.roster):
            self.refuse("roster changed")
        for root in self.roster:
            live = self.humans[root]
            self.capture(root)
            saved, _ = self.records[root]
            if live["z"] != saved["z"] or not live.get("direct_turf"):
                self.refuse("root changed level or owner")
            if root in self.spatial and self.spatial[root] != saved["turf"]:
                self.refuse("duplicate spatial owner")
            self.spatial[root] = saved["turf"]
        self.marker = "new"
