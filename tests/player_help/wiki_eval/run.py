#!/usr/bin/env python3
"""Score Ask for Help against player questions with known wiki answers.

Two scores, both over tests/player_help/wiki_eval/questions.json:

  evidence  offline. A question passes when the evidence the bridge would send
            to the model holds every marker line of the wiki passage that
            answers it. Needs no model and no network.
  answers   with --ollama-url. Each question is sent through the real bridge
            to the model; an answer passes when it states every key fact
            (case-insensitive patterns) and names no hidden topic.

    python3 tests/player_help/wiki_eval/run.py
    python3 tests/player_help/wiki_eval/run.py --ollama-url http://host:11434 --model NAME --output answers.json
    python3 tests/player_help/wiki_eval/run.py --list

README.md beside this file explains the question format and how to add one.

--bridge and --game-root score another checkout's bridge and corpus, and
--wiki-root an external wiki checkout, so an old deployment can be compared.
"""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[3]
QUESTIONS = Path(__file__).with_name('questions.json')
# Names the public Help must never use, whatever the question.
# A refusal may repeat the player's own words ("the guides do not cover spells").
HIDDEN = re.compile(r'\bPersistence\b|\bmana\b|\bwands?\b|\bincantation|\bshrine', re.I)
GAME_CONTEXT = {'map': 'Gaia', 'map_id': 'GAIA', 'gamemode': 'Civilizations', 'era': '5000 B.C.',
                'era_ordinal': 0, 'civilizations': True}


