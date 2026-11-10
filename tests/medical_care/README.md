# Medical care source contracts

Offline checks for field treatment items, internal-bleeding/artery surgery,
and limb reattachment admission, plus a check that every medical stack type resolves to an
icon_state that exists in its DMI. They read DM source and DMI metadata only
and do not run the game.

Run: `python3 -m unittest tests/medical_care/test_source.py`

The isolated limb reattachment fixture projects the production admission and
completion methods into fake organs and checks matching, mismatched and occupied
slots, including a slot filled during the wait. Run with the pinned BYOND bin:
`python3 tests/medical_care/limb_probe.py --byond-bin <BYOND-bin>`. Add
`--negative-control` to confirm that disabling limb identity makes it fail.
The fixture uses DreamDaemon `-safe` on port 0; it does not exercise live play.
