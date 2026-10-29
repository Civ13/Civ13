# Historical test inputs

These files preserve the exact bytes previously read with `git show` by
the exclusion source, preparation and historical-runtime contracts. The manifest
records the original commit/path, Git blob, byte count and SHA-256. These files
are test data, never live comparison bases, executable runners or runtime grants.
Text fixtures disable checkout EOL conversion so their raw hashes stay portable.

Historical source comparisons and mutation controls read these frozen inputs
without requiring old commit objects. A depth-one local test verifies selected
historical contracts with the old objects absent. Actual fixture preparation
still validates independent immutable event base/head commits and complete
production/helper equality, and fails closed when ancestry is unavailable.
Some synthetic integration-history tests intentionally use real ancestry and
therefore still need the relevant historical commit objects.

The reviewed extraction source is pinned by SHA-256 in the source test. Its focused local checks compare the checkout with its own HEAD and retain the historical exclusion and custody assertions; they do not require the reviewed commit object. The production preparation runner still fails closed when its independently verified extraction ancestry is unavailable.
