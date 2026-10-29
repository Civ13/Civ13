# Saved-character bed return: prepare-only native fixture

This dedicated fixture retains PR3355 source commit
`f065e129e2b3c422236869218353db29c2bf62de` as historical provenance. Current
inputs are hash-bound in each receipt, with focused executable lifecycle
procedure contracts checked before preparation. It is source/test preparation,
not a native acceptance receipt. It provides no compiler/runtime launcher.

## Why a separate preparation path

The former `run-durable-world.py --recovery-reconnect` adapter expected three
`lobby.client` accesses. Current reclaim has five, including post-movement and
failure-cleanup rechecks. Both preparation paths now adapt exactly those five
accesses without deleting the extra guards. The dedicated packet adds bed-specific
cases; it does not substitute an older production reclaim implementation.

The preparer checks the first-return/ownership lifecycle procedure contracts
before helper import/output. It records hashes of all twenty current inputs;
unrelated maintenance no longer has to match whole files from the historical
commit. The original twenty hashes remain as reference data, not current-source
claims. Any executable change to the scoped lifecycle procedures requires review;
comments are ignored in those procedure snapshots. Receipt source-tree digests
change whenever any actual input bytes change.
It reuses `run-cross-level.py` extraction, unique-replacement and stub-adaptation
helpers, the existing production saver/loader/graph and real movement/buckling
procedures, plus the established sleep-fixture declaration adapters. It never
calls the old runner's native functions or compiler validator.
Movement keeps production's default disabled tree-presentation branch, neutral
throw-launch fields and the actual clear_throw_launch helper. This fixture does
not establish active throwing or enabled tree-presentation behavior.

Only the generated dedicated packet removes the six disabled bed-return stubs.
It includes complete production `bed_return.dm`. The sole policy-file adaptation
replaces the five `allow_new_character` lobby-client accesses with the inert
client field. The complete reclaim procedure similarly adapts all five accesses,
one client declaration and the key-transfer expression. Reversing these exact
substitutions reproduces the original files byte-for-byte. Reservations, owner
checks, post-hook rechecks, readiness gates, claim consumption and customization
suppression are unchanged. All other generic harness and production files remain
untouched.

## Scope and cases

Eleven scenarios are prepared: disk ownership/state round trip; first versus later
return; failed handoff/retry; occupied and destroyed bed fallback; refused and
redirected movement; pre-existing reservation; recovery hold; dead-only admission;
and disabled-profile/TDM-policy preservation.

The disk case uses real version-2 Save_World, preflight, ClearMap, Load_World,
durable graph decoding, restored-body registration and final readiness release.
It changes the original values before import, checks scalar bed/body ownership,
metadata aliases, represented nutrition/water/health, one represented medical
datum and nested item state, then reclaims the restored body. Reclaim must retain
those same restored object identities. It is a **same-process** disk round trip,
not fresh-process recovery. Non-disk cases use the same real bed/reclaim policies.

The tiny metadata graph is the existing cross-level synthetic schema. A dedicated
`/map_storage/cross_level/character_return/begin_zone_export` adapter keeps it
zone-less while the real bed predicate sees an enabled profile. Generic topology
stubs still reject their unsupported use. This does not establish Nomads zone
topology, round-v2 full-world startup or real Gaia/Europe/TDM map acceptance.

Human construction, physiology, one medical datum and client handoff are explicit
adapters. No real account, Login/HUD, timed Sleep verb, real-client reconnect,
full organ/wound gameplay, OpenDream, live saves or server activation is tested.
Existing full-source wound/limb coverage is not duplicated. Runtime networking
inherits the existing closed-port/client-denial fixture hooks; source preparation
does not establish native startup listener behavior or OS containment.

## Preparation and offline checks

From an exact-source checkout, choose a new output directory:

```sh
python -B tests/world_save/character_return/test_prepare.py -v
python -B tests/world_save/character_return/prepare.py --prepare-only \
  --source-root . --output /new/isolated/character-return
python -B tests/world_save/character_return/prepare.py --prepare-only \
  --source-root . --output /new/isolated/character-return-control \
  --negative-control omit-claim-consume
```

For an immutable partial source snapshot, set `CIV13_CHARACTER_SOURCE_ROOT` only
for the offline test command. Lifecycle procedure contracts must still match.
Existing output, changed lifecycle/adapter anchors, unknown controls and native CLI
options are rejected. No child process is invoked during preparation; tests
poison subprocess entry points to verify this boundary. Receipts bind inputs,
generator/template bytes and every generated DM/DME file.

Generated-only controls:

| Control | Scenario | Required future native result |
|---|---|---|
| `omit-claim-consume` | repeat-return | `FAIL: repeated return moved back to bed` |
| `omit-reservation` | reserved | `FAIL: reserved return was admitted` |
| `omit-bed-owner` | disk | `FAIL: disk bed ownership lost` |

Offline tests verify exact omission generation and case binding; they do **not**
prove those native failures occurred. Compiler errors, runtimes, timeouts or a
different assertion cannot count as a successful causal control.

## Remaining native gate

Root reviews the generated source and separately admits an owned, bounded executor
with explicit BYOND516.1688 engine/archive provenance and process/network/resource
receipts. Do not invoke legacy `BASE.native`: it carries older516.1681 validation
and insufficient per-child resource containment. This preparer does not select,
download, probe or run an engine. Require clean compilation and independently
adjudicated candidate/control results before claiming tiny-world acceptance.
Real Windows client/HUD/reconnect acceptance remains separate. Draft/readiness,
publication, deployment and live-save decisions are unchanged.
