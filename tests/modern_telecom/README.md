# Modern educational schedule regression

Run `./tests/modern_telecom/run.ps1 -ByondBin <pinned-bin>` on Windows or
`python3 tests/modern_telecom/run.py --byond-bin <pinned-bin>` anywhere; both
check the compiler against `tools/byond/version.json`.
The runner compiles production sources without ordinary startup or maps, rejects
listening ports, and uses unique temporary save storage. Only the clock in a
generated source copy is replaced for deterministic schedule boundaries. A test
actor supplies an online-state adapter and native species/reagent containers;
award logic, stats and whole-world persistence execute production code.

Checks cover 1903 radio versus Modern TV/build gating, live presenter identity,
range, power, antenna, deaf audience, rate and 32-listener limits, station
identity save restoration and transient session exclusion, as well as, cycling-season eligibility, fixed/no-cycle evergreen
compatibility, starts/ends/reruns, exact native reward range, cap, offline and
reconnect rejection, durable lesson credits and save restoration. These checks
also cover real powered receiver delivery, frequency filtering, phone calls and
power-loss teardown over electricity cables, and local terminal delivery/rate
limits, and the cross-region long-range radio relay (keying, power, wear,
garbling, the outbound window, arrivals heard through a tuned handset, every
drop rule and the saved key and condition), and saved landline numbers that
restore in a different construction order (#4222). They do not establish recipe
reachability or graphical acceptance.
