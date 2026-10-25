# Inactive character-discovery native controller

This is executable **source preparation**, not authorization or native evidence.
It targets only Civ13/Civ13 head `9c54e1b57097035d51c35e4ea9cb755e7aa12a92`,
tree `0ad1eda47a01440c1839b836f6e313d4e3b481a1`, BYOND 516.1688 and the reviewed
Linux archive SHA-256 `16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9`.
AGENTS is unchanged from that published tree. No workflow/publication is added.

## What the executable proposal exercises

The DME includes the full production source, replaces only normal world/global
startup with the established closed fixture startup, removes production maps,
and adds an 8x4x1 fixture. Actual berries/reagents, `smell_description`,
`smell_for`, non-harm `secondary_attack_self`, mind learning/rendering and
`transfer_to` execute. Chat and Notes browser sinks become bounded fixture
recorders; Notes' client-presence guard is omitted, **not its mind ownership
check**. This is a headless text/ownership oracle, not real chat/browser delivery.
No claimed successful verb `usr` or authenticated client interaction is invented.

Baseline asserts actual observed text, no hidden berry-row disclosure, label
escaping/recipient ownership, rename dedupe/first label, explicit actor/turf gates,
consciousness/current-body learning gates, semantic context, field/count bounds,
and no eviction. Writer/fresh-reader use real `BuildVarDirectory` and `Load_Entry`
for two generic mind/list graphs, including a legacy empty mind and private notes.
Body pointers are deliberately detached before saving: full human reconstruction,
world metadata restoration, account reclaim and actual reconnect are **not**
accepted by this focused probe. A separate production mind transfer checks
knowledge retention; a new mind remains empty. See PROBE-NOTES.md for exact seams.

Four compiled variants make one causal change in production source each:
missing smell recording, missing label escaping, omitted overall capacity check,
and exclusion of `learned_discoveries` by the actual generic serializer's runtime-
variable filter. Each must reach its exact named failed assertion and no other
failure. The ordered assertion inventory is source-hash pinned. Compiler/runtime
errors, early or unrelated assertions, warnings, timeout and cleanup problems
fail the controller rather than satisfying a causal control.

## Retained boundaries

The retained-process helper is byte-identical to the reviewed winter/tree helper
(`b247b308ff088b832417466218b1b96f11be2f1a622e710749e92c77b451b1ea`). Its original
leader/descendant identity, owned-listener census, cleanup and anti-reuse behavior
are preserved. Source checkout, overlay, controller and archive-member bytes are
rechecked before every phase. Actual Git root/head/tree/cleanliness are required;
a local source export or synthetic Git snapshot cannot substitute for admission.

The fixed plan is 12 phases: five compiles, seven daemon invocations (baseline
same-process roundtrip, separate writer and fresh reader, four causal controls).
No optional extra suite or arbitrary command entry exists. Compiler wall180/CPU150
seconds, AS2GiB, file512MiB, FD256, stdout4MiB; daemon wall45/CPU30 seconds, AS1GiB,
file16MiB, FD128, stdout4MiB; total wall1200seconds with8seconds cleanup reserve.
Existing sampled output/private-HOME limits, source retirement and evidence caps
are unchanged. Reader gets exactly `discovery-mind.sav` (16MiB cap) and
`discovery-mind-entries.json` (4096bytes), copied only after the validated writer
has independently verified cleanup. Save contents never select paths.

The startup ready/go handshake requires world.port0 and an owned-process listener
census before fixture setup; normal Topic is closed and client New rejects clients.
This is sampled listener closure, not a network sandbox or proof that a transient
startup listener never existed. Runtime calls retain `-trusted`; no -safe fallback.
No acquisition, desktop changes, process discovery beyond owned processes, real
saves, Gaia, security changes or production server operations are included.

## Review / offline use

```sh
python -B -m unittest discover -s tools/discovery_native_1688 -p 'test_*.py' -v
python -B tools/discovery_native_1688/preview.py \
  --source-export /exact-published-source-export --output /fresh/offline-preview
```

Offline tests install an audit fence before implementation imports and reject
subprocess/native execution, sockets, dynamic native loading and /proc reads.
Injected lifecycle/cleanup tests and source projections are not runtime receipts.
`preview.py` only verifies source-export bytes/tree and builds generated overlays;
it sets `actual_git_checked=false` and `backend_admissible=false`. Its output is
not a `prepare` receipt and cannot be submitted to the native backend.

Real preparation remains read-only Git admission plus file generation:

```sh
python -B tools/discovery_native_1688/run.py \
  --source /actual-clean-checkout --output /fresh/prepared-evidence
```

No native invocation is authorized by this README. Only after parent/operator
review and an explicit exact one-shot grant may the same command additionally
receive `--reviewed-native --grant /reviewed/grant.json --byond-bin /pinned/bin
--byond-archive /pinned/archive.zip`. The template has null grant_id so it is not
admissible. This local grant format is a scope/consumption check, not a signature
or independent authority. Consumed grants/failures stay consumed; no retries or
marker removal. `collect_evidence.py` retains bounded fixed receipts and generated
sources, excluding saves, binaries and private HOME contents.

Stop at a specific admission or test failure, retain evidence, and seek fresh
review before any revised action. Success would establish only the named isolated
headless properties. Connected-client UI, login/reclaim, full-player saves,
normal world startup and gameplay remain distinct acceptance work.
