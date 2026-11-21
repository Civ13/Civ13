# Nation government

Code: `code/game/mob/groups/nation_government.dm` (prompts, announcements, era
reports) and `tools/transfer_storage/nations.py` (`GOVERNMENTS`, the rules the
coordinator applies) with `tools/transfer_storage/nation_motions.py` (motions,
ballots and elections). Tests: `python3 -m pytest tests/transfer_storage/test_nations.py`
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
| Republic | Classical Age | Consul, elected | +1 | 24 hours | The senate, by motion |
| Democracy | Classical Age | Archon, elected | 0 | 24 hours | The citizens, by referendum |
| Merchant league | Medieval Age | Doge, elected | +1 | 24 hours | The league council, by motion |

A nation never holds more than 9 factions. A type unlocks once a majority of
the member factions' lands have reached its ordinal age; each world reports
its land's age for its member factions (`era` op).

## Changing government

Use **Nation > Government**. A member faction's leader proposes a type and,
except for a confederation, the person to head it: an online citizen with a
Discord-verified account (`account_verified()`), and for a theocracy the
leader of a faith. Two thirds of the member factions voting for the same
proposal carry it in a confederation; an elective government decides by
motion (below). Under a theocracy, monarchy or dictatorship only the ruler
can change the government, by decree.

A change takes effect a day after it passes (`GOVERNMENT_NOTICE`), and a nation
may change at most once every 7 days (`GOVERNMENT_COOLDOWN`). Citizens online
in each land hear when a change is coming and when it takes effect.

## Votes of elective governments

A republic, democracy or merchant league decides admissions, the common money
and changes of government by **motion**, and elects its head for a term. Use
**Nation > Motions and elections**.

| Type | Motions decided by | Head elected by | Term |
| --- | --- | --- | --- |
| Republic | Senate: each member faction's leader, weighted by the faction's eligible citizens (at least 1) | All eligible citizens | 14 days |
| Democracy | Referendum of all eligible citizens; a third must take part | All eligible citizens | 7 days |
| Merchant league | Council: each member faction's leader, weighted by the coin in its strongbox (at least 1), no faction above 40% | The council | 14 days |

An **eligible citizen** has a Discord-verified account, has been on the
faction's roster for 3 days and has played a member in the last 7. Each world
reports its member factions' eligible citizens and strongbox worth (`census`
op) and says whether a request comes from the faction's leader or a citizen
(`role`). One account casts one ballot per motion; a new ballot replaces the
old one.

- Senate and council motions run 12 hours and close as soon as the outcome is
  certain; referendums and elections run 24 hours.
- A motion passes with more than half of the votes; a change of government
  needs two thirds, and in a referendum half of the eligible citizens voting.
- A referendum on anything else needs a third of the eligible citizens to vote.
- In a republic or league only member leaders open motions; in a democracy any
  eligible citizen can. An application opens its admission motion itself.
- When the head's term ends an election opens. Any eligible citizen may stand;
  the most votes win and a tie goes to whoever stood first. With no votes the
  head keeps the seat and another election opens a day later.

## Personal rule

Under a theocracy, monarchy or dictatorship the ruler acts from the Nation verb
while playing a character of a member faction in that faction's own land: they
admit or refuse applicants and choose the common money alone. The head vote of
the factions is closed under every type but a confederation.

If the ruler's faction leaves the nation, the government falls back to a
confederation and the longest-standing member becomes head.

## Succession

Each world reports when the nation's head is playing a member faction's
character in its land (`present` op, at most hourly). When the head has been
away longer than their government allows, the seat passes on
(`tools/transfer_storage/nation_succession.py`):

| Type | Away for | Then |
| --- | --- | --- |
| Theocracy | 7 days | The seat goes empty. Whenever a citizen with a verified account leads the state religion in any land, they become High Priest (`faith` op). |
| Monarchy | 7 days | The heir the monarch named (**Nation > Name an heir**) takes the throne; with none, the throne stands empty. |
| Dictatorship | 3 days | The nation falls back to a confederation. |
| Republic | 3 days | The deputy the consul named (**Name a deputy**) acts, and an election opens at once. |
| Democracy, merchant league | 3 days | An election opens at once. |

While a ruler's seat is empty, the member factions decide as in a
confederation. An empty throne can be claimed at any member faction's nation
assembly: a citizen with a verified account holds it for 30 minutes, and the
count pauses while another citizen of the nation stands within 3 tiles. The
first to finish takes the throne (`claim` op).

## Secession

Under every type but a confederation, **Secede** gives notice: the faction
stays a member for the notice period and may **Stay** to withdraw it.

## Saved state (coordinator)

- `nation_government`: nation, type, since, changed, head account and
  character name, religion, pending proposal (JSON) and when it takes effect.
  A nation without a row is a confederation.
- `nation_era`: faction -> ordinal age of its land.
- `nation_leaving`: faction, nation, when its notice runs out.
- Votes for a change (confederation) are `nation_vote` rows of kind `government`.
- `nation_motion`, `nation_ballot`, `nation_candidate`: open motions, their
  ballots (voter is an account, or a faction for leader bodies) and election
  candidates.
- `nation_census`: faction -> eligible citizens and strongbox worth.
- `nation_term`: when the elected head's term ends.
- `nation_seen`: when the head was last reported playing.
- `nation_successor`: the monarch's heir or the consul's deputy.

The registry snapshot every world reads adds `government`, `government_votes`,
`leaving`, `eras`, `motions`, `term_ends` and `census` to each nation.
