# Speech dictionary

`config/dictionary.txt` swaps out-of-character slang in say and whisper lines,
for example `brb` to `be right back`, and adds period slang for each research
era. It is loaded once at world setup by `load_speech_dictionary()` in
`code/_helpers/dictionary.dm`; editing the file needs a world restart.

## Rows

```text
brb,be right back
gamers,brothers
excuse me,mind the grease,4
```

A row is `source,replacement` (every era) or `source,replacement,era`, where
`era` is one digit matching `map.ordinal_age`:

| Era | Epoch |
| --- | --- |
| 0 | 5000 B.C. |
| 1 | 313 B.C. |
| 2 | 1013 |
| 3 | 1713 |
| 4 | 1873 |
| 5 | 1903 |
| 6 | 1943 |
| 7 | 1969 |
| 8 | 2013 |

Lines starting with `#` and lines without a comma are ignored. There is no
quoting, so neither field can hold a comma. Each of these is logged with its
line number and skipped:

- a field count other than 2 or 3
- an era that is not one digit from 0 to 8 (spaces around it are fine)
- an empty source or replacement, one with spaces at either end, or one with
  characters outside printable ASCII
- a source repeated in the same era (the first row wins; case does not matter)

The world log also reports the row count and which engine is in use.

## Matching

Each message gets a single pass:

- **Whole words.** A source only matches whole words. `lol` changes `lol` and
  `lol!` but not `lollipop`, and `cuck` leaves `cuckoo` alone. Word characters
  are everything except whitespace and `! " ( ) , . : ; ? [ ] { } & #`, so
  hyphenated words (`brave-looking`) and words with accented letters are left
  alone. A source edge that is punctuation needs no boundary, so `:)` matches
  anywhere, while `:b` does not match `:bread`.
- **Longest match wins.** Where sources overlap, the match that starts first
  wins. Of those starting at the same place, the longest wins, so `poggers`
  beats `pog` and `pm the admins` beats `admins`. File order does not matter.
- **No rescanning.** Replacement text is never matched again.
- **Case.** Matching ignores ASCII case. A source written in lower case copies
  the typed casing, the way `replacetext()` does: `LOL` gives `HAHAHA`, `Lol`
  gives `Hahaha`, anything else uses the replacement as written. A source that
  has capitals, such as `SS13`, always uses its replacement as written.
- **Speech arrives encoded.** `sanitize()` runs first, so `'` and `"` reach the
  dictionary as `&#39;` and `&#34;`. Sources are encoded the same way when they
  load, so `that's gross` matches, and entities count as separators, so
  `"brave"` and `brave's` match `brave`. Replacements are inserted as written.
- **Eras.** A row with an era applies only while `map.ordinal_age` equals it.
  With no map, only rows without an era apply. When an era row and an every-era
  row share a source, the era row wins in that era.

Plurals and other forms need their own rows (`gamer` and `gamers`).

## Engine

Each word of the message and of every source is wrapped in an invisible marker
character, so a plain substring search can only match whole words. At load,
ten tables are built: one with no map, and one for each era. Each table has a
rust_g Aho-Corasick automaton (`setup_acreplace_with_options`, case-insensitive,
leftmost-longest) and a BYOND regex of the same sources, longest first. Both
replace each match with an index token, and the line is rebuilt from the tokens.
A line with no match comes back unchanged.

rust_g is used when it loads and agrees with the regex on a self-test of every
source. Otherwise the regex is used and the world log says so. Both engines
give the same output; the regex is just slower (tens of microseconds a line
against a few).

The three marker characters (codes 1-3) are removed from a message before
matching.

## Tests

`tests/dictionary_era` holds the offline checks run by CI:

- `test_corpus.py` checks `corpus.json`, about 2,200 chat lines that the DM
  fixture ran through the frozen pre-rework helper (`legacy/`) and the current
  one. It confirms that two independent Python models reproduce both outputs,
  and that old and new differ only in the shapes the rework changed.
- `test_slang_content.py` checks the data: every row parses, the wiki slang
  inventory and its attribution, each wiki row only in its era, and no
  replacement containing another source.
- `test_sources.py` checks the wiring: call sites, loader, include order and
  the rust_g fallback.

After changing the helper or the data, regenerate the corpus with BYOND on
PATH (`bash scripts/cloud_byond_setup.sh`):

```text
python3 tests/dictionary_era/prepare.py --output <new dir> --write
```

`--run` instead of `--write` compiles and runs the fixture and checks it
against the recorded corpus. See [wiki-slang.md](wiki-slang.md) for where
the era slang comes from.
