"""Build the dictionary DM fixture and its corpus, and optionally run it.

    python3 tests/dictionary_era/prepare.py --output <new dir>          # fixture only
    python3 tests/dictionary_era/prepare.py --output <new dir> --run    # compile + run, check corpus.json
    python3 tests/dictionary_era/prepare.py --output <new dir> --write  # same, then rewrite corpus.json

The fixture holds the production dictionary helper, the frozen legacy helper,
the production speech prefixes and probe.dm. It never starts the game. Running
needs DreamMaker and DreamDaemon on PATH (scripts/cloud_byond_setup.sh).
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(HERE))
import reference  # noqa: E402

SAY = 'code/game/mob/living/carbon/human/say.dm'
WHISPER = 'code/game/mob/living/carbon/human/whisper.dm'
HELPER = 'code/_helpers/dictionary.dm'
RUST_G = 'code/__defines/_rust_g.dm'
CALL = '\tmessage = apply_dictionary_replacements(message)'
CORPUS = HERE / 'corpus.json'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def proc(source, name):
    match = re.search(r'^/proc/' + re.escape(name) + r'\([^\n]*\)\n', source, re.M)
    if not match:
        raise ValueError('Missing production proc: ' + name)
    end = match.end()
    for line in source[end:].splitlines(keepends=True):
        if line.strip() and not line.startswith(('\t', ' ')):
            break
        end += len(line)
    return source[match.start():end].rstrip() + '\n'


def speech_prefix(source, path):
    start_text = ('\tmessage = capitalize(sanitize(message))' if path == SAY
                  else '\tmessage = sanitize(message)')
    start = source.index(start_text)
    end = source.index(CALL, start) + len(CALL)
    if source[start:end].count(CALL) != 1:
        raise ValueError('Ambiguous dictionary call in ' + path)
    return source[start:end]


SENTENCES = [
    'lol that was funny', 'LOL', 'Lol ok', 'lol lmao rofl', 'unga bunga', 'bunga unga',
    'the cuckoo ate my lollipop in the bungalow', 'my gamergirl friend', 'poggers', 'pog pogo pogs',
    'pm the admins please', 'admin pm me', 'gamers rise up', 'GAMERS RISE UP', 'tl;dr no', 'tldr no',
    ':) hello :( bye ;) :b :bread', 'hello:)', 'noobs and noob', 'brb, afk', 'idk idfk idgaf',
    'excuse me, please', 'Excuse me!', 'be brave brave now', 'brave-looking bravest', 'the lord\'s steward',
    'that\'s gross', '"brave"', 'brave\'s horse', 'a potato and a dollar', 'stop! stop!!',
    'damned if i know', 'in prison, in jail', 'really good really great', 'my home', '(sausages)',
    'we live in a society', 'what the fuck wtf', 'café lol café', 'élol lolé',
    'lol\x01lol', '\x02lol\x03', 'a & b lol', '<b>lol</b>', 'lol #lol lol;', 'x' * 30 + ' lol',
    'We need to build a wall around the farm before winter arrives', 'ok', 'Hey :) can you bring bread, lol?',
]


def corpus_lines():
    """(kind, source, era, text, prefix) records, in a fixed order."""
    old = reference.frozen_legacy_rows()
    new = reference.current_rows()
    sources = {}
    for row in old:
        sources.setdefault((row[0], row[2] if len(row) >= 3 else None), True)
    for source, _, era in new:
        sources.setdefault((source, era), True)
    records = []
    shapes = [('plain', 'we said {} today'), ('start', '{} now'), ('alone', '{}'),
              ('inside_right', '{}ing'), ('inside_left', 're{}'), ('plural', 'two {}s'),
              ('possessive', "the {}'s hat"), ('quoted', 'he said "{}"'), ('hyphen', '{}-like'),
              ('punctuation', '({}), ok!')]
    for (source, era) in sources:
        for kind, shape in shapes:
            records.append((kind, source, era, shape.format(source), 'say'))
        records.append(('caps', source, era, 'WE SAID {} TODAY'.format(source.upper()), 'say'))
        records.append(('whisper', source, era, 'they said {}'.format(source), 'whisper'))
        for other in ([None, 4] if era is None else [None, (era + 1) % 9]):
            if other != era:
                records.append(('other_era', source, other, 'we said {} today'.format(source), 'say'))
    for text in SENTENCES:
        for era in reference.ERAS:
            records.append(('sentence', '', era, text, 'say'))
    return records


PARSER_LINES = [
    'a,b', 'a,b,0', 'a,b,8', ' a , b ', 'a,b,9', 'a,b,', 'a,b,x', 'a,b,0,phrase', 'a,b,c,d,e',
    'a,', ',b', 'café,b', 'a,café', '#a,b', 'no comma here', 'a,b, 4 ', 'a,b,4\r', 'a,b\r',
]


def prepare(output):
    output = Path(output)
    output.mkdir(parents=True, exist_ok=False)
    paths = [HELPER, RUST_G, SAY, WHISPER, 'code/_helpers/text.dm', 'code/__defines/__game.dm',
             'config/dictionary.txt', 'tests/dictionary_era/probe.dm',
             'tests/dictionary_era/legacy/dictionary.dm', 'tests/dictionary_era/legacy/dictionary.txt']
    sources = {path: read(path) for path in paths}
    text = sources['code/_helpers/text.dm']
    helpers = '\n'.join(proc(text, name) for name in
                        ('sanitize', 'replace_characters', 'trim_left', 'trim_right', 'trim', 'capitalize'))
    max_message = re.search(r'^#define MAX_MESSAGE_LEN [0-9]+$', sources['code/__defines/__game.dm'], re.M)
    if not max_message:
        raise ValueError('Missing production message-length define')
    fixture = ['#define TRUE 1', '#define FALSE 0', max_message.group(),
               sources[RUST_G],
               'var/global/list/dictionary_list = list()',
               'var/global/list/legacy_dictionary_list = list()',
               'var/global/datum/dictionary_era_map/map',
               '/datum/dictionary_era_map\n\tvar/ordinal_age = 0',
               helpers, sources[HELPER], sources['tests/dictionary_era/legacy/dictionary.dm']]
    for name, path in [('say', SAY), ('whisper', WHISPER)]:
        body = speech_prefix(sources[path], path)
        fixture.append('/proc/fixture_' + name + '(message)\n' + body + '\n\treturn message\n')
        legacy = body.replace(CALL, '\tmessage = legacy_apply_dictionary_replacements(message, legacy_dictionary_list)')
        fixture.append('/proc/legacy_' + name + '(message)\n' + legacy + '\n\treturn message\n')
    fixture.append(sources['tests/dictionary_era/probe.dm'])
    fixture = '\n'.join(fixture)
    (output / 'fixture.dme').write_text(fixture, encoding='utf-8', newline='\n')
    (output / 'dictionary.txt').write_text(sources['config/dictionary.txt'], encoding='utf-8', newline='\n')
    (output / 'legacy_dictionary.txt').write_text(sources['tests/dictionary_era/legacy/dictionary.txt'],
                                                  encoding='utf-8', newline='\n')
    records = corpus_lines()
    inputs = {'records': [[text, -1 if era is None else era, prefix] for _, _, era, text, prefix in records],
              'parser': PARSER_LINES}
    (output / 'inputs.json').write_text(json.dumps(inputs), encoding='utf-8')
    return {'fixture_sha256': hashlib.sha256(fixture.encode()).hexdigest(), 'records': len(records)}


def run(output):
    output = Path(output)
    for tool in ('DreamMaker', 'DreamDaemon'):
        if not shutil.which(tool):
            raise SystemExit(tool + ' is not on PATH; run scripts/cloud_byond_setup.sh and source byondsetup')
    build = subprocess.run(['DreamMaker', '-max_errors', '0', 'fixture.dme'], cwd=output,
                           capture_output=True, text=True)
    if '- 0 errors' not in build.stdout:
        raise SystemExit(build.stdout + build.stderr)
    subprocess.run(['DreamDaemon', 'fixture.dmb', '-safe', '-close', '-invisible'], cwd=output,
                   capture_output=True, text=True, timeout=600)
    result = json.loads((output / 'results.json').read_text(encoding='utf-8'))
    records = corpus_lines()
    corpus = {'schema': 1, 'engine': result['engine'],
              'records': [{'kind': kind, 'source': source, 'era': era, 'text': text, 'prefix': prefix,
                           'old': old, 'new': new}
                          for (kind, source, era, text, prefix), (old, new) in zip(records, result['records'])],
              'parser': [{'line': line, 'accepted': accepted}
                         for line, accepted in zip(PARSER_LINES, result['parser'])]}
    if len(result['records']) != len(records):
        raise SystemExit('fixture returned {} records for {} inputs'.format(len(result['records']), len(records)))
    return corpus


def dump(corpus):
    lines = ['{', '  "schema": 1,', '  "engine": ' + json.dumps(corpus['engine']) + ',', '  "records": [']
    lines += ['    ' + json.dumps(record, ensure_ascii=True) + ',' for record in corpus['records']]
    lines[-1] = lines[-1].rstrip(',')
    lines += ['  ],', '  "parser": [']
    lines += ['    ' + json.dumps(record, ensure_ascii=True) + ',' for record in corpus['parser']]
    lines[-1] = lines[-1].rstrip(',')
    lines += ['  ]', '}', '']
    return '\n'.join(lines)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--run', action='store_true', help='compile and run, then compare with corpus.json')
    parser.add_argument('--write', action='store_true', help='compile and run, then rewrite corpus.json')
    args = parser.parse_args()
    print(json.dumps(prepare(args.output)))
    if args.run or args.write:
        corpus = run(args.output)
        if args.write:
            CORPUS.write_text(dump(corpus), encoding='utf-8', newline='\n')
            print('wrote', CORPUS.relative_to(ROOT), len(corpus['records']), 'records, engine', corpus['engine'])
        else:
            recorded = json.loads(CORPUS.read_text(encoding='utf-8'))
            for key in ('records', 'parser'):
                if recorded[key] != corpus[key]:
                    raise SystemExit('fixture output differs from corpus.json (' + key + ')')
            print('fixture matches corpus.json:', len(corpus['records']), 'records, engine', corpus['engine'])
