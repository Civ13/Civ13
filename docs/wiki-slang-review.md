# Wiki slang exclusions and editorial decisions

The user approved mapping the wiki's 1896 AD section to engine 1903/ordinal 5,
and 1984 AD to engine 2013/ordinal 8. These are editorial approximations, not exact
historical matches. Neither approval requires blindly inverting every glossary
definition. Source and license details are in [wiki-slang.md](wiki-slang.md).

All nine 1896 terms have selected, explicit phrase-mode triggers. `Up the river` has
separate `in prison` and `in jail` triggers. Six 1984 terms have selected triggers;
`Hellacious` remains excluded because its source definition spans positive and
negative senses without one clear automatic substitution.

## Excluded terms

| Wiki section | Excluded terms | Reason |
| --- | --- | --- |
| 1013 AD | Acre; Apostate; Bailiwick; Baron; Chancellor; Constable; Exchequer; Justiciar; Sergeant; Steward | Definitions describe measurements, status or specific institutions/roles. Common modern one-word equivalents would erase distinctions; no sufficiently narrow trigger was selected. |
| 1713 AD | Admiral of the Narrow Seas; Bailed man; Rum gagger | Specific situations or long descriptions without a reliable concise substitution |
| 1713 AD | Cast up one's accounts | Pronoun and conjugation depend on the speaker/sentence |
| 1713 AD | Caper | Competes with the selected `to go up a ladder to bed` for the same hanging definition |
| 1713 AD | Paddy-whack | Automatic substitution of a nationality is unnecessary; no trigger selected |
| 1873 AD | Bow wow mutton | The bad-meat/naval context is narrower than an automatic generic meat replacement |
| 1940's AD | Dame | A broad identity replacement; `woman` is also produced by existing unrestricted rows |
| 1940's AD | Cockeyed | Multiple senses; `stupid` is already produced by unrestricted rows and would cascade |
| 1969 AD | Flower power; Freedom riders; Hawk | Movement or political context needs explicit meaning; the glossary descriptions are not safe universal synonyms |
| 1984 AD | Hellacious | Positive/negative ambiguity; no single reliable trigger was selected |

Short broad triggers such as `man`, `home`, `cool`, `sleep` or `leave` must not be
inserted as unbounded substrings. Even with literal space padding, the grammatical
role matters: `my home` is a noun phrase while `heading home` uses an adverb.
The selected `looking stylish` trigger avoids interpreting `cool` as temperature.
New `awesome`, `stupid` or `idiot` triggers would also consume outputs of original
unrestricted rules, so those original outputs remain untouched.

Only the new wiki rows opt in to phrase matching. Existing two-/three-field rows
remain literal. The conservative boundary policy preserves delimiters and rejects
hyphen/apostrophe/word/unknown-Unicode continuations without general regex syntax.
