# Shared player records fixture

Runs `code/modules/admin/shared_player_records.dm` and
`code/modules/admin/player_notes.dm` unchanged in a native BYOND fixture with
only their callers stubbed: the local journal, summaries, revokes, active bans
and their expiry, exact digit-string times, sending to a stub agent, dropping
records once the snapshot holds them, a refused record, and copying old
savefile notes once.

    python3 tests/shared_records/run.py --byond-bin <BYOND bin> --output <dir>

The Python side is tested in `tests/transfer_storage/test_player_records.py`.
