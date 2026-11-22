# Ask for Help test questions

`questions.json` is a set of questions a player might ask, each with the answer
the wiki gives. Use it to gauge whether Ask for Help can answer from the guides:
after a retrieval or prompt change, a model change, or a wiki re-pin.

The guides it quotes are the copies shipped with the game in
`UI/player-help-wiki/`, so the set needs no wiki checkout.

## Running it

```
python3 tests/player_help/wiki_eval/run.py
```

Offline, about a minute, no model. A question passes when the evidence the
bridge would send to the model holds the wiki passage that answers it. This is
the score CI checks (`tests/player_help/test_wiki_answers.py`): every question
must pass.

```
python3 tests/player_help/wiki_eval/run.py --ollama-url http://HOST:11434 --model civ13-help-qwen3-8b --output answers.json
```

Sends every question through the real bridge to the model and scores the
answers. An answer passes when it states every key fact and names no hidden
topic. `answers.json` keeps each answer for reading. Run this from a machine
that can reach the Ollama host. It needs no game server and does not touch the
live spool.

Other options:

- `--list` prints the questions, expected answers and source sections as Markdown.
- `--only id,id` runs some questions.
- `--rescore answers.json` scores saved answers again after a pattern change.
- `--bridge`, `--game-root`, `--wiki-root` score another checkout, to compare a
  deployment with the branch.

Read the saved answers as well as the score. The patterns are deliberately
loose, so a pass means the key facts are there, not that the whole answer is
right; a fail can also be a correct answer worded in a way no pattern expected.

## Question format

```json
{"id": "make-soap", "question": "How do I make soap?", "page": "guides/Guide_to_Hygiene.md", "section": "Soap",
 "expected": "Mix 20 units of corn oil with 2 units of lye in a container.",
 "evidence": ["To make soap, mix 20 units of corn oil with 2 units of lye in a container."],
 "answer": ["corn oil", "lye"]}
```

- `question`: what a player would type, in their words. Avoid copying the
  guide's sentence.
- `page`, `section`: the bundled guide and the heading that holds the answer.
- `expected`: the answer in a sentence or two, for a person reading results.
- `evidence`: text copied exactly from one line of the guide. All of it must
  reach the model. An item may be a list of alternatives when two guides hold
  the same fact; the first is always the named page's wording. Leave out link
  targets and runs of spaces, which the bridge removes.
- `answer`: case-insensitive regular expressions, one per key fact. All must
  match the model's answer.
- `turns` (optional): earlier exchanges, each `{"question": ..., "answer": ...}`,
  for a follow-up question. They are sent as the game sends a conversation, so
  the entry checks that "it" or "there" still finds the right guide.
- Hidden-topic checks have `"page": null`, no evidence and `"hidden": true`.
  The model must answer them without naming any hidden topic.

## Adding a question

1. Pick a fact a player would need and find its line in `UI/player-help-wiki/`.
2. Add the entry and run `python3 tests/player_help/wiki_eval/run.py --only <id> --verbose`.
3. If the evidence is missing, the bridge did not find the passage. Prefer
   fixing that (a keyword for the guide in `WIKI_REVIEWED_GUIDES`, or a word in
   `QUESTION_SYNONYMS`, in `scripts/player_help_bridge.py`) over rewording the
   question to match the guide.
4. Run `python3 -m unittest tests.player_help.test_wiki_answers`.

Keep hidden mechanics out of questions and expected answers. A guide that
changes on the wiki arrives through the re-pin, and a question whose line was
reworded then fails the unit test until its `evidence` is updated.
