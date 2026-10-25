# Native adapter preflight source

This is source preparation for PR #3243. No workflow calls this entry. Default
`run.py` prints a plan. No image, toolchain, compiler or daemon was acquired or
executed while preparing it. The shipped `toolchain.json` is deliberately
unresolved and fails admission. The active proposal targets 516.1688, matching
`tools/byond/version.json`. Its archive/compiler/daemon hashes come from reading
the already retained 1688 archive and bounded static inspection. They match the
central official-observed pin and repository-release metadata; neither is a
publisher-signed checksum. No download, extraction or member execution was needed.
Historical 1681 inventories and consumed pilots remain separate evidence.
Never invoke the old CI bootstrap as the bounded executor.

The Dockerfile is an inert recipe: a digest-pinned Python base plus a separately
reviewed rootfs containing BYOND and explicit 32-bit loader/shared objects. It
performs no downloads or package installs. No `toolchain-rootfs` is supplied.
Python hash, dependency versions/provenance and final image digest/ID remain
required; known archive/member hashes do not establish those missing identities. Rootfs acquisition and Docker layer/cache
disk, network and cleanup bounds need their own concrete reviewed proposal.
The accepted Python image is not a BYOND image.

`prepare.py --repo ... --head <40-hex> --output <fresh>` stages public, regular
files from Git archive, binding paths, Git blobs, SHA256 and sizes. It rejects
links, traversal, extra/missing/changed members and compiled inputs. Only the
146 name lists explicitly read by exact-head `code/names.dm` are allowed from
config. No private config, production checkout copy, saves or installed runtime
is staged. The 4 GiB source ceiling is a proposal, not permission to stage a
large resource bundle. Git-archive provenance originates at this trusted step;
a hand-authored self-consistent manifest is not independent ancestry proof.

`run.py --execute` requires a future exact packet/grant and public hosted manual
job. It never pulls an image, builds it, installs dependencies, dispatches CI,
retries a phase or expands limits. The native driver is distinct from the
22-process measurement CLI. It proposes exactly one common-fixture compile and
two fresh children, reserved=0/1, then the six-snapshot comparison with
1,350 overlay rows and 1,536 all-cell lumcount rows, including 36 fixed-omitted
rows. Missing or wrong semantic coverage fails before preflight completion. The fixture/probe/production code is unchanged. Compiler acceptance
uses its real exit code plus one exact 516.1688 banner and zero-error/zero-warning
log checks. Old, mixed or repeated compiler banners fail closed.
The adapter retains the existing Linux PID/start-tick, smaps, wait4 CPU, fatal
diagnostic and cleanup checks. Counter observations validate attribution only;
they are not comparative performance evidence.

Candidate bounds are 1,536 MiB memory/zero swap, 32 PIDs, one CPU, a separate
1 GiB hard compile filesystem, and ONE 128 MiB hard filesystem for both run
directories **and host controller logs/config/receipts**. All Docker CLI writers
live there. Capacity readback and actual ENOSPC controls precede native work.
Each receipt is additionally capped at 8 MiB; child output detection is 16 MiB.
Compiler RLIMIT_FSIZE is 1 GiB so a resource artifact larger than 16 MiB can fit;
stdout/stderr have a separate 16 MiB aggregate polling detector on the 128 MiB
hard filesystem. That detector can overshoot between polls. Compile wall/CPU
are 180/60 seconds; each smoke wall/CPU is 30/10 seconds. Each
phase requires 15 seconds of cleanup lease; outer deadline is 600 seconds.
The shared budget is the minimum of outer monotonic time and grant UTC time.
Fresh compile/smoke admission reserves 225/75 seconds including helper overhead;
all CLI operations, waits and cleanup calls are clamped to the shared remainder.
The caller must provide fresh, writable, correctly owned mounted filesystems;
this source does not mount them or select an unbounded fallback.

The controller retains an independent in-memory seal of the original compile
ledger, artifacts and compiler logs. It verifies that identity and the original
shared request before/after both smokes and final comparison; coherently changing
an artifact and its current ledger cannot replace the retained identity.
The capacity probe is removed only after this invocation created it exclusively;
a UUID collision preserves preexisting bytes and remains a failure.

The supplied source is not execution-ready. Independently reviewed larger-profile
causal memory/PID/network/descendant controls, an engine/account/socket contract,
and zero-cost bounded artifact export are explicit external admission inputs,
not implemented or accepted by checking boolean fields. A trusted sole owner
must bind their actual immutable receipts and issue the grant. Docker local log
rotation (`1m`, one file, compression disabled) is configuration, not a strict
aggregate host disk quota. Daemon/cache/log storage remains separately scoped.
Sampled sockets cannot exclude a transient internal listener; network=none
does not establish that engine contract. A stopped native phase proves only
owned-container removal, not independent retained-descendant retirement.

Run offline tests with an explicit Python executable:

```
<python> -B -m unittest discover -s tests/reserved_lighting/native_preflight -p test_preflight.py -v
```

All external effects in these tests are injected. Passing them does not prove
Docker, larger cgroups, Linux ABI/dependencies, actual compilation or native
adapter behavior. The successful earlier Python pilot 39636638727 was only
64 MiB/16 PIDs at master 61329b29. Its failed predecessor and both consumed
authorizations stay immutable. Neither authorizes this driver or the 22-run
batch. No Gaia quiet window or #3220 merge/rebase is needed for a genuinely
separate branch-relative hosted fixture; actual runtime assignment is still
required. Failure or uncertain creation remains incomplete, retains the original
cause, attempts cleanup only with verified owned CID/labels, and never retries.

The semantic correctness reference remains a93e490e9e05a4faace778dd8431abf0d6f10564;
its separate native correctness CI39679381491 is not this preflight's platform,
toolchain, counter or performance acceptance. The October 24 source candidate
reconciles master d6b06c638517bb4100beeca6a90d09adc3629fb7. Prior 166c/a946 and
9293137d source/runtime packets are historical for that changed source tree.
The compiler, fixture, runtime and controller provenance must be resealed for the
new exact feature head before any future separately admitted native execution.
