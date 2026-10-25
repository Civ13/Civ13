# Winter native Linux 516.1688 candidate 8070d5

Executable controller source for review, **inactive and not executed**. A proposed one-shot hosted workflow is included as source only; no workflow was
published or dispatched, acquisition performed, desktop changed or production edited.

Exact production HEAD `8070d5cbe26c39c42d6bf5ce132d16f7cc3768e0`, tree
`c26a26bf55518defa4f63f19f00695882183aae7`. Source inventory contains 5068 files,
SHA256 `be83445bdc17020e30550f4b269c735743497b60c048281cabca6358cacce1b9`.
Every blob/mode was compared to the connected GitHub recursive tree (not truncated),
and its native Git tree hash independently reconstructed offline. This confirms
export bytes, not local real-checkout admission. The local source Git remains a
synthetic baseline and must fail the real HEAD admission.

## Safe review commands

From the packet parent or repository containing `tools/winter_native_1688`:

```sh
WINTER_TEST_SOURCE=/absolute/candidate-export python3 -B -m unittest discover \
  -s tools/winter_native_1688 -p 'test_*.py' -v
python3 -B tools/winter_native_1688/run.py \
  --source /absolute/real-clean-8070d5-checkout --output /absolute/fresh-preparation
```

Tests install the offline audit fence: no native, real subprocess, socket or /proc
inspection. Mocked lifecycle/process evidence is never actual acceptance.
Preparation has no native opt-in and requires real clean HEAD/tree plus every
inventory byte, with no ignored extras or links.

## Proposed activation only after parent review

`ACTIVATION.json` at the packet root records the exact controller SHA256 and plan
identity. `grant-template.json` is an **unsigned review template**, not approval.
The parent must authorize and create the one-shot grant separately; the local
`.consumed` marker prevents retry of that grant path, not a global authorization
service. Never copy/rename a consumed grant to retry.

```sh
python3 -B tools/winter_native_1688/run.py \
  --source /absolute/real-clean-8070d5-checkout --output /absolute/fresh-one-shot-evidence \
  --reviewed-native --grant /absolute/reviewed-one-shot-grant.json \
  --byond-bin /absolute/already-verified/byond/bin \
  --byond-archive /absolute/already-verified/516.1688_byond_linux.zip
```

No toolchain acquisition/install occurs. Grant binds exact source/tree/manifest,
controller bytes, archive and 12 phases. It is consumed before compiler start; a
later failure retains that consumed state. Source, controller and runtime members
are reverified at phase boundaries. Changed bytes need fresh review, not overrides.

## Fixed plan and safety boundaries

Baseline compile/roundtrip/writer/reader, then hardiness/site/ancestry/payment
compile/roundtrip: **5 compiler + 7 daemon**. Compiler 180 wall / 150 CPU / 2 GiB,
daemon 45 wall / 30 CPU / 1 GiB, aggregate 1200s with 8s cleanup reserve; individual maxima
are not additive permission to exceed aggregate. Descriptor/file/log/privateHOME
bounds, retained-process ownership, signal cleanup and no-live-descendant checks
are inherited from reviewed tree controller 22215eab unchanged. Owned process
implementation SHA256 remains `b247b308ff088b832417466218b1b96f11be2f1a622e710749e92c77b451b1ea`.

World 8x4x1, no DMMs or normal startup, clients/Topic rejected, webhooks disabled.
The reviewed Linux startup allows one loopback bind then closure; the parent
censuses owned listeners before granting the bound ready/go acknowledgement.
This is not a network sandbox or the historical Windows no-socket rule.
Only fixed winter-food.sav and winter-food-entries.json cross writer/reader after
success/hash-seal/verified cleanup. Collector excludes binaries, saves and private
HOME contents. Any unknown failure, guard refusal, diagnostics or uncertain cleanup
stops the batch and preserves failure evidence. No automated retries.

## Exact acceptance and remaining gaps

Oracle requires 239 roundtrip, 20 writer, 21 reader ordered assertions. Four causal
controls must fail at their exact intended label, not just return any failure.
Actual full-production sowing/harvest/weather/soil/stage methods, 20 sprite states,
all 8 seed pools, oral chemistry and partial-food/seed/crop-scalar disk persistence
are covered if later compiled/run successfully. No DM compilation occurred here.

Frozen crop snapshots (`vstatic`) **do not prove growth callback resumption**.
No 600-tick growth/decay waits fit the unchanged 45s daemon cap; no timing mutations
were added. Plump RNG samples are diagnostics, not guaranteed time/yield proof.
Food transfer/metabolism is not connected-client eating or full Life. No natural
cadence, full-world save, roofing construction, multiplayer, gameplay screenshot
or shovel-follow-up coverage. Historical tree acceptance does not cover this head.

## Hosted proposal

`.github/workflows/winter-native-1688-once.yml` is restricted to initial creation
of `codex/winter-native-1688-8070d5-attempt1`, run attempt1, Civ13/Civ13, and a
single controller commit whose sole parent is8070d5. Publication of that branch
would activate it and is therefore held for parent review. No workflow_dispatch.
It reuses the reviewed Ubuntu22.04/i386 dependency commands and pinned action SHAs,
checks exact bootstrap/version Git blobs, and uses only the already-approved
repository-release archive with unchanged SHA256/redirect checks. No new package
source, fallback, system BYOND install or guard change. The exact workflow creates
one run-bound grant only after offline tests, candidate regressions and acquisition
checks pass; its controller hash must match the reviewed seal before native launch.
