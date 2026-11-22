// What a craft carries (docs/craft-core.md#cargo).
//
// Every carrier asks the same question of each thing on its tiles: built
// hulls and airships at each step, turf-built vessels at each hop, frame
// ships and modular vehicles as they gather what they move, and a ship packed
// for a crossing. Anything that stands in the world rides along: floors,
// structures, crates and chests with what is in them, machines, items, carts,
// small boats, animals and people. What only draws something, or is not
// really there, stays where it is: lighting, flick animations and speech
// bubbles, aiming marks, stack badges, the wake a vessel leaves, ghosts and
// admin observers, players still in the lobby and other abstract mobs. A
// thing that must stay where it was laid (a naval mine, a boathouse pile)
// says so with craft_left_behind().

// TRUE when a craft moving under this thing carries it along.
/atom/movable/proc/craft_cargo()
	return !craft_left_behind()

/atom/movable/lighting_overlay/craft_cargo()
	return FALSE

/atom/movable/lighting_fullbright/craft_cargo()
	return FALSE

/atom/movable/overlay/craft_cargo()
	return FALSE

/atom/movable/stack_count_badge/craft_cargo()
	return FALSE

/obj/chat_text/craft_cargo()
	return FALSE

/obj/screen/craft_cargo()
	return FALSE

/obj/aiming_overlay/craft_cargo()
	return FALSE

/obj/map_metadata/craft_cargo()
	return FALSE

/obj/effect/vessel_path/craft_cargo()
	return FALSE

/mob/observer/craft_cargo()
	return FALSE

/mob/new_player/craft_cargo()
	return FALSE

/mob/dview/craft_cargo()
	return FALSE

/mob/agent_proxy/craft_cargo()
	return FALSE
