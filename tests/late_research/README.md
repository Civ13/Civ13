# Late research on book-research worlds

Offline: `python3 -m unittest discover -s tests/late_research -v` checks the
source wiring: every standing node effect names a registered node, needs book
research and personal knowledge, is called from its system and is shown in
both research windows; every field work experiment names a late node and a
counted activity, a book takes each experiment once and the bench credits it
before looking for a scholar; big science slows a lone scholar without stopping
them, and rushing is off by default, late only and wired to its button; ciphers bind only
on book-research worlds and every way of taking research out of a book asks
them first.

Native: `python3 tests/late_research/run.py --byond-bin <pinned BYOND bin> --trusted`
only with authorization for the isolated native runtime (`--compile-only` does
not launch DreamDaemon). The fixture compiles the complete production source in
a temporary world with no listening port, maps or saves, replaces only client
presence, light and action waits, and runs the production procs.

None of this is in-game, client or graphical acceptance.
