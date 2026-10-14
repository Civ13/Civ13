# Runtime error history

The production cache retains the newest 1000 detail entries, with at most 100
per source. Normal details and skipped-runtime summaries share both limits.
Retirement removes both list memberships, breaks the source backreference and
clears captured user locations and detail strings. An external holder sees an
expiry message; once it releases the entry, native datum autocollection is
possible without adding a garbage-queue task.

Source metadata and its notification cooldown remain for the round. Counters
show lifetime logged runtimes and skipped occurrences separately from recent
detail entries. Source identity uses exception file and line, not error text.
Distinct file/line identities are not capped: synthetic or dynamically generated
exception identities can still grow metadata and the existing world/Error
cooldown dictionaries. This fix bounds retained detail history, not all possible
runtime memory or long-running server RSS.

Run with Python and a verified BYOND 516.1681 bin directory:

```
python3 tests/error_history/run.py --byond-bin /trusted/byond/bin --evidence-dir /tmp/error-history-fixed
python3 tests/error_history/run.py --byond-bin /trusted/byond/bin --evidence-dir /tmp/error-history-historical --historical
```

On Windows use a verified full Python path, never bare python/python3. The
standalone fixture includes actual production logging, retirement, constructors,
viewers and world/Error. Browser and logging outputs use isolated sinks and only
the delayed silence-summary wait is accelerated to two ticks. It refuses network
ports and starts no game controllers, maps, production config or persistence.
It checks FIFO memberships, backreferences, native autocollection, actual usr
location release, expired external holders, lifetime counters, skip summaries,
notification cooldowns, viewer text and world/Error totals/disk logging. The
historical control replaces only log_error with the immutable pre-fix body from
3ce4ece23 and must fail the eleven named retention contracts.

`--prepare-only` writes source and metadata without invoking native tools. This
does not prove compilation or runtime behavior. CI selects this new suite for
the introducing PR; subsequent runs require the existing extensive opt-in.
