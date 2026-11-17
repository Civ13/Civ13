# Knowledge spreads with a lag

On book-research worlds a subject (research node) is in one of three bands,
set only by how many eras its own era is behind the world's era:

| Band | Default lag | Meaning |
| --- | --- | --- |
| Guarded | the world's era and the one before | Research, books and teaching work as ever. |
| Spreading | 2 and 3 eras behind | Quicker to learn and to research again. |
| Common | 4 or more eras behind | Everyone knows it. |

`code/modules/research_tree/knowledge_spread.dm` works the band out
(`knowledge_band(node_id)`) from `map.ordinal_age`. Nothing is saved, so the
bands follow the era up and, after an era is lost, down. Subjects found only
in books stay guarded.

The lags are server config in `config/config.txt`, 1 to 10 eras each (10 never
happens): `KNOWLEDGE_SPREADING_ERAS` (2) and `KNOWLEDGE_COMMON_ERAS` (4).
Common wins when they overlap.

The tech tree and the research book and bench windows show the band after a
subject's era, for example "Stone Age - common knowledge".

Tests: `tests/knowledge_spread/` (offline suite `knowledge_spread`, native
`probe.dm`).
