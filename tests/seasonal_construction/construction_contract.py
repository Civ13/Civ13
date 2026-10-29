"""Project only the reviewed construction observer out of legacy debris parity."""

CLOCK = (
    '/obj/map_metadata/proc/record_abandonment_season_change(advance_decay = TRUE)\n'
    '\tif (advance_decay && src == map)\n'
    '\t\tabandonment_season_changes++\n'
)
HOOK = '\trecord_construction_season_change(advance_decay)\n'


def without_construction_hook(source):
    # Require the original debris increment and exactly one unconditional observer.
    # A moved, duplicated, conditional or missing hook must not be normalized away.
    if source.count(HOOK) != 1 or source.count(CLOCK + HOOK) != 1:
        raise ValueError('Construction observer differs from the reviewed clock hook')
    return source.replace(CLOCK + HOOK, CLOCK, 1)
