# Magic weapon contact

Run `<verified Python executable> -m unittest discover -s tests/magic_weapon_contact -p "test_*.py"` from the repository root.

This is an offline source-flow check. It checks that the production attack and contact paths retain the guards for rejected attacks, defense and late misses, and that actual hit and completed throat-slit paths invoke the magic contact hook. It does not compile or run DM, execute random outcomes, or prove live or in-game behavior. Native verification is separate.
