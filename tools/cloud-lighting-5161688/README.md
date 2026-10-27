# Held oversized-sprite lighting pair

This packet prepares two fresh hosted Windows jobs. It does not dispatch them.
Both workflow jobs, activation, derivative manifest and both DM entry flags are
held. The ordinary game source still defaults LIGHTING_COMPOSITION_V2 to zero.
Source preparation is not a compiler, client, pixel, lifecycle or deployment pass.

## Exact source and reuse

Game: ff67d89241336d55f456967ec596d5cd10358df6, tree
8614d882918542be45a8ce822d731f88c84e79f2. Owner proposal:
e70133bb86e4257d5958c78b0869db9baa0ee25f, five-file patch SHA256
b4d0da662478de19307b46ba5f7a09d5c7cc996edfc9142948f7a8eee815b64e.
Reference controller: 209e852bb81c25aaba53fa06ecf125ea532c7bc4.
The raw source inventory has 3,678 files and 241,332,481 bytes. Only civ13.dme,
code, icons, sound, UI, interface and config/names are exported. Production
configuration, SQL, saves, credentials and local checkout state are not inputs.

`unchanged-reference.json` pins the reused capture/process/acquisition guards
and tests. Three historical tests change only their workflow path, expiry value
or injected fresh-admission boundary. No pixel threshold, owned-window check,
socket policy or cleanup rule changes. The current world.dm hub-link additions
are preserved while reapplying the reference startup isolation. All other
reused isolation source files have identical old/current upstream bytes.

## Fresh proposed binding

- Branch: ci/cloud-lighting-v2-pair-5161688-20261027-r1
- Exact message: ci: held lighting V2 off-on native pair r1 (2026-10-27)
- Sole parent: ff67d89241336d55f456967ec596d5cd10358df6
- Jobs: lighting_off (V2=0), lighting_on (V2=1); attempt 1 only.
- Proposed deadline: 2026-10-27 12:00:00 UTC, five-minute startup reserve.
- GitHub assigns the fresh run ID and numeric job IDs at publication. They are
  currently unavailable. Each job records its actual controller SHA, run ID,
  attempt, job key and mode; DirectX receipts must match that same job.
- Initial publication must have EVENT_BEFORE equal to the sole parent or zero.
  No workflow_dispatch, rerun, old branch or consumed activation is accepted.

The current held commit is not an admitted activation. Root must review the
actual derivative/controller diff and authorize a freshly sealed activation
before publication. A release changes the workflow holds, activation flag,
derivative release identity and two explicit DM flags together, then reseals
and rechecks their exact bytes. It must not reuse a prior run identity. Confirm
that existing approved vendor/DirectX terms and sampled outbound socket scope
apply to these fresh hosted jobs; source review cannot grant new permissions.

## Scene and outputs

Each job uses the same 195-cell source-authored test map, normal grass/forest,
fixed original 64x96 pine art at (8,6), human eye at (8,5), hidden marker (8,7)
and visible marker (7,5). This is a diagnostic map, not a live authored gameplay
stage or the user's screenshot. Seed 3225 is set in fixture pre-map startup;
native deterministic appearance still needs checking across jobs.

The real human receives one genuine engine guest; isolated Login does not claim
production Login acceptance. Real /datum/hud and update_lighting_plane attach
the production masters. Native view() validates marker occlusion. No SEE_* flags,
screen-clearing workaround, imposed RGB corners or fabricated client is used.
Actual lighting startup, restored daylight application and source/overlay workers
run at Night/WEATHER_NONE. The only control mutation is pine-root opacity FALSE.
Snapshot files retain 49 turf rows and their real corner RGB/active/window values.

Capture is the unchanged owned-window BitBlt implementation at 480x480. The new
view3/zoom2 composition has 16px letterboxing; the reference was view2/zoom3.
Original nonblank and black-border heuristics remain unchanged and may reject a
valid dark scene. Such a rejection retains only a failed diagnostic, aborts the
job and requires review; it is never silently reclassified or retried.

`bakery-before.png` means opaque-root; `bakery-after.png` means clear-root.
Legacy basenames preserve the unchanged failed-diagnostic allowlist. Receipts
label phases and bind the corresponding lighting-opaque.json/lighting-clear.json
hashes. These are two stills, no movie or repeated frame spool. A completed pair
returns CAPTURED_LIGHTING_PAIR_REVIEW_REQUIRED, never lighting acceptance.

## Limits and cleanup

Per job: windows-2022; 15-minute workflow; one 165-second shared compile/runtime
work budget and 180-second total owner deadline; 512MiB per owned process,
128MiB watcher, 60 CPU seconds/process; one process per retained Job. Compile,
one daemon and one guest client use pinned 516.1688 bytes. DirectX keeps its
separate 60-second work/5-second cleanup cap and exact same-run receipt.
The full vendor manifest and member hashes are unchanged.

Compiler command: dm.exe -max_errors 0 civ13.dme. Daemon: dd.exe civ13.dmb
<reserved-port> -ip 127.0.0.1 -invisible -trusted -nowebclient -params
observer_mode=engine_guest_camera&filming_port=<same-port>. Guest:
dreamseeker.exe byond://127.0.0.1:<same-port>##guest. These are hosted candidate
commands, not permission to execute them locally.

Each owner is retained and cleaned in reverse order; unconfirmed exit fails.
Sampled sockets permit only the previously reviewed TCP policy and one bound
client loopback HTTP listener; UDP/extra or public listeners fail. They do not
prove continuous zero-egress. No unrelated process/window metadata is retained.
Artifacts remain allowlisted, <=1MiB/file, <=100 files and <=16MiB total, retained
seven days. Private environment directories, source packages and credentials
are never artifact uploads. Two jobs are independent, not a public game service.

## Acceptance still required

All fifteen gates in required-controls.json remain mandatory: occluded_oversize,
clear_root, ordinary_lit, weather, intentional_fullbright, dynamic_to_fullbright,
fullbright_to_dynamic, turf_replacement, save_import, sight_bypass, sight_restore,
hud_lifecycle, fully_covered_warm, view_edge and other_oversized_assets.
Only the first two are prepared here. Do not relabel old rejected receipts.

Before evaluating candidate pixels, independently review a nonempty bounded ROI
derived from original art geometry plus baseline native visibility. Require the
baseline reproducer, candidate blackening only in that ROI, exact equality
outside it and exact clear-root equality. The comparator never grants native
acceptance by itself. Weather, fullbright, ordinary lighting, other assets and
real lifecycle checks need separate actual evidence before activating V2 or TDM.

The private user screenshot could not be materialized: the current supported
Library helper returned "download failed". Its pixels were not inspected and
it is not included in this packet. Library text recovered the owner's exact
patch successfully; this download issue did not block independent preparation.
