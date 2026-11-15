# Language proficiency

A human knows each language to a score from 0 to 100. The code is in
`code/game/mob/language/proficiency.dm`; the numbers are the `LANGUAGE_*`
defines in `code/__defines/species_languages.dm`.

| Level | Score | Hearing | Speaking |
| --- | --- | --- | --- |
| None | 0 | Foreign syllables | Cannot |
| A few words | 1 to 24 | The odd word | Cannot |
| Broken | 25 to 59 | That share of the words | That share of the words; the rest comes out in the mother tongue |
| Conversational | 60 to 89 | As above | As above |
| Fluent | 90 to 100 | Everything | Everything |

The score is stored in `partial_languages` as points out of the language's
`difficulty`. A language given with `add_language()` (a mother tongue, a job's
language) is at 100. A learned one joins the `languages` list at Broken through
`add_language(name, FALSE, FALSE)` and keeps its score.

## How a score rises

`gain_language(L, amount, ceiling, daily_cap)` is the only way up.

- **Hearing** (`language_exposure`, from `hear_say`): 0.033 per line from
  someone who speaks it better, at most one line every 20 seconds. That is
  about 6 an hour, so about 10 hours among speakers to reach Conversational.
- **Speaking**: 0.1 per line when a better speaker hears it, same 20 second
  limit.
- Both halve from Conversational and stop at 12 per language per real day.
- **Lessons** (`teaching.dm`): the Teach Language verb. A fluent speaker
  teaches someone standing next to them who accepts. Both stay put for two
  minutes and the learner gains 1, up to 8 per language per real day, on top
  of hearing and speaking. With daily lessons Conversational takes about
  three days instead of five or more.
- **Language book**: a primer. Each 80 second sitting gives 5, up to Broken.
- **Study Writing**: as before, up to Broken.
- Books and writing share an allowance of 10 per language per real day.
- Related languages start from the `mutual_intelligibility` table, scaled by
  the score in the language that grants it. `symmetrize_language_kinship()`
  makes every pair agree at world start by taking the stronger value.

Reading and writing paper in a language needs Conversational. Paper stays all
or nothing: the paper system's projection never sends partly hidden text.

Nothing lowers a score.

## What players see

- Heard speech in a half-known language passes through `scramble()`, which
  lets through the score's share of words.
- `garble_own_speech()` does the same to what a learner says.
- Until fluent, speech outside the mother tongue is tagged, for example
  `(Latin, Old Norse accent)`. The mother tongue is the people's language
  (`docs/origins.md`), else the default language.
- Check Known Languages shows the level and percentage of every language,
  and lists languages still below Broken as "not yet speakable".

## Books

On book-research worlds each research chapter records the language it was
written in (`code/modules/research_tree/book_language.dm`): the writing
language of whoever researched, wrote or hand-copied it. A character writes
in their default language when they are Conversational in it, otherwise in
their mother tongue.

- Below Broken in a chapter's language it cannot be studied. From Broken to
  Fluent it takes longer, twice as long at Broken.
- Hand-copying a chapter at a bench needs Conversational in its language and
  writes the copy in the copier's writing language. That is translation: set
  the default language to the one wanted, then copy.
- A printed book and a torn-out chapter keep their language.
- Chapters with no recorded language, such as starting books, are plain to
  everyone. The book window lists the languages of its chapters.

Tests: `tests/language_proficiency/test_proficiency.py`,
`tests/book_language/test_book_language.py`.
