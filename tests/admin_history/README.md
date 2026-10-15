# Bounded admin history

The global `admin_log` previously retained every admin event for the entire
round. The production `log_admin()` now keeps at most 1,024 recent rows when
archival storage works. Overflow archives the oldest 64 exact rows in one JSON
record, then cuts those rows from the same list. The usual window is 961-1,024
rows. The actual admin view displays the recent rows and explains the archive.

Records use category `ARCHIVED_ADMIN_HISTORY`, round/time metadata and exact
`entries` in the existing private server diary. Archiving retired history is
independent of `LOG_ADMIN`; that setting still controls ordinary per-event
logging. Enabled ordinary logs and archive records can contain the same events.
No public or network sink is introduced.

Missing storage, zero writes and thrown errors retain every row. Only two
scalar timestamps survive failure, limiting retries/warnings to once per running
server minute. Successful later appends drain one batch each. Memory can grow
while storage fails; the row limit is not a byte limit. A successful native
`text2file` return acknowledges a write, not crash durability. Partial failed
writes may be repeated rather than risk losing audit records.

`test_sources.py` prepares the production writer and view without native work.
`run.py --byond-bin <516.1681-bin> --evidence-dir <fresh-directory>` compiles and
runs the actual writer/view in a one-tile world with temporary files, a closed
port, injected write failures, a permission parent and a captured browse sink.
The fixture checks the native file round trip, recent-view order, permission
rejection, exact text/duplicates, shared list identity, cooldowns and recovery.
Controls `failure-trim`, `alias` and `batch` must reach named failed assertions;
compile/runtime errors or timeouts invalidate them.

A matched 20,000-event baseline/candidate workload reports retained row/character
counts and archived rows/writes. The test oracle retains all rows for comparison;
these counts do not measure RSS, server latency or Gaia's long-run footprint.
