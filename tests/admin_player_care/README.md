# Player care context actions

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
python3 -m unittest discover -s tests/admin_player_care -p 'test_player_care.py' -v
```

These checks cover context registration, invocation-time rights and stale-target
guards, no yield between validation and mutation, the exact mutation/call scope,
clothing ownership/deletion guards, appearance/modifier refresh, and success
audit placement. Guard-omission controls must fail these checks. They are source
contracts, not executed DM or connected-client acceptance. The item-only native
fixture in `tests/admin_clean` does not cover the player actions.

In a separately authorized isolated graphical test, verify both player actions
appear only with `R_ADMIN`, including stale menus after deadmin/rights loss and
deleted targets. Check dirty, clean, clothed, unclothed, sleeping and dead humans;
repeat both actions, check mood below and above 100, and confirm unrelated stats,
forensic evidence and inventory contents are unchanged. Check smell/lice visuals
and current mood bonuses immediately, then verify normal progression resumes.
No live-server invocation is needed or authorized by these source checks.
