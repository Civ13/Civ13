# Crafting startup loader regression

The startup directory also contains furniture_joinery.json. That file is not a
material recipe list and must be skipped without file access or a failure notice.
The existing case-insensitive material_recipes substring match is retained;
filename selection is not tightened to a new prefix/extension grammar.

Recognized recipe files keep directory enumeration, row ordering, faction-key
mapping, comment rules and registration behavior. Even malformed comma rows retain
legacy registration before their field-count diagnostic. A marked row without a
comma is now diagnosed and still is not registered. Missing, empty or unreadable
recognized files report genuine failures and allow the rest of startup to continue.
Diagnostics identify the escaped filename and row/count; raw recipe values are
not echoed. Filename CR/LF are escaped before HTML encoding.

The focused test executes the complete selected startup block using the existing
audited source projector. Fake engine file/log boundaries are in memory. Its
lexical adapter only models DM string interpolation and protects the literal //
marker from the shared projector's comment splitter. The frozen pre-fix loop is
compatibility data, not Git-history lookup. It reproduces the joinery false warning;
all checked-in recipe registrations and order compare exactly with that loop.
Causal controls remove filename/missing-file/parse guards and expose their failures.

Run with a verified Python interpreter:

```
py -3 -B -m unittest discover -s tests/crafting_loader -v
```

This is offline source/control-flow evidence, not DM compiler, native startup or
live-server acceptance. No runtime, access-list, persistence, config activation,
server restart or deployment is performed by these tests. The CI registry selects
this stdlib-only suite without weakening existing startup/shared-source coverage.
