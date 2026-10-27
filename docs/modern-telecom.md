# Modern civilian communications and skills

This document describes the implementation and its isolated verification.
The runtime, crafting, sprite and native save checks below have passed.
It is not a production deployment announcement.

## Intended player loop

Research utilities for network landlines, factories for broadcast equipment,
and assembly-line manufacturing for television and local terminals. Recipes
use existing materials and modern-era gates.
Construction requires completed research and current native crafting skill:
100 for landlines, 105 for radios, radio desks and antennas, and 160 for TV,
TV desks and terminals. Both era and construction requirements are rechecked
after the paid build action.

Drag an adjacent electrical cable
onto each powered device. Phones and computers use the same cable network for
power and communications; this is an abstract game rule rather than a physical
simulation of mains wiring or real VoIP equipment.

Landlines show their number on examination. Click to dial, answer or hang up.
Both phones must have power and a valid route. Calls end on equipment removal,
lost routes or unanswered timeout. Local terminals send immediate text to other
powered terminals on the same network, with no message history or Internet
service. Delivery is limited to 32 terminals and 32 unique nearby listeners.

Place an antenna adjacent to a radio or television program desk, connect power,
choose a frequency and prepare a course with at least 100 raw skill. Powered
receivers of the matching medium and frequency receive broadcasts within 60
tiles on the same level. Educational broadcasts require Modern at both emission
and receipt. Six original lessons air ten seconds apart during a one-minute
window in a ten-minute running-server schedule. At most 32 nearby characters
receive each lesson.

| Course | Window within each ten-minute cycle | Cycling-map seasons |
| --- | --- | --- |
| Crafting | 1:00 through 1:59 | Fall and Winter |
| Farming | 3:00 through 3:59 | Spring and Summer |
| Medical | 5:00 through 5:59 | All four seasons |

Fixed-season maps, maps without a cycle and disabled seasonal cycles use an
evergreen schedule with the same time windows. Season eligibility reads the
existing map declaration; it never advances debris clocks. Restart resets the
running-server schedule, while durable per-character lesson credits prevent
repeat XP after restart, reconnect or rerun. Starting a desk midway through a
window joins the currently airing lesson; it does not restart the course.

Crafting, farming and medical courses each have six durable lesson credits.
Online, conscious hearing characters with current skill at least 10 and both
current and trained skill below 125 receive one percent per unique lesson below
100 trained skill, then half a percent for intermediate training.
Repeated broadcasts cannot repeat a credit. Existing practice multipliers,
books, mood effects and native maximums remain in use. Skill Progress displays
ten derived levels from the trained maximum; magic scales its native 100-point
maximum to the same ten-level display. These display levels do not replace the
native crafting or combat thresholds.

Starting at the native default 100, six intermediate lessons increase a skill
to about 103.04. A level-one industry book without religious modifiers takes
60 seconds and increases crafting from 100 to 103.2; a corresponding medicine
book increases medical skill to 116. Ordinary farming actions already use
0.5% or larger multipliers. Broadcast credit is finite and ends at 125, the sixth
derived practice-level threshold; books and useful practice retain their native
advanced progression up to 250. These comparisons follow the actual
`adaptStat` and book formulas; the isolated native curriculum test confirms
the baseline-100 result and the 125-point cap.

## Primary-source audit and provenance

The implementation was written independently for Civ13's legacy process system,
native cable reservations, stats and persistence. No upstream source, artwork,
broadcast script or Project Zomboid asset was copied.

Reviewed upstream telecom and power lifecycle concepts:

| Repository | Audited revision | Paths | License reported by repository |
| --- | --- | --- | --- |
| tgstation/tgstation | `49afd5fd7cbf9de60ce81419a9bc97947fc55dc9` | `code/game/machinery/telecomms/telecomunications.dm`, `code/modules/power/powernet.dm` | AGPL-3.0 |
| Baystation12/Baystation12 | `ca90ce8b501c4e04f24c1510990fc6f86623d4f1` | same telecom and powernet paths | AGPL-3.0 |
| cmss13-devs/cmss13 | `0973208b906a1e69f09a567ee5595319065426e9` | same telecom and powernet paths | AGPL-3.0 |

Explicit links, frequency filtering, powered relays and lifecycle cleanup were
useful conceptual references. Their subsystem and signal implementations are
not drop-in replacements for this codebase.

Project Zomboid's official [broadcast development post](https://projectzomboid.com/blog/news/2014/12/turbo-to-the-finishing-line/)
describes learning crafting and cooking from radio/TV. Its official
[RecordedMedia API](https://projectzomboid.com/modding/zombie/radio/media/RecordedMedia.html)
exposes media identity and listened-line bookkeeping. These informed the
bounded, per-character credit concept, without copying timings, reward tables
or program text. The six-line courses above are original Civ13 game guidance.

## Verification boundaries

Equipment uses existing DMI states. The compiled sprite audit and genuine DMI
static preview passed. `tests/modern_telecom/run.ps1` compiles all production sources
with BYOND 516.1681, zero errors and warnings. Its isolated runtime checks real
powered delivery, mismatched frequencies, power loss, cable phone calls, local
terminal delivery/rate limits, era/season/time eligibility, finite curriculum
rewards, reconnect/rerun deduplication and durable credits through world reload.

The fixture also checks powered splits, reconnects, phone deletion, restored
calls and a 200-cable route. Native recipe registration checks all seven paid
recipes, Modern visibility, completed-node gates and current crafting thresholds.
Research completion is an injected fixture precondition; actual player research
and menu interaction have not been exercised by a client.
Local fixtures do not prove public-server performance or human UI acceptance.
