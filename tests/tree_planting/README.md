# Tree planting regression

Run offline with a verified Python executable:

```text
<python> -B -m unittest discover -s tests/tree_planting -v
<python> -B tests/tree_planting/run.py --output <new-empty-evidence-directory>
```

The default runner only prepares production-source startup adapters and records
commit, dirty patch, source hashes and synthetic map dimensions (8x4x1). Prepared
DME includes refer to the checkout; this is a source packet, not a portable game.
It launches no compiler/runtime, opens no port and touches no production save.

After higher-priority native work is finished and native execution is approved:

```text
<python> -B tests/tree_planting/run.py --native --byond-bin <516.1681-bin> --output <new-empty-evidence-directory>
<python> -B tests/tree_planting/run.py --native --compile-only --byond-bin <516.1681-bin> --output <new-empty-evidence-directory>
```

The native fixture disables normal/global startup, rejects clients and port
reopening, uses isolated runtime files and the actual production serializer.
It asserts one-seed debit, occupancy rejection, partial-duration save/load,
runtime-clock exclusion, repeated restoration registration, winter pause,
irrigation, mature tree conversion, seven-log yield and drought death. The normal
runner compiles once, then runs a round trip, a restart writer and a fresh restart
reader sequentially. The reader exercises the real object-process dispatch,
legacy clock exclusion, one registration, partial-stage resume, same-tick service,
active save/load pauses and maturation. Durations are shortened only by fixture
assignments; production helpers and processing code are unchanged. Three optional
`--negative-control clock|duration|payment` modes mutate generated source only and
require their exact named failed assertion. Saves, binaries, logs, source hashes,
and process receipts are retained in the supplied evidence directory.

Windows uses the existing `scripts/native_fixture.py` Session unchanged: four
serial phases maximum, retained one-process Jobs, resource/deadline limits and
rejection of every sampled socket, including startup. Runtime argv includes the
existing loopback/no-webclient arguments. An earliest-global close and another
close before assertions do not establish the absence of an initial engine bind.

**Current blocker:** BYOND 516.1681 opened a localhost listener before fixture
startup in both supervised attempts, including the earlier-close variant. The
guard rejected the runtime and confirmed cleanup. No passing native tree/save
result or native mutation-control result is claimed. A prior uncontained attempt
compiled cleanly but failed fixture cleanup because of direct `del()` calls;
those calls now use production `qdel()`. Keep the failed evidence unchanged.
See [validation status](../../docs/tree-planting-native-validation.md).

The compile-only mode performs the same contained production-source fixture
build and launches no runtime. It can complete independently of the runtime
startup blocker. Native direct dispatch, natural scheduler cadence, full-world
fresh-process recovery and connected-client appearance are separate scopes.
