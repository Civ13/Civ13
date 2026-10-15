# Player changelogs

This standalone GitHub Actions publisher needs no bot process, Codex, OpenAI API
or desktop scheduler. It posts ordinary messages to Civ13/14 #changelog:
https://discord.com/channels/468979034571931648/468980578289713176
It does not crosspost announcement messages to following servers.

## PR description field (automatic on merge)

The optional field must contain actual announcement text on the same line.
Placeholders such as `required`, `TODO`, `TBD`, and template instructions fail
validation and publication, including when followed by real prose on later lines.
Leave it blank for no post. PR description edits rerun the changelog contract
check, which validates the event description through the same parser as the
publisher. Comments and fenced examples do not opt in. Validation cannot decide
whether text describes a meaningful player change; review still establishes that.

Add exactly one line to the pull request's opening description, outside HTML
comments, quotes and fenced code:

```text
Changelog: Fixed crafting consuming ingredients when assembly is cancelled.
```

Merging that PR into master posts `- Fixed crafting consuming ingredients when
assembly is cancelled.` to #changelog. Missing or blank fields post nothing.
Comments, titles and linked issues are not read. Multiple fields, mentions,
control characters and text over 1500 UTF-16 units fail closed. Use only concise
player-facing text, with no heading, PR/CI details or deployment/update-status
wording. The field is reviewed with the PR; it is not generated from commits.

The merge event freezes the description for retries. The publisher confirms the
PR's merge SHA and default-branch ancestry through GitHub before sending. It runs
only trusted base-branch code, never a fork/PR head. Receipt IDs are `pr-NUMBER`;
do not use this reserved prefix for manual manifests. Reruns suppress confirmed
deliveries and block uncertain deliveries rather than risk duplicate posts.
Do not also announce the same change through the older manifest route.

Both publishers retain up to 100 waiting runs in the shared concurrency queue.
If the queue fills, GitHub cancels additional runs; it does not replace an older
waiting run. Check cancelled **Discord PR changelog** runs after large merge
bursts. Once the queue has room, use **Re-run all jobs** on the original cancelled
run (or `gh run rerun RUN_ID --repo Civ13/Civ13`). This preserves the original
merge-event description and uses the same `pr-NUMBER` receipt. Reconcile a pending
receipt as described below before rerunning; never copy the announcement into a
new manifest or delete receipts to work around a failed run.

Released actionlint 1.7.12 predates `concurrency.queue`. CI uses
`node tools/changelog/check-queues.mjs` to require these two publishers' exact
shared, non-cancelling `max` queues and reject other queue configurations. Only
actionlint's unsupported-key diagnostic for this option is ignored; other
workflow diagnostics remain errors. Remove this compatibility guard when a
released actionlint supports the option.

The `discord-changelog` environment must have `DISCORD_MERGE_CHANGELOG_ENABLED=true`
and the existing `DISCORD_CHANGELOG_WEBHOOK` secret and receipt branch described
below. This setting enables only the merge route. The older manifest publisher
has its separate `DISCORD_CHANGELOG_ENABLED` flag. No deployment or server restart
is performed, and publication does not establish deployment.

## Older reviewed-manifest contribution contract

After a player change is merged, add a reviewed `changelogs/<unique-id>.json`
manifest in a separate PR. Its commit is the full SHA of the game version to ship,
NOT the commit adding the manifest. Manifests are read as data from master;
deployment/PR source is never executed by the privileged publisher.
The author and reviewer decide relevance; no AI classifier or commit scraper runs.

Example (replace SHA with actual game commit, and text with verified changes):

```json
{
  "schema": 1,
  "id": "crafting-fix",
  "commit": "0123456789012345678901234567890123456789",
  "heading": "",
  "entries": ["Fixed the crafting interaction. Use the crafting menu to select a recipe."],
  "skip": ""
}
```

Use concise informal bullets with no heading or deployment/update-status wording. Include
practical controls/recipes when helpful. Include only enabled, verified changes
players can use. Exclude CI, docs, tooling, MCP, internal refactors, dormant features,
unproven performance claims, PR numbers and CI logs. Do not claim deployment from
a merge. For a release with nothing meaningful, use entries [] and a nonempty
skip reason. IDs are globally unique and must never be reused or edited after
delivery begins. Each manifest is a complete reviewed announcement, not an
automatically accumulated fragment list. Avoid overlapping announcements.
The coordinator's pending one-time announcement must be accounted for before
creating the first manifest: do not replay the same content through both routes.

