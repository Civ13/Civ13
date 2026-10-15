"""Stage immutable current-head Gaia recovery inputs; no processes are launched."""
import argparse
import hashlib
import json
from pathlib import Path
import secrets
import shutil
import subprocess
import zipfile

BASE = '02993f52411a94c5f0c7cfedf801bef99def7059'
EXPECTED = {
    '1.sav': '31010a8982985fa9e25147a0bb4a7c80f142d268b39354ca09d35510f3d9e6b6',
    '2.sav': 'e472d7ffe4dd1185a01384bcefd5f776740eaf1a017e09e0805ca2c74345f490',
    'map.txt': '623ad9986ed79daecc2aeb3cceb20586fdf2756cb5585dad14a56727a3b6fcf2',
    'round.json': '71f1dc422166bc6346a93816958bf754ef794212d0c5f22fd6e089ec5355a2ef',
    'save_complete.txt': '7d224a6cefb58e12778d0b1116c5154a89087bcc71c7dab1a5174c34307c42a6',
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_originals(original):
    actual = {name: digest(original / name) for name in EXPECTED}
    if actual != EXPECTED:
        raise ValueError('Historical save hashes differ; originals must remain untouched')
    return actual


def instrument_world(source):
    topic = '/world/Topic(T, addr, master, key)\n'
    startup = '/world/New()\n\tmap_storage.record_compiled_dimensions()\n'
    if source.count(topic) != 1 or source.count(startup) != 1:
        raise ValueError('Expected unique production startup/Topic anchors')
    source = source.replace(topic, topic + '\tif("gaia_probe" in params2list(T))\n\t\treturn gaia_probe_topic(T, addr)\n', 1)
    return source.replace(startup, '/world/New()\n\tgaia_probe_seed_entry()\n\tmap_storage.record_compiled_dimensions()\n' + '\tif(world.params["gaia_intent_seed"] == "1")\n\t\tspawn(0) gaia_probe_seed_intent()\n\t\treturn\n', 1)


def prepare(repository, original, output):
    verified = verify_originals(original)
    output.mkdir(parents=True, exist_ok=False)
    archive = output / 'source.zip'
    subprocess.run(['git', '-C', str(repository), 'archive', '--format=zip', f'--output={archive}', BASE], check=True)
    game = output / 'game'
    with zipfile.ZipFile(archive) as exported:
        exported.extractall(game)
    saves = game / 'map_saves'
    saves.mkdir(exist_ok=False)
    for name in EXPECTED:
        shutil.copyfile(original / name, saves / name)
    if verify_originals(saves) != verified or verify_originals(original) != verified:
        raise ValueError('Derived copy or source changed during preparation')
    world = game / 'code/world.dm'
    original_world = world.read_text(encoding='utf-8')
    world.write_text(instrument_world(original_world), encoding='utf-8', newline='\n')
    shutil.copyfile(Path(__file__).with_name('control.dm'), game / 'gaia-probe.dm')
    dme = (game / 'civ13.dme').read_text(encoding='utf-8')
    anchor = '#include "maps\\nomads\\nomads.dmm"'
    if dme.count(anchor) != 1:
        raise ValueError('Expected unique default map include')
    dme = dme.replace(anchor, '#include "maps\\nomads\\nomads_gaia.dmm"')
    (game / 'playable-gaia.dme').write_text(dme + '\n#include "gaia-probe.dm"\n', encoding='utf-8', newline='\n')
    blocked = {'HUB', 'SERVER', 'ALLOW_WEBCLIENT', 'WEBHOOK_CAN_FIRE', 'WEBHOOK_ADDRESS', 'WEBHOOK_KEY', 'TORBAN', 'IPINTEL_EMAIL'}
    config = game / 'config/config.txt'
    config.write_text('\n'.join(line for line in config.read_text(encoding='utf-8').splitlines()
                              if not line.strip() or line.strip().split()[0].upper() not in blocked) + '\n', encoding='utf-8')
    (game / 'config/host.txt').write_text('ValZarGaming\n', encoding='utf-8')
    (game / 'config/lifecycle-token.txt').write_text(secrets.token_hex(16), encoding='ascii')
    (game / 'config/lifecycle-revision.txt').write_text(BASE, encoding='ascii')
    receipt = {'source_commit': BASE, 'originals': str(original.resolve()), 'sha256': verified,
               'original_world_sha256': hashlib.sha256(original_world.encode()).hexdigest(),
               'instrumented_world_sha256': digest(world), 'adapter_sha256': digest(game / 'gaia-probe.dm'),
               'entrypoint': 'playable-gaia.dme', 'launched': False,
               'limits': ['No native build or seed/recovery/client test performed by preparation',
                          'Original save unchanged; only derived copy may receive a new intent']}
    (output / 'prepare.json').write_text(json.dumps(receipt, indent=2), encoding='utf-8')
    return receipt


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--repository', type=Path, required=True)
    p.add_argument('--original', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    print(json.dumps(prepare(a.repository, a.original, a.output)))

