# Floor drain probe

Native probe for floor drains (`code/modules/1713/floor_drains.dm`).

    python3 tests/ecology_spawning/run_linux.py . tests/floor_drains/probe.dm 300

It checks that a floor drain running nowhere takes nothing. Once it joins an
outfall, a puddle on or beside it runs away and washes blood (not dry dirt)
down, fouling the outfall. A puddle two tiles off stays. Vomit landing on the
drain goes down, but gibs do not. A clogged drain shows it and takes nothing
until cleared. A cesspit also takes it, and off settlement maps it always
drains.
