# Official toolchain identity capture

This is the first real hosted acquisition adapter source, deliberately separate
from the accepted pinned image-acquisition controller. The official BYOND
[516 directory](https://www.byond.com/download/build/516/) lists the Linux
516.1681 archive, modified 2026-04-16, about 4.7 MiB. It provides no checksum in
that listing. No archive bytes were downloaded while preparing this source.
Consequently the image controller's unresolved SHA/member checks remain strict.
This stage can produce candidate observations for independent review, without
running, extracting, installing or building the downloaded code.

`adapters.py` supplies real standard-library TLS transport, ZIP member hashing,
static ELF32 i386 `DT_NEEDED` inspection and a dedicated Linux tmpfs backend.
It defaults to an inert description. Its standalone capture switch is disabled;
the outer launcher is the only executable entry. Explicit capture needs a
frozen exact-head request and one-use grant, the public hosted manual-attempt
identity, a fixed public peer, and the executor-provisioned controls below.
No workflow is activated or dispatched here. No Docker daemon/image backend is
claimed; building that backend before observing the archive's dependency
identities would conceal an unresolved input.

Transport performs one numeric-IP TCP/TLS connection to the official hostname,
with verified certificate and hostname, no DNS/proxy credentials, no redirect,
and no retry or fallback IP. It records peer, certificate SHA256, Last-Modified,
exact length, archive SHA256 and regular member hashes/sizes. Static inspection
reads only the two compiler/daemon ELF program and dynamic tables. It never
executes `ldd`, package scripts or BYOND. These are observed HTTPS identities;
they are not a publisher-signed checksum or native/platform acceptance.

The scratch backend accepts only the exact fresh `/run/civ13-capture-OWNER`
mount. It verifies tmpfs type, device, mount root, private propagation, noexec,
nosuid, nodev, mode, UID, empty contents and exactly 16 MiB capacity. An actual
fill-to-Linux-ENOSPC28 control precedes capture. Directory-FD and nofollow
exclusive operations prevent path/symlink escapes. It removes only files it
created whose retained device/inode still match. A collision or identity drift
is incomplete and preserves unowned bytes. It never unmounts an executor's
mount or signals a process. The executor must separately retire the exact
mount and owned cgroup; the returned candidate-complete field alone does not
establish that outer cleanup.

The proposed request limits one response to 8 MiB, each expanded member to
64 MiB, all expansion to 128 MiB and 512 entries. Central directory allocation
is bounded before `ZipFile` opens it. Duplicate, traversal, symlink, encrypted,
ZIP64/multidisk and unsupported-compression members fail. All outputs in the
capture are on the same 16 MiB hard filesystem; only a maximum 256 KiB JSON
inventory goes to job stdout. No binary artifact or cache is retained. The
executor's own bounded stdout/diagnostics are a separate 1 MiB budget. Final
receipt persistence/readback in the existing Actions job log is part of outer
acceptance, not proven by this controller's return value.

The smallest proposed execution is ONE fresh standard public Ubuntu job,
capture only, with 256 MiB memory, zero swap, 16 PIDs, CPU quota1, 20 CPU-second
process limit, 120 second wall watchdog, 5 second forced retirement and 10
second teardown/output reserve (135 second total envelope). Source staging and
registration must be reviewed separately; fixed numeric peer selection and
actual cgroup/mount/network readback are still prerequisites. No production or
Desktop mount, secret, paid runner, package install, image pull/build, native
compile, daemon, gameplay or performance measurement belongs to this request.
The resource allocator remains the prospective sole executor. The template
contains null admission fields and cannot execute as supplied.

Read-only package metadata already supplies some reproducible dependency
identities: Debian bookworm i386
[libc6](https://packages.debian.org/bookworm/i386/libc6/download),
[libgcc-s1](https://packages.debian.org/bookworm/i386/libgcc-s1/download), and
[libcurl4](https://packages.debian.org/bookworm/i386/libcurl4/download).
These are candidates only. The observed ELF closure must determine which are
needed; no fabricated `ldd` result, member hash or dependency completeness is
accepted. The official archive route can be added to the pinned controller in
a separate narrow reviewed change once its candidate identities are reviewed.

`launcher.py` now supplies the real, inert-by-default outer executor source.
It creates an exclusive bounded public source stage and `USED` record outside
the run tmpfs, binding request/grant hashes and exact Actions run ID. It retains
that record until ephemeral runner disposal. One future `--launch` creates a
systemd service with the proposed bounds and read-only public source bind.
The worker waits on an inherited pipe while the parent verifies exact owner,
InvocationID, cgroup, resource settings and effective ingress/egress/bind BPF
attachments. It retains the worker start tick, mount namespace and cgroup inode.
Unknown or replaced service identities never receive a stop signal; known
owned uncertain starts are reconciled for cleanup only, without gate or retry.
The parent bounds pipe collection, preserves bounded worker failure output,
reaps its direct CLI child and requires original worker/cgroup retirement.
The unique-unit verification and later stop are not an atomic systemd operation;
sole ownership and the external ephemeral-job boundary remain required.
The IP allow set must equal the singleton peer (/32 or /128); extra peers,
wildcards or unknown serialization fail before GO. The home protection must
read back inaccessible, and the worker must observe EACCES13 on listing `/home`.
Each helper combines stdout/stderr in a stream bounded at 32 KiB before
allocation, with a retained direct-child kill/reap and cleanup reserve. The
shared remaining minimum covers outer monotonic and grant UTC time before
unit creation, before GO and through cleanup; source staging consumes that
same outer budget. Expired time is not extended to manufacture a pass.
Normal systemd v255 cgroup pruning clears the `ControlGroup` property. A final
inactive/failed row may therefore use the previously retained cgroup only when
Description and InvocationID still match; original process/cgroup retirement
must independently pass and no stop signal is sent to that inactive row.
An empty cgroup identity at creation is never adopted. This source behavior is
derived from the upstream
[v255 cgroup lifecycle](https://github.com/systemd/systemd/blob/v255/src/core/cgroup.c).

Before HTTPS the worker reads actual memory/swap/PID/CPU cgroup files and CPU
time limit. It installs a fail-closed x86_64
[Landlock network ABI4](https://docs.kernel.org/userspace-api/landlock.html)
policy permitting TCP connect443 and no explicit TCP binds. A connect to the
official peer on port444 must fail with Linux EACCES13; a loopback port0 bind
must also fail. There is one explicitly proposed forbidden-peer TCP443 probe
to 1.1.1.1 (or 8.8.8.8 if that is the selected peer). Its timeout alone is not
causal IP-filter proof; retain it alongside effective BPF identities,
configuration and the later positive official-peer TLS result. Unsupported
systemd serialization, absent bpftool/cgroup/Landlock support or any drift
stops before archive capture, with no installation/fallback.
An additional fail-closed x86_64
[seccomp filter](https://docs.kernel.org/userspace-api/seccomp_filter.html)
permits socket creation only for TCP stream/default protocol, rejects socketpair
and incompatible syscall architectures, and requires UDP creation to fail with
EACCES13. The offline BPF interpreter covers socket flags, UDP/raw/SCTP, x32
and wrong-architecture cases. This supplies source for the protocol boundary;
no actual kernel installation or UDP negative control has run.

Current source has no causal OOM/PID or watchdog-termination pilot. Memory/PID
readbacks remain configuration evidence; the 64 MiB pilot cannot accept this
256 MiB service. Those executable controls, the actual outer platform and
registration still require source review and scoped admission. No runtime
acceptance follows from these injected tests or from a hypothetical returned
receipt. The proposed acquisition stage remains pending, with no actual
download, package, image, service, mount, listener or BYOND action performed.

The future literal standard public Ubuntu runner has
[free Actions usage](https://docs.github.com/en/billing/concepts/product-billing/github-actions).
The proposal uses neither artifact uploads nor cache/image storage. A private
repository, larger runner, paid image or unverified cost path fails the external
dispatcher gate. The source does not register a workflow or authorize a run.

Run offline controls with the configured real Python interpreter:
`-B -m unittest discover -s tests/reserved_lighting/native_preflight/hosted -p 'test_*.py' -v`.
All external network, Linux mount, time and filesystem effects in these tests
are injected. Passing them does not establish actual TLS endpoint, tmpfs,
systemd/cgroup, ZIP contents, native or measurement acceptance.
