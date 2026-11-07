# Speech dictionary tests

Offline (CI runs these; no BYOND needed):

```text
python3 -B -m unittest discover -s tests/dictionary_era -p "test_*.py" -v
```

- `test_corpus.py`: `corpus.json` holds the DM fixture's output for every
  corpus line, from the frozen pre-rework helper (`legacy/dictionary.dm` with
  `legacy/dictionary.txt`) and from the production helper. The Python models in
  `reference.py` must reproduce both, and old and new may differ only in the
  shapes the single-pass rework changed (whole words, casing, entities, rows
  that used to be shadowed, new rows).
- `test_slang_content.py`: the data parses, and the wiki slang inventory
  matches `wiki_slang.json`.
- `test_sources.py`: call sites, loader, include order and the rust_g fallback.

Native fixture (needs DreamMaker and DreamDaemon on PATH; `bash
scripts/cloud_byond_setup.sh` installs the pinned compiler):

```text
python3 tests/dictionary_era/prepare.py --output <new dir> --run     # check corpus.json
python3 tests/dictionary_era/prepare.py --output <new dir> --write   # regenerate it
```

The fixture holds only the dictionary helpers, the production speech prefixes
(`capitalize(sanitize())` for say, `sanitize()` for whisper) and `probe.dm`.
It runs with `-safe` in its own directory, opens no game world and starts no
other process. It reports which engine it used. On Linux without
`librust_g.so` that is the regex fallback, which the rust_g path must match
exactly; the helper checks this at load before it uses rust_g.
