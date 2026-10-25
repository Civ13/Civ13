"""Restricted production-DM projection, with explicit list and IO adapters.

This executes the selected source statements, not native BYOND semantics.
Unknown statements fail preparation. No compiler, daemon or network is used.
"""
import hashlib
import json
import math
from pathlib import Path
import re
from types import SimpleNamespace as NS

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/persistence/functions.dm'


class L:
    def __init__(self, values=()):
        self.assoc = dict(values) if isinstance(values, dict) else {}
        self.values = list(values)

    @property
    def len(self):
        return len(self.values)

    def __iter__(self):
        return iter(self.values)

    def __contains__(self, key):
        return key in self.values

    def __getitem__(self, key):
        if isinstance(key, (int, float)):
            return self.values[int(key) - 1]
        return self.assoc.get(key)

    def __setitem__(self, key, value):
        if key not in self.values:
            self.values.append(key)
        self.assoc[key] = value

    def __iadd__(self, other):
        self.values.extend(other.values)
        return self

    def Copy(self):
        result = L(self.values)
        result.assoc = self.assoc.copy()
        return result


def packed(value):
    if isinstance(value, L):
        return {k: packed(value[k]) for k in value} if value.assoc else [packed(v) for v in value]
    return value


def unpacked(value):
    if isinstance(value, dict):
        return L({k: unpacked(v) for k, v in value.items()})
    if isinstance(value, list):
        return L([unpacked(v) for v in value])
    return value


def body(source, signature):
    match = re.search(r'^' + re.escape(signature) + r'\n(.*?)(?=^/|\Z)', source, re.M | re.S)
    if not match:
        raise ValueError('Missing production proc: ' + signature)
    return match[1]


def expression(text):
    # Only the ternaries present in the selected production procs are supported.
    for dm, py in {
        'isnull(elevation_regions) ? list() : elevation_regions': '(list() if isnull(elevation_regions) else elevation_regions)',
        'version == 2 ? 12 : 11': '(12 if version == 2 else 11)',
        'copytext(marker, 1, 10) == "round-v2:" ? 2 : 1': '(2 if copytext(marker, 1, 10) == "round-v2:" else 1)',
        'ticker ? ticker.current_state : GAME_STATE_PREGAME': '(ticker.current_state if ticker else GAME_STATE_PREGAME)',
        'phase == GAME_STATE_PREGAME ? 0 : elapsed': '(0 if phase == GAME_STATE_PREGAME else elapsed)',
        'phase == GAME_STATE_PREGAME ? 0 : roundstart_time': '(0 if phase == GAME_STATE_PREGAME else roundstart_time)',
        '(round_start_time || round_elapsed_offset) ? max(0, world.time - round_start_time) + round_elapsed_offset : 0': '(max(0, world.time - round_start_time) + round_elapsed_offset if (round_start_time or round_elapsed_offset) else 0)',
    }.items():
        text = text.replace(dm, py)
    if '?' in text:
        raise ValueError('Unknown ternary: ' + text)
    # These calls contain no nested list expressions; preserve argument grouping.
    while re.search(r'\blist\(', text):
        start = re.search(r'\blist\(', text).start()
        depth, end = 1, start + 5
        while depth:
            depth += (text[end] == '(') - (text[end] == ')')
            end += 1
        args = text[start + 5:end - 1]
        if re.search(r'"\w+" = ', args):
            args = re.sub(r'("\w+") = ', r'\1: ', args)
            replacement = 'L({' + args + '})'
        else:
            replacement = 'L([' + args + '])'
        text = text[:start] + replacement + text[end:]
    text = text.replace('&&', ' and ').replace('||', ' or ')
    text = re.sub(r'!(?!=)', 'not ', text)
    text = text.replace('global.game_id', 'globals_state.game_id')
    return text


