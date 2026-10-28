# Fishing-stock completion source contracts

Run from the repository root:

```sh
python3 -m unittest discover -s tests/fishing_stock -p 'test_*.py' -v
```

This suite is **offline source and model evidence**, not DM execution. It extracts
the three production `attackby` completion blocks and rejects changes outside its
reviewed, indentation-sensitive subset. A bounded Python projection covers stock
admission, the existing chance/debit/product ordering, contested completions,
cancellation, failed bites, species selection and a refill between completions.
Removing each route's new guard independently reproduces a deficit in the model.

The immutable pre-fix source at
`083cbf20f0d64abffdbef9b478bf1eda74458f65` admits two actors against one remaining
fish; after two successful waits/bites it can decrement twice and create two fish.
All nine ordered pairs of modern rod, ordinary pole/net and sharpened-branch
routes reproduce `counter=-1`, two products and two refill callbacks in the
source-bound projection. The changed source returns immediately when the stock
is empty after a successful wait, before its chance roll, message or debit.

The patch preserves the 120/150/120 waits and 40/30/20 percent chances for stock
that remains available. Empty entry and cancelled waits still do not roll or
debit. Product construction remains after the debit. No callback owner, refill
delay, capacity, species, fish cage or persistence policy changes are included.

Actual DM scheduling, `do_after`, chat effects, constructors, deletion and
save/load are not executed by these tests. Compile/native acceptance is still
required before claiming an engine-verified fix. The present refill procedure's
save/reload lifecycle needs a separate policy and source review; a passing model
does not establish sustainable fishing rates or aquaculture.
