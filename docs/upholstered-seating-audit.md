# Upholstered seating review - 2026-10-29

This slice reviews the next family after document drawers. Active material rows,
constructors, padding dispatch and generic recovery were inspected together.
Existing recipes are preserved. No additional recipe is justified in this slice.

| Existing global route | Constructor / interaction | Decision |
| --- | --- | --- |
| Padded wooden chair and wing-backed chair: six finished planks, Fine Furniture | Static wooden art, with stack/wirecutter interactions refused by the wooden-chair handler | Existing preindustrial wood routes; do not invent a second recipe or a removable textile ledger from baked-in art |
| Brown comfy chair: six leather, Basic Furniture | Steel frame plus leather padding; ordinary paid replacement/removal after unpadding | Preserve the legacy recipe; refuse the inherited generic wood refund for the nonwood comfy-chair family |
| Divan: nine leather, Fine Furniture | Wooden frame plus leather padding, inherited removable padding | Existing wood/leather construction abstraction; no arbitrary material alternative |
| Old sofa, left/centre/right: eight cloth each, Fine Furniture | Fixed art; empty add/remove-padding handlers; generic hammer previously returned one wood log | Refuse unsupported stack padding before any debit and refuse generic wood recovery |
| Chair sofa, left/centre/right | Same fixed-art/no-op padding behavior; map types without active material rows | Apply the same conservation rules to the inherited interaction, without inventing recipes |

The brown comfy-chair constructor explicitly supplies steel and leather. Other
colored comfy constructors also supply steel; fancy sofas and booths under that
family use leather material. Their common generic wood refund is therefore
refused at the comfy parent. Ordinary wooden chairs and beds retain their existing
recovery behavior. This does not add a recovered steel/leather bill to old crafted
or mapped objects whose original inputs are not recorded.

## Concrete fixes and material accounting

The bed stack handler spends one padding unit before invoking `add_padding`.
Both fixed sofa families override that procedure with an empty return. The old
path therefore loses one cloth/leather unit without changing the sofa, and a
second attempt can lose another. Each fixed sofa parent now refuses stack
interactions before reaching that debit. Non-stack dispatch still reaches the
existing bed/structure handlers.

Those fixed sofas also inherited `not_disassemblable = FALSE`: a hammer reached
the generic structure action and returned one wood log. The three eight-cloth
recipes could thus convert cloth to wood. Fixed sofas and the nonwood comfy-chair
family now refuse that generic recovery. No speculative refund is substituted.

Beds and stools already accept one paid cloth/leather padding unit. The first
hosted control exposed a third bug: those two material definitions have no
generic `stack_type`, so `place_sheet` returns nothing and removal discards the
padding reference. Upholstery recovery now has exact cloth/leather fallbacks to
their existing stack items. Other materials use their existing sheet mapping.
Removal clears the reference only after an item is returned, so an unmapped
material such as dark leather stays installed rather than disappearing or being
converted to ordinary hide. Repeat removal cannot mint additional material.
Bed/stool padding dismantling uses the same recovery helper. This is local to
upholstery; generic material metadata and other material recovery are unchanged.
Hammer dispatch also recovers supported padding before frame output/deletion and
refuses destruction while installed padding cannot be recovered. The bed check
runs after its existing wait, so cancellation does not strip padding and a late
change to unmapped padding refuses the frame refund. Unpadded wooden-bed recovery
is unchanged. These guards apply to intentional hammer teardown; combat and
explosion destruction keep their existing behavior.

## Period and appearance limits

The Met's [sixteenth-century Spanish walnut/leather armchair](https://www.metmuseum.org/art/collection/search/196742)
and [late-sixteenth-century Florentine walnut/leather armchair](https://www.metmuseum.org/art/collection/search/197332)
support wood-and-leather seating before industrial steel furniture. They do not
date the game's red/wing chair silhouettes, establish ancient/universal medieval
upholstery, or establish its material quantities. Existing Fine/Basic Furniture
tiers and legacy costs are gameplay gates and abstractions.

All existing sprites and constructor appearance are retained. The old-sofa art
remains a stylized existing object; this repair does not backdate it or introduce
a historically reconstructed sofa. A new removable upholstered wooden chair
would need an explicit material ledger and compatible visual states; duplicating
the current static wooden rows would not supply that behavior.

## Verification and remaining audit

Offline checks execute the actual sofa stack dispatch, the production bed
padding branch and the generic structure hammer branch through bounded inert
adapters. Controls deliberately enter the old no-op padding and wood-refund paths
and demonstrate material loss/conversion. Legacy rows and research/art identities
remain checked. Recovery tests execute the actual fallback, generic sheet factory
and bed/stool removal bodies, including exact material identity and an unmapped
dark-leather control. The compiled native fixture exercises all six fixed-art
sofa types, the three paid eight-cloth recipes, a steel comfy chair, paid bed/stool
cloth/leather removal and actual hammer teardown, refusal for dark-leather padding,
bed-wait cancellation/late-change guards and an unpadded wooden-bed hammer control.
Record hosted execution separately from compilation.

Connected-client presentation, natural resource/research reachability and world
save round trips are unverified by offline checks. This source review adds one
follow-on family and ten concrete output types to the audit index; inventory
membership does not imply historical or native acceptance of every route.
Remaining independent slices are canopy fold/unfold and roof-area lifecycle,
then production/storage stations such as barrels, cutting boards and kitchen
handlers. Full anvil, cooking, chemistry, clothing and weapons reviews remain
outside completed slices.
