# Deferred reviewed YouTube requests

This is a default-disabled implementation proposal. Merging this source does not
enable the controller, create a queue, open an upload gate or grant new access.
The existing manual uploader remains usable with the feature disabled.

## Activation blocker and owner decisions

The controller requires fresh REST reads of repository **and** protected
environment variables, including immediately after environment approval. GitHub
documents repository Variables read permission for the first endpoint and
Environments read permission for the second. Neither is an available workflow
`GITHUB_TOKEN` permission key. Therefore source review and passing offline tests
alone do **not** establish that this controller can operate with the existing
token. A denied/unavailable read stops before dispatch or media transmission.

After reviewing the source branch, manually dispatch `YouTube uploader contracts`
on that exact branch. Its credential-free capability step attempts only the two
variable-list GETs with the ordinary workflow token and emits support/status
booleans, never variable values. Both `supported` fields must be true before any
queue initialization or feature activation is considered. A false result is an
activation blocker requiring a separately reviewed authorization design; do not
add a PAT, change grants, suppress the check or substitute cached variables.
The probe does not itself initialize or enable anything.

The following remain separate owner-approved operations after source review and
successful capability proof:

1. Approve the proposed controller's `contents: write` and `actions: write`
   permissions, native workflow dispatch/cancellation, and hourly execution.
   Its issues/pull-request permissions are read-only. No YouTube secrets enter
   the controller job.
2. Initialize `deferred.json` from `tools/youtube/deferred.example.json` on the
   existing data-only `youtube-upload-receipts` branch, preserving `receipts.json`
   and all historical reservations. Missing queue data fails closed.
3. Explicitly enable repository `YOUTUBE_DEFERRED_ENABLED=true`. Absence or any
   other value disables the scheduled job and uploader deferral hook.
4. For a bounded attempt, independently authorize/open all six existing gates
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
`tick`, `status` and `cancel` operations. `cancel` requires the displayed queue key.
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
