# CM-SS13 ports

```
python3 tests/cm_ports/run.py --byond-bin <pinned bin>
```

Builds the full game source without maps or startup, adds `probe.dm` and runs
it headless. It checks the round-start location text, balloon alert timing and
client guards, round-end facts (kill credit, first blood, top lines, a real
death reaching the death hook, announcing once), canopy shelter warmth, the
holiday calendar dates and opening a holiday gift.

The second batch adds checks for the megaphone speech range, glowsticks
(lighting, no switching off, burning out), container labels, the display case
(storing, key locking, taking back), the alarm tripwire (friends pass, strangers
trip it, the rattle cooldown), rally flags strengthening leader orders, the
codebook (ten distinct codes per side, kept all round, given to leaders only)
and the emote panel's list.

The third batch checks bipods (fitting, bracing prone or against a wall ahead,
unbracing on the move), the empty-gun ammo count, floor exercise limits and
fatigue, and the lockbox (first key sets the lock, wrong keys fail, blocked
storage while locked, beating the lock off). The escape menu needs a real
client and is not covered here.

The fourth batch checks the roll of the fallen (one entry per death, team rounds
only), dog tags (dead bodies only, one set per body, comrade and enemy counts),
commander medals (rank, side, citation and per-round limits), the weapon light
(lit only in hand), the gun sling (caught onto the shoulder only when knocked
down), the motion detector's contact list and the rangefinder report.

The fifth batch checks the typing bubbles (separate speech and emote sprites,
upright when lying down, cleared once the owner cannot type, not saved),
triage tags (four colours, kept through icon rebuilds, removable, not saved),
drag trails (only a dragged, bleeding body leaves one smear per tile), the four
signal smoke colours and the new-player marker's handling of missing clients.

The sixth batch checks squad colours, who the squad tracker points at (squad
leader, else the commander, team rounds only) and its bearings, the field HUD
images (one arrow, chevrons only on squadmates), medic health states and the
own-side rule, the mine detector's armed-mines-in-range list and high fives and
fist bumps (answer, expiry, adjacency).

The seventh batch checks fire teams in squads, player factions and companies
(who may organize, membership, one leader per team, dropping the team on
leaving the group), the roster pages, the tracker pointing at fire team
leaders, friendly-fire counting and its round fact, machine gun barrel heat
and cooling, filled autoinjectors and the clotting agent, the modern combat
kit contents and the observer HUD.

The eighth batch checks Spot Enemy (who sees the mark, the cooldown, expiry,
the field HUD marker), rally points (who may set one, the tracker pointing at
it, replacing and clearing), the death recap lines and killing blow, personal
round stats, the searchlight beam (reach, walls, turning, on and off, what is
saved) and that fire teams are saved with the character.

The ninth batch checks ghillie camouflage (fading after lying still on the
right ground, revealing when bumped or standing, the winter suit, what is
saved), night-vision dazzle, the respawn countdown text, cell timers (who may
set one, holding the door, counting down, saving and reloading, the cap,
release) and breaching charges (filling, planting, blowing the door, who is
knocked down, valid targets).

The tenth batch checks ghost death notices (text, follow link, who gets one),
last words (empty, length, kept for the roll of the fallen, the round-end
lines) and the time since death on a body (rounding, the medic-only revive
hint).
