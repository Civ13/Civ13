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

## Offices of state

A nation whose government has a head fills three offices
(`tools/transfer_storage/nation_offices.py`, **Nation > Offices of state**):

| Office | Power |
| --- | --- |
| Treasurer | Chooses the common money in the ruler's place under personal rule, or brings one to a vote of the senate, council or citizens. |
| Chancellor | Admits or refuses applications in the ruler's place under personal rule. Nation laws and courts will go through this office. |
| Marshal | Guards the nation's assemblies: a marshal standing within 3 tiles pauses any claim or revolt held there. |

The head appoints a verified citizen of a member faction (`appoint` op).
Under personal rule the appointment stands at once; under an elective
government it is an `office` motion the body confirms by a majority. The head
dismisses an officer, and an officer resigns, at once (`dismiss` op). A
person holds one office at a time and never the head's own seat. Offices
lapse when the government changes, and an officer whose faction leaves the
nation loses the office. A confederation has no offices.

## Treaties

Nations make treaties with each other from **Nation > Foreign affairs**
(`tools/transfer_storage/nation_treaties.py`, `treaty` op):

| Kind | Made by | Notes |
| --- | --- | --- |
| Alliance | both nations | Cannot be made at war. |
| Non-aggression pact | both nations | Cannot be made at war. |
| Trade treaty | both nations | Cannot be made at war. |
| War | one nation alone | Ends any alliance or pact between the two. |
| Peace | both nations | Ends a war. |

Each nation agrees under its own government: the ruler alone under personal
rule, a `treaty` motion of the senate, council or citizens (a majority)
under an elective government, and more than half of the member factions'
leaders in a confederation. One nation's agreement stands as an offer for 7
days; once the other agrees too, the treaty is in force. Either nation may
renounce an alliance, pact or trade treaty alone. A nation keeps at most 24
treaties, and treaties end when either nation dissolves. Citizens are told
when a treaty starts or ends, and Nation view lists each nation's treaties.
Treaties do not yet change sieges or other play; they are the record later
features read.

## Legitimacy

Every government holds a legitimacy score from 0 to 100
(`tools/transfer_storage/nation_legitimacy.py`), shown on its government
line. A new government starts at 50. Once a day a head who played that day
adds 2, a head away longer takes 2 off, and an empty seat under personal rule
takes 2 off; a confederation drifts 1 a day back towards 50. A motion that
carries adds 1 and one that fails takes 1 off; a faction admitted adds 2 and
one that secedes takes 3 off; a filled revolt petition that fails adds 5 and
one that never fills adds 1.

The share of eligible citizens a revolt petition needs is the government's
share (below) times 0.5 + legitimacy / 100: half of it at 0, as listed at
50, half again at 100, and never above 90%.

## Revolt

Citizens can overthrow any government, in play rather than by a menu
(`tools/transfer_storage/nation_revolt.py`):

1. An eligible citizen (verified account, member for 3 days, played this
   week) opens a petition from **Nation > Revolt**, naming the government they
   want and, except for a confederation, its head (`revolt` op).
2. Eligible citizens sign it (`sign` op) within 2 days. It needs this share
   of the eligible citizens the worlds count:

   | Government | Share |
   | --- | --- |
   | Confederation, theocracy, monarchy | half |
   | Dictatorship | a third |
   | Merchant league | two fifths |
   | Republic | two thirds |
   | Democracy | three quarters |

3. Once it fills, every citizen is warned. From a day later the signers have
   3 days to hold any member faction's nation assembly for 30 minutes. Where
   the assembly stands in a province, the count runs only in that province's
   defence window. It pauses while a citizen who did not sign stands within
   3 tiles.
4. Success (`overthrow` op) installs the petition's government at once, with
   no notice. A filled petition that succeeds or fails bars the nation from
   another for 7 days. A petition that never fills bars only the citizen who
   opened it, so a loyalist cannot shield the government with a sham petition.

The nation's head can neither open nor sign a petition against themself.
Signing is never a crime in itself, the petition shows only how many have
signed, and a failed revolt removes no one from play.

## Staff tools

**Admin > Nations** (`code/modules/admin/nation_staff.dm`, coordinator
`tools/transfer_storage/nation_staff.py`) shows any nation's government, head
account, motions, revolt petition with its signers, and the last 10 staff
log entries. Staff can, with a reason that goes in the log (`staff` op):

- **Freeze** or **Thaw**: a frozen nation cannot change government, vote,
  name successors, claim a throne or revolt, and its head's absence does not
  count. Thawing restarts the absence clock. Citizens see that staff have
  paused changes.
- **Void a motion** or **Void the revolt petition**: closes it without a
  result or a cooldown.
- **Set the government**: installs a type and a head (a verified citizen
  playing in the staff member's land) at once, past the era and notice.

Staff act on any nation from any land; the world checks admin rights first.

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
- `nation_revolt`, `nation_signature`: the open petition (proposal JSON, who
  opened it, when, when it filled) and its signers.
- `nation_office`: nation, office, holder's account, character name and
  faction, since when.
- `nation_treaty`: the two nations (sorted), kind and since when;
  `nation_treaty_offer`: a nation's standing agreement, to which nation, kind
  and when. A confederation's treaty votes are `nation_vote` rows of kind
  `treaty:<proposal>`.
- `nation_legitimacy`: nation, score, and when its daily change last ran.
- `nation_frozen`: nations staff froze, and since when.
- `nation_staff_log`: nation, when, staff account, act and reason (the last
  100 kept).
- `nation_revolt_cooldown`: nation and account (`''` for the whole nation)
  -> when another petition may open.

The registry snapshot every world reads adds `government`, `government_votes`,
`leaving`, `eras`, `motions`, `term_ends`, `census`, `revolt`, `frozen`, `staff_log`, `offices`, `treaties` and `legitimacy` to each nation; `government.revolt` is the share after legitimacy.
