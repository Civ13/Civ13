# Declared paid-child transfers during export

The production saver opens an export frame for each pinned entry. Existing
before_save hooks still run through the default before_save_context adapter.
A hook that moves paid children into its direct owning turf must prepare a
save_transfer ticket before moving anything, then commit after the normal hook.

Preparation requires the current hook, attached source storage, an active
same-file owning turf frame, and one list of at most 12 unique unsaved items.
Missing or finalized parent context, excluded items, duplicate handles and a
second declaration refuse before the drop. Empty producers can use their
unchanged hook without a ticket.

The owning frame drains only those declared handles after saved-variable
recursion, then publishes deduplicated numeric content references. It neither
rescans the world nor repeats hooks for entries already pinned. Every drain
checks child location and parent identity. A runtime-only turf frame marker
detects replacement even if native turf handles retarget.

The producer owns its gameplay unwind. The serializer cannot undo callback
effects, manufacture paid items, rebuild runtime slots or grant new nutrition.
Any declaration or drain failure aborts export; the existing world-save
completion and backup protocol preserves the prior completed generation.
Unsupported reference-first producer export must fail before mutation.

The food hook is maintained in the food branch/PR and depends on this API.
This shared patch alone does not change dehydrator behavior.

## Prepared verification

tests/world_save/transfers.dm is included in the existing offline round-trip
runner. It checks direct and late saved-variable discovery, exact content
occurrence counts, scalar preservation, repeated commits, reference-first
refusal, duplicate/over-limit/uncommitted transfers, turf replacement, moved
children, and failure cleanup. A failed world export checks the byte digest of
the previous completed level in the backup and completion-marker refusal.

Adding this executable fixture selects the existing world-save CI suite through
scripts/select-ci.py; no new runtime suite or automatic deployment is added.

Local compiler, native execution, runner and helper checks are held by the
coordinator. This fixture is prepared source, not passing runtime evidence.
The separate food fixture covers real rack storage, progress and restoration.
Neither fixture alone proves gameplay visuals, full-world memory, or latency.
