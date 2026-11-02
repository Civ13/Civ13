"""Conservative source contract for the experimental tile-only restore branch.

This is a source test, not a DM preprocessor or runtime/save validation.
"""
import re


POSITION_WRITE = re.compile(r'\b(?:loc|step_x|step_y|pixel_x|pixel_y)\s*=(?!=)')
DIRECTIVE = re.compile(r'^[ \t]*#\s*(\w+)', re.MULTILINE)
DECLARATION = '/mob/living/human/after_load()\n'
MARKER = '#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL\n'
RESTORE = (
    '\tif(human_subtile_transaction || human_subtile_pulse) throw EXCEPTION("Restored human has active movement ownership")\n'
    '\tstep_x = 0\n'
    '\tstep_y = 0\n'
    '\thuman_subtile_position = null\n'
    '\thuman_subtile_restore_schema = 0\n'
    '\thuman_direct_preflight_position = null\n'
    '\thuman_subtile_offset_owned = FALSE\n'
    '\thuman_subtile_import_owned = FALSE\n'
)


def uncomment(source):
    """Remove DM comments without treating quoted comment markers as comments."""
    out = []
    i = 0
    quote = None
    depth = 0
    while i < len(source):
        ch = source[i]
        pair = source[i:i + 2]
        if depth:
            if pair == '/*':
                depth += 1
                out.extend('  ')
                i += 2
            elif pair == '*/':
                depth -= 1
                out.extend('  ')
                i += 2
            else:
                out.append('\n' if ch == '\n' else ' ')
                i += 1
        elif quote:
            out.append(ch)
            i += 1
            if ch == '\\' and i < len(source):
                out.append(source[i])
                i += 1
            elif ch == quote:
                quote = None
        elif pair == '//':
            end = source.find('\n', i)
            end = len(source) if end < 0 else end
            out.extend(' ' * (end - i))
            i = end
        elif pair == '/*':
            depth = 1
            out.extend('  ')
            i += 2
        else:
            out.append(ch)
            i += 1
            if ch in ('"', "'"):
                quote = ch
    if depth or quote:
        raise AssertionError('unterminated source comment or quote')
    return ''.join(out)


def validate_tile_restore(source):
    code = uncomment(source)
    if code.count(DECLARATION) != 1:
        raise AssertionError('ambiguous restore declaration')
    before, tail = code.split(DECLARATION, 1)
    # No unknown outer conditional may make the declaration disappear.
    stack = []
    for directive in DIRECTIVE.findall(before):
        if directive in ('if', 'ifdef', 'ifndef'):
            stack.append(directive)
        elif directive in ('else', 'elif'):
            if not stack:
                raise AssertionError('unbalanced preprocessor branch')
        elif directive == 'endif':
            if not stack:
                raise AssertionError('unbalanced preprocessor end')
            stack.pop()
    if stack:
        raise AssertionError('restore declaration is conditionally hidden')
    if tail.count(MARKER) != 1:
        raise AssertionError('missing experimental guard')
    pre, rest = tail.split(MARKER, 1)
    if '#else\n' not in rest:
        raise AssertionError('missing alternative branch')
    experiment, post = rest.split('#else\n', 1)
    if DIRECTIVE.search(pre) or DIRECTIVE.search(experiment):
        raise AssertionError('unexpected conditional around tile restore')
    if experiment.count(RESTORE) != 1:
        raise AssertionError('guarded reset or ownership cleanup missing')
    if POSITION_WRITE.search(before + pre + experiment.replace(RESTORE, '', 1) + post):
        raise AssertionError('unexpected direct position assignment')
