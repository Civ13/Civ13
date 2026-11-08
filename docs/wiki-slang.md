# Curated wiki slang

This lexicon adapts selected entries from Civ13's
[Guide to Slang](https://civ13.github.io/civ13-wiki/guides/Guide_to_Slang.html).
It adds 50 era rows after the unrestricted rows in `config/dictionary.txt`.

## Source and attribution

The reviewed source is `Civ13/civ13-wiki` at commit
`8c361bc28cb5cfae3b215800622d509d534b7370`, file
[`src/guides/Guide_to_Slang.md`](https://github.com/Civ13/civ13-wiki/blob/8c361bc28cb5cfae3b215800622d509d534b7370/src/guides/Guide_to_Slang.md),
Git blob `966a476eb352c0a445c19192688b62d64aaf1437`, retrieved 2026-10-26.
The page's last source change was `990e1de2754240f1925725d196d3a764339d9392`
by `taislin` on 2026-05-15, after the mdBook migration. The pinned repository
declares the MIT license, copyright 2017 Drassil.org; the complete notice is
retained in [third-party/civ13-wiki-MIT.txt](third-party/civ13-wiki-MIT.txt).
The source page has no separate license notice or term-level historical citations.
This is attribution to the game's guide, not an independent dating of each term.

The wiki presents terms and definitions, not machine-ready replacement rules.
Modern trigger phrases and grammatical articles are editorial adaptations of
those definitions. For example, `a minor court fine` becomes `an amercement`,
and `some sleep` becomes `some shuteye`. `A talkative lady` uses a narrow synonym
for the wiki's `a talkative woman`, avoiding the `woman` output of existing rules.
`A police officer` similarly adapts `policeman` without embedding the old `man`
replacement, which could otherwise complete a new trigger inside a sentence.
The approved 1896/1984 additions likewise use grammatical qualifiers: `an excellent
thing` keeps `corker` as a noun, `my home` preserves ownership, and `looking stylish`
selects the positive appearance sense of `fly` instead of temperature. `A foolish
fellow` avoids consuming the original `idiot` output. These triggers are editorial
choices, not quotations of complete wiki definitions.
The source spelling `Bags o’ Mystery`
uses a curly apostrophe; the configured output uses an ASCII apostrophe.
The reviewed row inventory and source pins are in
`tests/dictionary_era/wiki_slang.json`.

## Period mapping

| Ordinal | Engine epoch | Wiki section | Included rows / decision |
| --- | --- | --- | --- |
| 0 | 5000 B.C. | None | No invented Stone Age vocabulary |
| 1 | 313 B.C. | 313 BC | Historical events only; no slang table |
| 2 | 1013 | 1013 AD | 6 rows; exact epoch correspondence |
| 3 | 1713 | 1713 AD | 8 rows; exact epoch correspondence |
| 4 | 1873 | 1873 AD | 9 rows; exact epoch correspondence |
| 5 | 1903 | 1896 AD | 10 rows; user-approved editorial approximation, not an exact historical match |
| 6 | 1943 | 1940's AD | 6 rows; 1943 lies within the named decade and is the engine's WW2 tier |
| 7 | 1969 | 1969 AD | 5 rows; exact epoch correspondence |
| 8 | 2013 | 1984 AD | 6 rows; user-approved editorial approximation, not an exact historical match |

The decade-to-1943 decision is explicit; no new selector alias is introduced.
An era-6 entry applies only at ordinal 6, not to a date range. The user explicitly
approved using the engine's 1903 tier for the wiki's 1896 section and its 2013 tier
for the 1984 section. These are coarse editorial approximations; neither changes
engine dates or claims that the paired historical years are identical. Excluded
terms and the reasons for rejecting unsafe or ambiguous triggers are recorded in
[wiki-slang-review.md](wiki-slang-review.md), outside the loaded dictionary.

## Matching

The wiki rows are ordinary era rows (`source,replacement,era`). Like every row
they match whole words only, so `excuse me, please` becomes `mind the grease,
please` and `be brave brave now` becomes `be bricky bricky now`, while `bravest`,
`brave-looking` and `excuse meow` are left alone. See [dictionary.md](dictionary.md)
for the full rules.

The curated rows have no conflicting same-era sources and no replacement that
contains another source.

## Verification scope

`tests/dictionary_era/test_slang_content.py` checks the inventory against
`wiki_slang.json`, the source and license pins, and each row in every era.
`test_corpus.py` checks the recorded DM output for every row.
