---
name: civ13-merge-and-changelog
description: Civ13 PR Changelog line rules, when and how an authorized PR is admin-merged, and the post-merge follow-ups (master CI, wiki and Crafting Atlas guides, Help re-pin, public roadmap). Use when writing a PR body's Changelog line, merging a PR, or closing one out.
---

# Changelog, merging and post-merge follow-ups

## The `Changelog:` line

The PR template's single `Changelog:` line is posted to Discord's #changelog
on merge, and the "Changelog contracts" check validates it.

- Player-facing change: one line of exact player-visible text. No heading, PR
  number, `@` mentions, `<`/`>`, or merge/deployment/availability wording.
- Anything else (refactors, tests, CI, docs, agent guides): leave the line
  BLANK. Never write `none (...)`, `n/a`, "not player-facing", "internal only"
  or any explanation; the check rejects filler and placeholders.
- Keep deliberately hidden systems and secrets out of changelog text, as the
  wiki's player documentation policy requires.

## Merging

Source PR work alone grants no merge authority; merge only with the user's
authorization. Where the maintainer has given standing merge authorization
for agent PRs:

- Admin-merge (merge commit) once the exact head compiles locally and the
  focused tests and `python3 scripts/agent_preflight.py all --write` pass.
  Hosted CI need not finish first, but a real compile or test failure blocks.
- Contributor (non-agent) PRs are never merged without the maintainer's
  explicit OK for that PR. Approval to merge covers only the PRs open at the
  time it was given.
- After merging, watch master's CI for the merge commit and fix anything it
  breaks in a new PR, without waiting to be asked.

## Follow-ups after a merge

- Player-facing gameplay: update or add the civ13-wiki guide and the Crafting
  Atlas when appropriate (`civ13-wiki-and-help-pins`).
- A merged wiki edit to a pinned guide needs a Help re-pin PR in Civ13.
- Public roadmap (`Civ13/civ13.github.io`, `_data/roadmap.json`): when a merge
  touches a roadmap topic, update its entry in that repository. It accepts
  merge commits only (no squash) and its own checks enforce field and list caps.
- Screenshots as proof when cheap; map changes always carry renders
  (`civ13-map-renders`).
