# Severe illness and renewable medicine

These are game balance rules, not real medical advice. Plague, typhus,
malaria and cholera use active mob processing ticks, nominally one second.
An untreated illness warns immediately, becomes debilitating after three
minutes, becomes critical after fifteen, and kills after twenty. Disconnects
pause progression; there is no offline catch-up. Other injuries, hunger and
environmental hazards still apply. Flu and zombie infection retain their
separate legacy behavior.

Continuous appropriate treatment pauses deterioration and clears the illness
after three minutes. Penicillin treats plague, typhus and cholera; quinine
treats malaria. An oral dose of two units of penicillin or ten units of quinine
supplies the complete course. Interrupted treatment resets course completion,
but a fresh complete course can still cure the patient before the deadline.

Healing herbs provide the early alternative. Use a herb stack in hand while
conscious and able to eat. Each herb supplies ten units of herbal remedy,
lasting about three minutes twenty seconds. Take three herbs, dosing again
before the previous dose runs out, for a continuous ten-minute course.
Reserve another herb for planting. The minimum cultivated harvest is three
herbs, so one can be replanted and two retained. Building a treatment stock
takes multiple harvests. This patch does not change herb growth or initial
availability; worlds without herbs still need their existing crop bootstrap.

Later medicine uses the existing extraction, fermentation and apothecary
equipment/research. Renewable charcoal and ethanol can now make acetone:
one charcoal plus two ethanol produces one acetone. Ten enzyme plus one
acetone produces five penicillin. Wood-derived charcoal avoids relying on
finite coal for this recipe. The existing barrel route also converts one
charcoal item to three carbon units for the original acetone recipe. Use a
barrel for that route; a beaker does not accept charcoal directly. Cinchona
remains the existing quinine source.

A grain or flour starter ferments without existing yeast. Let its yeast grow
before withdrawing a container if you want to retain the culture; each yeast
container holds fifty enzyme units. Beer uses barley flour, water, hops and
enzyme as a catalyst. Distilling four beer units produces two ethanol units.
The ethanol distillery is an existing softwood crafting recipe with an
Economy & Production threshold of 45. The starter jar needs glass and the
Pottery Storage node; apothecary equipment is gated by Herbalism then
Apothecary. These are existing research/equipment costs, so herbs remain the
early fallback rather than an immediate industrial cure.

Person-to-person transmission applies to susceptible healthy humans near an
infected source. Malaria and zombie infection do not use this route. Existing
immunity and sterile-mask protection remain applicable. Nearby exposure never
resets an already infected patient's progression.

Verification uses production disease procedures, real reagent metabolism,
oral herb use, harvest output and reaction holders in an isolated world.
Accelerated procedure calls establish tick counts and contracts; they do not
measure full-game scheduler load, multiplayer access to supplies, or player
acceptance of the balance.

## Sleep and bed rest

The Sleep verb no longer refuses a sick character. `resting_in_bed()` is true
for a body buckled to a real bed and for one sleeping in a bed (the Sleep verb
does not buckle), so an untreated flu passes at the bed-rest pace while its
host sleeps there. Plague, typhus, malaria, cholera, worms and the immune
response are all paused while their host sleeps (`inducedSSD`: no offline
catch-up), as before, so sleep neither worsens nor heals them; lying buckled
and awake is what doubles the immune gain. Recovery is announced in large
green text.

## Flu knock-downs

Flu no longer applies drowsiness (which could put a character to sleep or
paralyse it for several ticks at random): `flu_haze` only blurs the eyes. The
high fever floors a character at most once per illness, for 2 ticks
(`flu_knockdown`, `FLU_MAX_DOWNS`, `FLU_DOWN_TIME`), and says so in chat.

## Cholera immunization, from the 1903 epoch

Study the Medicine chapter **Immunization** after Germ Theory and
Pharmacology, then build an immunization clinic from the glass crafting menu.
A glass sheet stocks three abstract supply doses; the desk holds at most
twelve. The desk's doses are not a recipe for real medicine, and no samples
from ill characters are needed. With an empty hand choose yourself or a
nearby patient; another player must explicitly consent. A refusal, movement
out of reach, or a previously scheduled dose leaves the stock untouched.

The dose prevents new cholera after about ten real-time minutes, for about
six hours. It does not treat active cholera or stop worms from dirty water.
Use **IC > Check Immunizations** privately to see the time remaining, even if
there is no medic nearby. The timer is attached to that character and uses
the real clock, so it does not reset on save/load or reconnect. A new dose
can be given after the record expires.

In a region group, every receiving game build must understand the optional
immunization field before operators set `SHARD_IMMUNIZATION_RECORDS 1` (default
off) to enable stocking and dosing. An existing record is still read and sent
when the switch is off. Before taking custody of any traveler or party with a
record, the departure world checks the actual destination afresh. Older,
unreachable, or held destinations cannot take custody and silently lose it.
Keep the decoder deployed across rollbacks after any doses are issued. This is
not a change to clean-water or treatment rules.
