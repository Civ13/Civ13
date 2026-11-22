# Drug class tests

- `test_drug_classes.py`: offline source contracts (DME include, class keys instead of single-drug keys, Life/overdose/examine hooks, every drug doses its class, overdose and mixing dangers, tolerance fading faster than dependence). CI suite `drug_classes`.
- `probe.dm`: native probe of class membership, dependence and tolerance from a dose, the tolerance-raised overdose line, old-key migration, cross-relief, opium-with-alcohol breathing, an opium overdose and the examine signs. Run with the pinned BYOND from `scripts/cloud_byond_setup.sh`:

```
python3 tests/ecology_spawning/run_linux.py . tests/drug_classes/probe.dm 300
```
