"""Prepare a small production-source DM fixture. Never compile or launch it."""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
SAY = 'code/game/mob/living/carbon/human/say.dm'
WHISPER = 'code/game/mob/living/carbon/human/whisper.dm'
HELPER = 'code/_helpers/dictionary.dm'
OLD_LOOP = '\tfor (var/i in dictionary_list)\n\t\tmessage = replacetext(message,i[1],i[2])'
NEW_CALL = '\tmessage = apply_dictionary_replacements(message)'


def read(path, root=ROOT):
    return (root / path).read_text(encoding='utf-8')


def proc(source, name):
    match = re.search(r'^/proc/' + re.escape(name) + r'\([^\n]*\)\n', source, re.M)
    if not match:
        raise ValueError('Missing production proc: ' + name)
    end = match.end()
    lines = source[end:].splitlines(keepends=True)
    for line in lines:
        if line.strip() and not line.startswith(('\t', ' ')):
            break
        end += len(line)
    return source[match.start():end].rstrip() + '\n'


def speech_prefix(source, path):
    start_text = ('\tmessage = capitalize(sanitize(message))' if path == SAY
                  else '\tmessage = sanitize(message)')
    start = source.index(start_text)
    end = source.index(NEW_CALL, start) + len(NEW_CALL)
    if source[start:end].count(NEW_CALL) != 1:
        raise ValueError('Ambiguous dictionary call')
    return source[start:end] + '\n\treturn message\n'


def prepare(output, root=ROOT):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    paths = [HELPER, SAY, WHISPER, 'code/_helpers/text.dm', 'code/setup.dm',
             'code/__defines/__game.dm', 'civ13.dme', 'tools/byond/version.json',
             'config/dictionary.txt', 'tests/dictionary_era/probe.dm',
             'tests/dictionary_era/wiki_slang.json']
    sources = {path: read(path, root) for path in paths}
    text = sources['code/_helpers/text.dm']
    helpers = '\n'.join(proc(text, name) for name in
                        ('sanitize', 'replace_characters', 'trim_left',
                         'trim_right', 'trim', 'capitalize'))
    max_message = re.search(r'^#define MAX_MESSAGE_LEN [0-9]+$',
                            sources['code/__defines/__game.dm'], re.M)
    if not max_message:
        raise ValueError('Missing production message-length define')
    fixture = '''#define TRUE 1
#define FALSE 0
'''
    fixture += max_message.group() + '\n'
    fixture += '''
var/global/list/dictionary_list = list()
var/global/datum/dictionary_era_map/map
/datum/dictionary_era_map
\tvar/ordinal_age = 0
'''
    fixture += helpers + '\n' + sources[HELPER] + '\n'
    for name, path in [('say', SAY), ('whisper', WHISPER)]:
        body = speech_prefix(sources[path], path)
        fixture += '/proc/fixture_' + name + '(message)\n' + body
        # Freeze the previous loop for direct native legacy-output comparison.
        fixture += '/proc/legacy_' + name + '(message)\n' + body.replace(NEW_CALL, OLD_LOOP)
    fixture += sources['tests/dictionary_era/probe.dm']
    (output / 'fixture.dme').write_text(fixture, encoding='utf-8', newline='\n')
    (output / 'dictionary.txt').write_text(sources['config/dictionary.txt'],
                                         encoding='utf-8', newline='\n')
    manifest = {
        'schema': 1, 'scope': 'isolated dictionary and speech-prefix contracts',
        'target_byond': json.loads(sources['tools/byond/version.json'])['version'],
        'native_compilation': 'not_run', 'native_execution': 'not_run',
        'full_game': 'not_run', 'geometry': '1x1x1 fixture; no production map',
        'source_sha256': {p: hashlib.sha256(s.encode()).hexdigest()
                          for p, s in sources.items()},
        'fixture_sha256': hashlib.sha256(fixture.encode()).hexdigest(),
        'adapters': ['inert map metadata datum', 'no normal world startup',
                     'speech prefixes only; no mobs or listeners'],
    }
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n',
                                        encoding='utf-8')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(prepare(args.output), indent=2))
