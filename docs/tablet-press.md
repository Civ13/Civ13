# Calcium-bound tablet press

The global catalog adds a constructed tablet-press subtype for nominal 20
electronics and base 120 deciseconds, scaled by strength/crafting. Admission
needs 20; Production's existing discount debits 18. The exact type maps to
Pharmacology (tier 5, minimum bench tier 4, Apothecary+Printing Press), maximum
recipe era 8. Circuits retain coefficient >= 2.2, nominal copper/iron and bulk costs.

Canonical text integer map.age must be greater than 1843: 1843 refuses, 1844
admits with research and other prerequisites. Listing, construction admission,
post-wait/pre-debit and use check it. BC, missing, malformed, ranges and fractional
labels are not inferred from research tiers. This does not promise 1844 access:
electronics, Pharmacology and actual map resources may delay availability.

The new machine starts empty/unanchored. Wrench it into place and install a glass
beaker. Menu loading/recovery transfers exactly 1 carbonate or 4 aspirin between that
beaker and its 120-unit internal buffer; ejection retains the buffer. There is no
added power demand. The constructed subtype cannot dismantle or yield salvage.
Ordinary unanchoring/relocation remains possible. Existing pill makers are unchanged.

Pressing uses only the retained buffer: 1 calcium_carbonate + 4 aspirin -> one empty-base
pill containing 5 units, named aspirin tablet. The preset aspirin-pill constructor,
which supplies 10 aspirin, is not used. Loading/recovery admits only those two exact
reagent types, whole selected stock volumes, and matching raw metadata for same-ID
merges. The bounded operation admits at most 128 buffer entries. The new buffer is
inert; unrelated chlorine, ethanol and fractional traces remain intact.

The product uses ordinary can_eat/CHEM_INGEST and existing aspirin effects. After
private staging it regains ordinary pill flags/reactions. The isolated initial
pair has no matching current chemical reaction; later dissolution/mixing can
change it. This adds no potency, medical dosing or physical-compression claim.

Local guarded staging validates retained objects, actual accepted amounts,
capacity, metadata and one balanced debit/credit before publication. Detected
pre-publication failure restores the same objects. Publication precedes external
notifications. There is no proportional drain, ethanol-family removal or shared
chemistry-holder API change. Runtime actions are excluded from custom persistence.

Raw selected metadata preserves null,0, empty text/list, order and associations.
Primitive acyclic trees are limited to 4 list levels, 128 entries and 4096 total
text characters with finite numbers. Unsupported references/keys/cycles/bounds
reject unchanged. Unrelated metadata stays on its original datums.

## Aspirin supply policy remains pending

Carbonate already has the controlled-bench game recipe 1 calcium + 1 carbon + 3 oxygen ->
5 carbonate. Aspirin's existing automatic game recipe is 5 carbon + 4 water + 2 oxygen ->
5 aspirin. Existing pills/packs and metabolism remain.

That automatic recipe is conditional on feedstock supply, normal holder state
and competing reaction ordering. Its definition does not establish a reliable
player route or map-level supply. The press adds no controlled aspirin recipe.

Source has no aspirin-specific research/date override. This patch does not add
aspirin to the controlled bench or broaden availability. Main must select that
policy before adding a selected route. The equipment's after 1843 floor is not
an aspirin invention-date assertion.

## Verification limits

[Offline tests](../tests/tablet_press/README.md) execute production guards,
metadata and accounting through bounded adapters, with mutation controls.
They do not establish native compilation, actual holders/callbacks, menu operation,
ingestion, gameplay, save/load or deployment. No native test was run.
