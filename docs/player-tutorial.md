# Player tutorial

New players are walked through short steps on their real character the first
time they join (`code/modules/client/player_tutorial.dm`). Each step appears in
chat with a **Got it** or **Skip** link and as one line at the top of the
screen (click it to repeat the step). Steps that ask the player to do something
finish by themselves when the character does it; reading steps finish after 25
seconds. A step that is not done is shown again after 3 and 6 minutes.

| Step | Finishes when |
| --- | --- |
| move | the character is 3 tiles from where the step began, or changed level |
| hud | read (ConsoleStyle names the food, water and stamina bars) |
| pick_up | a hand holds an item it did not hold when the step began |
| swap | the active hand changed |
| stow | more items are worn or in worn storage than when the step began |
| intent | the intent changed |
| atlas | the Crafting Atlas verb was used |
| eat | food or water rose between two 2-second checks |
| chat | read |
| research | a book was placed on a research bench or a chapter was studied; only on maps with `book_research_enabled()` |
| help | read, or Ask for help was used |

## Progress and reset

Progress lives in the player's preferences (`tutorial_state`, `tutorial_done`
in `SQL/charprefs.txt`), so it carries over between rounds, characters and
regions sharing that file. States: 0 unset, 1 active, 2 finished or stopped,
3 offered.

- A player whose preferences are created for the first time starts at 1.
- Players with preferences from before the tutorial (state 0) get a one-line
  notice on their next spawn instead, and move to 3.
- **Game Menu** (Esc), **Tutorial** (also the OOC verb **Tutorial**): show the
  current step, stop, start again, or **Reset tutorial progress**.
- Character setup, **Settings** page: the tutorial status and **Reset progress**.

The practice body from the lobby Practice Room ([practice-rooms.md](practice-rooms.md))
never runs the tutorial. The tutorial only watches the character; it never
changes it.

Tests: [tests/player_tutorial](../tests/player_tutorial/README.md).
