# Natural crop bootstrap walkthrough

`full_game.py` + `full_game_probe.dm` are the headless full-game acceptance run
for #3048: a fresh character goes from empty hands to a harvested and replanted
crop on the real North America map, across a real save and restart.

```bash
source "$HOME/byond-516.1688/byond/bin/byondsetup"
python3 tests/natural_bootstrap/full_game.py --byond-bin "$HOME/byond-516.1688/byond/bin" --output /tmp/bootstrap-run
```

The runner appends the probe to a temporary copy of `civ13.dme` with the North
America map, configures the evidence directory as a persistent book research
world with one agent autospawn line, and runs DreamDaemon twice:

1. **write**: the production agent autospawn starts a Nomad on the tile the
   production start picker draws. Through player actions only
   (`agent_control.perform_step`: clicks, hand actions, verbs, prompts, screens
   and the click-to-move route) the character walks to the nearest fresh water
   with farm ground, founds a faction for its Stone Age master book, studies
   Basic Toolmaking, searches a rock for two flints and knaps a flint knife,
   cuts down a tree with it, crafts a digging stick from the wood, ploughs
   three plots, forages seed from wild small bushes, plants it and waits for a
   crop to reach its third stage. `ticker.savemap()` then saves the world.
2. **read**: a new daemon restores that save by itself at boot. The character,
   its faction, learned chapter and carried items, the digging stick left at
   the camp, and every crop's type, stage, soil type and soil nutrition are
   compared with the write stage's manifest. The crop then grows on to harvest,
   is harvested with the knife, the produce is eaten when it is food and the
   character has room for it (the result names which happened), and the
   harvested seed is replanted and grows a stage.

The probe spawns, grants and moves nothing. Its adapters are listed in
`run-manifest.json` and in each `result-<stage>.json`: the map include, the
persistent-world config, the round start, the weather process and season timer
held, a fixed random seed for the start tile, and `recipe_knowledge_exempt`
returning FALSE so the agent body learns chapters the way a player does. When it
is too dark to read, the probe turns the production day clock forward and
records that too.

Evidence in the output directory: `result-write.json` and `result-read.json`
(checks, the step journal and the character's own message log), `manifest.json`
(the state saved), `summary.json`, per-stage daemon logs, runtime error sites
and OS samples. `--seed` picks another start; a start in a land with no
farmable bank within reach, or a character lost to a predator, fails the run
honestly rather than being moved.

It does not cover client pixels, the tgui windows a player sees, or more than
one crop generation after the restart.
