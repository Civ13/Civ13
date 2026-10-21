# Public Europe representative source adapter

This contains native executor source and injected contract coverage. No native
execution is admitted or claimed. Default CLI prints a plan and runs no effects.
Existing ordinary CI does not select this
subdirectory automatically; source checks can be invoked explicitly:

```text
<verified-python> -B -m unittest discover -s tests/save_latency/representative -v
<verified-python> -B tests/save_latency/representative/execute.py
```

`source.prepare()` admits only reference `61d9903d6b083fcc1a0bb597c05b34b4a393a10e`
and candidate `0eac5f3b19b9c6d93d906045d9ef5bed78909ebb`. It reads immutable Git
objects and writes a new observer overlay packet, preserving serializer inputs.
The pure observers come from full-map fixture commit
`c345c9b3ede9d437af39e1a9b2dce62dc23e6b16`; the historical fixture is unchanged.
Missing or duplicate insertion anchors reject before packet creation. Its fixed
historical BASE is never used to label the proposed host.

The executor exports exact public source, verifies input hashes, places
`representative.dme` at the game root and other observers in `representative/`,
sanitizes public configuration, writes the existing private test token and freezes
DMB/RSC/toolchain/config hashes. This packet neither copies
private inputs nor prepares canonical/live directories.

The test-only DM extension uses existing authenticated/session-bound dispatch.
It adds asynchronous cohort census and ordered `first`/`second` actions, calls real `ticker.savemap()` and
`persistence_restart.current_identity()`, and returns an actual production
generation identity after completion. A crate marker distinguishes first and
second saves. A scheduled heartbeat counter has no saver callbacks or fake clock.
These sources have not been compiled or executed; protocol/source tests are not
native fixture acceptance.

`protocol.two_saves()` checks actual source/session/phase/generation response
contracts. It deliberately returns `acceptance: false`: even two successful saves
do not prove either fresh reader. `compare_reader()` rejects unchanged boot/process
identity, import holds/errors, dimension/round changes and missing/duplicate
sentinels. The executor requires verified owned PID, creation-time and
binary-hash identities; injected test receipts do not establish native ownership.

`files.freeze_generation()` verifies known file inventories and production
identity text digests while retaining raw SHA-256. `stage_reader()` copies known
bytes and writes a fixture restart intent from the returned production identity.
This is explicitly a controlled recovery input, not a genuine native-reboot test
or a parser of `.sav` internals. Native production preflight must validate it.

`sampler.sample()` records independent monotonic scheduled/send/receive times,
actual heartbeat values, timeouts and over-budget transports, with no burst after
a stall. Cadence/timeout/sample bounds must be fixed before execution. No absent
heartbeat is replaced with fabricated progress. This is a component, not an
already connected listener or source of an accepted latency threshold.

The source executor sequences seven non-overlapping game processes: one public
format-2 seed producer; one writer and two separate fresh readers per revision.
Imported seed bytes are retained outside the new first-save output. First-save
bytes must match the second save's actual backup. Reader inputs retain raw hashes
after production import and owned exit. Dimensions, boundary turf types, round
identity, saved environment/research clock and real crate/nested-knife uniqueness
are checked. The same public seed and exact per-type cohort counts are compared
across A/B; different cohorts refuse comparability. The cooperative census is not
an atomic world snapshot, and it does not establish player behavior.

The historical fixture readiness observes fresh setup/nature flags that production
recovery skips. Only the generated observer additionally recognizes actual
`map_storage.round_restored && persistence_restart.import_complete`; it never sets
those flags. Other quiet/readiness conditions remain unchanged.

The observer retains monotonic samples, phase dispatch/ack/completion receipts,
response-phase labels, no-save samples, missed slots and timeouts. It separately
samples process private/working bytes, CPU and aggregate output growth. Fragmented
transport obeys one total query deadline. Resource ceilings are sampled, not OS
enforced memory quotas. Strict diagnostics run after owned exit; historical
`nslookup` diagnostics are not suppressed.

After source review and separate allocation an operator can explicitly request
`--execute --repository <local-repo> --resource-packet <current-owner-packet>`.
The deliberately invalid example packet grants nothing. Execution requires Windows,
approved existing BYOND hashes, new unlinked output, an allocated unoccupied port,
frozen expected listener addresses and measured storage/resource ceilings. Expiry
must cover setup plus 9810 core seconds: two compiles at most 300 seconds each,
seed at most 1800, each arm at most 3600 including both readers, and seven 30-second
cleanup reserves. No installation/download, PID rediscovery, retry or implicit
extension occurs. Unsupported anchors, timeout, stale identity, wrong generation
or cleanup failure preserve every seed, output and recovery file.

Tests drive the actual orchestration with injected files/transports and seven fake
owned processes. They run no compiler, native game, sockets or HTTP/DNS. Injected
results explicitly retain `execution_mode: injected` and cannot report native
correctness or representative acceptance. Even real completed phases leave
performance and representative acceptance false until raw evidence receives
independent review. `execution_ready: false` records the unallocated/unexecuted
boundary; no synthetic receipt can stand in for an unrun operation.

Use the task evidence proposal for the public-Europe matched workload and finite
unallocated envelope. The 8192/20/80 candidate is an experimental duty-cycle change,
not equal-budget optimization. Faster saves with worse service latency require an
explicit tradeoff decision; no arbitrary numerical acceptance is introduced here.
