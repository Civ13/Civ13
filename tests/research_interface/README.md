# Research bench screen and book window

Offline: `python3 -m unittest discover -s tests/research_interface -v` checks
source wiring: the one-click copy, copy-all and write actions keep every cost
and post-wait recheck of the menus they replace, the queue is bounded, the
screen data procs change nothing, and the book window only answers for a book
in reach.

Native: `python3 tests/research_interface/run.py --byond-bin <pinned BYOND bin> --trusted`
only with authorization for the isolated native runtime (`--compile-only` does
not launch DreamDaemon). The fixture compiles the complete production source in
a temporary world with no listening port, maps or saves. It replaces only the
action waits in the three book research files, client presence, bench light and
inventory transfers, then runs the production procs: bench and book window
data for a new, working, dark and finished bench, studying, the queue, copying
one chapter and all of them, the blank sheet helper and writing from memory.
`--fixtures <dir>` keeps the screen data it produced (`bench.json`,
`book.json`) for browser previews of the interfaces.

The React screens have their own tests in `tgui/src/interfaces/ResearchBench.test.tsx`
and `ResearchBook.test.tsx`; `tests/tgui/test_backend_contract.py` checks that
every button reaches a Topic branch. None of this is in-game, client or
graphical acceptance.
