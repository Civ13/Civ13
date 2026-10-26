# Speech dictionary

`config/dictionary.txt` is loaded at world setup. Each comma-separated row is
`source,replacement` or `source,replacement,era`. For example:

```text
brb,be right back
excellent,corker,4
hello,greetings,0
```

The first row applies in every era. The second applies only at ordinal era 4;
the third applies only at era 0. Existing two-field rows need no migration.
These examples demonstrate syntax; they are not additional default replacements.

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

The optional selector must be one digit from `0` through `8`. Leading/trailing
whitespace around that selector is ignored. Empty selectors, names, dates,
ranges, lists, decimals and other values are invalid. Invalid selectors and rows
with more than three fields are diagnosed in the world log with their file and
line number, then skipped. An empty third field does not mean unrestricted.
Lines without a comma are ignored, as before. There is no quoting or escaped-comma
syntax; source and replacement fields retain their original whitespace and bytes.

Eligibility reads the current `map.ordinal_age` when speech is processed, including
after prototype research or an administrator changes it. The display `map.age`
can differ from this research tier. Slang-guide period headings are not selectors.
If map metadata is absent, only unrestricted rows apply. Changing the dictionary
file itself still requires world setup; live era changes require no reload.

Eligible rows run in file order using the existing `replacetext` operation. Rows
may overlap or transform earlier output; there is no special priority for restricted
rows. Normal speech still sanitizes and capitalizes before dictionary replacement.
The whisper verb still sanitizes before replacement and capitalizes later in
`whisper_say`. Both retain their existing language and radio handling.

Offline checks and a source-only native fixture preparer live in
`tests/dictionary_era`. Prepared fixtures are not compiled or executed by the
offline checks. Native compiler/runtime and connected-client acceptance remain
separate checks; see that directory's README.
