"""Fail-closed source contract; no compiler or runtime execution."""
import re


AREA_POLICY = ('// Author policy is not restored from an ordinary or historical area payload.\n'
               '/area/persistence_runtime_var(key)\n'
               '\treturn key == "lighting_reserved_clearance_enabled" || ..()\n\n')


def reconstruct_list_baseline(master):
    """Reverse only the three reviewed switch hooks in pinned current master."""
    for kind in ('atom', 'turf', 'mob'):
        pattern = rf'^/{kind}/persistence_runtime_var\(key\)\n(?P<prefix>(?:\t[^\n]*\n)*?)\tswitch\(key\)\n\t\tif \(([^\n]+)\)\n\t\t\treturn TRUE\n\treturn \.\.\(\)'
        matches = list(re.finditer(pattern, master, re.M))
        if len(matches) != 1:
            raise ValueError(f'Expected exactly one pinned master {kind} switch hook')
        match = matches[0]
        replacement = f'/{kind}/persistence_runtime_var(key)\n{match["prefix"]}\treturn (key in list({match[2]})) || ..()'
        master = master[:match.start()] + replacement + master[match.end():]
    return master


def project_reserved_policy(baseline):
    """Apply only this PR's declared policy to the historical list baseline."""
    anchor = '\treturn (key in list("affecting_lights", "lighting_overlay"'
    insertion = '// HUD objects belong to a client session and are rebuilt by the normal HUD path.'
    if baseline.count(anchor) != 1 or baseline.count(insertion) != 1:
        raise ValueError('Historical reserved-policy projection anchors drifted')
    if '"lighting_reserved"' in baseline or '/area/persistence_runtime_var(key)' in baseline:
        raise ValueError('Historical baseline already contains reserved policy')
    return baseline.replace(anchor, '\treturn (key in list("lighting_reserved", "affecting_lights", "lighting_overlay"', 1).replace(insertion, AREA_POLICY + insertion, 1)


def transform(baseline):
    expected = project_reserved_policy(baseline)
    for kind in ('atom', 'turf', 'mob'):
        pattern = rf'^/{kind}/persistence_runtime_var\(key\)\n(?P<prefix>(?:\t[^\n]*\n)*?)\treturn \(key in list\((.*?)\)\) \|\| \.\.\(\)'
        matches = list(re.finditer(pattern, expected, re.M))
        if len(matches) != 1:
            raise ValueError(f'Expected exactly one baseline {kind} hook')
        match = matches[0]
        replacement = f'/{kind}/persistence_runtime_var(key)\n{match["prefix"]}\tswitch(key)\n\t\tif ({match[2]})\n\t\t\treturn TRUE\n\treturn ..()'
        expected = expected[:match.start()] + replacement + expected[match.end():]
    return expected


def validate(baseline, candidate):
    if transform(baseline) != candidate:
        raise ValueError('Only approved dispatch and reserved-policy projections may differ')
