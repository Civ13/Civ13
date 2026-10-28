# Speech dictionary

`config/dictionary.txt` is loaded at world setup. Supported comma-separated rows:
`source,replacement`, `source,replacement,era`, and
`source,replacement,era,phrase`.

```text
brb,be right back
hello,greetings,0
excuse me,mind the grease,4,phrase
```

Two-field rows remain unrestricted literal replacements. Three-field rows retain
their literal substring behavior and apply only in the selected era. Only the
explicit four-field `phrase` form uses phrase boundaries. The last example is
part of the curated wiki lexicon; the era-zero example only demonstrates syntax.
No migration is required for existing two- or three-field rows.

| Selector | Existing epoch label |
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

The selector must be one digit from `0` through `8`; its outer whitespace is
ignored. Empty selectors, dates, names, ranges and other values are diagnosed
with file/line information and skipped. Four-field rows require the exact,
case-sensitive mode `phrase` after trimming that field's outer whitespace.
Unknown or empty modes and other field counts are diagnosed and skipped.
There is no quoting or escaped-comma syntax. Lines without commas are ignored.

Phrase sources must be nonempty ASCII without outer whitespace. Their interior
text is matched literally, including punctuation and spaces; no regex syntax,
tokenization or whitespace normalization is added. Replacement bytes are authored
text, with no automatic recasing. Literal rows keep their original whitespace.

Phrase boundaries are start/end of text or these known ASCII separators:
whitespace (codes 9-13 and 32), `!`, `"`, `(`, `)`, `,`, `.`, `:`, `;`, `?`,
`[`, `]`, `{`, `}`. Letters, digits, underscore, hyphen, apostrophe and all
unclassified characters, including Unicode neighbors, are continuations.
Thus `excuse me`, `excuse me!` and `(excuse me)` match the opted-in rule, while
`excuse meow`, `brave-looking` and Unicode-adjacent fragments are protected.
Single-quoted or Unicode-punctuation neighbors deliberately remain conservative.

Each phrase row scans its original input once. Delimiters remain outside the
replacement, adjacent matches work, and inserted output is not rescanned by the
same row. Later rows still consume earlier output in file order. Two-/three-field
rows continue to use the existing `replacetext` operation and overlap behavior.

Eligibility reads live `map.ordinal_age`, including after research/admin changes.
The displayed `map.age` can differ. Missing metadata permits unrestricted rows
only. Editing the dictionary file still requires world setup; era changes do not.
Normal speech still sanitizes/capitalizes before replacement; whispers sanitize
before replacement and capitalize later in `whisper_say`. These call sites are
unchanged. Replacement text is never automatically recased by either mode.

See [wiki-slang.md](wiki-slang.md) for attribution and the approved approximate
1896/1984 mappings. Offline tests and a source-only native fixture preparer are in
`tests/dictionary_era`. Compilation does not establish runtime/gameplay behavior.
