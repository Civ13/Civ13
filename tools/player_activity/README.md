# Player activity aggregator

Reads the per-region `data/player_activity/*.jsonl` files the game writes into
one host SQLite database, and prints a report. See
[docs/player-activity.md](../../docs/player-activity.md).

Tests: `python3 -B -m unittest discover -s tests/player_activity -p 'test_*.py'`.
