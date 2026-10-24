# Acquisition-only source packet and adapter wrapper

This prepares a separate, future BYOND 516.1681 toolchain acquisition proposal for
PR #3243. It does not activate a workflow. The command line prints the unresolved
plan; there is no execution switch or implicit host/network/Docker fallback.
No download is performed by this source update. It reuses the already-retained
official archive and its independently checked HTTPS-origin receipt.
No package script, compiler, DreamDaemon, game or measurement runs in this scope.
The accepted parent preflight source is unchanged.

The reuse review found:

* `scripts/travis_pre_byond.sh` supplies the Linux URL and historical dependency
  names. Its host apt/dpkg/install/delete/full-game compile sequence is not used.
* `tools/opendream-client/native/Byond.cs` supplies useful explicit-redirect,
  exclusive-output, hash and length principles. Its Windows installer/checksum,
  GUI installation and retry paths are unrelated and are not reused for Linux.
* The accepted parent `Dockerfile` and Python base digest/ID are exact inputs.
  The existing Python pilot proves neither acquisition nor a BYOND image.

`plan.json` now binds the official Linux archive (4,884,042 bytes, SHA256
`614c126b9d0073c67558172c2c2fcb92c31298cf36092208ed55a416326bede3`)
and four selected compiler/daemon/bundled-library members. A bounded static read
validated all 61 regular files, 14,618,256 expanded bytes and five i386 ELFs.
These are observed official-origin HTTPS identities, not publisher signatures.
The original collector's EOF bookkeeping error remains in its receipt; exact
Content-Length and independent hash reads reconciled completion offline. The
mirror failed TLS and is excluded, without retry or certificate-policy change.
No new capture workflow or duplicate download is needed to discover these hashes.
Dependency package versions/index provenance/closure, executor and external
network/storage/image/handoff identities remain unresolved. Validation rejects unresolved values before any adapter action.
Every download needs its exact HTTPS URL, SHA256 and byte length. Every selected
regular member needs its exact archive path, rootfs destination, SHA256 and size.
There are no whole config/runtime copies, inferred dependencies or package-manager
scripts. Any future changed archive needs a newly reviewed identity. The wrapper never
turns an unknown checksum into approval by downloading first.

Candidate acquisition limits, not runtime acceptance:

| Scope | Hard proposed capacity |
| --- | --- |
| Downloads, extracted rootfs and build context together | 2 GiB |
| Private Docker daemon data-root, image/layer cache and daemon logs | 8 GiB |
| Host controller/transport/image CLI logs and all receipts | 128 MiB |
| Candidate OCI/image export and handoff files | 2 GiB |

Downloaded bytes total at most 576 MiB; each downloaded/selected file at most
64 MiB; selected rootfs and each archive's total expanded members at most 512 MiB;
each archive at most 4,096 members. Receipts are at most 8 MiB within the evidence
filesystem. The shared outer/grant budget is 600 seconds with 30 seconds retained
for cleanup (15 daemon, ten storage, five receipt persistence); a stream request/read is capped at ten seconds, one image preparation
at 240 seconds and one export at 60 seconds. These are proposals, not permission
to allocate the volumes or start a daemon. A bind-mounted context alone cannot
establish the separate daemon/cache bound.

The future storage adapter must demonstrate exact independent hard-filesystem
capacities, ENOSPC controls, exclusive owner+plan claims, no links/path escapes,
bounded reads/writes and exact whole-rootfs inventory checks. All transport,
controller and backend writers must use those volumes. A path-local counter or
polling size check is insufficient hard-disk proof. Existing files are never
adopted or overwritten. An uncertain claim is reconciled only by its exact fresh
owner/plan identity; unknown identity stays incomplete and permits no signals.

The future image adapter must use a separate, retained private daemon/process
identity and socket with its entire state under the bounded daemon volume. It
must not adopt or reconfigure a shared host daemon or use Desktop/production
state. Its `preflight` operation is read-only inspection; creation is confined
to `build_owned`, which retains ownership before returning or raising. Only
anonymous acquisition of the pinned public Python image is proposed, with exact
registry egress hosts in the plan, no registry login, credentials or secrets.
Actual network-policy/DNS/redirect/registry enforcement and private-daemon
process-tree retirement require independent controls. Matching booleans from an
unreviewed adapter is not evidence of those properties.

Final success also requires a fresh shared-budget check after receipt persistence.
An adapter overrun produces an incomplete return and bounded failure closeout;
the source cannot force a blocked OS call to return. No overrun is accepted as a
pass, and failure-closeout writes do not restart acquisition or enlarge its grant.

Archive streaming checks forbid redirects/encoding changes, unexpected lengths,
hash drift, traversal, selected links/devices, missing/changed members and
aggregate expansion. Raw gzip/xz decoding is bounded before tar interpretation;
header/padding/unselected bytes count, xz dictionary memory is capped, and
PAX/GNU long-name/link extensions are rejected before metadata allocation. ZIP
central-directory count/size/extent is checked before library metadata allocation.
Debian ar/data archives are parsed as data; apt/dpkg/make
and control/maintainer scripts are never executed. Required symlink destinations
must instead map to explicitly hashed regular archive members. The exact recipe
permits only FROM/COPY/ENV/USER/WORKDIR/ENTRYPOINT; no RUN/native command is allowed.
Rootfs/recipe identity is checked before and after image preparation.

A newly created image's ID is an output, not a fictional prior known input. The
wrapper captures that ID, the base identity, export hash/size and provenance as
`CANDIDATE_REQUIRES_INDEPENDENT_REVIEW_NOT_NATIVE_ADMISSION`. No resulting manifest
is automatically installed into the parent preflight's accepted toolchain file.
Native preflight still needs independent exact-image/ELF/dependency acceptance,
larger controls and fresh admission, followed later by a separate 22-run grant.

Cleanup is one attempt and owner-bound. Original acquisition/build errors remain
in the receipt alongside cleanup failures. If private-daemon lifetime cannot be
confirmed retired, its mounted storage is retained for exact reconciliation;
unmounting/deleting beneath a possibly live daemon is prohibited. Evidence/export
are retained under their own quotas. No automatic retry, arbitrary recursive
deletion or envelope enlargement is supplied.

There is currently **no real transport/storage/private-image adapter or hosted
workflow in this source packet**. They must be implemented and independently
reviewed in an accepted executor before this is an executable proposal. The
20 injected tests establish controller/validation behavior only. They use tiny
in-memory archives and fake adapters: no network, apt, process, Docker or native
operation occurs. Source tests do not establish actual hard quotas or egress.

For a future public repository job, standard GitHub-hosted compute is free per
[GitHub Actions billing](https://docs.github.com/billing/managing-billing-for-github-actions/about-billing-for-github-actions).
No larger/paid runner, cache service or artifact-upload action is selected here;
bounded export/handoff approval remains an explicit required plan input. The
source neither dispatches a run nor grants permission to spend money.
