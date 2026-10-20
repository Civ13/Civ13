# Reviewed gameplay video uploads

This source-only feature adds a manual, default-off path for selected successful
gameplay clips. It does not create credentials, approve a clip, generate recordings,
publish videos, configure a schedule, or launch a game. The destination is
**@valzartech8995**, immutable channel **UCFRx_n3Mh3FfvL9yOUfG-yw**. The existing
one-off uploader verified this mapping in the authenticated Studio account and
actual handle link on 2026-10-20. Every API invocation independently verifies the
same grant's channel before mutation. The earlier Valgorithms destination is obsolete.

New uploads are public and can be discovered, watched and redistributed. The owner explicitly replaced the earlier unlisted-only request; this code does not change visibility of existing videos.
The uploader always sets `privacyStatus=public` and `notifySubscribers=false`;
neither is a manifest option. A mismatch, rejected video, missing owner readback
or pending processing cannot produce a successful upload receipt.

## Trust boundaries

`youtube-upload.yml` accepts a manifest ID and `execute_upload` (default false).
Its optional `verify_only` flag (default false) selects receipt-only readback.
It calls the reusable `youtube-upload-worker.yml` from the same reviewed commit.
Only a manual invocation of the default-branch wrapper is eligible. PR events,
forks, non-default dispatches and other callers cannot reach the worker's jobs.
No `workflow_run`, scheduled upload or capture trigger is installed.

