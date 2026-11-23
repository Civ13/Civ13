# Dentistry tests

- `test_dentistry.py`: offline source contracts (DME include, every icon state drawn, file-local defines, plain saved head state, unsaved tooth freshness, the eating/speech/examine/knock-out/revive hooks, recipe research mapping and craft needs, research gates on the surgery steps). CI suite `dentistry`.
- `probe.dm`: native probe on a bare head organ: plaque and decay, once-a-minute checks, drawing rotten teeth first, replanting counts, clamping and abscess clearing, a bridge falling out without anchors, tooth freshness through split and merge, knocked-out teeth coming out fresh, bite size and speech with and without dentures, taking dentures out and knocking them out, and the porcelain firing result. Run with the pinned BYOND from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/dentistry/probe.dm 300
```
