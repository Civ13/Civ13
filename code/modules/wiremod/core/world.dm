// Where a circuit is in the world and what it may do there. A component that
// senses or acts on the world works from the shell the circuit is installed in.
// A loose circuit has no shell and so no place to act from: every helper gives
// nothing then, and a circuit inside a locked container cannot reach through it.

/proc/wiremod_circuit_shell(obj/item/integrated_circuit/circuit)
	if(!istype(circuit))
		return null
	var/obj/item/circuit_shell/shell = circuit.loc
	return istype(shell) ? shell : null

// The thing a circuit acts as: its shell. A loose circuit has no anchor, so
// none of the world-facing components can sense or act through it.
/proc/wiremod_anchor(obj/item/integrated_circuit/circuit)
	return wiremod_circuit_shell(circuit)

/proc/wiremod_anchor_turf(obj/item/integrated_circuit/circuit)
	var/atom/anchor = wiremod_anchor(circuit)
	return anchor ? get_turf(anchor) : null

// The shell a circuit is installed in, or null. Kept as a separate name so the
// action components say plainly that a circuit in a pocket cannot light, speak,
// print or transmit into the world.
/proc/wiremod_shell(obj/item/integrated_circuit/circuit)
	return wiremod_circuit_shell(circuit)

/proc/wiremod_shell_turf(obj/item/integrated_circuit/circuit)
	var/atom/shell = wiremod_shell(circuit)
	return shell ? get_turf(shell) : null

// The air around the anchor, or null when there is no turf.
/proc/wiremod_anchor_air(obj/item/integrated_circuit/circuit)
	var/turf/here = wiremod_anchor_turf(circuit)
	return here ? here.return_air() : null

// Every movable thing the anchor can see, as weak references, without the
// circuit or its shell. Bounded by CIRCUIT_MAX_VIEW_ENTITIES.
/proc/wiremod_anchor_view(obj/item/integrated_circuit/circuit)
	var/list/result = list()
	var/turf/here = wiremod_anchor_turf(circuit)
	if(!here)
		return result
	var/atom/anchor = wiremod_anchor(circuit)
	for(var/atom/movable/thing in view(CIRCUIT_DIRECTION_RANGE, here))
		if(thing == anchor || thing == circuit)
			continue
		if(length(result) >= CIRCUIT_MAX_VIEW_ENTITIES)
			break
		result += WEAKREF(thing)
	return result

// Plays a sound from the anchor at a chosen pitch. The caller has checked the
// sound against its own list of allowed files and clamped the volume. The sound
// reaches the players who can hear the anchor, with a steady pitch rather than
// the random one the general sound helper picks.
/proc/wiremod_anchor_sound(obj/item/integrated_circuit/circuit, sound_file, volume, frequency)
	var/turf/here = wiremod_shell_turf(circuit)
	if(!here || !sound_file)
		return FALSE
	for(var/mob/listener in player_list)
		if(!listener.client)
			continue
		var/turf/theirs = get_turf(listener)
		if(!theirs || theirs.z != here.z)
			continue
		if(get_dist(here, theirs) > CIRCUIT_DIRECTION_RANGE)
			continue
		listener.playsound_local(here, sound_file, volume, TRUE, frequency)
	return TRUE

// Has the anchor say something out loud. The text is escaped; the caller has
// capped its length.
/proc/wiremod_anchor_say(obj/item/integrated_circuit/circuit, message)
	var/atom/anchor = wiremod_shell(circuit)
	if(!anchor || !istext(message))
		return FALSE
	anchor.visible_message("<span class='game say'><b>[html_encode(anchor.name)]</b> says, \"[html_encode(message)]\"</span>")
	return TRUE

// Turns a light on the anchor on or off. Off restores it to no light.
/proc/wiremod_anchor_light(obj/item/integrated_circuit/circuit, is_on)
	var/atom/anchor = wiremod_shell(circuit)
	if(!anchor)
		return FALSE
	if(is_on)
		anchor.set_light(CIRCUIT_LIGHT_RANGE, CIRCUIT_LIGHT_POWER, "#fff4d6")
	else
		anchor.set_light(0, 0)
	return TRUE

// The turf at bounded coordinates on a level. Components look a place up by
// coordinates here, never by looking up a typepath from a player's request.
/proc/wiremod_turf_at(x, y, z)
	if(!isnum(x) || !isnum(y) || !isnum(z))
		return null
	x = round(x)
	y = round(y)
	z = round(z)
	if(x < 1 || x > world.maxx || y < 1 || y > world.maxy || z < 1 || z > world.maxz)
		return null
	return locate(x, y, z)

// The name of a BYOND direction, or null for none.
/proc/wiremod_compass_name(direction)
	var/static/list/compass = list(
		"[NORTH]" = "north", "[SOUTH]" = "south", "[EAST]" = "east", "[WEST]" = "west",
		"[NORTHEAST]" = "northeast", "[NORTHWEST]" = "northwest",
		"[SOUTHEAST]" = "southeast", "[SOUTHWEST]" = "southwest",
	)
	return compass["[direction]"]

// A living thing's health, or null for anything that is not a mob.
/proc/wiremod_entity_health(value)
	var/mob/living/target = wiremod_entity(value)
	if(!istype(target))
		return null
	return wiremod_safe_number(target.health)

// A person's species name, or null for anything that has no species.
/proc/wiremod_entity_species(value)
	var/mob/living/human/target = wiremod_entity(value)
	if(!istype(target) || !target.species)
		return null
	return wiremod_safe_text(target.species.name)

// What an item is made of, as material name to amount. Base materials are held
// as flat name and amount pairs; a metal item's dominant material is added when
// it is not already listed.
/proc/wiremod_entity_materials(value)
	var/obj/item/target = wiremod_entity(value)
	if(!istype(target))
		return null
	var/list/materials = list()
	var/list/base = target.basematerials
	for(var/index = 1, index + 1 <= length(base) && length(materials) < CIRCUIT_MAX_ASSOC_ENTRIES, index += 2)
		var/material_name = base[index]
		var/amount = wiremod_safe_number(base[index + 1])
		if(!istext(material_name) || isnull(amount))
			continue
		var/material_key = lowertext(material_name)
		// Construction calls the common metal Metal; the scanner names it Iron.
		if(material_key == "metal")
			material_key = "iron"
		materials[material_key] = amount
	var/material/dominant = target.get_material()
	if(istype(dominant) && istext(dominant.name) && length(materials) < CIRCUIT_MAX_ASSOC_ENTRIES)
		var/dominant_name = lowertext(dominant.name)
		if(!(dominant_name in materials))
			materials[dominant_name] = 1
	return materials

// What a container holds, as reagent id to volume, or null for a thing that
// holds no reagents.
/proc/wiremod_entity_reagents(value)
	var/atom/target = wiremod_entity(value)
	if(!istype(target) || !target.reagents)
		return null
	var/list/reagents = list()
	for(var/datum/reagent/reagent in target.reagents.reagent_list)
		if(length(reagents) >= CIRCUIT_MAX_ASSOC_ENTRIES)
			break
		if(!istext(reagent.id))
			continue
		reagents[reagent.id] = wiremod_safe_number(reagent.volume)
	return reagents
