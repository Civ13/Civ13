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
finite coal for this recipe. Cinchona remains the existing quinine source.

Person-to-person transmission applies to susceptible healthy humans near an
infected source. Malaria and zombie infection do not use this route. Existing
immunity and sterile-mask protection remain applicable. Nearby exposure never
resets an already infected patient's progression.

Verification uses production disease procedures, real reagent metabolism,
oral herb use, harvest output and reaction holders in an isolated world.
Accelerated procedure calls establish tick counts and contracts; they do not
measure full-game scheduler load, multiplayer access to supplies, or player
acceptance of the balance.
