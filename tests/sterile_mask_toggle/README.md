# Sterile mask toggle

`test_toggle_coverage.py` checks that putting a lowered sterile mask back up
restores its initial face coverage, and lowering it clears coverage (#6713).
Run with `python3 -B -m unittest tests.sterile_mask_toggle.test_toggle_coverage`.
