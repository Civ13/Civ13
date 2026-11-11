# Player tutorial

New players are walked through short steps on their real character
(`code/modules/client/player_tutorial.dm`, [docs/player-tutorial.md](../../docs/player-tutorial.md)).

```sh
python3 -B -m unittest discover -s tests/player_tutorial -v
python3 tests/player_tutorial/run.py --byond-bin <pinned bin> --evidence-dir <fresh dir>
```

`run.py` compiles the full DME without maps through the existing
`isolated_startup` adapter and runs `probe.dm` on a 20x20 world: every step has
text, the book step only appears where research lives in books, and each
watched step is pending and then done from the state its action leaves (moving,
picking up, swapping hands, stowing, intents, the atlas event, eating, a reading
step's timer). No client joins: chat links, the screen line, the Game Menu and
preference saving are not driven.
