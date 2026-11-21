# Research familiarity

On book-research worlds a character slowly comes to understand a subject they
do not know by living with its things. Code: `code/modules/research_tree/familiarity.dm`.
Tests: `tests/familiarity/`.

- **Using** a thing (clicking with it in hand, firing it, working a structure
  or machine by hand, wearing clothing or armour) teaches 5% of its subject the
  first time for each kind, then 1% per use, at most once every 2 minutes per
  subject.
- **Being around** a thing: every 60 life ticks (about 2 minutes) a character
  notices one new kind within 3 tiles, 2% each, once per kind.
- **Origin does not matter**: anything counts, whoever made it.
- **Slow**: at most 10% of one subject per real day.
- **Never alone**: familiarity's own share is capped at 50% of a Stone Age
  subject, 5% less per later era, never below 5%. It also never takes the last
  step: a book, a teacher or a bench finishes the subject.

It adds to the same per-character study progress as reading, watching and
guided work (`study_progress.dm`), so the routes combine. The record
(`familiarity` on the human) is saved, cleaned on load and cleared on death; it
does not travel between regions, but the study progress it built does.
Agents and the dead learn nothing.
