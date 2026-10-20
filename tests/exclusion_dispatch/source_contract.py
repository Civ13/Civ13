"""Fail-closed source contract; no compiler or runtime execution."""
import re


# Reviewed bounded-save integration adds only these non-hook blocks to the
# pinned 5bf351 baseline. Keep complete-file equality after this projection;
# deriving a baseline from candidate source would hide unrelated changes.
BOUNDED_BLOCKS = (
    ('\t\tlist/saving_export_stack = list()\n',
     '\t\tlist/saving_content_owners = list()\n\t\tlist/saving_world_movables = list()\n\t\tvar/saving_work = 0\n\t\tvar/saving_slice_start = 0\n'),
    ('\tsaving_export_stack = list()\n',
     '\tsaving_content_owners = list()\n\tsaving_world_movables = list()\n\tsaving_work = 0\n\tsaving_slice_start = world.tick_usage\n'),
    ('/map_storage/proc/add_export_content(datum/save_export_frame/frame, ref)\n\tif(!ref) return\n\tvar/key = "[ref]"\n',
     '\t// Keep the first captured edge if a completed child later moves.\n\tvar/owner = saving_content_owners[key]\n\tif(owner && owner != frame.entry) return\n\tsaving_content_owners[key] = frame.entry\n'),
)

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


def project_bounded_save(baseline):
    for anchor, addition in BOUNDED_BLOCKS:
        # Match complete lines: the reset anchor must not match declarations.
        pattern = re.compile(r'^' + re.escape(anchor), re.M)
        if len(list(pattern.finditer(baseline))) != 1:
            raise ValueError('Expected exactly one bounded-save baseline anchor')
        baseline = pattern.sub(lambda match: match[0] + addition, baseline, count=1)
    return baseline


def transform(baseline):
    expected = project_bounded_save(baseline)
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
        raise ValueError('Only the three approved hook transformations may differ')
