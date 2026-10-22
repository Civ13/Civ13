"""Prepare generated observers against explicit Git inputs; never run a game."""
import hashlib
import json
from pathlib import Path
import subprocess

REFERENCE = '9db2b2f42a5fbbb0bdd49d50a2672da6111a7709'
CANDIDATE = '069f88d0790bfc8772f7bee8b7b121569ef4a09f'
HELPERS = 'c345c9b3ede9d437af39e1a9b2dce62dc23e6b16'
MAP = 'maps/nomads/nomads_europe.dmm'
PRODUCTION = ('code/modules/persistence/saving.dm', 'code/modules/persistence/functions.dm',
              'code/modules/persistence/loading.dm', 'code/modules/persistence/restart_transaction.dm')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def git_source(repository, commit, path):
    return subprocess.check_output(['git', '-C', str(repository), 'show', commit + ':' + path], timeout=30)


def once(text, anchor, replacement):
    if text.count(anchor) != 1:
        raise ValueError('Unsupported source anchor: ' + repr(anchor))
    return text.replace(anchor, replacement, 1)


def text(data):
    return data.decode('utf-8-sig').replace('\r\n', '\n')


def prepare(repository, commit, output, reader=git_source):
    """Write an overlay packet only; exported game files remain immutable inputs.

    This intentionally does not export, compile, configure or launch a host.
    A separately reviewed executor must apply these hash-bound includes to its
    exact Git archive, sanitize public configuration and verify all owned effects.
    """
    if commit not in (REFERENCE, CANDIDATE):
        raise ValueError('Only the frozen comparison commits are admitted')
    output = Path(output)
    if not output.is_absolute() or output.exists():
        raise ValueError('Use a new absolute packet directory; preserve prior evidence')
    required = ('civ13.dme', 'code/world.dm', 'code/game/gameticker.dm',
                'code/modules/1713/roundstart_etc.dm', MAP, *PRODUCTION)
    raw = {name: reader(repository, commit, name) for name in required}
    helper_path = 'tests/world_save/full_map_lifecycle/'
    helpers = {name: reader(repository, HELPERS, helper_path + name)
               for name in ('prepare.py', 'control.dm', 'query.py', 'run.py')}
    # Reuse the exact existing pure observer builders, without importing run.py
    # or query.py (whose module imports would bind their historical BASE).
    namespace = {'__name__': 'frozen_full_map_prepare'}
    exec(compile(helpers['prepare.py'], helper_path + 'prepare.py', 'exec'), namespace)
    world = namespace['instrument_world'](text(raw['code/world.dm']))
    generated = {'world.dm': world}
    for original, name in (('code/game/gameticker.dm', 'gameticker.dm'),
                           ('code/modules/1713/roundstart_etc.dm', 'roundstart_etc.dm')):
        generated[name] = namespace['instrument_lifecycle'](original, text(raw[original]))
    # Reboot is deliberately not changed or invoked: fresh readers need a new
    # process and copied production current_identity(), not a simulated reboot.
    control = text(helpers['control.dm'])
    control = once(control,
                   'return full_map_probe_setup_done && full_map_probe_nature_done.len == 4 && ticker',
                   'return ((full_map_probe_setup_done && full_map_probe_nature_done.len == 4) || (map_storage.round_restored && persistence_restart.import_complete)) && ticker')
    control = once(control, '/proc/full_map_probe_status()\n',
                   '/proc/representative_base_status()\n')
    action_anchor = '\tif(input["action"] == "start")\n'
    control = once(control, action_anchor,
                   '\tif(input["action"] == "first" || input["action"] == "second" || input["action"] == "census")\n'
                   '\t\treturn representative_save_action(input["action"])\n' + action_anchor)
    generated['control.dm'] = control
    adapter = Path(__file__).with_name('probe.dm').read_bytes()
    environment = text(raw['civ13.dme'])
    environment = once(environment, '#include "maps\\nomads\\nomads.dmm"',
                       '#include "maps\\nomads\\nomads_europe.dmm"')
    for original, generated_name in (('code/world.dm', 'world.dm'),
                                     ('code/game/gameticker.dm', 'gameticker.dm'),
                                     ('code/modules/1713/roundstart_etc.dm', 'roundstart_etc.dm')):
        include = '#include "' + original.replace('/', '\\') + '"'
        environment = once(environment, include, '#include "representative/' + generated_name + '"')
    environment += '\n#include "representative/control.dm"\n#include "representative/probe.dm"\n'
    generated['representative.dme'] = environment
    inputs = {name: sha(data) for name, data in raw.items()}
    manifest = {'schema': 1, 'commit': commit, 'map': MAP, 'source_sha256': inputs,
                'helper_commit': HELPERS,
                'helper_sha256': {name: sha(data) for name, data in helpers.items()},
                'generated_sha256': {name: sha(value.encode()) for name, value in generated.items()},
                'adapter_sha256': sha(adapter), 'entrypoint': 'representative.dme',
                'execution_ready': False,
                'unsupported': ['Native executor requires separate current resource allocation; none is granted by preparation.',
                                'Generated DM has not been compiled or executed; actual runtime phase receipts remain absent.',
                                'Runtime, memory, storage and listener allocation remains ungranted.'],
                'production_serializer_modified': False}
    # Validate all anchors before allocating anything, then never reuse output.
    output.mkdir(parents=True, exist_ok=False)
    for name, value in generated.items():
        (output / name).write_text(value, encoding='utf-8', newline='\n')
    (output / 'probe.dm').write_bytes(adapter)
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    return manifest
