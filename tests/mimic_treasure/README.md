# Mimic treasure initialization

Run `python -B tests/mimic_treasure/test_initialization.py -v` with a working
Python 3 interpreter. This offline source projection checks the mimic death
constructor, each rarity branch and boundary using minimum random counts,
saved-construction ordering, and stack-only amount randomization. It checks the
crate parent's population loop before projecting its input; unfamiliar source
shapes fail for review. The pre-fix parent-first constructor fails all rarity
cases because its selected loot table does not exist at the parent call.

This is not a DM compile, native execution, real save/load, or map playthrough.
