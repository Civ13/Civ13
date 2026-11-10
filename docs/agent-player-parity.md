# Agent player parity

Goal: an agent character (Ada and other autopilot players, see
[agent control](agent-control.md)) can do everything a player can. This page
tracks what a player reaches through the client that the agent control layer
does not, and which change closes each gap. Update it when a gap closes or a
new player-facing input appears.

Already covered: walking, clicks with intent, modifiers and body zone,
crafting from stacks, equip and take, examine, drop, swap hand, resist, verbs
(right-click menu and verb panels), throwing, say, emote, OOC, bug reports,
`WWinput` prompts (`choose`), boats and routes, sounds and change lists.

| # | Gap | Player input | Status |
| --- | --- | --- | --- |
| 1 | Menu windows | HTML windows and their links (research, trade posts, suppliers, faction and recruitment desks, books, telephones) | Closed: `windows` in observe, `topic` and `close_window` actions |
| 2 | Typed prompts | Raw `input()`/`alert()` (stack split amounts, names, paper, frequencies, money) answer nothing for a clientless character | Closed: `player_input`/`player_alert` answer from `choose`; the few raw calls left are listed in `PromptTests` |
| 3 | HUD-only toggles | Run/walk/sneak/prone, dodge/parry, tactic, kick/jump/bite, fixed facing, gun aim modes, equip to a chosen slot | Closed: `stance` action, `equip` with `slot` |
| 4 | Movement parity | `move` calls `Move()` directly: no hill climbing cost, no riding animals or wheelchairs, grabs and pulls skip the client path | Closed: `agent_walk_step` mirrors the client's rules and costs (tile steps; free sub-tile sliding stays player-only) |
| 5 | Vehicles beyond boats | Cars and carts (wheel, gears), trains, aircraft (climb/descend), drones, turret controls | Closed: `drive` action for the driver's seat HUD, `move` presses the arrow-key extras (wheel, turret, drone), `use` with `alternate`; trains are clicked |
| 6 | Observation | Contents of crates and closets, terrain height, light level | Closed for storage containers (`contents`, click inside), `height` and `light`; closets dump their contents on the floor when opened, so they need nothing more |
| 7 | TGUI and NanoUI screens | Crafting atlas, chemistry machines and similar | Closed for machine screens (research bench, dispensers, vending, faction and recruitment desks): `screens` in observe, `screen` action. Reader screens (books, notes, lists, photos, atlas, paper editor) still need a client; the crafting atlas data is already in `craftable` |
| 8 | Region travel | Gates require a BYOND key; an agent body cannot travel and its agent cannot follow | Open: needs a design decision |
