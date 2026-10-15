# Bounded combat history

`/mob/proc/append_attack_log()` owns the recent combat history. The migration
routes all 86 existing writers through it without changing their row expressions.
It keeps at most 1,024 recent rows under normal operation. On overflow, it writes
the oldest 64 rows as one JSON record to the existing private attack log, then
cuts those rows from the same list. The recent window therefore varies from
961 to 1,024 rows. Bodies and ghosts retain their shared list identity.

Archive records have category `ARCHIVED_MOB_ATTACK_HISTORY`, round/time and
subject metadata, and an `entries` array containing the exact original rows in
order, including duplicates. This archival path runs even when the optional
ordinary attack logger is disabled. The admin verb explains where older rows go.

If the file is unavailable, a write returns zero, or it throws, no rows are cut.
Two global scalars limit retries and warnings to once per running-server minute;
there is no retained registry, per-mob callback or sleeping timer. Histories can
still grow during a logging failure. A successful `text2file` return acknowledges
the write, not crash durability. A partially written failed batch can be repeated
on retry; duplicate archive rows are preferable to silently dropping history.

Legacy oversized lists are not trimmed while idle. Each later append archives
at most one batch. A 5,000-row history converges after 64 successful appends,
preserving those new rows too. The limit is a row count, not a byte bound, and
saved legacy histories are not rewritten by this change.

## Verification

Pure checks (no compiler, daemon, network or production data):

```powershell
& '<verified-python>' -m unittest discover -s tests/attack_history -p test_sources.py -v
```

`check_writers.py` rejects direct mutation outside the explicit initialization,
shared-ghost assignment and central helper. It compares all migrated expression
fingerprints and multiplicities with `writer-migration.json`. This lexical guard
does not prove arbitrary dynamically named aliases cannot mutate a list.
`migrate_writers.py` reproduces the one-time source transformation from the
recorded baseline and rejects another inventory before writing anything.

The native fixture compiles the real production helper and shared ghost
assignment under pinned BYOND 516.1681. It replaces only the write boundary and
warning sink; successful writes still use a real temporary file. There is no
normal game startup, production configuration, save, outbound hook or listening
port. Every name and history row is synthetic.

```sh
python3 tests/attack_history/run.py --byond-bin /trusted/byond/bin --evidence-dir /fresh/evidence
```

The 28 contracts cover exact ordering/text/duplicates, shared identity, archive
before cut, disabled ordinary logging, actual disk round trip interleaved with
ordinary stream writes, zero/throw/missing
file failures, bounded warnings/retries, and gradual legacy catchup. Negative
controls `failure-trim`, `alias` and `batch` must complete without engine errors
and fail their named contracts. The PR's existing introduced-test CI selector
runs the pure suite and the hosted native positive/control cases, with artifacts.

The matched 20,000-append workload reports recent-history row and character counts
for the old unbounded append and the candidate, plus archived rows/write count.
Fixture oracles intentionally retain the expected and archived rows for equality
checks. These counts demonstrate the history retention contract; they are not
process RSS, live server latency, gameplay acceptance or attribution of Gaia's
reported 12.5 GB usage. No full-server improvement is claimed without live data.
