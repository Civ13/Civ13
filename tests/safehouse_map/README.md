# Safehouse map static checks

Offline checks for the inactive Extraction party safehouse template in
`maps/WIP/extraction_safehouse.*`. See `docs/extraction-safehouse-map.md`.

```sh
python3 tests/safehouse_map/build_map.py            # regenerate DMM, layout, descriptor
python3 tests/safehouse_map/build_map.py --check    # deterministic output check
python3 tests/safehouse_map/validate_map.py         # static geometry and contract checks
python3 -m unittest discover -s tests/safehouse_map -p "test_*.py" -v
python3 tests/safehouse_map/compile_map.py --byond-bin <bin> --evidence-dir <fresh dir>
python3 tests/safehouse_map/preview.py              # docs/images diagram (Pillow)
```

Edit `build_map.py` and regenerate; never hand-edit the DMM. The compile
harness is native compile-only evidence and starts no world. The registered
CI suite is `safehouse_map`; any new executable file here must be added to
`SAFEHOUSE_MAP_OFFLINE_TESTS` in `scripts/select-ci.py`.
