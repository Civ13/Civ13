# Nation government

Code: `code/game/mob/groups/nation_government.dm` (prompts, announcements, era
reports) and `tools/transfer_storage/nations.py` (`GOVERNMENTS`, the rules the
coordinator applies). Tests: `python3 -m pytest tests/transfer_storage/test_nations.py`
and `python3 tests/nation_government/test_source.py`.

Val approved the plan on 2026-11-21 ("Nation government types - plan"). A
government belongs to a **nation** only. Member factions keep their own
leaders, offices, courts and treasuries whatever the nation's government, and
a faction outside a nation has no government to choose.

## Types

| Type | Unlocks at | Head | Extra factions | Secession notice | Who admits members and sets the common money |
| --- | --- | --- | --- | --- | --- |
| Confederation (default) | Stone Age | Symbolic head faction, by majority vote | 0 | none | Majority of member factions |
| Theocracy | Stone Age | High Priest: the leader of a faith | 0 | 24 hours | The High Priest |
| Monarchy | Classical Age | Monarch, for life | +1 | 48 hours | The monarch |
| Dictatorship | Classical Age | Dictator | +2 | 72 hours | The dictator |
| Republic | Classical Age | Consul | +1 | 24 hours | Majority of member factions |
| Democracy | Classical Age | Archon | 0 | 24 hours | Majority of member factions |
| Merchant league | Medieval Age | Doge | +1 | 24 hours | Majority of member factions |

A nation never holds more than 9 factions. A type unlocks once a majority of
the member factions' lands have reached its ordinal age; each world reports
its land's age for its member factions (`era` op).

## Changing government

Use **Nation > Government**. A member faction's leader proposes a type and,
except for a confederation, the person to head it: an online citizen with a
Discord-verified account (`account_verified()`), and for a theocracy the
leader of a faith. Two thirds of the member factions voting for the same
proposal carry it. Under a theocracy, monarchy or dictatorship only the ruler
can change the government, by decree.

A change takes effect a day after it passes (`GOVERNMENT_NOTICE`), and a nation
may change at most once every 7 days (`GOVERNMENT_COOLDOWN`). Citizens online
in each land hear when a change is coming and when it takes effect.

## Personal rule

Under a theocracy, monarchy or dictatorship the ruler acts from the Nation verb
while playing a character of a member faction in that faction's own land: they
admit or refuse applicants and choose the common money alone. The head vote of
the factions is closed under every type but a confederation.

If the ruler's faction leaves the nation, the government falls back to a
confederation and the longest-standing member becomes head.

## Secession

Under every type but a confederation, **Secede** gives notice: the faction
stays a member for the notice period and may **Stay** to withdraw it.

## Saved state (coordinator)

- `nation_government`: nation, type, since, changed, head account and
  character name, religion, pending proposal (JSON) and when it takes effect.
  A nation without a row is a confederation.
- `nation_era`: faction -> ordinal age of its land.
- `nation_leaving`: faction, nation, when its notice runs out.
- Votes for a change are `nation_vote` rows of kind `government`.

The registry snapshot every world reads adds `government`, `government_votes`,
`leaving` and `eras` to each nation.
