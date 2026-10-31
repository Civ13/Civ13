# GitHub-hosted wildlife smoke: nonexecuting launch proposal

Status: **plan for main review; not an execution authorization or a run.** No
workflow, branch, container, download, image build, compiler or daemon has been
published or started by this proposal. User authorization covers isolated cloud
compilation and bounded movement/save regression as reviewed stages become ready;
the user also approved the specific restricted temporary Docker setup on the
GitHub-hosted runner. Main source review and a concrete job are still required.
The denied Windows desktop runtime is not retried. No Gaia, live world, host
firewall, Docker daemon configuration, or repository security setting is changed.

## Existing infrastructure and its limits

`moving-save-chunks.yml` is an existing repository-owned GitHub Actions manual
workflow on `master`; it already uses the standard hosted Linux runner, pinned
checkout, repository-release acquisition and BYOND verification. Its current job
runs its own save/memory suite and is **not** an entry point for this wildlife
harness. `reserved-lighting-containment.yml` and `containment_pilot.py` provide
examples of explicit manual admission, immutable image readback, per-container
Docker controls, scoped CID/label cleanup and bounded CLI logs. Their control-only
scope excludes BYOND. Do not dispatch, broaden or retry that pilot for this task;
its previously failed and successful small-container receipts are historical and
do not prove this larger native envelope. Reuse narrow implementation patterns,
not its hardcoded 64-MiB/16-PID cases or its 240-second controller.

GitHub's manual-dispatch workflow must exist on the default branch. A branch-only
new workflow cannot be dispatched merely because it was pushed. The local source now adds a **default-false, manual-only wildlife selector** to
the existing `moving-save-chunks.yml`, with a guard that prevents
its unrelated `isolated-native` job from running when that selector is true. Keep
ordinary pull-request and manual behavior unchanged when false. The selected
branch's reviewed version would be dispatched once with an exact expected commit.
Before relying on this route, verify in the target repository that the existing
workflow remains registered on default and that a branch-ref dispatch uses the
reviewed branch version. A separately registered new workflow would require a
normal reviewed default-branch registration, outside the present no-merge hold.
No fallback silently broadens the existing measurement suite.

## Exact known pins and remaining image work

- Standard public-repository runner: `ubuntu-24.04`, Linux x86-64; verify repository
  ID `141349998`, public visibility, `RUNNER_ENVIRONMENT=github-hosted`, OS and
  architecture before allocation. No paid or larger runner.
- Checkout action: `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683`,
  exact workflow/feature HEAD, `fetch-depth: 1`, `persist-credentials: false`.
  Require a clean worktree and exact `GITHUB_SHA`/input/head identity after the
  final test-job commit exists. The eventual HEAD will differ from this plan's
  current commit; never substitute the older reviewed feature SHA.
- Candidate base image, exactly as the existing pilot: Linux/amd64
  `docker.io/library/python@sha256:57d96f71de145a98e7ceca18ee4ade77bba4103a33a72dfaea026b23625c6bf0`,
  expected image ID
  `sha256:3c4d812a6efe003770aafbdba65f9c1960ba8234ab23a133934205a70bdcda77`.
  Inspect manifest digest, image ID, OS and architecture after anonymous pull.
  This is a pinned **Python base image**, not a complete BYOND/Git runtime image.
- BYOND Linux archive `516.1688`, 4,887,281 bytes, SHA-256
  `16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9`;
  use `scripts/byond_toolchain.py` with its explicitly pinned repository-release
  route, and `scripts/byond_runtime.py` before every native phase. The known
  DreamMaker and DreamDaemon member hashes are respectively
  `5c7d95f6a5f6f6b096409794446416e006503005996ef37dd52f48fdcf59bfa9` and
  `0047b52e042647ea3a496b368ab829672917052a130cb67646c515a01c20188a`.
  These are observed byte identities, not a vendor-signed guarantee.
- **Unresolved blocker:** the base does not establish the 32-bit loader,
  transitive libraries or a working Git executable required by this exact
  harness. The repository's `native_preflight/toolchain.json` explicitly leaves
  dependency versions, rootfs closure and final image identity unresolved.
  Pin and independently review the exact package/archive identities, regular-file
  hashes, loader paths, 64-bit Git and its dependencies, i386 BYOND dependencies,
  compatible base and licenses. Then either provide that closure through reviewed
  read-only mounts or produce and review a final immutable image digest/ID. Never
  infer the final digest from the base or silently run host `apt`, `dpkg`, an
  unpinned package install, privileged image build, or host libraries. No native
  launch can be claimed ready until this dependency packet exists.


