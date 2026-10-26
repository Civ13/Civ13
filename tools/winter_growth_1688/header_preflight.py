"""Bounded, source-only prerequisite check for this fixed Linux round-v1 fixture.

This does NOT open 1.sav, validate native references/level generation, restore a
world, or replace production validate_world_save/read_round_state. A pass is
header consistency only. Never use it to validate missing historical bytes.
"""
import hashlib
import json
import math
import os
import re
import stat

LIMITS = {'round.json': 65536, 'map.txt': 8192, 'save_complete.txt': 128}
KEYS = {'version','generation','map','maxx','maxy','maxz','game_id','state',
        'elapsed','roundstart_time','elevation','metadata'}
DIMS = {'maxx':10,'maxy':8,'maxz':1}


def require(ok, reason):
    if not ok:
        raise ValueError(reason)


def strict_json(text):
    def pairs(rows):
        out = {}
        for k,v in rows:
            require(k not in out, 'duplicate JSON key: '+k)
            out[k] = v
        return out
    def constant(value):
        raise ValueError('nonfinite JSON constant: '+value)
    try:
        return json.loads(text, object_pairs_hook=pairs, parse_constant=constant)
    except (RecursionError, UnicodeError) as exc:
        raise ValueError('invalid bounded JSON') from exc


def numeric(v, lo, hi):
    return type(v) in (int,float) and math.isfinite(v) and lo <= v <= hi


def validate_header_bytes(headers):
    """Pure validation of three exact byte strings; stricter than legacy reader."""
    require(type(headers) is dict and set(headers)==set(LIMITS), 'header inventory')
    texts = {}
    for name,limit in LIMITS.items():
        raw = headers[name]
        require(type(raw) is bytes and 0 < len(raw) <= limit, 'header size: '+name)
        try:
            texts[name] = raw.decode('utf-8')
        except UnicodeError as exc:
            raise ValueError('header UTF-8: '+name) from exc
        require('\x00' not in texts[name] and '\r' not in texts[name], 'non-Linux header text: '+name)
    marker = texts['save_complete.txt'].strip(' \t\n')
    require(re.fullmatch(r'round-v1:[0-9a-f]{32}', marker) is not None, 'round-v1 generation marker')
    meta = texts['map.txt'].split('\n')
    if meta[-1]=='': meta.pop()
    require(len(meta)==14 and meta[0]=='NOMADS_PANGEA', 'current map metadata shape/map')
    require(all(v in ('0','1') for v in meta[10:14]), 'round-mode flags')
    state = strict_json(texts['round.json'])
    require(type(state) is dict and set(state)==KEYS, 'current round-v1 schema')
    require(type(state['version']) is int and state['version']==1, 'round version')
    require(state['generation']==marker, 'generation/header relation')
    require(state['map']==meta[0], 'round map relation')
    require(state['metadata']==hashlib.md5(headers['map.txt']).hexdigest(), 'metadata MD5 relation')
    for k,v in DIMS.items():
        require(type(state[k]) is int and state[k]==v, 'fixture dimension: '+k)
    require(type(state['game_id']) is str and 0<len(state['game_id'])<=128, 'saved round identity')
    require(type(state['state']) is int and state['state'] in (1,3,4), 'saved round phase')
    for k in ('elapsed','roundstart_time'):
        require(numeric(state[k],0,1e15), 'saved round clock: '+k)
    require(state['state']!=1 or state['elapsed']==state['roundstart_time']==0, 'pregame active clock')
    e = state['elevation']
    require(type(e) is dict and set(e)=={'version','default_metres','regions',*DIMS}, 'elevation schema')
    require(type(e['version']) is int and e['version']==1, 'elevation version')
    for k,v in DIMS.items():
        require(type(e[k]) is int and e[k]==v, 'elevation dimension: '+k)
    # Fixed inert fixture, not a general production elevation validator.
    require(numeric(e['default_metres'],0,0) and e['regions']==[], 'fixture flat elevation')
    return {'status':'header-prerequisites-passed', 'scope':'fixed round-v1 text headers only; native level validation remains required',
            'round_state':state, 'headers':texts,
            'header_files':{'map_saves/'+n:{'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()} for n,b in headers.items()}}


def validate_saved_headers(source_dir, *, expected_files=None):
    """Read fixed regular files without following final dir/file symlinks.

Caller owns source_dir and its ancestor directories and must keep them quiescent.
If supplied, expected_files is the supervisor's authoritative writer inventory;
all three actual header bytes must match. Other restart entries are not read.
"""
    flags = os.O_RDONLY | os.O_NOFOLLOW
    root = os.open(source_dir, flags | os.O_DIRECTORY)
    try:
        directory = os.open('map_saves', flags | os.O_DIRECTORY, dir_fd=root)
        try:
            headers = {}
            for name,limit in LIMITS.items():
                fd = os.open(name, flags | os.O_NONBLOCK, dir_fd=directory)
                try:
                    before = os.fstat(fd)
                    require(stat.S_ISREG(before.st_mode) and 0 < before.st_size <= limit, 'regular bounded header: '+name)
                    with os.fdopen(fd, 'rb', closefd=False) as stream:
                        data = stream.read(limit+1)
                    after = os.fstat(fd)
                    require((before.st_dev,before.st_ino,before.st_size,before.st_mtime_ns,before.st_ctime_ns)==
                            (after.st_dev,after.st_ino,after.st_size,after.st_mtime_ns,after.st_ctime_ns)
                            and len(data)==before.st_size, 'header changed during read: '+name)
                    headers[name] = data
                finally:
                    os.close(fd)
        finally:
            os.close(directory)
    finally:
        os.close(root)
    result = validate_header_bytes(headers)
    if expected_files is not None:
        require(type(expected_files) is dict, 'external header inventory')
        for name,row in result['header_files'].items():
            require(expected_files.get(name)==row, 'external header hash/size mismatch: '+name)
    return result


def validate_identity_init_source(probe_source):
    """Narrow lexical contract, not a control-flow/native execution proof."""
    setup = probe_source.split('/proc/winter_setup()',1)
    require(len(setup)==2, 'missing winter_setup')
    body = setup[1].split('\n/proc/',1)[0]
    code = '\n'.join(line.split('//',1)[0] for line in body.splitlines())
    require(re.search(r'^\tgenerate_gameid\(\)\s*$',code,re.M) is not None, 'setup must call production generate_gameid directly')
    call = re.search(r'^\tgenerate_gameid\(\)\s*$',code,re.M)
    require('Save_World(' not in code[:call.start()], 'identity initialization must precede save')
    require('global.game_id =' not in code and re.search(r'(?<![\w.])game_id\s*=',code) is None,
            'setup must not replace generated identity')
    return True


def validate_generator_source(world_source):
    """Pin reviewed production generator: clocks and seven fixed base-62 steps,
    no IO, RNG, sleeps or background processes. Source-only evidence."""
    parts = world_source.split('/proc/generate_gameid()\n')
    require(len(parts)==2 and '\nvar/world_is_open' in parts[1], 'generator source boundary')
    body = parts[1].split('\nvar/world_is_open',1)[0]
    require(hashlib.sha256(body.encode()).hexdigest()==
            'bf75dd126229ac57b37d5485b2c8fdaa475dc75ba484dbb7ed1342c686a3535c',
            'reviewed ordinary bounded no-IO generator changed')
    return True
