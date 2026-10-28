# Public Europe representative source adapter

This contains native executor source and injected contract coverage. No native
execution is admitted or claimed. Default CLI prints a plan and runs no effects.
Existing ordinary CI does not select this
subdirectory automatically; source checks can be invoked explicitly:

```text
<verified-python> -B -m unittest discover -s tests/save_latency/representative -v
<verified-python> -B tests/save_latency/representative/execute.py
```

`source.prepare()` admits only reference `9db2b2f42a5fbbb0bdd49d50a2672da6111a7709`
and candidate `069f88d0790bfc8772f7bee8b7b121569ef4a09f`. It reads immutable Git
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
The expected source/generated input, config/token, compiler/daemon and compiled
DMB/RSC seals stay in independent immutable memory. They are rechecked before
each copy/compile/launch, after owned phases and copies, and before/after final
result publication. Rewriting an on-disk manifest cannot replace those seals.

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
The owned observer uses one schedule for the complete phase, capped at 100000
samples and the existing absolute deadline. Response rows are retained before
resource sampling, whose delays remain explicit missed slots rather than query
latency. Stop-aware waits end on phase completion; windows never reset the cadence
or queue catch-up requests. The full-phase sample bound is checked before launch.
Early wakes recheck the same monotonic target and wait only its remaining time;
cancellation and the original absolute deadline still stop observation. No timing
tolerance permits an early request. The final observer wait follows the same rule.

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
Log copying and diagnostic scanning also run after failed phase/cleanup attempts.
Original logs stay in place, and shutdown output is included once streams close.
Secondary retention errors are recorded in `diagnostic-retention-failure.json`
when writable and attached to the original exception; they cannot turn failure
into acceptance or hide its cause. Unconfirmed cleanup remains a failed attempt.

After source review and separate allocation an operator can explicitly request
`--execute --repository <local-repo> --resource-packet <current-owner-packet>
--admission <reviewed-admission> --admission-sha256 <independently-reviewed-digest>`.
The deliberately invalid example packet grants nothing. Execution requires Windows,
approved existing BYOND hashes, new unlinked output, an allocated unoccupied port,
frozen expected listener addresses and measured storage/resource ceilings. Expiry
must cover setup plus 9810 core seconds: two compiles at most 300 seconds each,
seed at most 1800, each arm at most 3600 including both readers, and seven 30-second
cleanup reserves. No installation/download, PID rediscovery, retry or implicit
extension occurs. Unsupported anchors, timeout, stale identity, wrong generation
or cleanup failure preserve every seed, output and recovery file.
One clock anchored before setup consumes the greater elapsed monotonic or UTC
time; a forward UTC jump cannot outlive the grant and backward jumps cannot
extend it. Staging and final-write overruns refuse completion. Each phase retains
30 seconds inside its existing deadline for owned cleanup; listener admission
requires another 120 seconds before launch. Stop/wait/join never obtain a new
deadline. Already-owned handles still receive immediate stop/kill attempts when
the budget is exhausted, with zero remaining wait rather than an implicit grant.
Daemon argv adds supported `-ip 127.0.0.1` before startup; the later OS listener
census verifies that bind and sole ownership. No firewall or host policy changes.

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

The CLI now enters through `admission.invoke()` before native execution. The
admission example is deliberately unauthorized. A real reviewed packet binds a
canonical SHA-256 of the entire resource packet (including output and port), exact
host/account/Python path and executable hash, every actual driver `.py` file and
`probe.dm`, source repository, executor thread, authority reference, resource owner
and existing external reservation. Use `Operator.identity()` values for the exact
account representation. These are operator claims checked for consistency, not a
signature or evidence that a JSON boolean creates authority. The expected canonical
digest must arrive from independent review, not be computed from an unreviewed
file as an automatic approval step. Duplicate keys, oversized packets and linked
paths refuse. Runtime inputs and prepared A/B source remain independently sealed
by the executor.

The resource sample names `measured_utc`, `host`,
`output_volume_free_bytes` and `cpu_accepted_by_owner`. It must be at most 60 seconds
old immediately before invocation and meet the existing disk floor. The user's
override of available-memory admission is honored: reported free RAM is not a
new admission gate. Allocated private-memory ceilings and sampled runtime stops
remain unchanged. A claim is not a fresh host
probe or continuous CPU/RAM guarantee. Actual storage preflight and existing
sampled process/output checks still run; the caller does not supply hard quotas.

`ledger_directory` must already exist outside source and run output, be the
operator's shared durable reservation store, and be honored by every dispatcher
using that allocation. The caller exclusively creates and fsyncs
`<attempt_id>.json` before entering the executor. A collision, uncertain write or
failed invocation is consumed and must never be deleted to retry. The record
binds the independent admission digest and remains `CONSUMED_BEFORE_EXECUTION`;
it does not advertise success. Driver imports, packet reads, hashing, claim writes
and executor work share the script-entry monotonic/UTC limit, after only the
minimal clock imports. Slow preparation cannot start a new
9810-second budget. Source/identity and claim checks run again before return.
Allocation release and native/performance acceptance remain separate reviewed
facts, including when invocation returns without raising.

This cooperative caller is not a security boundary against a hostile operator,
concurrent source mutation or deletion of the external ledger. The Python API
remains available for the existing injected tests; it must not be used to bypass
the reviewed native invocation route. The reservation identifier does not itself
lock a TCP port. Existing explicit loopback launch and actual listener ownership
checks remain required; a conflicting listener stops the one-use attempt.

## Post-merge comparison refresh

The frozen comparison now includes the same merged master changes in both arms,
including disabled reserved lighting. Their production diff is limited to the five
bounded-save persistence files. Earlier 61d9903/0eac5f3 packets remain historical;
regenerate source and admission packets before any representative execution.
This pin refresh grants no execution and does not turn earlier fixture results
into representative acceptance. The observer helper commit remains unchanged.
