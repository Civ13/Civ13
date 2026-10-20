# Deferred reviewed YouTube requests

This is a default-disabled implementation proposal. Merging this source does not
enable the controller, create a queue, open an upload gate or grant new access.
The existing manual uploader remains usable with the feature disabled.

## Dedicated control-read authorization and activation

The controller requires fresh REST reads of repository **and** protected
environment variables, including immediately after environment approval. GitHub
documents repository Variables read permission for the first endpoint and
Environments read permission for the second. Neither is an available workflow
`GITHUB_TOKEN` permission key. The ordinary-token capability probe confirmed this
access gap. The owner has approved a dedicated GitHub App with **Variables read,
Environments read and mandatory Metadata read only**, installed only for
`Civ13/Civ13`. App registration/installation, credential placement and live proof
remain separate operator steps; source review does not establish their completion.
A missing token or denied/unavailable read stops before dispatch or transmission.
Transient GitHub GET failures (HTTP 5xx or network/read errors) wait as
`provider_unavailable` with finite exponential backoff and consume the existing
six-attempt budget. The next eligible tick freshly revalidates approval and source;
invalid/revoked approval, permission denial and malformed data still block. This
classification never retries a mutation or uncertain media insertion. A skipped
upload returns to `gates_closed` waiting only when its single matching inspection
job succeeded and the complete bounded job inventory confirms that pairing.
Failed, cancelled, missing or ambiguous inspection requires reconciliation.

The denied ordinary-token probe is retired and removed from contract CI; its
historical evidence is run `39473476821`. Do not retry it. After approved App setup
and reviewed default-branch code, manually dispatch `control-probe` on the deferred
workflow. It reads only the eight named controls, reporting only HTTP/support
outcomes, with no queue access or upload activation. It is allowed with feature
OFF. Missing optional-to-operation configuration (`YOUTUBE_DEFERRED_ENABLED` and
`YOUTUBE_DEFERRED_ARMED_UNTIL`) is reported as 404 and leaves the overall proof
incomplete; create them as `false` and `0` only after separate owner approval.
Never enable or arm merely to run the proof. Do not initialize the queue or enable
the feature until proof/storage approvals are complete. Do not add a PAT, suppress
a failed read, broaden App permissions or use cached controls.

