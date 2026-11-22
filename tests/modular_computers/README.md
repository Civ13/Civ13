# Modular computer regression

Run `python3 tests/modular_computers/run.py --byond-bin <pinned-bin>` on Linux
or Windows; it checks the compiler against `tools/byond/version.json`. The
runner compiles production sources without ordinary startup or maps, rejects
listening ports and uses unique temporary save storage.

Checks cover the Electronic Computing node and recipe gates, lazily built OS
and program definitions, slot limits and the closed case, capabilities from
modules, the Files program (new, save, rename rules, size and capacity caps,
delete), diskette copies both ways, printing to paper, power off, part
removal shutting the computer down, and a native save and reload of the
chassis, its parts, drive files, diskette and printer paper. They do not cover
the window in a real client or graphical acceptance.
