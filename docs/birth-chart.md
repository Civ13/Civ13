# Birth Chart

Open **IC > Birth Chart** on your living character to see your private chart.
It shows where and when the character was born if recorded. The outer ring uses
the twelve Civ13 signs, with the character's Sun sign lit. The inner ring has
houses 1-12 starting at the Rising line. The wheel marks the **Sun**, **Moon**
and **Rising** with the letters S, M and R; the three cards below it read left
to right, showing each one's degree and sign, its house and its absolute
longitude. A line joins two markers only for a listed aspect, and each kind of
aspect has its own colour and line pattern, repeated in the Aspects list.

- **Birth date, time and place:** New Nomads and Civilizations characters record
  their region at creation. Regions with the shared world calendar also record
  the exact in-game birth day and minute. The chart shows the local calendar
  date and clock when the region offset is known. These records do not change
  on reconnection, a region move, or a later daylight override.
- **Older characters and unknown data:** A saved sign remains the Sun sign.
  A missing date, time, place or placement is shown as **Not recorded**.
  Logging in or travelling cannot fill in a missing birth record. A region
  without a supported clock can still record its name.
- **What changes mechanically:** Nothing. The existing sign, sign selection,
  stat bonuses, and training effects are unchanged. Houses, Moon, Rising and
  aspects are roleplay only. The chart is not sent to an Atlas or lobby
  directory.

## How the Civ13 model works

This is a fictional sky, not a real-world ephemeris. The original Sun sign roll
or selection is retained. The charts use twelve 30-degree signs in the game's
sign-table order; a full turn wraps from 359° to 0°. The same rules produce the
same chart after save/load and transfer.

- **Sun:** the original sign's starting angle plus the shared game-day index
  modulo 30. The date locates the degree within that sign, not the sign itself.
- **Moon:** 13 degrees per shared game day, plus one per 120 elapsed shared game
  minutes that day. It is the same at the same instant in every region.
- **Rising:** one degree per four local game minutes since midnight. The
  character's birth-region longitude gets the existing shared-calendar time
  offset. The Rising angle is the first house's cusp; subsequent cusps occur
  every 30 degrees clockwise. If no region offset is known, Rising and houses
  remain unrecorded.
- **Aspects:** shortest circular separation, within 5° of the nominal angle:
  conjunction 0°, sextile 60°, square 90°, trine 120°, opposition 180°.
  The chart lists the pair, aspect type, actual separation, exact angle and
  difference from exact (the orb). The cusp table shows the exact signs,
  degrees and longitudes at the start of all twelve equal houses.


## Later chart consumers

The birth record is versioned and remains the source of truth. The numeric
placement, cusp and aspect helpers are separate from the private UI. Additional
celestial bodies and angles should extend a documented sky model, not fabricate
missing historical inputs or silently change existing charts. Future gameplay
can select from those structured values under its own rules; the chart itself
grants no new effects.
