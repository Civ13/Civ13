# Persistence minimum date

Run `python3 -B -m unittest discover -s tests/persistence_year -v` with a real
Python interpreter (use its full path on Windows). No engine, network, game
startup, production save or external service is used.

The tests translate an explicit vocabulary from the production floor procedure,
retaining branches and assignments. They check earlier/equal/later dates,
unknown labels, repeated calls, unrelated modes, independently advanced tiers,
unchanged research data, activation/startup/restore wiring and save field
contracts. Generated defect controls demonstrate equal-date mutation, tier
reset and missing entry calls. Save/restore traces use Python adapters; they
do not execute BYOND serialization or establish native acceptance.

`age` is a displayed date/epoch string, while `ordinal_age` is a separate 0-8
technology tier. Prototype research can advance the tier without changing the
date. There is no independent continuous calendar-year field or general era to
year conversion. The floor orders the two standard BC epoch labels and canonical
numeric date strings only; unknown labels remain unchanged. Raising an earlier
date sets `age` to `1943`, retains any tier above WW2 and marks epochs 1-6 complete
so legacy research cannot replay an earlier epoch. It does not grant faction
research, reset founding baselines, copy WW2 mode research defaults or change
unrelated modes. An already equal/later date returns without changing any field.

The ordinary Persistence admin toggle calls the floor only when enabling the
mode. Disabling retains the date; re-enabling is idempotent. Configured
`PERSISTENCE` startup calls it for a fresh world. Completed imports call it after
both positional and durable metadata restoration, using the restored persistence
flag, so a later saved date wins over fresh map defaults. Earlier persistent
saves receive the floor in memory; no save format or original save is rewritten
by loading. Persistence Chad Mode + and the Nations RP persistence map are
separate existing modes and are not newly enabled or otherwise reconfigured.

Native acceptance uses the existing full-source durable-world runner:

```
python3 tests/world_save/run-durable-world.py --persistence-year --byond-bin <516.1681-bin>
```

The guarded public CI build job executes this case and `--negative-control`
`year-helper`, `year-load`, and `year-order` independently. They respectively
disable the helper, omit the post-import call and move it before durable restore.
Controls must fail at `earlier date not raised` or `saved date floor lost` after
clean native compilation; engine errors, timeouts and unrelated assertions fail
acceptance. Generated sources, hashes, logs and receipts are retained for 7 days
in the exact-head `persistence-year-<SHA>` artifact, including failed attempts.

The fixture compiles actual production helper/admin/save/load procedures using
existing startup adapters. It extracts the configured startup activation block
before autoload dispatch, invokes the actual admin toggle, and performs 24 actual
`ticker.loadmap()` imports (12 disk generations, each loaded twice). These cover
1903/1943/2023 and persistence on/off in both v2 durable and v1 positional saves.
V2 checks restore faction data and shared aliases after clearing live progress;
v1 lacks those durable fields, so checks their live preservation while restoring
the available date/tier/default-research header. The v1 fixture is a Gaia child
outside the existing durable-profile allowlist; production admission is intact.
Every case checks unchanged saved header/metadata/marker bytes and released load
ownership. Earlier/equal/later dates, BC epochs, repeated activation, independently
advanced tiers and unrelated modes also execute natively.

The world rejects clients, Topic and port reopen, disables visibility and uses
the existing runner's native-port and OS zero-listener census handshake. Maps,
SQL, normal world/global startup and external hooks remain disabled. This is an
8x8x2 inert-turf fixture, not a live map, fresh-process recovery, or connected
client acceptance. Local `--prepare-only --persistence-year` stages packets with
no native execution; the offline packet test checks all three mutation anchors.

An isolated connected-client Persistence interaction remains separate graphical
verification. Reproduce by enabling
Persistence at `1903`, `1943`, then `2023`: expect `1943`, `1943`, `2023`.
Disable/re-enable each time and repeat with fresh configured startup and isolated
legacy/current-format saves, checking tier/flags and faction research too.
