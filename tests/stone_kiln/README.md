# Campfire kiln checks

`test_source.py` inspects the production upgrade, payment and shared fuel contracts. Its projected wait cases include omitted-guard controls for completed saves, extinguish/relight, insufficient stone, occupied fire and an active stove pot. These are source-only checks; they do not execute DM, callbacks or serialization. Native timing, inventory, fuel and save/load acceptance remain outstanding.

The vessel dispatch checks project filled and empty flammable mugs, non-harm and explicit harm intent, liquid fuel, and mixed fuel/unsupported contents. A removed-guard control reproduces implicit solid-fuel treatment of a filled mug. The checks inspect dispatch ordering and the IDs targeted for removal; they do not execute the kiln or observe real inventories.

The bucket check uses the actual flammable `/glass/bucket` definition and its nonflammable steel subtype. It projects empty, filled, liquid-fuel and invalid-holder cases, with a control restoring the old glass-first dispatch. Both open and closed empty buckets are eligible; nonempty or inconsistent holders do not use the new empty-vessel shortcut.

The first hot-stone source-suite run against this change failed its exact persistence-exclusion string because the campfire gained a third runtime-only field. The assertion now includes that field while retaining both original exclusions; the original guards and controls remain present.
