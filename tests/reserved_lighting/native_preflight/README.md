# Native adapter preflight source

This is source preparation for PR #3243. No workflow calls this entry. Default
`run.py` prints a plan. No image, toolchain, compiler or daemon was acquired or
executed while preparing it. The shipped `toolchain.json` is deliberately
unresolved and fails admission. Its archive URL and dependency names are
references from the existing CI bootstrap, not accepted download identities.
Never invoke that bootstrap as the bounded executor.

The Dockerfile is an inert recipe: a digest-pinned Python base plus a separately
reviewed rootfs containing BYOND and explicit 32-bit loader/shared objects. It
performs no downloads or package installs. No `toolchain-rootfs` is supplied.
Archive SHA, compiler/daemon/Python hashes, dependency versions/provenance and
final image digest/ID remain required. Rootfs acquisition and Docker layer/cache
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
two fresh children, reserved=0/1, then the existing six-snapshot/1,350-row
comparison. The fixture/probe/production code is unchanged. Compiler acceptance
uses its real exit code plus exact 516.1681/zero-error/zero-warning log checks.
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
The caller must provide fresh, writable, correctly owned mounted filesystems;
this source does not mount them or select an unbounded fallback.

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
