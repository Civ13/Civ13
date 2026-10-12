# Tool assembly workbench

Craft a tool assembly workbench from 10 soft wood through the ordinary global
material catalog. Its construction takes 100 ticks. Maps that replace the global
catalog keep their own catalog; the bench does not unlock restricted components.

Use the bench with an empty hand to select Pickaxe, Shovel or Hatchet. Hold the
matching usable head and insert it by clicking the bench, then insert a usable
handle. Status reports the missing parts. Choose Assemble for a normal ten-second
action. Moving away, incapacitation, ingredient removal or cancelling prevents
completion. There are no timing minigames.

Choose Retrieve / cancel to place stored inputs or the finished tool on the bench's
tile. Cancelling keeps the ingredients; the bench remains busy until the current
action returns. Destroying the bench releases its contents. Two ingredients or
one finished tool fit at a time. Retrieve everything before changing recipes.

Assembly preserves the same head/handle material, quality, condition and bounded
stats as hand assembly. Existing hand recipes and the gunsmithing bench remain
available. Native saves retain staged parts and completed tools, while an active
assembly restarts as idle after load. Saved assembly time does not produce work
offline.

The interaction is inspired by the public Pocket Stronghold 13 workbench at
commit `2bfb1906a9a68f58c5e5da25383f83dd495bf138`. Implementation and graphics use
Civ13 sources and its existing workbench sprite; no upstream code or art is copied.
