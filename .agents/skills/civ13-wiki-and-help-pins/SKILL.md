---
name: civ13-wiki-and-help-pins
description: Update civ13-wiki player guides and the Crafting Atlas after a Civ13 merge, check feature availability and secrecy, and re-pin the in-game Help's reviewed wiki guides. Use when editing civ13-wiki, after a player-facing merge, or when Help drops a wiki page.
---

# Wiki guides and Help pins

## Writing wiki guides

The wiki repository's `AGENTS.md` and `CONTRIBUTING.md` are authoritative;
read them before editing. In short:

- Document only features available to players in ordinary play. A Civ13
  merge counts when its recipe or verb is active (not commented out, admin-only,
  behind a default-off flag or a disabled research node); cite the merged PR in
  the wiki PR. A map counts when it has an active vote entry in
  `code/processes/mapswap.dm`. Otherwise leave that detail out and publish the rest.
- Never publish secrets, hidden discoveries or private information, even if
  the source is public. Describe the current game directly, without version
  banners or upcoming-feature notes.
- Wiki links from Civ13 use `https://civ13.github.io/civ13-wiki/` paths;
  `tests/player_help/test_wiki_links.py` rejects old MediaWiki-style links.
- Build and check with the wiki's full CI command from its `CONTRIBUTING.md`.

## Crafting Atlas

`UI/crafting-atlas.json` and `docs/crafting-recipe-audit-index.json` are
generated in Civ13: run `python3 scripts/agent_preflight.py generated --write`
after any recipe change and never hand-merge them.

## Help re-pin

`scripts/player_help_bridge.py` pins the guides in `WIKI_REVIEWED_GUIDES` by
LF-normalized SHA-256 and silently drops a page whose hash changes. After a
civ13-wiki merge that edits a pinned guide, open a Civ13 PR that re-pins:

```bash
python3 scripts/agent_preflight.py wiki-pins --wiki-root ../civ13-wiki --write
```

Review the changed guides, commit with the new wiki revision, and note in the
wiki PR that the re-pin is needed. Its `Changelog:` line stays blank.
