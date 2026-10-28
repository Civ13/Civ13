# Humanity wild medicinal-plant art

This directory preserves the exact source PNGs and both versions of their
per-asset rights metadata for a four-state, asset-only DMI port. Read the
[audit](../../docs/civ14-humanity-art-audit.md) and
[credit notice](../../icons/farming/ATTRIBUTION.md#humanity-wild-medicinal-plants).
`sources/humanity_wild_herbs/manifest.json` pins the source repository, revisions,
paths, hashes, state semantics and modifications. The complete metadata lists
twelve upstream states; only the four explicitly selected PNGs are vendored.

Use a verified Python 3 interpreter with Pillow. The local validation used
CPython 3.12 and Pillow 10.4.0. On Windows, select a real executable in
`$PythonPath`; do not use the Microsoft Store alias. From the repository root:

```powershell
& $PythonPath tools/art_ports/humanity_wild_herbs.py verify
& $PythonPath -m unittest discover -s tools/art_ports -p test_humanity_wild_herbs.py -v
& $PythonPath tools/art_ports/humanity_wild_herbs.py rebuild
& $PythonPath tools/art_ports/humanity_wild_herbs.py preview --output docs/media/humanity-wild-herbs.png
```

`rebuild` writes only `icons/farming/humanity_wild_herbs.dmi` unless `--output`
selects another file. It preserves all 4x32x32 RGBA pixels and inserts standard
DMI 4.0 metadata: one direction and one frame per state, without animation delays.
The converter deliberately rejects animated/directional upstream changes rather
than guessing a timing or direction conversion.

To verify every vendored blob against original Git objects, supply an existing
Humanity checkout containing the manifest's audited head and origin commit:

```powershell
& $PythonPath tools/art_ports/humanity_wild_herbs.py verify --upstream ../humanity
```

It compares PNGs at both revisions and checks both metadata snapshots. No command
fetches sources or changes Git settings. If the Git checkout belongs to another
OS account, run with its authorized owner; do not disable ownership checks globally.

For the missing-art comparison, the Civ13 Git object database must contain the
manifest's baseline commit. The audit reads every committed PNG/DMI under `icons/`,
so a sparse working tree does not reduce its coverage:

```powershell
& $PythonPath tools/art_ports/humanity_wild_herbs.py audit --output herbs-audit.json
```

Optional `--baseline-repo PATH --baseline FULL_SHA` compares another explicitly
selected revision. It reports the exact revision and rejects any matching selected
image. Full visible pixels, translated alpha-bounded pixels and horizontal mirrors
are compared independently of names. Same state names are reported separately.
The command fails on decode errors instead of returning a clean incomplete scan.

Tests use temporary files and injected Git responses for duplicate controls;
the committed audit report uses actual baseline Git blobs. Commands do not run
DreamMaker, DreamDaemon, servers, network requests, or gameplay. No new dependencies,
CI workflows or security configuration are installed by this batch.
