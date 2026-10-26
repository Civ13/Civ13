# Focused harness follow-up

Source commit: `1fb818120a6437b925f268575f77cb88f0ca56ef`.
Parent: `8a0bdc36b3c4907a26d9634445a7a75770866247`.
No additional master integration is included.

At published head `1245e155194dedf3438c4b307dd1b6cfedfeaae4`, ordinary
[CI40252373259](https://github.com/Civ13/Civ13/actions/runs/40252373259) passed
the complete extraction sequence, the current/historical exclusion oracle and
all three native admission-adapter cases. The separate inactive capture
[CI40252373207](https://github.com/Civ13/Civ13/actions/runs/40252373207) passed its
positive and four exact controls. The ordinary run failed later in the save
wrapper because its cases run before the round-trip fixture constructs map
metadata. See [the additional fixture bootstrap correction](wrapper-bootstrap.md).

[harness-followup.patch](harness-followup.patch) contains the complete 13-file
source follow-up. SHA-256:
`12990af9dc96cddbbd03dffc9284957c40bd4cca83cf5a960825455c40c9db1c`
(38,003 bytes). This is additional to the preserved original manual-resolution
patch, not a replacement for it.

## Corrections

- Active extraction runners and the persistence-admission/wrapper runners now
  read the single central current version, 516.1688. Before every compiler or
  daemon phase they passively verify the four installed Linux members against
  the adjacent reviewed `BYOND/pinned.zip` archive through the existing identity
  helper. They require one exact complete compiler banner and one clean summary,
  including stderr, and reject historical, extended, duplicate or prefixed banners.
  Existing process arguments, deadlines, cleanup and assertion adjudication stay
  unchanged. No compiler-version alternative is accepted.
- The historical exclusion packet remains bound to its original immutable
  extraction source. Its original mutation assertions execute against that
  source explicitly. Current-source checks separately require full-file equality
  with reviewed merge `c4585fabaf81e1357054b4527d71d4f3a2d8a0b2`, including every
  runtime exclusion, diagnostic and custody path. Omission controls reject each
  key and guard change. The historical `run.py`, `source_contract.py`,
  `resources.py` and `probe.dm` remain byte-identical to the previous PR head.
  Historical native receipts and the native hold retain their original scope.
- The minimal serializer fixture declares the loader's area registry, roof type
  and generated-snow dependency. Constructing a roof or applying nonzero generated
  snow fails explicitly because those behaviors require their production
  fixtures. Its zone hook permits only the ordinary no-zone no-op path; actual
  topology restoration still throws. This supports the inactive capture fixture
  and ordinary save wrapper without inventing roof/zone/snow acceptance.

## Evidence and limits

[harness-offline-checks.json](harness-offline-checks.json) records **182 passing
offline tests**: extraction compile-only/identity/generation/map boundaries,
standalone instance contracts, historical/current exclusion oracles, inactive
capture source controls, restore integration, sleep/cross-level/profiling and CI
policy. Changed Python sources also parse successfully. Native executables were
not invoked locally; injected compiler output remains mocked evidence.

The fresh ordinary CI run at the published follow-up head is the native
integration oracle. Passing offline checks do not establish the three formerly
blocked native paths. Other historical persistence runners retain their own
strict pins; any newly reached incompatibility must remain an explicit blocker
until its scope is reviewed. No resource limit or admission guard is widened.

The extraction game modules and shared persistence production sources are
unchanged. Connected-player, representative save/restart/recovery, external
custody/surface integration and independent final review remain separate gates.