def compile_proc(source, signature, env, fields=()):
    args = signature[signature.index('(') + 1:-1]
    args = ', '.join(a.strip().split('/')[-1] for a in args.split(',') if a.strip())
    lines = ['def projected(self' + (', ' + args if args else '') + '):']
    for raw in body(source, signature).splitlines():
        text = raw.split('//', 1)[0].rstrip()
        if not text.strip():
            continue
        indent = len(text) - len(text.lstrip('\t'))
        text = text.strip()
        declaration = re.fullmatch(r'var/(?:\w+/)*(\w+)(?: = (.*))?', text)
        if declaration:
            text = declaration[1] + ' = ' + (declaration[2] or 'None')
            if text.endswith(' = new'):
                text = text[:-3] + 'Profile()'
        elif text.startswith('if('):
            # The only inline bodies in this subset are a return or a throw.
            depth, end = 1, 3
            while depth:
                depth += (text[end] == '(') - (text[end] == ')')
                end += 1
            condition, tail = text[3:end-1], text[end:].strip()
            if tail and not tail.startswith('return '):
                raise ValueError('Unknown if statement: ' + text)
            text = 'if ' + expression(condition) + ':' + (' ' + expression(tail) if tail else '')
        elif text.startswith('for('):
            match = re.fullmatch(r'for\(var/(?:\w+/)*(\w+) in (.*)\)', text)
            if not match:
                raise ValueError('Unknown loop: ' + text)
            text = 'for ' + match[1] + ' in ' + expression(match[2]) + ':'
        elif text == 'else':
            text = 'else:'
        elif text.startswith('throw EXCEPTION('):
            text = 'raise ValueError' + text[len('throw EXCEPTION'):]
        elif not (text.startswith('return ') or re.match(r'[\w.]+ (?:=|\+=) ', text)
                  or re.fullmatch(r'elevation_profile_from_snapshot\(.*\)', text)):
            raise ValueError('Unknown production statement: ' + text)
        text = expression(text)
        for field in fields:
            text = re.sub(r'(?<![\w.])' + field + r'\b', 'self.' + field, text)
        lines.append('    ' * indent + text)
    exec('\n'.join(lines), env)
    return env['projected']


def load(source=None, dimensions=(8, 6, 2), filesystem=None):
    source = SOURCE.read_text() if source is None else source
    env = dict(L=L, NS=NS, TRUE=True, FALSE=False, null=None,
               isnum=lambda v: isinstance(v, (int, float)), islist=lambda v: isinstance(v, L),
               isnull=lambda v: v is None, istext=lambda v: isinstance(v, str),
               round=math.floor, length=len, max=max,
               world=NS(maxx=dimensions[0], maxy=dimensions[1], maxz=dimensions[2], time=100),
               globals_state=NS(game_id='elevation-fixture'),
               ticker=NS(current_state=1), GAME_STATE_PREGAME=1, GAME_STATE_PLAYING=2,
               GAME_STATE_FINISHED=3, GAME_STATE_SETTING_UP=4,
               round_start_time=0, round_elapsed_offset=0, roundstart_time=0)
    class Profile:
        def __init__(self):
            self.default_metres, self.regions = 0, L()
    env['Profile'] = Profile
    for name, args in (
        ('elevation_metres_valid', 'value'), ('elevation_coordinate_valid', 'value, limit'),
        ('build_elevation_profile', 'default_metres, list/source_regions, maxx, maxy, maxz'),
        ('elevation_profile_from_snapshot', 'list/snapshot, maxx, maxy, maxz'),
    ):
        fn = compile_proc(source, '/proc/' + name + '(' + args + ')', env)
        env[name] = lambda *args, fn=fn: fn(None, *args)
    Profile.at = compile_proc(source, '/datum/elevation_profile/proc/at(x, y, z)', env,
                             fields=('regions', 'default_metres'))
    class Map:
        def __init__(self, default=0, regions=None):
            self.elevation_default_metres, self.elevation_regions = default, regions
            self.elevation_profile_cache = None
    for name, args in (
        ('effective_elevation_profile', ''), ('elevation_snapshot', ''),
        ('restore_elevation_snapshot', 'list/round_state, maxx, maxy, maxz'),
    ):
        setattr(Map, name, compile_proc(source, '/obj/map_metadata/proc/' + name + '(' + args + ')', env,
                    fields=('elevation_default_metres', 'elevation_regions', 'elevation_profile_cache', 'effective_elevation_profile')))
    env['Map'] = Map
    def get_turf(value):
        while value is not None and not getattr(value, 'is_turf', False):
            value = getattr(value, 'loc', None)
        return value
    env['get_turf'], env['map'] = get_turf, Map()
    env['get_elevation'] = compile_proc(source, '/proc/get_elevation(atom/location)', env)
    env['capture'] = compile_proc(source, '/map_storage/proc/capture_round_state(generation)', env)
    if filesystem:
        env.update(file2text=lambda name: (filesystem / name).read_text(),
                   fexists=lambda name: (filesystem / name).is_file(), trim=str.strip,
                   copytext=lambda value, start, end: value[start-1:end-1],
                   md5=lambda value: hashlib.md5(value.encode()).hexdigest(),
                   json_decode=lambda value: unpacked(json.loads(value)))
        env['read'] = compile_proc(source, '/map_storage/proc/read_round_state()', env,
                                   fields=('save_validation_maxz',))
    return env