Run `node --test tools/changelog/*.test.mjs` and
`node tools/changelog/publish.mjs --validate`. Node 24, no dependencies.
The validator checks structure and safety; review establishes meaning.

## Trigger and activation

Inspection on 2026-10-11 found no GitHub releases or deployments. Existing launch/
update scripts pull/build/copy on the server without GitHub success reporting.
The older manifest route does not announce on merge, push or CI success. The
explicit PR field route above announces on merge independently of deployment.

1. Create a Discord incoming webhook scoped to the channel above. Store its URL
   only in the GitHub environment `discord-changelog` secret
   `DISCORD_CHANGELOG_WEBHOOK`. Never commit or paste it into logs.
   The publisher verifies incoming type, guild and channel before posting.
2. Configure that environment's deployment branch policy to allow only master.
   Recommended: required reviewers for activation and live confirmations.
3. Provision remote branch `discord-changelog-receipts` from master with a
   `receipts/.gitkeep` file. Keep it permanently; allow Actions contents writes.
   Do not merge this state branch into master or delete/rewrite its receipts.
   It is not a game feature branch and needs no PR.
4. Set environment variable `DISCORD_CHANGELOG_ENABLED=true` only after setup.
   Missing variable/secret/receipt branch fails closed.
5. Run **Discord shipped changelog** on master with manifest ID and game SHA.
   Leave dry_run true to inspect the exact payload without Discord/receipt writes.
   After independently confirming that SHA is live, rerun with dry_run false and
   confirm_live true. This confirmation does not deploy or restart anything.

For future deployment integration, a trusted deployment system may create a
GitHub deployment with ref master, task deploy, environment production,
production_environment true, full deployed SHA and payload {"changelog":"ID"}.
Report success only after the exact version is live. The publisher refetches that
deployment and requires the newest status to match the success event.
No such integration is installed here. Anyone allowed to create these production
records can cause publication when enabled; restrict deployment permissions.
A published GitHub release is not proof of live game deployment.

## Receipts, failures and reconciliation

All publisher runs share concurrency group discord-changelog. A durable
optimistically updated receipt is reserved BEFORE every POST. Each chunk has
a content hash and pending/sent state; confirmed messages retain Discord IDs.
Known sent chunks are skipped on reruns, including partial completed batches.
Changing a manifest after a receipt exists fails. GitHub state errors fail closed.
Receipts are durable Git contents, not expiring Actions artifacts or caches.

A timeout, 5xx, invalid Discord confirmation or failed post-send receipt write
leaves pending. Automatic retries/manual reruns then refuse to send. Inspect
Discord and the receipt at
`discord-changelog-receipts:receipts/<ID>.json`. If delivered, manually record
the actual ID and sent state after checking content/channel. If positively proven
not delivered, remove ONLY the pending final chunk with a reviewed state commit,
then rerun the SAME manifest. Do not blindly delete receipts. If certainty is
unavailable, leave blocked. This favors duplicate prevention over automatic
availability; exactly-once delivery across GitHub and Discord is impossible.
Success logs contain receipt/message IDs and no webhook URL.

Messages are bounded to 1900 UTF-16 units; at most 40 entries of 1500 each.
Newlines, control characters, @ and angle brackets in entries/headings are rejected.
allowed_mentions disables all parsing; content never enters a shell.
Webhook URLs allow only HTTPS discord.com incoming webhook paths, no redirect,
query, credentials or fragment. wait=true requests a saved-message confirmation.
429 respects Retry-After/retry_after up to 60 seconds with five attempts. Longer
waits/exhaustion stop for later reconciliation. GET 5xx retries exponentially.
POST 5xx/network failures are ambiguous and never automatically replayed.
HTTP errors log status only, not remote bodies that might echo credentials.

Official contracts:
- https://docs.discord.com/developers/resources/webhook
- https://docs.discord.com/developers/topics/rate-limits
- https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows
- https://docs.github.com/en/rest/repos/contents
- https://docs.github.com/en/rest/deployments/statuses

Offline tests do not prove a real webhook works or that any game version is live.
No gameplay change is made; screenshots would not resolve automation contracts.
