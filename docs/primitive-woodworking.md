# Manual splitting and whittling

This local implementation follows the user's requested hammer/wedge splitting,
small-piece whittling, crude planks and flattening. The video reference is
[the supplied woodworking example at 13:20](https://www.youtube.com/watch?v=7P4eCopYK_Q&t=800s).
The parent supplied a transcript summary about wedges, splitting and side-axe
finishing; video frames were not verified here. The user's direct clarification,
not an inference from those frames, defines this behavior. Existing wooden-handle
reuse is confirmed by Civ13 source, not by the video.

## Gathered-material chain

1. Obtain actual logs and sharpened flint, or a sharp **knife** whose actual
   `get_material().hardness` exceeds the workpiece's material hardness. Supported
   knife families are material kitchen knives and both material throwing-knife
   families. Equal
   hardness rejects. Arbitrary harder swords, axes or other non-knives do not
   qualify as whittling tools. Ordinary wood is supported; this does not silently
   turn hardwood or bamboo into ordinary wood.
2. Use the held shaping tool on logs to cut a small wood piece. These pieces
   have their own stack/material identity and cannot merge into logs or planks.
3. Use the shaping tool on a wood-piece stack and select a wooden wedge or
   simple wooden mallet. The mallet reuses the existing item and art. The wedge
   reuses sharpened-stick art, but has its own minimal tool type so it cannot
   silently become a flint-axe shaft or hot-stone stick. Existing five-log hammer
   crafting also remains available.
4. Hold a wooden hammer/mallet actively and the wooden wedge in the other hand;
   use the hammer on logs on reachable ground. This requires no axe or saw and
   produces **crude planks**. A metal clawhammer is not a wooden hammer.
5. Use held sharpened flint or another actually sharp tool whose working material
   is non-wood to flatten crude planks one-for-one into finished planks.
   **Flattening does not debit tool durability or call its wear helper.**
   A metal axe with a wooden handle qualifies: `get_material()` describes its
   working head. Wooden working materials (including hardwood/plank subtypes),
   unsharpened flint and unverified/unknown materials reject. The exact legacy
   bronze scalpel also qualifies: its existing bronze recipe identifies the
   working material despite its absent material API. Generic scalpels and unknown
   subclasses receive no guessed material. Crude planks are not subclasses of finished planks and have
   `processing_only = TRUE`, so existing plank recipes cannot use them.
6. Existing recipes still make a wood handle from one finished plank, or a plank
   handle from two. They remain reusable hot-stone tools under that separate
   water implementation. No handle recipe or spawn equipment is changed.

## Explicit balance assumptions for review

| Action | Paid input -> output | Base wait, divided by strength |
|---|---|---|
| Cut workable piece | 1 log -> 1 small piece + 1 bark | 120 ds |
| Whittle wedge | 1 small piece -> 1 wooden wedge | 120 ds |
| Whittle mallet | 5 small pieces -> existing wooden mallet | 240 ds |
| Hammer/wedge split | 2 logs -> 1 crude plank + 2 bark | 240 ds |
| Sharp non-wood tool flatten | 1 crude plank -> 1 finished plank | 80 ds |

These are game abstractions, not measured historical production. One usable small
piece per log is deliberately conservative; it avoids introducing fractional log
units or producing multiple items that generic flammable-fuel fallbacks could
value above the original log. No offcut item is created. The mallet costs the
same five-log input equivalent as existing wooden-hammer crafting. Bark is paid
once per original log, never again when whittling a piece or flattening a plank.

The split yield matches the existing ordinary axe conversion's two logs per
finished plank, with 240 + 80 ds of work instead of its 80-ds cut. The integrated
sawmill checkpoint `d3c33c561fdcb3e85a581482b43f8668d4789306` supplies one finished
plank per log at the primitive station, with its 20-ds cut and station advantage.
Its production source is retained unchanged; this integration does not rebalance
the owner's larger/powered mills. The existing direct axe and
hand-saw conversion code is unchanged except for refusing logs owned by a pending
woodworking action.

Material knives and the wooden wedge lose 0.25 durability per successful applicable
job, matching the existing small tool-wear increment. Cancelled jobs charge none.
Flint and existing non-material hammers keep their current wear convention.
The user's zero-wear rule applies to all tools flattening crude planks. Whittling
keeps its separate flint-or-harder-knife rule; a harder sword can flatten but cannot
whittle.

## Bootstrap feasibility and limits

The wedge and mallet can be made without an axe or finished planks: stocked rock
-> flint -> sharpen against rock (20% success per strike), actual timber -> logs
-> wood pieces -> whittle tools. The existing generic plant-damage path permits
sharp flint to expose logs, although it is not timed native harvesting evidence.
One wedge, one mallet and the first crude plank require eight logs in this
whittled-mallet route; the same sharpened flint can flatten it into a finished plank
for the existing handle recipe. This removes the branch/axe requirement from this
new route. Whittling itself never waits for finished planks. With the mug and fire,
the conservative whittled-mallet route spends thirteen logs before its first
potential boiled drink; actual gathering, travel and dehydration timing are unknown.

Actual flint-bearing rock, timber and a safe route remain map-dependent. The Gaia
puddle/palm-spawner witnesses do not guarantee those inputs or a dehydration
margin. No automatic spawn gear, map cache or death/respawn resource reward is
added. Peg joinery, furniture and additional whittled products are outside scope.

## Transaction and save boundaries

Each wait snapshots the exact source stack, amount, direct location/turf, actor
turf, active tool, tool health/material, workpiece hardness, and any held wedge.
Source, actor, tool and wedge have one runtime owner. Both boundary checks require
conscious connected ownership and the same tools/materials; legacy axe/saw cutting
also refuses an owned log stack. Stack split/merge, transfer, tool loss, competing
wear, burning and cancellation refuse output. A second commit is refused.

The water checkpoint `69f4866babe83a68896c4219a30193e72d4ac7e2` supplies the shared
admitted save/load identity. Woodworking snapshots that identity and invalidates
waits even if the operation finishes before the wait returns; it adds no second
operation constructor. Busy
save, active operation and recovery holds also refuse work. `woodwork_owner` is
excluded on export/import; action datums have `should_save = FALSE`. No wait is
resumed after loading. The commit uses the normal stack debit **without a human
argument** (no Production-religion discount), checks the resulting amount, then
creates output stacks with final counts before automatic merging. Ownership stays
claimed through constructors and is released only by the matching action.

## Verification and integration

`tests/primitive_woodworking` projects the actual source constructor, admission,
commit and release bodies with injected waiting, type, constructor and stack
boundaries. It covers cancellation, transfers, repeated/exhausted stacks, reentry,
tool loss, knife hardness/type, save-completed-during-wait, distinct crude material,
flattening conservation and unchanged tool wear. Guard-removal controls reproduce
false completion and harder non-knife admission. These are **offline source
projections**, not a DM compiler, native movement, real callbacks or save round trip.
The focused hosted command is wired into the existing evidence-checker job.
The bounded baseline also selects woodworking on production or modified-test
changes. Shared material/Atlas dependencies retain the conservative all-suite
fallback; selector regression cases prevent narrowing that coverage.

The Atlas exporter reads quantities from `woodwork_spec`, supplies the same
acquisition steps to Help, and registers genuine reused sprite states. Tanning
source digests are refreshed only after reviewing unchanged tanning conversions,
unchanged direct axe/saw yields, the added legacy log-owner guard and the two new
material declarations. The focused tanning regression includes that owner guard.

Before publication Main retains independent source/design review and runtime
acceptance. Compiler and offline results belong to the exact integration evidence
packet. No native world, save or live action was run by this task, and no
publication is authorized here.
