# Admin item Clean

The runner below is a historical BYOND 516.1681 fixture, not current-pin native
acceptance. It has not been rerun for the cosmetic HUD-refresh change.
Use an explicit verified Python executable:

```powershell
& $PythonPath tests/admin_clean/run.py --byond-bin $ByondBin --output $FreshEvidenceDirectory
```

Use a fresh output directory for each run. Repeat with `--control rights`,
`--control target`, and `--control refresh`; each must detect its named defect.
`--prepare-only` checks registration and prepares source without launching BYOND.
The existing CI selector runs this introduced suite for the PR, then leaves it
opt-in for later changes. No workflow permissions or server settings change.

The 43 native checks cover missing/other staff rights, rights loss and deadmin,
direct calls, null/non-item/deleted/queued/detached targets, ordinary and clothing
cleaning, audit calls, ground/contained/held/worn refresh routing, repeat use,
and preservation of nested items, location, ownership, health and reagent volume.
The runner extracts the production command, rights helper and inherited
`clean_blood` bodies. A one-tile world closes its port, refuses reopening and
rejects clients; no production startup, configuration, saves or external hooks run.
The native engine can bind loopback briefly before `world/New`; this fixture
does not claim an OS-level zero-listener census.

Client identity is adapted to a plain datum; native clients need a connection.
Logging is counted at its existing sinks. Carrier regeneration is a counted
adapter and held/worn are modeled locations, without real equipment slots.
Source checks verify that the production human regeneration refreshes hands,
uniform, shoes and back. Item overlays use native appearances and the real
cleaning bodies, with an instrumented icon callback.

Current offline regressions live in tests/admin_player_care/test_player_care.py.
They interpret the production human regeneration call/guard sequence with
injected call effects, check that item Clean requests appearance refresh without
rebuilding the HUD, and detect both an unconditional HUD refresh and an omitted
Clean argument. Ordinary regeneration keeps its default HUD check. Clean still
avoids that needless check; the shared HUD path now also preserves unrelated
screen members and compositor filters. tests/admin_player_care/test_hud_refresh.py
projects that separate membership/recovery contract with inert screen adapters.
Ground/nested items do not take the generic carrier path. These checks do not
prove connected-client flicker or pixel timing.

Visibility is checked through source registration: the command appears only in
`admin_verbs_admin`, added for `R_ADMIN`, and removed with that group. These
checks do not establish a connected client's context menu or rendered gear.

For isolated graphical acceptance, use a fresh approved test installation of
the PR head, never a live checkout or production server:

1. Right-click a dirty item as a player and as staff without `R_ADMIN`: no Clean.
2. Grant `R_ADMIN`: Clean appears in the item's Admin menu. Invoke it on a ground
   item, each hand and worn clothing. Verify stains vanish immediately.
3. Remove rights/deadmin while a menu is open; a stale invocation cannot wash.
   Try a deleted target as well. Denied calls must not emit success audits.
4. Confirm clothing dirt/fleas/radiation and forensic stains clear, while nested
   contents, reagent volume, ownership and durability stay unchanged.
5. Record tested head, map and dimensions, exact steps and any genuine captures.

No OpenDream, footwear submersion masking, live actions or security settings are
part of this suite.