def load_bridge(path):
    spec = importlib.util.spec_from_file_location('wiki_eval_bridge', path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def build_corpus(bridge, game_root, wiki_root=None):
    """The corpus main() builds, with its wiki coverage status."""
    game_root = Path(game_root)
    corpus = bridge.bounded_json(game_root / 'UI/player-help.json', 32768)
    corpus += bridge.recipe_context(game_root / 'UI/crafting-atlas.json')
    corpus += bridge.acquisition_context(game_root / 'UI/crafting-atlas.json')
    corpus += bridge.tips_knowledge(game_root)
    status = {}
    corpus += bridge.gameplay_knowledge(game_root, wiki_root, wiki_status=status)
    return corpus, status


def plain(text):
    """Evidence as the model reads it, with JSON escapes undone for marker checks."""
    return text.replace('\\n', '\n').replace('\\"', '"').replace('\\u2019', "'")


def score_answer(entry, answer):
    facts = [bool(re.search(pattern, answer, re.I)) for pattern in entry['answer']]
    hidden = bool(HIDDEN.search(answer))
    return {'facts': sum(facts), 'of': len(facts), 'hidden': hidden, 'pass': all(facts) and not hidden}


def question_list(questions):
    """The question set as Markdown, grouped by guide, for a person to read."""
    lines, pages = ['# Ask for Help test questions', ''], {}
    for entry in questions:
        pages.setdefault(entry['page'], []).append(entry)
    for page in sorted(pages, key=lambda name: (name is None, name or '')):
        lines += ['## ' + (page[:-3].split('/')[-1].replace('_', ' ') if page else 'Must refuse (hidden topics)'), '']
        for entry in pages[page]:
            lines += ['- **%s**' % entry['question'],
                      '  - Expected: %s' % entry['expected']]
            if page:
                lines.append('  - Source: `%s`, section "%s"' % (page, entry['section']))
            lines.append('  - Id: `%s`' % entry['id'])
        lines.append('')
    return '\n'.join(lines).rstrip()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--bridge', type=Path, default=ROOT / 'scripts/player_help_bridge.py')
    parser.add_argument('--game-root', type=Path, default=ROOT)
    parser.add_argument('--wiki-root')
    parser.add_argument('--num-ctx', type=int, default=16384)
    parser.add_argument('--evidence-chars', type=int, default=16000)
    parser.add_argument('--ollama-url')
    parser.add_argument('--model', default='civ13-help-qwen3-8b')
    parser.add_argument('--timeout', type=int, default=120)
    parser.add_argument('--only', help='comma-separated question ids')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--verbose', action='store_true')
    parser.add_argument('--rescore', type=Path, help='score the answers saved in an earlier --output file again')
    parser.add_argument('--list', action='store_true', help='print the question set as Markdown and exit')
    args = parser.parse_args()

    if args.list:
        print(question_list(json.loads(QUESTIONS.read_text(encoding='utf-8'))))
        return 0

    if args.rescore:
        expected = {entry['id']: entry for entry in json.loads(QUESTIONS.read_text(encoding='utf-8'))}
        rows = [score_answer(expected[row['id']], row.get('answer', '')) for row in json.loads(args.rescore.read_text(encoding='utf-8'))['rows']]
        print(json.dumps({'questions': len(rows), 'answers_pass': sum(row['pass'] for row in rows), 'facts': sum(row['facts'] for row in rows),
                          'facts_of': sum(row['of'] for row in rows), 'hidden_leaks': sum(row['hidden'] for row in rows)}))
        return 0
    bridge = load_bridge(args.bridge)
    corpus, status = build_corpus(bridge, args.game_root, args.wiki_root)
    questions = json.loads(QUESTIONS.read_text(encoding='utf-8'))
    if args.only:
        questions = [entry for entry in questions if entry['id'] in args.only.split(',')]
    config = {'enabled': True, 'model': args.model, 'workers': 1, 'timeout_seconds': args.timeout,
              'num_ctx': args.num_ctx, 'evidence_chars': args.evidence_chars, 'think': False,
              'endpoint': 'http://localhost/api/chat',
              # One batch of test questions must not trip the per-minute limit for all players.
              'limits': {'global_requests': 4096, 'global_seconds': 1}}
    if args.ollama_url:
        url = args.ollama_url.rstrip('/')
        config['endpoint'] = (url[:-3] if url.endswith('/v1') else url) + '/api/chat'
    prompts = []

    def transport(endpoint, payload, headers, timeout):
        prompts.append(payload['messages'][0]['content'])
        if args.ollama_url:
            return bridge.network(endpoint, payload, headers, timeout)
        return {'message': {'content': 'offline'}}

    rows = []
    with tempfile.TemporaryDirectory() as spool:
        worker = bridge.Bridge(Path(spool) / 'spool', config, corpus, transport)
        try:
            for index, entry in enumerate(questions):
                request = {'id': str(index + 1), 'account': '%032x' % (index + 1),
                           'question': entry['question'], 'game_context': GAME_CONTEXT}
                before, started = len(prompts), time.monotonic()
                reply = worker.answer(request)
                if reply.get('status') not in ('ok', 'unavailable'):
                    raise SystemExit('The bridge refused a test question: ' + str(reply.get('status')))
                evidence = plain(prompts[before]) if len(prompts) > before else ''
                # A marker may be a list of alternatives: two guides can both hold the answer.
                missing = [marker if isinstance(marker, str) else marker[0] for marker in entry['evidence']
                           if not any(option in evidence for option in ([marker] if isinstance(marker, str) else marker))]
                row = {'id': entry['id'], 'question': entry['question'], 'expected': entry['expected'],
                       'evidence_pass': not missing if entry['evidence'] else None, 'missing_evidence': missing,
                       'status': reply.get('status'), 'seconds': round(time.monotonic() - started, 1)}
                if args.ollama_url:
                    row['answer'] = reply.get('answer', '')
                    row.update(score_answer(entry, row['answer']))
                rows.append(row)
                if args.verbose or args.ollama_url:
                    print(('PASS' if row.get('pass', row['evidence_pass']) in (True, None) else 'FAIL'), entry['id'],
                          '' if not missing else 'missing evidence: ' + ' | '.join(missing), flush=True)
        finally:
            worker.close()

    graded = [row for row in rows if row['evidence_pass'] is not None]
    summary = {'wiki_status': status, 'questions': len(rows),
               'evidence_pass': sum(row['evidence_pass'] for row in graded), 'evidence_of': len(graded)}
    if args.ollama_url:
        summary.update({'answers_pass': sum(row['pass'] for row in rows),
                        'facts': sum(row['facts'] for row in rows), 'facts_of': sum(row['of'] for row in rows),
                        'hidden_leaks': sum(row['hidden'] for row in rows),
                        'unavailable': sum(row['status'] != 'ok' for row in rows)})
    print(json.dumps(summary))
    for row in rows:
        if row['evidence_pass'] is False:
            print('  no evidence:', row['id'])
    if args.output:
        args.output.write_text(json.dumps({'summary': summary, 'rows': rows}, indent=1, ensure_ascii=False), encoding='utf-8')
    return 0


if __name__ == '__main__':
    sys.exit(main())
