# Ordinary wrapper metadata bootstrap

The fresh ordinary run at `1245e155194dedf3438c4b307dd1b6cfedfeaae4` reached
the save wrapper after passing the complete extraction sequence, the exclusion
source oracle, and the positive/binding/recheck native admission-adapter cases.
Its retained wrapper log reported `Cannot execute null.restore elevation snapshot()`
before `FAIL: wrapper result //1`.

The wrapper cases execute before `roundtrip.dm` constructs its ordinary map.
They now create an owned temporary `/obj/map_metadata` only when no map exists,
then restore the original map and retire the fixture object on both return and
exception. The production geographic restore and all existing result, custody,
cleanup and callback-order assertions are unchanged.

[wrapper-bootstrap.patch](wrapper-bootstrap.patch) is the complete two-file
source correction against that head (2,803 bytes), SHA-256:
`976f3a8defa0e4b1ba3badbcfb62bf741185ddc0195e0eea9be027798612a76a`.
[wrapper-bootstrap-offline-checks.json](wrapper-bootstrap-offline-checks.json)
binds the tested parent/delta and records 183 passing focused offline tests;
unchanged passing suites are reused. Wrapper round-trip source preparation also
passed without compiling or starting an engine.

Native verification is left to fresh ordinary CI on the published correction.
No local native/manual run, production change, workflow change, resource increase,
master sync, merge or deployment is included. Later historical persistence
fixture compatibility remains distinct from these corrected admission paths.
