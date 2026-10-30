"""Exact copied-packet headroom fault injection; never launches native code."""

SCENARIOS = ('headroom-normal', 'headroom-visited', 'headroom-unvisited',
             'headroom-delete', 'headroom-container', 'headroom-cross-z',
             'headroom-parent-replaced', 'headroom-parent-closed', 'headroom-nonprogress')


def instrument_headroom(source):
    start = '/map_storage/proc/capture_moving_save_root(savefile/destination, list/record)\n'
    end = '/map_storage/proc/moving_save_root_edge('
    if source.count(start) != 1 or source.count(end) != 1:
        raise ValueError('Headroom capture boundaries changed')
    before, body = source.split(start)
    body, after = body.split(end)
    checks = '\tif(world.tick_usage >= 80)\n'
    first = '\tif(world.tick_usage >= 80)\n\t\tsleep(world.tick_lag)\n'
    second = '\t\tif(world.tick_usage >= 80)\n\t\t\tthrow EXCEPTION("Moving save capture has no tick headroom after bounded wait")'
    if body.count(checks) != 2 or body.count(first) != 1 or body.count(second) != 1:
        raise ValueError('Headroom threshold/sleep anchors changed')
    if body.count('sleep(world.tick_lag)') != 1 or body.index('sleep(world.tick_lag)') > body.index('var/savefile/staged = new'):
        raise ValueError('Headroom wait must precede stage allocation')
    body = body.replace(first, '\tif(world.tick_usage >= 80 || fixture_force_headroom(A))\n\t\tfixture_headroom_before_wait(A, parent_frame)\n\t\tsleep(world.tick_lag)\n')
    body = body.replace(second, '\t\tif(world.tick_usage >= 80 || fixture_headroom_nonprogress())\n\t\t\tthrow EXCEPTION("Moving save capture has no tick headroom after bounded wait")')
    return before + start + body + end + after