The pinned official `actions/create-github-app-token` v3.3.0 action
(`64ab729a6294000f5aa4a4bc0b73d1f32bc45510`, Node24) mints a job-local installation
token restricted to owner `Civ13`, repository `Civ13`. The public App identifier is
repository variable `YOUTUBE_CONTROL_APP_ID`; its supported legacy `app-id` input
is used. This version has no `permission-variables` input (upstream issue #231).
Setting only `permission-environments` would omit required Variables permission.
Therefore **all** `permission-*` inputs are deliberately omitted, inheriting only
the dedicated installation's exact three approved read permissions. Never add
other permissions to this App; a permission change needs new source/owner review.
Do not invent an unsupported action input. The checked-in action metadata fixture
records the missing narrow input. Default post-job revocation is explicitly kept
on, including on failures. Installation tokens expire after one hour if cleanup
cannot complete; no token is passed to another job.

Only the mint action receives `YOUTUBE_CONTROL_APP_PRIVATE_KEY`. Python receives
its ephemeral output as `YOUTUBE_CONTROL_TOKEN`, used by a separate `ControlReader`
for eight fixed named GETs: repository `YOUTUBE_UPLOAD_ENABLED`,
`YOUTUBE_UPLOAD_STOP_USE`, `YOUTUBE_ZERO_COST_CONFIRMED`, `YOUTUBE_DEFERRED_ENABLED`,
`YOUTUBE_DEFERRED_ARMED_UNTIL`, plus only the first three names in environment
`youtube-unlisted`. No variable lists, arbitrary routes, other environments or
writes are exposed by this reader. Ordinary `GITHUB_TOKEN` retains queue Contents
CAS, workflow dispatch/cancellation, provenance, artifact and receipt operations.
The official action separately revokes its own token during post-job cleanup;
application code never uses the control-read token for a mutation.

The controller tick uses a separate `youtube-controls` environment with **master-only
deployment policy**, containing no YouTube credentials. Create and read back that
policy **before** placing the private key or running any tick that references it:
GitHub automatically creates missing referenced environments without protections.
This source does not claim to verify deployment-branch policy at runtime. Manual
status/cancel run in a separate job with no environment or App mint, so reading or
cancelling with the feature disabled cannot accidentally create this environment.
The upload worker mints its own token only after the existing `youtube-unlisted`
human review, and only when deferral is enabled or an existing deferred claim is
present. The optional named key forwarding preserves ordinary manual feature-OFF
uploads with no App key or control-read dependency. Existing reviewer requirements,
YouTube credentials and six gate names are unchanged.

The following remain separate owner-approved operations after source review and
successful dedicated-token capability proof:

1. Approve the proposed controller's `contents: write` and `actions: write`
   permissions, native workflow dispatch/cancellation, and hourly execution.
   Its issues/pull-request permissions are read-only. No YouTube secrets enter
   the controller job.
2. Obtain explicit storage approval for the App private key in master-only
   `youtube-controls` and existing protected `youtube-unlisted`, and the public
   App ID in repository variable `YOUTUBE_CONTROL_APP_ID`. Verify the installation
   targets only this repository and has exactly the approved read permissions.
   Registration, key creation and secret placement are not performed by this source.
3. Initialize `deferred.json` from `tools/youtube/deferred.example.json` on the
   existing data-only `youtube-upload-receipts` branch, preserving `receipts.json`
   and all historical reservations. Missing queue data fails closed.
4. Explicitly enable repository `YOUTUBE_DEFERRED_ENABLED=true`. Absence or any
   other value disables the scheduled job and uploader deferral hook.
5. For a bounded attempt, independently authorize/open all six existing gates
   and set repository `YOUTUBE_DEFERRED_ARMED_UNTIL` to a UTC Unix timestamp no
   more than 900 seconds ahead. The controller and approved worker recheck this
   deadline. The controller has no variable-write operation and cannot extend
   the deadline or reopen gates. Restore the six gates OFF afterward and verify
   readback using the established operator procedure.

Do not leave gates open to await a future rate-limit slot. A waiting queue entry
can outlive the arm window, but requires another explicit bounded activation
when due. This preserves the global emergency-stop authority. It does not promise
unattended upload while the owner has closed gates. Protected environment review
and the exact current human clip-approval comment remain required per attempt.

References: [repository variables](https://docs.github.com/en/rest/actions/variables#list-repository-variables),
[environment variables](https://docs.github.com/en/rest/actions/variables#list-environment-variables),
[workflow token permissions](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#permissions).

Action references: [pinned v3.3.0 documentation](https://github.com/actions/create-github-app-token/blob/64ab729a6294000f5aa4a4bc0b73d1f32bc45510/README.md),
[missing Variables input](https://github.com/actions/create-github-app-token/issues/231).

## Eligibility and durable state

When enabled, the existing approved upload path can record a deferral before any
media transmission. Only registered immutable historical manifests are eligible;
their original approval digest/comment and media SHA256 are pinned. The queue key
is the destination channel plus media SHA256, so changing source revision cannot
create a second item for identical bytes.

`next_eligible_at` is UTC and separate from `hold_reason`. The existing two-reservation
rolling 24-hour cap includes uncertain reservations. Its inclusive boundary means
a reservation made at `t` releases its slot at `t + 86401`, not `t + 86400`.
The two current reservation timestamps `1792497964` and `1792509762` first allow
another reservation at **2026-10-21 12:06:05 UTC**. This is eligibility, not a
promise of dispatch: the native controller polls hourly at minute 17 and GitHub
may delay scheduled jobs. An explicitly authorized manual tick can run sooner.
No runner sleeps until a future timestamp.

Trusted provider `Retry-After` and reset headers are reduced to a bounded UTC
timestamp. Unknown read limits use finite conservative backoff; YouTube quota
responses without reliable reset metadata wait 24 hours. Only fixed status,
timestamp and a media-attempted boolean cross the PHP boundary. Response bodies,
headers, credentials and URLs are never copied into queue reasons or logs.

The queue uses the GitHub Contents SHA as a compare-and-swap lock. A successful
durable claim must precede native workflow dispatch. If dispatch acknowledgement
is lost, the controller reconciles an exact token, workflow, branch, commit and
run attempt. An unknown or duplicate result blocks owner reconciliation; it does
not redispatch. Controller concurrency is separate from destination upload
concurrency, allowing overdue reviews to be cancelled. It checks all queue owners
and bounded active manual upload runs before starting another request.

Each item expires after seven days and has at most six dispatch/provider attempts.
Observing closed gates consumes no attempt. A run still pending/running 15 minutes
after dispatch is marked blocked and receives native cancellation. Cancellation
does not undo an insert or reservation, and an uncertain cancellation remains
blocked. `cancel` records a terminal owner cancellation before requesting native
run cancellation. Cancelled, expired, blocked and exhausted entries cannot be
revived by another enqueue.

Any attempted `videos.insert` failure, including an explicit 429, keeps its durable
reservation and requires reconciliation. A queue never clears a receipt to gain
retry permission. A known video ID permits owner readback/verification only;
successful public processing readback completes the queue. An ambiguous insertion
without an ID blocks further media transmission.

## Revalidation and artifacts

Every due attempt checks the current default-branch source, current human approval,
source/run provenance, importer identity, fresh receipt ledger, gates and artifact
metadata. The worker checks queue ownership, cancellation/expiry, source and fresh
gates again after protected environment review. A changed trusted branch stops
that attempt.

Expired/missing artifacts or an importer from an older trusted commit trigger the
existing importer using the **same immutable reviewed media bytes**. Its normal
hash, transformation, metadata and inspection checks still apply. No capture or
server startup is performed. The PR3031 derivative uses its exact reviewed masked
transport; the unmasked original is provenance data and cannot replace approved
public media. New historical manifests are discovered from the importer registry,
without weakening generic source or duration validation.

## Status and recovery

The default-branch `Deferred reviewed YouTube requests` workflow supports bounded
`tick`, `status`, `cancel` and read-only `control-probe` operations. `cancel` requires the displayed queue key.
Manual `status` and `cancel` remain available while the feature is disabled;
`tick` remains disabled. Cancellation never requires reopening the feature.
The Actions summary displays manifest, state, waiting reason, independent hold,
UTC eligibility and consumed attempt count. Durable queue records retain the
claim token, importer/upload run IDs and approved digest. `receipts.json` remains
the authority for upload outcome and duplicate prevention.

For blocked/uncertain outcomes, inspect the exact Actions run and channel/receipt
through the existing owner procedure. Do not delete an uncertain reservation,
reset attempts, edit approved media identities or replay an insert. This source
does not implement an owner override or automatic reconciliation of unknown media.

Offline tests cover the exact rolling boundary/current reservations, provider
metadata and timezones, CAS races, manual destination ownership, unknown dispatch,
overdue cancellation, revoked approval, stale artifacts, known-ID verification,
disabled gates/feature, bounded attempts and masked original separation. They do
not establish live token capability or prove an upload occurred.
