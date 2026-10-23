# Saved roof-area recovery (draft, native execution held)

Normal roofs replace turf membership with a canonical roofed climate area.
The serializer stores an area reference as its first turf coordinate and type;
the durable header also captures area fields at that anchor. Fresh startup has
the unroofed map there. Rejecting that reference against startup topology before
loading any saved roofs makes a valid historical generation unrecoverable.
The map and relevant serializer/validator/roof code were unchanged between the
investigated writer and reader revisions. This is source evidence, not a native
baseline or proof that every historical payload is valid.

The candidate projects only direct saved turf contents whose roof type, explicit
scalar `switch_area` and `current_area_type`, current base area and supported
climate agree. It validates ordinary and durable references against that
prospective topology without creating areas or objects. After normal preflight
and map clearing, it restores roof membership before decoding graph fields.
Roof constructors reuse this topology; recursively referenced roofs keep their
validated turf and identity. Ordinary area checks remain strict. Ambiguous
placements, missing metadata, unsupported climates and multiple explicit area
instances of one roof type fail closed instead of being merged silently.

BYOND normally has one canonical instance per area type; explicit `new /area()`
with a null location can create additional instances. The compatibility path
does not infer such additional instances from an old anchor/type reference.
Reference: https://www.byond.com/docs/ref/info.html#/area

## Offline preparation

```
<verified-python> -B tests/roof_area_recovery/test_preparation.py -v
<verified-python> -B tests/world_save/run-durable-world.py --roof-areas --prepare-only
```

The preparer disables normal game startup and omits every DMM. It retains a
full-source DME and a tiny synthetic 8x8x2 writer/reader fixture. It copies no
configuration, credentials, production save or player data. Its native execution
entry is deliberately refused. Existing full-game CI compilation does not
compile or execute the new fixture. Offline passes do not establish recovery.

## Native validation required before merge/deployment

Use a separately reviewed immutable packet and normal resource admission.
No native execution is requested by this document or enabled by the preparer.
Proposed limits: one compiler at a time (180s), then one child at a time (60s
per mode), 30s total cleanup allowance, 1024 MiB per compiler/daemon process,
120 MiB aggregate generated-artifact budget, logs capped at 1 MiB per phase,
and an outer deadline covering the explicitly enumerated modes. Any cap failure
rejects acceptance and retains evidence. Ownership, child exit and absence of
remaining listeners must be checked externally; in-world port closure alone is
not enough. Startup uses a single fixed reviewed loopback port, then the
fixture closes it, rejects reopening and rejects every client. No public probes.

1. Compile full production sources with the synthetic fixture on BYOND516.1681.
2. Fresh `roof_mode=write` creates two supported real roofs, ordinary object area
   references, nested list aliases/area keys and a durable metadata area edge.
   It exports a real generation and validates the writer's still-roofed world.
3. Retain and hash those synthetic payloads. Copy them separately for each mode.
4. Fresh `roof_mode=read` starts unroofed, preflights without world mutation,
   then imports and checks exact area/roof aliases, roof location/settings,
   durable area fields, operation release and unchanged generation.
5. Six fresh copy-only negative modes: `missing-roof`, `wrong-base`,
   `missing-scalar`, `disabled-roof`, `unrelated-area`, `duplicate-area`.
   Each must reject before world mutation. Preserve their altered fixture copies.
6. Old-defect control: remove only the projection call in an immutable source
   copy. The writer still succeeds; the fresh reader must reproduce the exact
   area-reference rejection before import. Do not call an unrelated crash a pass.
7. Expand coverage before acceptance for disabled roofs that should restore,
   ambiguous placement, full base-area coverage and unrelated malformed graphs.

Retain source/DME/patch hashes, compiler output, per-mode result/log hashes,
process birth/exit identities, external socket observations and cleanup receipts.
The proposed limits and fixtures are not a grant or an executable runner.

## Private generation acceptance

Original saved payloads and backups remain untouched. After reviewed synthetic
native acceptance and source review, validate the exact existing generation using
the separately authorized canonical compile/restore lifecycle. A successful full
import, readiness, advancing ticks and absence of recovery errors are still
required. No fresh world, other save, blanket type-check relaxation or save
rewrite substitutes for that acceptance.
