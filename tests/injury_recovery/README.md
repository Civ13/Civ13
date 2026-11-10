# Gradual injury recovery

`python3 tests/injury_recovery/test_source.py` checks production wiring, guards,
pain scaling and a deterministic arithmetic projection. These are offline checks,
not execution of BYOND gameplay or savefiles.

Viable attached internal organs recover 0.01 damage per active organ-processing
call, halved while broken and doubled while lying down, multiplied by the existing
organ regeneration setting. At the nominal one-second mob tick, 10 damage takes
about 24 minutes standing at the default 0.7 regeneration multiplier; 40 damage
with a 30-point broken threshold takes about 119 minutes standing. Brain tissue
uses the same gradual recovery rather than its old modulo-based plateaus. This is gameplay balance, not medical advice. Missing/dead
organs do not regrow, severed organs do not heal, and active infection/rejection and
cryo, poor oxygenation and inadequate blood volume pause recovery. Ongoing injury can still exceed recovery. No offline catch-up
or new saved timer is introduced. Surgery and medicine remain faster paths.

Pain from internal organ damage and internal bleeding scales with remaining
damage. Zero-damage bleeding records awaiting their ten-minute cleanup no longer
produce stabbing pain. Other legitimate causes, including fractures, toxins,
embedded objects and infection, remain intact. This phase does not remove wound
care, splinting or severe internal-bleeding requirements.

Native acceptance still needed: fresh and restored patients, minor/severe organ
injury and brain injury, rest vs standing, active infection, and zero-damage wound
records retained before cleanup. No live server or save operation was performed.
