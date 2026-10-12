# Extraction survival verification

Use BYOND 516.1681 and a verified full Python interpreter path:

```powershell
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe store
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe restart
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe equipment
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe mode
& $PythonPath tests/extraction/run.py --byond-bin $ByondBin --probe equipment --provenance-negative-control
```

All probes use temporary storage, close their listening port and disable normal
game startup. The restart probe runs three separate native daemon processes over
one disposable directory. Its equipment entries are opaque transaction records:
it proves account journal behavior, not rendered items or full-world restart.
The equipment probe uses production item constructors and native journal files.
The mode probe uses the original map and production transition procedures with
injected client identity and accelerated action waits. None replaces gameplay
acceptance. Generated compilation files are unique and removed on completion.

The mode probe additionally checks PMC/Scav eligibility, carried/nested backpack
denial, eligibility changes during the extraction wait, actual keyed-door
unlock/close/lock state, room occupancy and lost-key rejection. Native hand
dispatch needs a client, so the fixture calls the production door switch and
leaves real click dispatch for graphical acceptance. Nested item shipment tests
cover another-account/concurrent/replay rejection, physical retirement after
commit and actual gun/optic restoration after death and journal reopen.

## Required safe-house concept video

Record a genuine disposable local playable world after integrated regressions
pass. Use the exact pinned build and record its full commit, dirty patch when
applicable, map dimensions, local process IDs, compiler/runtime versions and
reproduction steps in the evidence bundle. Do not use production storage or
reference material from private repositories.

| Sequence | Visible acceptance | Supporting check |
| --- | --- | --- |
| Two accounts | Distinct identities enter different private rooms; another account is denied entry | Mode ownership and room gate |
| Hub navigation | Leave gear in private room, enter shared concourse, return to bound room; gear remains | Hub transition and carried-gear rejection |
| Reconnect | Disconnect and reconnect the same account; actual identified stored items remain | Native journal plus equipment graph reload |
| Upgrade | Show cost before, completed payment, increased house level and removed payment items | Atomic upgrade and native restart |
| Idle release | Show room/session release after idle grace, then reload without item loss | Mode release/reopen |
| Local restart | Stop only the disposable local world, restart that exact build with its disposable account directory, then show retained items and upgraded level for both accounts | Three-process journal test plus integrated restart |
| Secure storage | Show access isolation, completed deposit, death and retained contents when implemented | Deposit transaction and failure controls |

Request an exclusive bounded screen turn from the coordinator only when the
build, test scripts and storyboard are ready. There is no standing screen grant.
Use readable captions and zooms/highlights. Compress no-frame-change waits and
label accelerated periods; preserve genuine completion and before/after frames.
Do not claim unshown mechanics, production behavior or indefinite durability.
Record blocked flows explicitly rather than substituting mock images.

Reuse the independently owned PR 3083 capture tools after they merge; do not edit
that owner's active capture infrastructure. Authorized evidence uploads still
need attachment-access verification before any local generated media deletion.
Respect later retention instructions. Validate the bundle with the repository's
game-evidence checker, then review the actual video separately: bundle validity
only establishes metadata and file consistency.
