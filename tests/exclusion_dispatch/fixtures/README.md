# Historical test inputs

These nine files preserve the exact bytes previously read with `git show` by
the exclusion source, preparation and historical-runtime contracts. The manifest
records the original commit/path, Git blob, byte count and SHA-256. These files
are test data, never live comparison bases, executable runners or runtime grants.
Text fixtures disable checkout EOL conversion so their raw hashes stay portable.

The historical comparisons and mutation controls use these frozen inputs without
depending on old branches or unreachable Git objects. Actual fixture preparation
still validates independent immutable event base/head commits and complete
production/helper equality. Its tiny temporary Git histories remain intentional
tests of that real preparation path; they do not retrieve historical objects.
