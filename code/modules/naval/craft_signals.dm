// ============================================================
// Hails and running dark (docs/craft-core.md)
// ------------------------------------------------------------
// A ship speaks to another ship her lookout can see: the helm hails her and
// both crews hear it, with the distance and bearing it came from.
//
// A ship running dark shows no lights and keeps her name to herself: other
// ships' charts and radar list her as an unknown contact, and her hails come
// from "an unknown ship". Ships of her own owners still know her. Running
// dark she makes slow ahead at most. It is not saved: after a restart she
// shows her lights again.
// ============================================================

#define CRAFT_HAIL_COOLDOWN 50
#define CRAFT_HAIL_LENGTH 200

/datum/craft
	var/tmp/running_dark = FALSE
	// The last hail her crew heard, and when her helm last sent one.
	var/tmp/last_hail = ""
	var/tmp/last_hailed_at = 0

// TRUE when this craft knows who the other is: she shows herself, or both
// answer to the same owners.
/datum/craft/proc/knows(datum/craft/other)
	if (!other)
		return FALSE
	if (!other.running_dark)
		return TRUE
	var/mine = party()
	return mine && mine == other.party()

// What this craft calls the other.
/datum/craft/proc/name_of(datum/craft/other)
	return knows(other) ? other.name : "unknown contact"

// Douses or shows her lights. Returns TRUE when it changed.
/datum/craft/proc/set_dark(state)
	state = state ? TRUE : FALSE
	if (running_dark == state)
		return FALSE
	running_dark = state
	if (token)
		token.dark = state
	if (body)
		body.dark_changed(state)
	return TRUE

// A dark ship makes slow ahead at most.
/datum/craft_body/proc/dark_changed(state)
	if (state && craft && craft.speed > VESSEL_SPEED_SLOW)
		craft.set_speed(VESSEL_SPEED_SLOW)

/datum/craft_body/template/dark_changed(state)
	if (!vessel)
		return
	if (state)
		vessel.set_deck_lights(FALSE)
		if (vessel.speed > VESSEL_SPEED_SLOW)
			vessel.set_speed(VESSEL_SPEED_SLOW)
	else
		vessel.set_deck_lights(TRUE)

// The fastest step a vessel may ring now: her own limit, or slow ahead
// while her craft runs dark.
/datum/vessel/proc/speed_cap()
	var/datum/craft/C = craft_of_vessel(src, FALSE)
	if (C && C.running_dark)
		return min(max_speed, VESSEL_SPEED_SLOW)
	return max_speed

// The ships her lookout can see, nearest first: label = craft.
/datum/craft/proc/hail_candidates()
	. = list()
	var/turf/here = centre()
	if (!here)
		return
	var/list/found = list()
	for (var/datum/craft/C in crafts)
		if (C == src)
			continue
		var/turf/P = C.centre()
		if (!P || !sights(C))
			continue
		found += C
	while (found.len)
		var/datum/craft/nearest = null
		var/best = INFINITY
		for (var/datum/craft/C in found)
			var/d = get_dist(here, C.centre())
			if (d < best)
				best = d
				nearest = C
		found -= nearest
		var/label = "[capitalize(name_of(nearest))], [best] tile\s [submarine_bearing(here, nearest.centre())]"
		while (.[label])
			label += " "
		.[label] = nearest

// Calls across the water. Returns TRUE when the other crew heard it, FALSE
// with last_refusal set when they could not.
/datum/craft/proc/hail(datum/craft/other, text, mob/from)
	var/turf/here = centre()
	var/turf/there = other ? other.centre() : null
	if (!here || !there || other == src)
		last_refusal = "there is nobody to hail"
		return FALSE
	if (!sights(other))
		last_refusal = "she is out of sight"
		return FALSE
	if (!length(text))
		last_refusal = "there is nothing to say"
		return FALSE
	if (last_hailed_at && world.time < last_hailed_at + CRAFT_HAIL_COOLDOWN)
		last_refusal = "the last hail is still carrying across the water"
		return FALSE
	last_hailed_at = world.time
	var/who = other.knows(src) ? "the [name]" : "an unknown ship"
	other.last_hail = "Hail from [who], [get_dist(there, here)] tile\s [submarine_bearing(there, here)]: \"[text]\""
	other.crew_message(SPAN_NOTICE("<b>[other.last_hail]</b>"))
	crew_message(SPAN_NOTICE("[from ? "[from] hails" : "The [name] hails"] [knows(other) ? "the [other.name]" : "the unknown contact"]: \"[text]\""))
	return TRUE

// The helm's hail menu.
/datum/craft/proc/hail_menu(mob/living/human/H, atom/at)
	if (!istype(H) || QDELETED(at))
		return
	var/list/choices = hail_candidates()
	if (!choices.len)
		to_chat(H, SPAN_WARNING("The lookout sees no other ship within [lookout_range()] tiles of the [name]."))
		return
	var/choice = WWinput(H, "Hail which ship? Her whole crew hears it.", "Hail", "Cancel", choices + list("Cancel"))
	var/datum/craft/other = choices[choice]
	if (!istype(other) || QDELETED(src) || QDELETED(at) || get_dist(H, at) > 1)
		return
	var/text = player_input(H, "What do you call across to her?", "Hail", "", "text", null, TRUE)
	if (isnull(text) || QDELETED(src) || QDELETED(other) || QDELETED(at) || get_dist(H, at) > 1)
		return
	text = sanitize(copytext(text, 1, CRAFT_HAIL_LENGTH))
	if (!hail(other, text, H))
		to_chat(H, SPAN_WARNING("The hail is not heard: [last_refusal]."))
		return
	log_game("[key_name(H)] hailed the [other.name] from the [name]: [text]")

// Run dark or show her lights, from the helm.
/datum/craft/proc/dark_menu(mob/living/human/H, atom/at, state)
	if (!set_dark(state))
		return
	log_game("[key_name(H)] [state ? "ran the [name] dark" : "showed the [name]'s lights"].")
	if (state)
		crew_message(SPAN_NOTICE("[H] at the [at.name]: run dark. Other ships see a contact without a name, and slow ahead is all she makes."))
	else
		crew_message(SPAN_NOTICE("[H] at the [at.name]: show her lights. Other ships know her again."))
