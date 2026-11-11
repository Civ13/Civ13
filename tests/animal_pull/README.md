# Animal pull probe

Native probe for pulling animals with free movement. Wildlife stands at pixel
offsets it owns, and the pull rope claims the offset after every slide, so
`/atom/movable/Move` refused every rope slide of an owned-offset animal and the
hold broke ("You lose your hold on the lion.", live Gaia 2026-11-11). A pulled
animal now stays draggable, matching pulled human bodies.

    python3 tests/ecology_spawning/run_linux.py . tests/animal_pull/probe.dm 300
