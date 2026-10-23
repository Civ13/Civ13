"""Offline execution of a small audited DM subset, with fake engine boundaries.

This is source control-flow evidence, not DM compilation or engine acceptance.
Every executable line in an extracted procedure is translated; unsupported
syntax fails Python compilation. No native executables or game are launched.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')


def extract(source, declaration):
    matches = list(re.finditer(r'^(\t*)' + re.escape(declaration) + r'\([^\n]*\)[ \t]*(?://[^\n]*)?\n', source, re.M))
    if len(matches) != 1:
        raise AssertionError(f'Expected exactly one {declaration}')
    match = matches[0]
    base = len(match[1])
    result = []
    for line in source[match.end():].splitlines():
        stripped = line.strip()
        depth = len(line) - len(line.lstrip('\t'))
        if stripped.startswith('//'):
            continue
        if stripped and not stripped.startswith('//') and depth <= base:
            break
        result.append(line[base:])
    return '\n'.join(result)


FIELDS = ('loc', 'sleeping', 'facing_dir', 'stat', 'lastx', 'lasty', 'lastz',
          'inducedSSD', 'buckled', 'storage', 'kind', 'backend_started',
          'contents_started', 'mutation_started', 'restoring_players',
          'current', 'enter_backend', 'enter_contents', 'finish',
          'contents', 'stomach_contents', 'pulledby', 'position', 'icon_state', 'none_state', 'next_activation',
          'l_hand', 'r_hand', 'equipped', 'update_inv_l_hand', 'update_inv_r_hand', 'equip_to_slot',
          'in_protected_sleep_zone', 'release_protected_sleep_buckle',
          'drop_item', 'forceMove', 'sleep_update', 'persistence_set_loc',
          'save_world_contents', 'load_world_contents', 'cleanup_world_operation',
          'clear_bookkeeping', 'release_durable_world', 'movement_location', 'stopped', 'stopped_until')


def project(source, declaration, args, env, method=False):
    """Project complete selected bodies; only engine effects are supplied by tests."""
    lines = ['def projected(' + args + '):', '    global persistence_active_operation, persistence_save_in_progress, persistence_load_recovery_required']
    for raw in extract(source, declaration).splitlines():
        code = raw.split('//', 1)[0].rstrip()
        if not code.strip():
            continue
        indent = len(code) - len(code.lstrip('\t'))
        code = code.strip()
        # DM article macros are opaque message text at the fake output boundary.
        code = code.replace('\\The', '\\\\The').replace('\\the', '\\\\the')
        typed_loop = re.fullmatch(r'for\s*\(var/([\w/]+)/(\w+) in (.*)\)', code)
        if typed_loop:
            code = f'for ({typed_loop[2]} in typed_iter({typed_loop[3]}, "/{typed_loop[1]}"))'
        code = re.sub(r'\bvar/(?:\w+/)*(\w+)\b', r'\1', code)
        code = code.replace('/area/caribbean/admin', 'ADMIN_AREA')
        code = code.replace('in_protected_sleep_zone() ? 2 : 0', '(2 if in_protected_sleep_zone() else 0)')
        code = code.replace('&&', ' and ').replace('||', ' or ')
        code = re.sub(r'!(?!=)', 'not ', code)
        code = re.sub(r'\bTRUE\b', 'True', code)
        code = re.sub(r'\bFALSE\b', 'False', code)
        code = re.sub(r'\bnull\b', 'None', code)
        code = re.sub(r'= new$', '= new_operation()', code)
        code = re.sub(r'^\. = ', 'result = ', code)
        code = re.sub(r'^([\w.]+)\+\+$', r'\1 += 1', code)
        code = re.sub(r'^([\w.]+)--$', r'\1 -= 1', code)
        code = code.replace('return .', 'return result')
        if method:
            # Never rewrite a string literal or an already qualified member.
            pieces = re.split(r'("(?:[^"\\]|\\.)*")', code)
            for i in range(0, len(pieces), 2):
                parameters = {arg.strip().split('=')[0] for arg in args.split(',')}
                for name in set(FIELDS) - parameters:
                    pieces[i] = re.sub(r'(?<![\w.])' + name + r'\b', 'src.' + name, pieces[i])
            code = ''.join(pieces)
        if re.match(r'^set (name|category|desc|hidden) = ', code):
            code = 'pass'  # compile-time verb metadata, not an executable action
        elif code.startswith('spawn('):
            code = 'if deferred' + code[5:] + ':'  # injected timer callback boundary
        elif code == 'try':
            code = 'try:'
        elif code.startswith('catch('):
            code = 'except Exception as ' + code[6:-1] + ':'
        elif code.startswith('throw '):
            code = 'raise ' + code[6:]
        elif code.startswith('else if'):
            code = 'elif ' + code[len('else if'):].strip() + ':'
        elif code == 'else':
            code = 'else:'
        elif code.startswith('else '):
            code = 'else: ' + code[5:]
        elif code.startswith('if'):
            opening = code.index('(')
            depth = 1
            closing = opening
            while depth:
                closing += 1
                depth += (code[closing] == '(') - (code[closing] == ')')
            code = 'if ' + code[opening + 1:closing] + ':' + code[closing + 1:]
        elif code.startswith('for ') or code.startswith('for('):
            code = code[3:].strip()
            if not (code.startswith('(') and code.endswith(')')):
                raise AssertionError('Unsupported loop: ' + code)
            code = 'for ' + code[1:-1] + ':'
        lines.append('    ' * indent + code)
    translated = '\n'.join(lines) + '\n'
    exec(compile(translated, declaration, 'exec'), env)
    return env['projected']
