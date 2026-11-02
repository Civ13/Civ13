# Species-disabled fallback fixture (review draft)

The fixture calls real crab Life and the production mosquito species helper in a
headless full-source world. This is not the mob scheduler, a connected client,
infection/contact parity, a save/load test, or a wildlife activation request.

Source gates remain default-off. The draft production fallback refuses legacy
movement during a transaction, pulse, paid deadline, owned partial offset or
another movement owner. Readiness retires an aligned obsolete species owner
and cancels its own superseded wild pending intent; a remaining pending intent
of another kind blocks fallback. The aligned setter refuses overlapping owners and
retires its species owner. Follow/flee/pet flag fallback is not changed.

Cases: crab legacy and mixed flags; mosquito native-direction legacy and mixed
flags; successful aligned opt-out and native replacement; active partial
opt-out rejection and explicit direct-base-flag fault injection. Each case has a
fresh lifetime ID. The test-only observer records paired Move boundaries,
physical coordinates/offsets, owner/generation, flags, completion, tick usage and
a bounded 512-event trace. Four-ds quiet windows sample each engine tick and
fixture-only forwarding wrappers record every species-owner or pulse admission,
including one that completes without moving. Sampling does not prove absence of
unrelated direct state writes between ticks.
The fixture runs no mob scheduler; crab Life is invoked once manually.

The independent host validator requires complete ordered six-case receipts,
matching engine 516.1688/head, an 18x14-tile map with 32x32-pixel actor bounds,
trace continuity, actual
physical displacement, flags, per-case observation windows, owner retirement
and exactly-once partial completion. Synthetic positive and negative tests do
not prove the DM fixture compiles or the native world behaves as assumed.

## Bounded controller integration required before execution

This draft includes fixture, prepare-only staging, and host receipt validation.
It does NOT include a selectable cloud worker, reviewed exact-head source
binding, archive validator integration, workflow dispatch, or native result.
The existing run-npc.py prepare_source archives only Git HEAD; never claim the
working tree was staged. Any future candidate must bind one immutable commit
whose parent is c78817c50d49a38586d0c00ef04a5a365432a205 and verify every
fixture/production/runner blob and allowed source delta before compilation.

Port the known reviewed transition05 controller as a narrow new selector rather
than enabling the old selector: 2 CPUs, 3 GiB memory/swap, 64 pids, network-none,
read-only root, 1 GiB scratch, existing pinned 516.1688 Linux archive and exact
image verification. Bound one compile to 90s, one fresh daemon to 60s, timed
setup to 60s, shared work to 490s and total outer cleanup deadline to 600s.
The 210s admission reserve covers compile+daemon+timed setup; source validation
before the timed setup must also fit inside the outer deadline. Do not increase
limits or hide Git-validation time.

Before any dispatch, implement and independently review: exact immutable
base/tree/path guards; test-only overlays with matched preimages and archived
original/generated manifests; no unexpected source modifications; unique
source/receipt and runtime resource copies; checked process-group cleanup;
bounded failure receipts; exact suite-specific archive member names/count,
path/type/size and XZ EOF/trailing validation; complete host validation and
negative controls; explicit manual selector and no overlapping jobs. Keep
partial observations on assertion/compile/daemon failure. Do not weaken the
native port startup/closure or container network policy.

The existing compiled game and separate historic experiments are not native
evidence for this draft. No daemon or compiler has been invoked by this change.
