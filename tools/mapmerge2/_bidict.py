"""Minimal stand-in for the `bidict` package, used only when it is not installed.

Civ13 addition: lets the map lint and parser run in CI with the standard
library alone. It implements only what dmm.py uses: item get/set/delete,
`inv`, `forceput`, and the duplication errors.
"""


class DuplicationError(Exception):
    pass


class ValueDuplicationError(DuplicationError):
    pass


class bidict(dict):
    def __init__(self):
        super().__init__()
        self.inv = {}

    def __setitem__(self, key, value):
        owner = self.inv.get(value, key)
        if owner != key:
            raise ValueDuplicationError(value)
        if key in self:
            del self.inv[dict.__getitem__(self, key)]
        dict.__setitem__(self, key, value)
        self.inv[value] = key

    def __delitem__(self, key):
        value = dict.__getitem__(self, key)
        dict.__delitem__(self, key)
        del self.inv[value]

    def forceput(self, key, value):
        owner = self.inv.get(value)
        if owner is not None and owner != key:
            dict.__delitem__(self, owner)
        if key in self:
            self.inv.pop(dict.__getitem__(self, key), None)
        dict.__setitem__(self, key, value)
        self.inv[value] = key

    def copy(self):
        clone = bidict()
        dict.update(clone, self)
        clone.inv = dict(self.inv)
        return clone
