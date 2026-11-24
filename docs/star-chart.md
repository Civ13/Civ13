# Star Chart and Astrological Almanac

Open **IC > Star Chart** on your own living character. The wheel and the
three cards under it show the current fictional Sun, Moon and local Rising
point, marked S, M and R, with the Sun's present sign lit on the ring. The
Sun and Moon cards give the next sign change in game time. When the birth
chart has recorded placements, they appear as outlined markers inside the
dotted ring, and a line joins a moving body to a birth point for each listed
transit, in that aspect's colour and line pattern. Reopen the
window for a fresh reading; it does not run a client or server timer.

The **Astrology** section compares the current Sun and Moon with the
recorded Sun, Moon and Rising of your [Birth Chart](birth-chart.md).
It reports the shortest arc, exact aspect and orb within the same 5° rule,
and the natal houses currently occupied by the Sun and Moon if natal Rising
was recorded. No other character's chart can be opened through this reader.
A sign-only legacy record still shows its fixed sign but gives no exact
transits or houses. Unknown or unsupported current calendars show no reading.

## Fictional clock

- One observation of the [shared world calendar](world-calendar.md) supplies
  both the shared moment and its time in the current in-game region. No
  IP, client location, weather reading or administrative lighting override
  is used. The chart may be read indoors: it is a computed almanac, not a
  claim that a body is visible, a navigational bearing, or a real ephemeris.
- The **live Sun** advances one degree per game day and wraps every
  **360 game days**, a separate celestial cycle from the compressed terrain
  seasons. The **natal Sun sign** remains exactly the one chosen or rolled
  at character creation; a live Sun elsewhere does not override it.
- The **Moon** uses the same formula as birth records, 13° per game day
  plus a degree per 120 completed game minutes that day. The almanac checks
  upcoming 120-minute boundaries, including the midnight jump, rather than
  assuming fractional motion through every degree.
- The **current Rising** is the same model rule as natal Rising but uses the
  game's current region: one degree per four local game minutes. Current
  Rising is not used as a transit body. Natal houses always use recorded
  **birthplace** Rising, even after moving to another region.

This is informational roleplay. Viewing or reopening the chart cannot modify
a birth record, trained stats or world state. It adds no
new navigation controls, observations, recipes, art assets, or saved data.