The wrapper forwards only the three named credential bindings, and the worker
declares those names required. GitHub requires this forwarding even when the
values exist only in the worker's protected environment; omitting it silently
resolves them to empty strings. Required names do not prove nonempty values, so
the Python bridge also rejects missing/malformed credentials before any OAuth/API
request. Environment protection still controls value access, and the inspection
job receives no credential environment variables. Do not use broad secret
inheritance or move credentials to repository/organization scope. See
[GitHub's reusable-workflow secret guidance](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows).

The inspection job has a read-only GitHub token and no YouTube secrets. It loads
only trusted `tools/youtube` code from the default-branch dispatch commit, validates
the selected run/artifact, downloads a bounded archive, and runs the runner's
version-checked `MediaInfoLib 24.01` on the MP4. It never checks out or runs the producer's scripts.

The upload job uses the protected `youtube-unlisted` environment on another
standard Ubuntu runner. It checks out the same trusted code, revalidates current
source provenance and human approval, and downloads/checks the same artifact
again. It installs only the trusted committed Composer lock with plugins and scripts
disabled, before the step that receives OAuth credentials. It never executes an
artifact, decodes media, checks out a PR, or treats metadata as executable input.
Checkout and PHP setup actions are pinned by immutable SHA. Composer 2.9.8 installs
YoutubePHP at commit `7ce9b24eb26a32af7ffcd4936d8083c06a428fb0`; all 23 dependency
references are locked. Python uses its standard library for provenance/receipts;
YouTube API calls and OAuth refresh use the requested YoutubePHP framework through
`adapter.php`. No package update occurs in the secret-bearing workflow.

The worker's GitHub permissions are `contents:read`, `actions:read`, `issues:read`
and `pull-requests:read` for inspection. Upload needs `contents:write` solely to
record durable receipts, plus the same read permissions. GitHub's token cannot
scope Contents writes to one branch: this is a material remaining privilege.
Protect master against this token and keep the receipt branch separate. Receipts
contain public video IDs, hashes and provenance only, never authorization headers,
refresh/access tokens, resumable session URLs or signed artifact download URLs.

## Producer and approval contract

Generic producer policies/manifests are not enrolled in this feature. The exact historical PR3031 pilot described below has separate owner approval; the separately enrolled PR3081 clip retains a new exact human approval comment. No other existing
screenshot, fixture or candidate is implicitly approved as a video. A subsequent
reviewed change must create `tools/youtube/policy.json` from `policy.example.json`,
enroll actual workflow IDs/paths and named human GitHub approvers, and commit a
per-clip manifest in `tools/youtube/approved/<id>.json`. Do not enroll a workflow
until its recorded tested commit matches its Actions run head SHA. For a PR job,
capture the actual tested revision explicitly; do not label a tested merge ref as
the PR head. Initial eligibility is same-repository PRs, or a push/manual run of
the exact merged PR commit. Fork runs are deliberately ineligible initially.

Generate clips/tests in separate jobs with no upload credentials. A producer
must retain the immutable real media path, SHA256, exact tested game commit/PR,
source owner, capture/reproduction context, test result and known limitations.
Use the existing game evidence checker where applicable; passing it proves file
and metadata consistency, not gameplay acceptance or publication approval.

Artifacts must use the `gameplay-video-...` name prefix and contain exactly two
flat regular files: `gameplay.mp4` and `evidence.json`. No directories, symlinks,
encrypted entries, executables or additional files are accepted. The MP4 must be
15-180 seconds, 320-1920 by 240-1080 pixels, H.264 with optional AAC, at most
32 MiB. Its declared duration must match inspection within one second. The ZIP
must be at most 33 MiB, match both GitHub's SHA256 artifact digest and the approved
archive hash, and have been created during the exact successful approved run
attempt. Run ID, attempt, SHA, repository IDs, workflow ID/path, event, branch,
artifact ID/name/size/digest/expiry and PR association are checked via GitHub API.
Missing provenance fields fail closed.

The embedded evidence object has exactly these fields, with actual values:

```json
{"schema_version":1,"tested_commit":"FULL_GAME_COMMIT","run_id":123,"run_attempt":1,"clip_sha256":"MEDIA_SHA256","result":"success","classification":"genuine-gameplay"}
```

Enforce duration/size caps **before** an artifact upload. If an approved capture
producer is added later, pin `actions/upload-artifact` by SHA, select only these
files, disable hidden files, set `retention-days: 1`, and fail when no clip exists.
Do not attach whole evidence trees, saves or logs to the video artifact. The bounded historical importer below retains only the two exact enrolled historical clips for one day; no automatic capture producer is installed.

Review the entire genuine clip for meaningful observed behavior, source ownership,
private chat, credentials, player names, session data, internal paths, unexpected
audio and other unintended content. Reject blank, redundant, failed, synthetic
or misleading footage. Factual title/description and review fields use bounded
printable ASCII without angle brackets; category and audience flags are fixed.
Do not call a scripted/fixture result full gameplay acceptance. The adult game
development audience and absence of synthetic media must be affirmatively reviewed.

Use `manifest.example.json` only as a schema example; its values are placeholders.
After filling real values and creating an enrolled policy, run the trusted script
with `approval --manifest <id>` to print the exact approval sentence. A named human
policy approver must independently inspect the clip and post that exact sentence
as a comment on the specified issue/PR. The sentence binds a SHA256 of all manifest
fields except the comment reference itself, including channel, media/archive SHA,
source commit, metadata, audience and content review. Put the actual comment ID
in the manifest and review/merge it through the normal PR process. An edited
title, different clip, changed limitations or destination invalidates approval.
The current API comment author must be an allowlisted human, the full body must
match exactly, and creation/update timestamps must match. Edit evidence or missing
timestamps require a new comment; generic approval, bot comments and approval on another issue
are rejected. Do not put private evidence references or secrets in this public
manifest or approval comment.

## Exact owner-approved historical pilot

The owner approved the 41-second masked PR3031 recording for public upload, with
subscriber notifications disabled. `imports/pr3031.json` fixes its exact title,
description, media SHA256, original attachment/comment, tested commit and limits.
`upload.py` pins the material approval digest. The public operator approval alias
`owner-approved-pr3031-public-20261020` records already received authorization;
it is not a reusable approval input. Any media, metadata, destination, original
attestation or limitation change fails validation and requires another reviewed
source change. No private conversation reference is committed. The protected
environment still requires the owner's explicit job approval.

The original native capture is owner-attested footage from an isolated pregame
scene, not CI-generated footage or multiplayer acceptance. Its exact-head CI
run 38127733413 succeeded, but did not produce a media artifact. Schema2 keeps that
historical tested commit/run separate from the trusted packaging commit/run.
When that merged historical run has an empty Actions PR association, the pilot
requires GitHub's commit-to-PR association and the merged PR's exact head SHA,
with both repositories verified. Generic producers and conflicting run
associations remain ineligible; no provenance check is skipped.
Original frame presentation times are retained; only the session Game ID is masked,
and the review copy's ending is 0.44 seconds longer. There is no audio or generated
or interpolated gameplay imagery.

The importer is manual, master-only, has no environment/channel credentials and
cannot capture a game, transform media or call YouTube. It needs a **public GitHub
attachment containing the exact approved masked MP4**. A private Library file or
the unmasked original cannot substitute. The importer checks the source attachment
hash, owner comment hash and original successful CI, then separately downloads
and hashes the exact approved masked bytes. Attachment redirects are anonymous,
bounded and restricted to GitHub's media hosts. It probes media only in the
credential-free job, then retains exactly gameplay.mp4/evidence.json for one day.
The artifact action is pinned; one upload is at most 1.31 MB for this pilot.

After importer success, dispatch the trusted wrapper on the **same default-branch
commit** with `manifest_id=pr3031-power-public`, its actual `import_run_id`, and
initially `execute_upload=false`. The trusted code derives the policy and manifest
from the pinned material plus actual GitHub workflow/run/attempt/artifact IDs,
size and digest. It never invents identifiers or calls the historical CI run the
packager. No additional approval-comment post or second enrollment PR is needed
for this exact already approved pilot. Other clips retain the generic per-clip
approval path. `verify_only=true` reconstructs this pilot's manifest from its
durable receipt so artifact expiry cannot block known-ID verification.

The existing credential environment keeps its name `youtube-unlisted`; that is
an environment identifier, not the new visibility policy. Its owner reviewer,
master restriction, disabled administrator bypass and default-off gates remain
unchanged. A public/private mismatch fails readback; no visibility update call
is available and no old video is silently made public.

## Historical PR3081 weapon attachment clip

`imports/pr3081.json` enrolls one additional existing public recording, not a new
capture producer. The owner-attested source is
[PR3081 comment6115344644](https://github.com/Civ13/Civ13/pull/3081#issuecomment-6115344644):
`gun-configuration-captioned.mp4`, SHA256
`f66da1999bead0b726a1bd48167163ce4529eaf627bc98f57d5ed767eb0daf2f`,
2,200,621 bytes, 126.066667 seconds, H.2641920x1032 at15fps, no audio. The tested
game is merge commit `60b8cf9937617d62c4cc01f82bf32401559b84f4`; successful push
CI38183016828 is provenance for that game revision, not its recorder or packager.
The local disposable scene tooling is separately documented in PR3083.

This footage shows empty-SVD inspection, PSO-1 removal, rail/red-dot installation
and native Examine. It uses conventional cuts, captions, focus enlargement and
highlights. Retained actions play at1x. Artificial60percent condition setup is
disclosed; completed cleaning, bench repair and firing are not established.
Startup Bad ref/DecRefCount and nslookup diagnostics prevent clean full-game
runtime acceptance. The MP4 is packaged unchanged from its public attachment;
no transformation or replacement of the historical game revision is permitted.

After normal source review and merge, select
`manifest_id=pr3081-attachments-public` in the existing importer and supply its
public attachment URL from the source comment. Packaging remains credential-free
and may precede publication approval. The uploader still requires an allowlisted
human's exact, unedited comment on PR3081:

```text
I approve Civ13 YouTube upload 5e3277908210fb71e0f27bd6ffdb20c12ca9c78ec6fb07c0279836c25e04493e to @valzartech8995 (UCFRx_n3Mh3FfvL9yOUfG-yw) as public.
```

Print that sentence offline with `MANIFEST_ID=pr3081-attachments-public` and
`prepare_import.py approval`; it is a preview, never a claim of approval.
The checked-in comment ID1 is a placeholder, never publication approval. Dispatch
the upload wrapper with that manifest ID, the actual current-commit importer run
ID and `approval_comment_id` from the owner's new comment. Start with
`execute_upload=false`. Generic statements, old source approval, PR3031's alias,
changed media/metadata and bot/edited comments cannot authorize this upload.
The later live dispatch still requires all six bounded gates and the protected
environment's explicit owner review. `verify_only=true` supports the same clip
with its known receipt after artifact expiry; it never inserts another video.

## Durable receipts and uncertain outcomes

Before enrollment, initialize `receipts.json` on a dedicated
`youtube-upload-receipts` branch using `tools/youtube/ledger.example.json`, after
all known attempts have been accounted for and ledger initialization is authorized. The uploader
refuses a missing ledger or `imports_complete:false`. This flag means all known attempts are imported; an uncertain record may remain blocked while a different clean media hash is tested. Never resolve or delete the uncertain record merely to enable another clip. This branch is data only;
its contents are never checked out or executed. Do not protect it in a way that
prevents the configured token from recording receipts. Restrict deletion/force
push and administrative edits; changes outside the uploader require reconciliation.

The shared source key is:

```text
SHA256("civ13-youtube-v1\n" + "Civ13/Civ13" + "\n" + tested_commit + "\n" + media_sha256)
```

The additional destination+media-hash scan catches renamed manifests and the same
clip from different commits. Coordinate this ledger with every one-off uploader;
the destination+media hash is authoritative even when its source-key scheme differs.
The one-off thread remains owner of its attempted publication. No parallel API
upload is authorized by this source PR.

**Known blocked hash:**
`9c82f548ce4d2251e0dff7e0d607eeaac5c4d8e570b418cfb0103545453ec796`, tested commit
`c3767579b0e72035debe702ae2147c75549a7455` (PR 3228). Its browser file-selection call
failed with an uncertain outcome on 2026-10-20. No video ID or saved visibility was verified. The ledger example preserves it as `uncertain`, with
`imports_complete:false`. This record is a duplicate-prevention block, not content
approval. Do not retry via API or assume that an empty uploads playlist proves no
incomplete Studio draft exists. Owner-authorized reconciliation must cover possible
drafts/incomplete uploads as well as existing video IDs. The API may not expose all
Studio drafts; if it cannot resolve this, stop for owner evidence rather than using
browser automation or another account. Preserve the original one-off receipt.

Every new upload first commits a `reserved` record using GitHub Contents API's
conditional file SHA. If that write fails or is uncertain, no YouTube mutation is
attempted. A single destination-wide workflow lock serializes the full lifecycle.
After successful video insertion, the video ID is saved as `uploaded`, then owner
readback must confirm channel, public privacy, processed upload status and
successful processing before the record becomes `verified`. Polling is bounded to
12 reads with 11 ten-second waits. For a saved video ID, dispatch with
`verify_only:true`: both inspection and execution validate the current human
approval and durable receipt without requiring retained source media or an
unchanged producer run. This route cannot insert media, reserve a new upload or
clear an uncertain outcome; an unknown ID or unreconciled receipt stops before
OAuth. Environment/budget gates still apply. YoutubePHP uses one bounded multipart `videos.insert` call; this pinned version
does not implement resumable video uploads. It holds the file in memory, so the
32 MiB cap applies before the PHP process. There is no upload resumption. The
adapter explicitly overrides the framework's normal 503/rate-limit retry behavior:
a route allowlist, sanitized nonretryable error responses and a process-wide
one-write guard prevent another network send, including 401 replay. Each operation
uses an existing refreshed access token with no device flow, token store or
automatic reauthorization. No retries or account switching occur after an error.

If insertion times out, the job is cancelled, the video-ID save fails, processing
fails or any service returns a quota/rate/error response, stop-use and inspect the
durable record. A reservation without ID or an `uncertain` record blocks another
upload. Do not delete it to retry. After authorized owner reconciliation, attach
the existing video ID and set a known `uploaded` state, or retain a blocking
tombstone. A proven no-upload result requires a separately reviewed operator
decision before any new mutation. Never log session URLs during recovery.

## Secure setup and local helper

Keep one shared setup coordinated with the existing one-off API uploader. Do not
create duplicate projects or grants. The user created project
**`calcium-circuit-384407`** and approved the Desktop client/scopes proposal.
The earlier candidate ID `civ13-gameplay-videos` is obsolete. The user-selected
downloaded JSON passed bounded type/project/endpoint validation without displaying
credential values. The owner subsequently completed the reviewed helper, verified the approved channel and explicitly confirmed the three environment secret writes. Metadata-only readback confirmed placement; upload execution remains disabled. No new grant, secret rotation or account change is part of this feature update.

1. **Project/client:** use only `calcium-circuit-384407`, display name
   `Civ13 Gameplay Videos`. Enable only YouTube Data API v3, with no paid service or billing
   activation. Create one OAuth Desktop client named `Civ13 reviewed uploader`.
   Confirm consent-screen audience/testing status and refresh-token lifecycle.
2. **Channel/grant:** authorize the owning Google account's **@valzartech8995 /
   UCFRx_n3Mh3FfvL9yOUfG-yw** channel, requesting exactly
   `https://www.googleapis.com/auth/youtube.upload` and, as a separately explained
   readback requirement, `https://www.googleapis.com/auth/youtube.readonly`.
   Upload alone is the minimum for insertion. Official API discovery lists
   `youtube.readonly` for `channels.list` and `videos.list`, while upload is absent
   from their allowed scope lists. The same combined grant lets `channels.list`
   with `mine=true` prove the destination before insertion and owner-only video
   processing readback confirm success afterward. Do not request broad `youtube`,
   `force-ssl`, partner or unrelated scopes. The implementation rejects any
   refresh response with missing or additional scopes.
3. **Secure authorization:** use Google's supported Desktop flow with PKCE S256,
   state checking and a temporary loopback listener through a separately reviewed
   local setup helper. The user completes Google's consent UI securely. API-only
   publication does not remove Google's required interactive consent. Never scrape
   browser cookies/tokens, bypass site prompts, put secrets into chat or use an
   unofficial token broker. The user-run helper `tools/youtube/authorize.py`
   implements the code exchange. It never runs from Actions or controls a browser.
   It prints a local start link for the user to open directly; that link redirects
   to Google without logging its authorization parameters. It uses PKCE S256,
   a constant-time state check and a five-minute IPv4 loopback callback. Its
   channel check uses the pinned YoutubePHP framework. Credential/token values
   are not displayed, logged, passed as arguments or written to token files.
4. **GitHub destination:** only `Civ13/Civ13`, environment **`youtube-unlisted`**,
   secrets **`YOUTUBE_CLIENT_ID`**, **`YOUTUBE_CLIENT_SECRET`** and
   **`YOUTUBE_REFRESH_TOKEN`**. Use GitHub's encrypted secret input or a reviewed
   local encrypted transfer, never PR files, workflow inputs, outputs, artifacts,
   repository-wide secrets or chat. Environment deployment branches must allow
   only `master`; require only `valzargaming` (User ID `7202504`) as reviewer,
   set `prevent_self_review=false`, and disable admin bypass
   (`can_admins_bypass=false`). The owner can dispatch and explicitly approve the
   environment job. This is owner review, without a second-person requirement;
   allowing self-review does not bypass the approval step. Do not grant secrets
   to PR/test environments.
5. **Enrollment/activation:** reconcile/import one-off records first; create the
   data branch and reviewed policy separately. Keep repository variables
   `YOUTUBE_UPLOAD_ENABLED=false`, `YOUTUBE_UPLOAD_STOP_USE=true` and
   `YOUTUBE_ZERO_COST_CONFIRMED=false` until their exact setup/first approved run
   is authorized. For a bounded approved run, explicitly confirm public-repository
   standard-runner/$0 eligibility and existing account stop-use budget, then set
   enabled=true, stop-use=false and zero-cost-confirmed=true. No schedule is part
   of this proposal. Start with inspection-only dispatch before enabling mutation.

Risks to approve: the refresh token is persistent access to upload/manage videos
and read the channel under the displayed scopes; public links are shareable;
authorized trusted default-branch code and environment administrators can access
the grant. GitHub masking is not a substitute for keeping tokens/session URLs out
of output. Store the refresh token only in the approved environment, revoke the
Google app grant and remove secrets to terminate access, and close the stop-use
variables immediately on any budget, quota, rate, auth or ambiguity incident.
No approval to create/store credentials is inferred from approval of this PR.

## User-run helper sequence

In [YouTube API Library](https://console.cloud.google.com/apis/library/youtube.googleapis.com?project=calcium-circuit-384407),
enable YouTube Data API v3 with billing unlinked. In Google Auth Platform, choose
Branding `Civ13 Gameplay Videos`; enter your own support/contact details and
review Google's policy agreement yourself. Start with External/Testing and only
your owning Google account as test user. In Data Access enter the **complete
URLs**, not the shorthand names:

```text
https://www.googleapis.com/auth/youtube.upload
https://www.googleapis.com/auth/youtube.readonly
```

In [Clients](https://console.cloud.google.com/auth/clients?project=calcium-circuit-384407),
create the approved Desktop app `Civ13 reviewed uploader`. Do not choose a web
client, service account, API key or TV/device flow. Keep its downloaded JSON in
a private local folder **outside the repository**, restricted to your Windows
account/SYSTEM/administrators. The helper does not change Windows ACLs; use a
private account folder, not shared/synced storage. On Unix it requires owner-only
file permissions (600). No credential values or downloaded JSON belong in chat.

For this assistant-operated automation client, select **Use this client for an
AI-powered agent** when Google offers that self-declaration. Retain Desktop app
and exactly the two full scope URLs above: the designation grants no additional
scopes or privileges. Agentic client IDs are for AI/automated tool use; a future
direct human application or mixed use needs a separately planned client. No
additional client is created by this setup. See [Google's agentic-client guidance](https://support.google.com/cloud/answer/15549257#agentic-client).

Before obtaining a token, the GitHub destination must already have been separately
authorized and configured: public repository `Civ13/Civ13`, environment
`youtube-unlisted`, sole required reviewer `valzargaming` (User ID `7202504`),
`prevent_self_review=false`, explicitly disabled administrator bypass, and an
explicit deployment branch policy allowing only `master` (`protected_branches=false`,
`custom_branch_policies=true`, exactly one rule with `name=master`, `type=branch`).
The helper refuses another/additional reviewer or missing self-review/bypass state.
The helper creates no environment, changes no permissions, and never
overwrites existing `YOUTUBE_CLIENT_ID`, `YOUTUBE_CLIENT_SECRET` or
`YOUTUBE_REFRESH_TOKEN`. Rotation needs a separately reviewed procedure because
GitHub cannot read back prior secret values for rollback.

Repository activation variables must be explicitly set to
`YOUTUBE_UPLOAD_ENABLED=false`, `YOUTUBE_UPLOAD_STOP_USE=true`, and
`YOUTUBE_ZERO_COST_CONFIRMED=false`, shadowing any organization defaults.
Environment overrides must be absent or have those same disabled values.
Keep them disabled throughout setup. The helper
checks those gates before consent and every secret write, and never enables them.
The current source PR need not be merged to inspect this reviewed local helper;
setting secrets does not authorize merging or running uploads.

Install the committed Composer lock with scripts/plugins disabled, using PHP 8.4+
and an already authorized GitHub CLI. Then the user can run this from the repository:

```powershell
& 'C:\Users\valza\AppData\Local\Programs\Python\Python313\python.exe' -B tools/youtube/authorize.py check --client-json 'C:\PRIVATE-LOCAL-FOLDER\client.json'
& 'C:\Users\valza\AppData\Local\Programs\Python\Python313\python.exe' -B tools/youtube/authorize.py authorize --client-json 'C:\PRIVATE-LOCAL-FOLDER\client.json'
```

Replace the illustrative path locally; do not send its contents to the agent.
`check` validates the Desktop JSON's exact project and trusted endpoint fields,
then reads GitHub protection/secret metadata without granting access or writing
secrets. `authorize` requires an interactive local terminal. It rechecks all
prerequisites, prints a fresh local consent-start link, and waits at most five minutes.
The user opens that link directly; its loopback redirect reaches Google's normal
consent page, where the user selects the approved channel/account. The Google
authorization URL, state/challenge and client fields are not logged to the terminal.
Wrong state, denied/error callbacks, duplicates, expired/missing tokens, expanded
scopes or another channel stop before secret placement. The helper makes no
automatic retry or account/client change. It never requests production publication.

After channel verification it displays the repository/environment and refers to
the three credential fields documented above, then asks the user to type:

```text
STORE Civ13/Civ13 youtube-unlisted
```

Only that action starts `gh secret set`, passing values through stdin so GitHub
CLI encrypts them before transfer. The new refresh/access tokens exist only in
process memory until placement; the original downloaded client JSON remains under
the user's control. The helper does not delete that original file. After confirmed
setup the user can remove that download from their private folder according to
their own retention choice. Never run setup/rotation concurrently; a local
credential-free lock prevents two helper processes on this computer.

GitHub has **no multi-secret atomic transaction**. If a write fails, times out or
is interrupted, the helper does not retry it: it attempts removal of newly
attempted names and keeps uploads disabled. A remote write can finish after a
timeout, so every unsuccessful/uncertain write remains blocked for owner
reconciliation even when immediate metadata snapshots show no secret. If cleanup
itself cannot be confirmed, it likewise reports only affected names and stops for owner
reconciliation. A forced process kill or a competing external administrator can
prevent cleanup; the disabled environment gates and exclusive operator procedure
are mandatory. This is compensating rollback, not a claim of server-side atomicity.
No existing secrets are knowingly overwritten or removed. If consent was granted
but setup is declined/abandoned, revoke the app in your Google account; discarding
tokens locally does not revoke that Google grant. No automatic revocation is made
because it could invalidate another authorized session of the same client.

External/Testing refresh tokens for these scopes expire after seven days. Initially
keep uploads disabled and complete the bounded owner checks. For continued use,
choose later between a separately approved consent-screen Production change with
Google's applicable verification requirements, or a separately approved renewal
procedure. The helper does neither automatically and refuses to overwrite secrets.

## Limits and verification

Only public-repository standard `ubuntu-24.04` runners are configured; no larger
runners or paid services. The [deferred controller proposal](youtube-deferred.md)
adds default-disabled hourly scheduling with separate activation blockers and
owner approval. Upload jobs time out at 5/8 minutes. One clip
per dispatch, at most two reservations in a rolling 24 hours, max 1,000 receipt
records and 1 MiB ledger/JSON are enforced. Reaching a cap stops for a reviewed
maintenance plan; never prune dedup history to make room. Existing account-wide
budget/stop-use instructions remain controlling. Short-retention producer artifacts
can expire before review; fail and obtain new evidence rather than broaden access
or retain an unbounded archive. Receipts are small durable text, not video storage.

Current official documentation checked 2026-10-20: `videos.insert` describes a
100-calls/day Video Uploads bucket with cost 1 per call, and says unverified API
projects are not restricted to private viewing. No obsolete private-only project
assumption is used. OAuth consent verification and owner account limits remain
separate considerations. This implementation stays below its own much smaller cap.

Offline contracts and a no-network CLI dry-run test:

```powershell
& 'C:\Users\valza\AppData\Local\Programs\Python\Python313\python.exe' -B -m unittest discover -s tests/youtube_upload -v
composer install --working-dir=tools/youtube --no-dev --no-scripts --no-plugins --prefer-dist --no-interaction
php -d display_errors=0 tests/youtube_upload/framework.php
```

On Linux use `/usr/bin/python3`. With a real reviewed policy/manifest enrolled,
`upload.py dry-run --manifest <id>` validates local inputs without network, OAuth,
receipt writes or uploads; `approval` prints the exact required approval text.
Composer may warn that the intentional exact framework commit constraint is a
commit-ref; the lock and offline pin check enforce the reviewed source. Use an
isolated Composer configuration when resolving dependencies so local global path
overrides never enter this portable lock. The dry-run fixture is synthetic test data and is never presented as gameplay
evidence. Tests cover provenance/attempt tampering, approval injection, ZIP paths,
symlinks/extra files, caps/hash mismatch, credential-free signed redirects,
reservation ordering, uncertain outcomes, failed receipt persistence, dedup across
commits, channel/visibility/processing failures and scope restrictions. The PHP test injects a fake driver into the actual locked framework and exercises
multipart metadata, fixed privacy, channel/processing hydration, 401/429/503/network
failures, and the single-send guard. Tests do
not prove live authorization, real media acceptance or channel publication.

Official references:

- [Insert semantics, scopes, notifications and quota](https://developers.google.com/youtube/data/reference/rest/v3/videos/insert?hl=en)
- [Current API discovery, including method-specific scope lists](https://youtube.googleapis.com/$discovery/rest?version=v3)
- [Video owner readback fields](https://developers.google.com/youtube/data/reference/rest/v3/videos/list)
- [Resumable upload protocol](https://developers.google.com/youtube/data/guides/using_resumable_upload_protocol)
- [Desktop OAuth/PKCE and consent](https://developers.google.com/youtube/data/guides/auth/installed-apps)
- [GitHub artifact provenance/digests](https://docs.github.com/en/rest/actions/artifacts)
- [GitHub trusted-workflow security](https://docs.github.com/en/actions/reference/security/secure-use)