### Additional candidate: pinned i386 Python image

Docker's official catalog identifies the `linux/386` manifest for
`python:3.12-bookworm` as
`docker.io/library/python@sha256:e859437f5f6d28ecc8452905c49f0729533f72e680feec294186e1ab3799a445`
(index `sha256:a5bab0ff300f91231c2e68bf73a8a8d60762ac39ce1c50eaf6803e4c38a9062b`).
Unlike the earlier amd64 slim base, this is a full i386 root filesystem. The
upstream buildpack dependency recipes include Git and i386 curl development
libraries. This makes it a **candidate** for the Git/Python/BYOND runtime without
host package installation. The exact image has not been pulled or inspected, its
Git/loader/transitive library hashes and kernel IA32 support remain unverified,
and the candidate must not be called an accepted dependency closure.

After main reviews the controller and acquisition bounds, the proposed exact
preload action is an anonymous public-registry pull on the temporary hosted VM:

```text
docker pull --platform linux/386 docker.io/library/python@sha256:e859437f5f6d28ecc8452905c49f0729533f72e680feec294186e1ab3799a445
```

Then read back `docker image inspect` OS/architecture, repo digest, image ID and
size. Independently inventory the image's Git, `/lib/ld-linux.so.2`, the exact
32-bit loader/libc/libstdc++/libgcc/libcurl and their transitive runtime members,
with hashes and licenses, without executing BYOND or package scripts. A
read-only, bounded Docker export/ELF-inspection phase needs its own reviewed host
storage/stream and timeout limits; neither its implementation nor closure proof
exists yet. After isolation admission, the staged worker performs bounded `ldd`
loader tracing of its i386 Git, Python and four pinned BYOND ELF members, rejects
missing dependencies and records the observed library hashes. That loader trace
is a native process inside the container and is not a complete proof of optional
`dlopen` paths or a substitute for independently reviewing the image. No apt/dpkg install, build, or privileged container is implied. Stop
if the exact image or closure cannot be independently verified. The controller
requires a preloaded image and never pulls or builds it. The source-stage workflow
coordinator performs at most one anonymous digest-pinned pull before entering the
controller, with a 120-second phase limit and the shared 600-second deadline.

## Proposed branch job and isolated container

After the dependency packet, workflow changes, supervisor and exact commit are
reviewed, the standard GitHub host performs only source checkout, verified public
archive/base acquisition and a narrowly scoped Docker controller. It receives
only GitHub's ephemeral `contents: read` checkout credential where necessary;
`persist-credentials: false` prevents writing it into the repository. The
container receives **no credentials, token, Docker socket, host Unix socket,
ports, devices, production data, secrets or inherited Actions environment**.
Verify mount lists and sanitized environment before start. Archive, source and
runtime inputs are read-only. Bind-mount only the minimum exact source tree/Git
objects and independently inventoried runtime files; validate the checkout does
not contain persisted credential headers. Use the nonzero numeric checkout owner
as container UID/GID after explicit validation so Git's ownership checks need no
unsafe global override. The writable 1-GiB scratch mount is a separate tmpfs.

The reviewed controller should create exactly one uniquely named/labelled
container, verify the returned CID and inspected settings before start, then run
Python directly as its initial process; do not use an Actions job container,
`docker exec`, privileged mode, host networking, extra capabilities or unconfined
profiles. Proposed per-container settings:

```text
--network none --read-only --user <verified-nonroot-checkout-uid:gid>
--cap-drop ALL --security-opt no-new-privileges
--pids-limit 64 --memory 3g --memory-swap 3g --cpus 2
--cgroupns private --ipc private --shm-size 1048576
--tmpfs /work:rw,noexec,nosuid,nodev,size=1073741824,mode=1777
--mount type=bind,src=<exact-clean-checkout>,dst=/source,readonly
--mount type=bind,src=<verified-byond-bin>,dst=/opt/byond/bin,readonly
--mount type=bind,src=<verified-pinned-zip>,dst=/inputs/byond.zip,readonly
--workdir /source --restart no --stop-timeout 1 --no-healthcheck
--log-driver local --log-opt max-size=1m --log-opt max-file=1 --log-opt compress=false
--platform linux/386 --entrypoint /usr/local/bin/python3.12 <verified-i386-candidate-image>
-I -B /source/tests/human_subtile/cloud_npc_smoke.py --head <reviewed-job-HEAD>
--byond-bin /opt/byond/bin --byond-archive /inputs/byond.zip
--scratch-root /work --reviewed-cloud-envelope
```

