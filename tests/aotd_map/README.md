# Art of the Deal map checks

```sh
python3 -B -m unittest discover -s tests/aotd_map -p 'test_*.py' -v
python3 -B tests/aotd_map/compile_map.py --byond-bin /path/to/byond/bin --evidence-dir /new/evidence/directory
```

On Windows use a verified full Python path. The native helper reads the compiler
target from `tools/byond/version.json`, retains all production declarations and
changes only the compiled map include in a uniquely named temporary DME. It
compiles the complete 220x220x2 map without starting DreamDaemon or importing saves.
The compiler has a 180-second deadline. Logs, input/artifact hashes, head and dirty
state are retained, including binaries emitted before an abnormal compiler exit.
A zero-error banner followed by a compiler crash remains a failure.

The offline checks reject merge markers, duplicate palette alternatives, legacy
vendor types, obsolete ambience, broken geometry and the DMM `alist(...)` override
that triggers a native compiler heap fault. The restored `ata` list literal matches
historical canonical revision `0ba67fa882d6a04c65ddd11cf0c00a44a1b1b5dc` and retains
its five authored values. Runtime vendor/vehicle behavior, sound and client
rendering require separate gameplay verification; compilation is not a join test.

CI follows the repository's existing admission policy: the offline and native
checks run when this test suite is introduced by a PR or when extensive
regressions are explicitly selected. Ordinary pushes do not opt into native
regression suites implicitly.
