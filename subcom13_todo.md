# SUBCOM13 — Remaining Tasks

## High Priority
- [ ] Fix submarine start position: currently `(1000, 1000)` — should be centered at `(500, 500)`
- [ ] Add torpedo items to equipment locker or map for player acquisition
- [ ] Refine win/loss conditions (mission completion scoring, null-safety on `global.subcom_map.missions`)

## Medium Priority
- [ ] Balance NPC weapon damage, detection ranges, and AI aggression
- [ ] Crew management (track crew members, injuries, assignments, oxygen status)
- [ ] Test full game loop end-to-end (map loads, process ticks run, missions generate, combat works)

## Done
- [x] Overworld framework (map controller, torpedoes, vessel contacts)
- [x] NPC AI with state machine (PATROL → HUNT → ATTACK)
- [x] Enemy type definitions (14 vessel archetypes)
- [x] Water, flooding & atmosphere physics
- [x] Diesel engine support (optional nuclear)
- [x] CSS component library for console UIs
- [x] All 8 console panels restyled
- [x] Expanded mission system (6 types)
- [x] Compartment status panel
- [x] Combat interactions and weapon damage
- [x] Process scheduler integration
- [x] Map metadata and win/loss conditions
- [x] Submarine interior map (58×14 tiles)
- [x] Job definitions (Captain, Officer, Crew)
- [x] Faction setup (AMERICAN, job registration)