All angle-bracket values are unresolved review inputs, **not executable shell**.
Each bind source/destination, image ID, UID, environment and Docker inspect result
must match the reviewed packet. Only configure the new container's namespaces and
limits; do not alter runner firewall, host networking, Docker daemon config,
security profiles, kernel settings or desktop state. `--network none` provides
only loopback inside the container; confirm there are no shared host-socket mounts.
The user has approved this restricted temporary container and hosted Docker-daemon
use. No host-level security/network change is proposed or authorized.

## Time, cleanup and evidence

One harness invocation first checks the i386 loader inventory, then compiles one isolated full-source-derived **fixture DME**
with map includes removed, then launches two sequential smoke daemons. This is
not a full production-game compile. Harness limits are 600 seconds aggregate,
120 seconds compiler, 90 seconds per daemon, 3 GiB/zero swap, two CPUs, 64 PIDs
and one dedicated 1-GiB in-container scratch filesystem. Docker process-group and
container cleanup should use the retained CID plus unique owner/head/scope labels,
inspect identity before kill/wait/removal, census cgroup descendants, retain
partial receipts, and never signal an unrelated container. No automatic retry;
reconcile uncertain create/start/dispatch before any possible follow-up. An
incomplete cleanup or unverified isolation is a failed/incomplete result.

The staged harness records bounded phase/status checkpoints, packages only
allowlisted evidence, and emits an explicit finished/error marker with an at-most-
15-second evidence lease inside the same 600-second budget. It cannot handle SIGKILL, process-wide OOM or host
loss; Docker removes tmpfs contents when the container stops. The new task-specific controller implements that bounded copy and identity-checked
removal in source, with an independent deadline watchdog, but it has not been
reviewed or run and **detailed evidence export is not yet assured**. It waits for
the marker in bounded logs, then retrieves
only an exact allowlist of receipt, source manifest, compiler/daemon logs and
summary from the still-running container via Docker copy; no `docker exec` and no
writable host bind. Stream and validate archive members as data, reject links,
traversal and extras, and enforce per-file and aggregate output caps before writing
into a fresh runner-temp directory. Preserve partial failure evidence; if OOM,
crash, alarm or runner interruption prevents copying, report incomplete with
available bounded container logs. After the copy lease expires, wait for exit and
perform identity-checked container removal with verified absence. Record Docker
exit/OOM state and host-side timeout or signal even when the Python process cannot
write a receipt. Reserve teardown within a hard 600-second host deadline, and use
a separate outer watchdog that forcibly retires this exact owned container if the
controller itself stalls. A sampled empty cgroup alone is not container cleanup. Retain evidence for a short bounded period with
bounded workflow logs; exclude DMB/RSC and temporary save contents. The
coordinator compresses the exact evidence allowlist to at most 1 MiB, emits a
hash and numbered base64 chunks, and fails if it cannot retain that evidence.
No artifact upload or paid service is selected.

The 1-GiB tmpfs is a hard bound for fixture scratch, **not** a bound on Docker
image layers, shared host daemon data or GitHub runner logs. The existing pilot's
1-MiB local log rotation is not a complete hard host-disk budget. Before launch,
main must choose and review a finite acquisition/image/daemon/evidence storage
budget and demonstrate or explicitly account for those host-side writes without
changing Docker daemon settings. If a required hard host quota cannot be provided
by the ordinary hosted runner, stop rather than describe the whole job as capped.

## Outcomes and outstanding checks

A passing vendor run reports only the existing 46 vendor/pulse/cancellation and
save-codec assertions. The separate nine-check wildlife fixture directly calls
the contact-tick helper; it does not establish actual Life cadence, bite/disease
probability, general AI, full-game compilation, multi-tile collision, visual
smoothness or safe live operation. The broader native plan remains in
`WILDLIFE-NATIVE-PLAN.md`. A failed run cannot be called a feature pass.

Before execution main must review: exact workflow and commit, base and full
runtime dependency identities, ownership/mount and network boundary, timeout and
hard storage accounting, evidence-hold/copy implementation and negative controls,
reviewed container-only security action and Docker-daemon use. Publishing the temporary reviewed branch and
launching its one job are only for the user-authorized cloud validation; neither
publishes, merges, deploys or claims the feature ready.

