# Local CI attestation and CI waivers

A trusted maintainer can run the ordinary CI set on their own machine and attest
the pass for one exact commit. Hosted CI then skips its heavy jobs for that
commit and still reports `CI required aggregate`. With no valid local pass, CI
runs exactly as before.

## Running it (Windows + Git Bash, or Linux)

Use a worktree of the PR branch, never the live server checkout:

```bash
git worktree add ../civ13-pr my-branch && cd ../civ13-pr
py -3 scripts/local_ci.py run --push      # Linux: python3 scripts/local_ci.py run --push
```

`run` refuses a dirty tree, then:

1. Selects like hosted CI: `scripts/select-ci.py` against the tip of the PR base
   branch, with the PR title (a `build:` title still forces compilation).
2. Stops with "hosted CI is required" when the selection admits extensive or
   newly introduced native suites, or when the diff touches CI-control paths
   (`.github/`, `scripts/select-ci.py`, `scripts/ci_baseline.py`,
   `scripts/ci_checkout_refs.py`, `scripts/local_ci.py`,
   `scripts/byond_toolchain.py`, `tools/byond/`, `tools/ci/`).
3. Runs `scripts/ci_baseline.py run` (the same offline suites the hosted
   `baseline` job runs) and the advisory `check_forbidden_patterns.py`.
4. Compiles `civ13.dme` with the pinned compiler when selected (`dm.exe` from
   `C:\Program Files (x86)\BYOND\bin` on Windows, `DreamMaker` on Linux, or
   `--compiler PATH`). The banner must equal `tools/byond/version.json`.
5. Runs dreamchecker when a verified binary is found (`--dreamchecker PATH`,
   `.ci/lint/dreamchecker[.exe]` or PATH). Without one, hosted dreamchecker
   still runs.
6. Writes `.ci/local/receipt.json` and, if everything passed, pushes (with
   `--push`) and attests: a commit comment holding the receipt, then a
   `local-ci/attested` commit status whose description carries the receipt's
   SHA-256. The token comes from `GITHUB_TOKEN`/`GH_TOKEN` or `gh auth token`.

Without `--push` the branch must already be at `HEAD` on the remote. If hosted CI
had already started its heavy jobs before the status landed, re-run that CI run
from the Actions tab. `attest` republishes an existing passed receipt.

## What the hosted gate checks

The `local-attestation` job in `.github/workflows/test.yml` runs after
`changes`. It checks out `scripts/local_ci.py` and
`tools/ci/local_attesters.json` from the PR base commit, never the head, and
runs `local_ci.py verify`. Heavy jobs skip only when all of these hold:

| Check | Rule |
| --- | --- |
| Scope | ordinary `pull_request` gating run, exact comparison, no extensive or introduced suites, no CI-control paths |
| Status | latest `local-ci/attested` status on the head is `success`, created by a GitHub user id in the base's attester list |
| Receipt | the linked commit comment is on this head, written by the same user, and hashes to the digest in the status |
| Content | receipt head and tree equal the hosted head, BYOND version equals the pin, baseline passed, compile passed when selected |
| Selection | the receipt's selection core (compile, extensive, introduced suites, offline suites) equals the hosted selection's |

Any failure or error writes `skip=false` and the hosted jobs run; the gate never
turns CI red. On a skip, `baseline`, `evidence-checker`, `build` and
`extraction-instances` are skipped, `dreamchecker` is skipped only when the
receipt shows it ran, and `CI required aggregate` runs `local_ci.py aggregate`
instead of the artifact checks.

The workflow file itself still comes from the PR, as for every other check, so
a PR that edits workflows needs review whatever this gate says.

## Waiving CI with a label

A maintainer on the attester list can add the label `skip-ci:<full head SHA>`.
The gate accepts it only when the latest label event for that name was added by
an attester and the diff touches no `.dm`, `.dme`, `.dmm`, `.dmi` or `.rsc`
file and no CI-control path. A new push needs a new label. The aggregate's
summary says the head was waived, not verified.

Separately, `scripts/select-ci.py` skips compilation automatically for Markdown
outside `.agents/`, `code/`, `maps/`, `config/`, `wiki/`, `html/`, `UI/` and
`tgui/`, for `.claude/**/*.md`, and for `LICENSE`, `.gitattributes`,
`.gitignore` and `.editorconfig`. The offline baseline still runs for those.

## Changing who can attest

Edit `tools/ci/local_attesters.json` (login plus numeric user id). The change
takes effect after it merges to master, because the gate reads the base copy.
