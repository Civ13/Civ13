# Reserved-lighting containment-only pilot

`.github/workflows/reserved-lighting-containment.yml` prepares a separate
manual pilot; container execution requires workflow_dispatch and confirmation defaults to false.
A PR introducing this suite runs only six injected offline tests through the
existing change-selection policy. PR events cannot enter the container job. Its
only runner is the standard `ubuntu-24.04` GitHub-hosted runner for this public
repository. A live repository-ID/visibility check, exact reviewed SHA and manual
confirmation must pass. No BYOND, compiler, game input, measurement batch,
credentials, cache or artifact-upload step is included. No Docker pilot result is claimed by this source change. No Desktop image or runtime is installed.

`containment_pilot.py` defaults to printing an inert plan. Its explicit execution
mode additionally rejects non-Linux, self-hosted, private-repository, non-manual,
wrong-repository and mismatched-head contexts before Docker access. The official
Python Linux/amd64 image is pinned by manifest digest and image ID, sourced from
Docker's repo-info Git blob `e4a0e633985ceac539eb2d33c23c98df0ef167a9` at
https://github.com/docker-library/repo-info/blob/master/repos/python/remote/3.12-slim-bookworm.md.
The future hosted job may anonymously pull that image; no registry login occurs.

The smaller containment-only envelope is 64 MiB container memory with the same
memory-plus-swap ceiling (zero swap), 16 PID/threads, 0.25 CPU, an 8 MiB noexec
scratch tmpfs and 1 MiB shared memory. Host Docker settings and in-container
cgroup/scratch values must read back correctly. Controls check denied egress,
protected-input write denial with a positive scratch write, actual scratch
ENOSPC, PID rejection with an increased cgroup event counter, hard-memory OOM
and forced retirement of an owned surviving descendant. EACCES alone could be
file permissions; separate mount RW=false inspection is configuration evidence.

Containers have a read-only root, only this public pilot script mounted read-only,
no network/published ports, a non-root user, dropped capabilities and private
namespaces. Cleanup signals only an exact retained CID after label/identity
checks, checks retained PID start ticks and cgroup retirement, then removes only
that stopped container. An uncertain create is reconciled by its fresh unique
name and labels; it is never started/retried automatically. Every incomplete
result is retained as incomplete. CLI calls are observed with a 1 MiB log
detection threshold, which may overshoot between polls; it is not a hard host
disk quota. Aggregate controller/cleanup deadlines are 240/30 seconds. Six
injected tests exercise these source contracts; they do not prove Docker or
cgroup behavior. A successful future pilot would still not admit BYOND or the
22-run measurement envelope.

The workflow must be present on master before GitHub permits manual dispatch.
This independent registration contains no experimental lighting, BYOND runtime,
compiler, game resources, measurement adapter or production configuration.

The authorized pilot is exactly one manual execution after required checks and
review and a normal registration merge. The allocator is the sole executor and
must verify current ownership and absence of an earlier dispatch before running.
Dispatch inputs are `confirm_containment_only: true` and `expected_sha` equal to
the exact reviewed merged master commit. No automatic retry is authorized.
The receipt must show all controls and owned cleanup complete; cancellation or
host interruption can prevent receipts and is incomplete, never a success.
CPU-limit readback is configuration evidence, not timing calibration.

Only contents:read is granted. The repository API check receives the ephemeral
read-only GitHub token; it is not passed to container execution. There are no
repository secrets, environment credentials, registry logins or persistent caches.
Anonymous image download and GitHub's job logs are the only external services.
The free standard public runner is selected literally, with no larger runner or
artifact-upload step. No Desktop image, live process, save, port or DMB is touched.

References:
- https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow

Offline verification (use a verified Python executable):
```
<verified-python> -B -m unittest discover -s tests/reserved_lighting -p test_containment_pilot.py -v
```