References: [GitHub manual workflows](https://docs.github.com/actions/managing-workflow-runs/manually-running-a-workflow),
[Docker none network](https://docs.docker.com/engine/network/drivers/none/),
[Docker resource limits](https://docs.docker.com/engine/containers/resource_constraints/),
and [Docker tmpfs](https://docs.docker.com/engine/storage/tmpfs/).

Candidate references: [official Python image manifest](https://hub.docker.com/layers/library/python/3.12-bookworm/images/sha256-e859437f5f6d28ecc8452905c49f0729533f72e680feec294186e1ab3799a445), [official buildpack recipe](https://github.com/docker-library/buildpack-deps/blob/master/debian/bookworm/Dockerfile), and [official SCM recipe](https://github.com/docker-library/buildpack-deps/blob/master/debian/bookworm/scm/Dockerfile).

## Source-stage implementation and scratch estimate

`cloud_npc_controller.py` now contains a task-specific, explicit-execute hosted
controller. It requires the exact candidate 386 image to be **preloaded** and
never pulls, builds or installs it. It checks the hosted job identity, clean Git
HEAD and credential-free checkout config; uses a credential-free Docker client
configuration; creates and inspects exactly one labelled nonprivileged container;
checks resource, namespace, entrypoint, command and mount settings; and supervises
one worker with an independent watchdog started before container creation. It
copies one bounded, hash-checked and allowlisted evidence tar during the worker's
lease and revalidates both distinct suite receipts on the host. It records
terminal/OOM state, kills/waits/removes only the exact owned container, and checks
absence. A timed-out create with no reconciled identity stays uncertain and keeps
the watchdog until its deadline. The separate watchdog also reconciles the fresh
name and labels before any action. Controller, watchdog and fixture code are
**unreviewed and unexecuted**; injected tests do not establish actual Docker or
kernel behavior. VM loss can still prevent durable local receipts.

At the prior exact source revision `bfd223e072db7dc2115215d97019a542803d35cd`,
`git ls-tree` reported 3,819 selected tracked blobs totaling 244,072,975 bytes.
The archive and extracted stage thus require at least roughly 488,145,950 bytes,
plus tar metadata. The harness now uses one hashed, read-only compiled DMB/RSC
copy hard-linked into both distinct runtime directories, rechecking its hashes
before and after each daemon. Compiled bytes, config, logs, temporary saves,
evidence tar and tmpfs overhead remain additional. The actual total has not been
measured; 1 GiB remains a hard tmpfs limit and ENOSPC is a test failure, never an
excuse to enlarge the cap. These figures describe the prior revision; recompute them for the final reviewed
commit.

The worker samples tmpfs allocation every 0.25 seconds and reports the highest
observed allocation after packaging evidence. This sampled value can miss a
short-lived peak; the 1 GiB filesystem quota remains the hard limit. No actual
peak or native result is available before the reviewed cloud execution.

## Implemented source-stage workflow and host checks

The checked-in local change to `.github/workflows/moving-save-chunks.yml` now has
an exact-head, public-repository, manual-only selector that defaults to false. It
skips the existing unrelated job only when that selector is true. The source-stage
`cloud_npc_job.py` measures the selected Git blobs, checks runner and Docker data
are on the same observable filesystem, requires 5 GiB initial free space, and
samples host free space while acquiring at most one immutable image and one pinned
BYOND archive. It interrupts on a sampled 3 GiB growth threshold or 2 GiB free
floor. Sampling may miss or overshoot a burst and is **not a hard host quota**;
the existing 1 GiB container tmpfs remains the hard fixture-scratch limit.
Image/layer writes live in the standard ephemeral hosted runner's existing Docker
daemon and are not deleted or represented as bounded by that tmpfs. No host
network/firewall/daemon configuration, package install or paid runner is used.

The coordinator shares one absolute 600-second deadline with the controller and
its independent watchdog. The watchdog begins containment with 60 seconds left,
verifies exact CID/name/labels and prioritizes kill/wait/stopped inspection and
owned removal/absence; bounded logs are optional only after stop if time remains.
The worker performs a network-none i386 Git/Python loader preflight before tracing
pinned BYOND ELF dependencies; no DreamMaker or DreamDaemon launch is attempted
if that preflight fails. The source changes, image closure, preloaded layer size,
Docker daemon accounting and actual workflow behavior remain unreviewed and
unexecuted. Any failed or uncertain phase remains incomplete, with no automatic
retry. A hosted VM loss or SIGKILL can still prevent logs from being persisted.
