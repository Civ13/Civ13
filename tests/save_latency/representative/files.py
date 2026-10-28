"""Confined immutable input/output staging, not a native savefile validator."""
import hashlib
import json
from pathlib import Path
import re
import shutil


def unlinked(path):
    path = Path(path).absolute()
    for part in (path, *path.parents):
        if part.is_symlink() or getattr(part, 'is_junction', lambda: False)():
            raise ValueError('Linked staging path refused')
    return path


def file_sha(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def inventory(directory):
    directory = unlinked(directory)
    if not directory.is_dir():
        raise ValueError('Generation directory missing')
    result = {}
    for path in directory.iterdir():
        unlinked(path)
        if not path.is_file() or not (path.name in ('map.txt', 'round.json', 'save_complete.txt')
                                      or re.fullmatch(r'[1-9][0-9]*\.sav', path.name)):
            raise ValueError('Unknown or incomplete generation output')
        result[path.name] = file_sha(path)
    if not {'map.txt', 'round.json', 'save_complete.txt', '1.sav'}.issubset(result):
        raise ValueError('Incomplete generation inventory')
    return result


def freeze_generation(directory, destination, identity):
    """Copy only known files, binding actual current_identity() text and bytes.

    The calling protocol still requires the actual production save/read validation.
    No native .sav contents are interpreted or marked accepted by this function.
    """
    directory, destination = unlinked(directory), unlinked(destination)
    if destination.exists() or destination.is_relative_to(directory):
        raise ValueError('Preserve existing destination')
    before = inventory(directory)
    marker = (directory / 'save_complete.txt').read_text(encoding='utf-8').strip()
    if not isinstance(identity, dict) or marker != identity.get('generation'):
        raise ValueError('Generation marker differs from production receipt')
    for key, name in (('metadata', 'map.txt'), ('round', 'round.json')):
        normalized = (directory / name).read_bytes().replace(b'\r\n', b'\n')
        if hashlib.md5(normalized).hexdigest() != identity.get(key):
            raise ValueError('Generation text differs from production receipt')
    round_state = json.loads((directory / 'round.json').read_text(encoding='utf-8'))
    if not isinstance(round_state, dict) or round_state.get('generation') != marker:
        raise ValueError('Round generation differs')
    destination.mkdir(parents=True, exist_ok=False)
    for name in before:
        shutil.copy2(directory / name, destination / name)
    if inventory(directory) != before or inventory(destination) != before:
        raise ValueError('Generation changed while freezing; preserve both copies')
    world_state = round_state.get('world_state', {})
    environment = world_state.get('environment') if isinstance(world_state, dict) else None
    return {'identity': dict(identity), 'files_sha256': before, 'saved_environment': environment,
            'native_contents_validated_here': False}


def stage_reader(frozen, destination, receipt):
    """New copy plus fixture intent built from the returned production identity.

    This is a controlled recovery input, not proof that native reboot published
    the intent. The executor must start a genuinely new process and compare it.
    """
    frozen, destination = unlinked(frozen), unlinked(destination)
    if inventory(frozen) != receipt.get('files_sha256'):
        raise ValueError('Frozen generation changed')
    freeze_generation(frozen, destination, receipt['identity'])
    (destination / 'restart_intent.json').write_text(json.dumps(receipt['identity']), encoding='utf-8')
    return {'recovery_input': str(destination), 'native_restore_executed': False}
