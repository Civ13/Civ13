# Irrigation persistence: offline validation and prepared native coverage

Run only the offline suite with a verified interpreter:

```
<python> -B -m unittest discover -s tests/irrigation_persistence -p test_contract.py -v
```

The tests execute a strict translation of the two new scalar/preflight helpers,
using synthetic save entries and lists. They verify complete dry/fresh/salty
tuples, explicit zero fields, wrong/missing scalar envelopes, graph-reference
rejection, unsupported versions, contradictory bits, ambiguous legacy entries,
read-only rejection, three generated-source controls, and JSON disk round trips.
Source guards bind admission and the two loader callsites, verify native-default
reset, prohibit propagation/timers in overlay rebuilding, and project the entire
old irrigation file and loader back to their exact baseline bodies.

`SourceBaseline` verifies all eleven baseline blobs against GitHub's immutable blob
IDs at upstream `067478b82c7ad9f1b83759a221e6f22080ba865a`. It demonstrates the
baseline admission gap using exported field selection, not an engine import.
`baseline.json` records the upstream SHA and blobs. The full checkout uses that
upstream commit directly. Retain that immutable Git reference before enabling
this suite in CI. A whole-code scan also rejects duplicate floor after_load
definitions and proves the existing snowfall hook is byte-for-byte unchanged.
Irrigation uses the parent turf hook and replaces only its owned overlay, so
restoration does not clear snow or other derived overlays. CI changes are
limited to this issue's selected offline/native steps.

CI now prepares the exact `067478b82c7ad9f1b83759a221e6f22080ba865a` Git object
in the workflow before running this suite, including from a depth-one checkout.
The tests never fetch, guess another baseline or skip missing coverage. All eleven
blob hashes remain mandatory. Locally, fetch that exact SHA from the repository
before running the suite if the checkout lacks it.

The introduced-suite/extensive guard also selects the prepared trench restoration
fixture in the existing build job. It explicitly requests 516.1688 and retains
synthetic diagnostics for normal, filling-omission and digging-omission runs.
The historical runner default remains strict 516.1681. Compile-only validation
can use its explicit `--compile-only` boundary; that returns before config-copy
or any daemon invocation. No local restoration world is authorized by this text.

The adapter is not a DM compiler, native list/type oracle or BYOND
savefile codec. JSON round trips do not prove engine save/load. The old flooded
trench fixture succeeds from native type defaults and did not cover ordinary
floor `irrigate()` channels. No unrun engine failure is claimed.

The existing `tests/trench_save/probe.dm` has prepared (UNRUN) D/F/S ordinary dirt
channels with custom names and no natural source. It checks explicit zero fields,
forces different-type replacement and poisoned same-type destinations, then uses
actual world export/preflight/import and checks flags plus overlay metadata. A
non-channel cell with stale flooded/salty residue must not regain irrigation.
Native trench controls remain unchanged. Main must first admit the exact engine,
full checkout, containment runner and resource bounds. No allowance is spent here.

Next native controls, after normal reproduction/compile admission: omit one of
the four admitted fields in generated source; require specific preflight failure
before ClearMap, original save/world sentinel preservation, and clean owned
process cleanup. Then test connected junctions and repeated restores. This work
does not authorize those runs, clients, production saves or deployment.
