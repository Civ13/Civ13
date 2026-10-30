# Admin item Clean

Run with BYOND 516.1681 and an explicit verified Python executable:

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

## Player care context actions

`Clean Player` and `Restore Mood` are separate `R_ADMIN` human-target actions.
Clean Player restores hygiene and clears dirt/fleas on the worn suit, uniform
and shoes (the three clothing slots checked by the hygiene tick), then refreshes
the smell/lice overlay. It deliberately preserves blood and forensic stains,
radiation, reagents, disease, wounds and other physiology. Use the existing item
Clean command separately when washing an item's stains is intended.
Restore Mood raises morale to its initial value (100), preserving higher boosts,
and immediately recomputes the mood modifier. Normal subsequent mood/hygiene
changes continue; neither action heals, revives or grants immunity.

Run the offline source contracts with:

```sh
python3 -m unittest discover -s tests/admin_clean -p 'test_player_care.py' -v
```

These checks cover context registration, invocation-time rights and stale-target
guards, no yield between validation and mutation, the exact mutation/call scope,
clothing ownership/deletion guards, appearance/modifier refresh, and success
audit placement. Guard-omission controls must fail these checks. They are source
contracts, not executed DM or connected-client acceptance. The item-only native
fixture above does not cover the player actions.

In a separately authorized isolated graphical test, verify both player actions
appear only with `R_ADMIN`, including stale menus after deadmin/rights loss and
deleted targets. Check dirty, clean, clothed, unclothed, sleeping and dead humans;
repeat both actions, check mood below and above 100, and confirm unrelated stats,
forensic evidence and inventory contents are unchanged. Check smell/lice visuals
and current mood bonuses immediately, then verify normal progression resumes.
No live-server invocation is needed or authorized by these source checks.
