// ============================================================
// Heteromorphs: characters with a second, non-human true form, played only
// by staff as gods or for staff-run events. Hidden mechanic: keep it out of
// changelog lines, the wiki and the public Crafting Atlas.
// ------------------------------------------------------------
// A heteromorph looks like an ordinary human (its guise) and later phases add
// the true form, flight and breath. This file holds the shared registry, the
// grant and revoke steps, the saved state and the close-range guise clues.
//
// Each kind is a /datum/heteromorph subtype. `origin` names the world a kind
// may be created on: null means anywhere a god grants it, while a planet id
// (for example "yggdrasil") limits creation to that planet once it exists.
// ============================================================

/datum/heteromorph
	var/id = null              // saved on the human as heteromorph_id
	var/name = null            // shown to staff only
	var/origin = null          // null: any world; otherwise a planet id
	var/staff_only = TRUE      // only staff-run characters may carry it
	var/list/colours = null    // colour id -> staff label; first is the default
	var/list/guise_clues = null // colour id -> the line seen within one tile

/datum/heteromorph/proc/default_colour()
	return length(colours) ? colours[1] : null

/datum/heteromorph/proc/guise_clue(colour)
	if (!islist(guise_clues))
		return null
	return guise_clues[colour] ? guise_clues[colour] : guise_clues[default_colour()]

/datum/heteromorph/dragonoid
	id = "dragonoid"
	name = "Dragonoid"
	colours = list("gold" = "Gold", "ash" = "Ash (dark red)")
	guise_clues = list("gold" = "Their eyes catch the light like beaten gold, and a faint warmth and smell of woodsmoke hang about them.", "ash" = "Their eyes glint a hard yellow, and the air about them is warm and smells of cinders.")

// id -> /datum/heteromorph, built on first use.
var/global/list/heteromorph_kinds = null

/proc/heteromorph_kinds()
	if (islist(heteromorph_kinds))
		return heteromorph_kinds
	heteromorph_kinds = list()
	for (var/kind in subtypesof(/datum/heteromorph))
		var/datum/heteromorph/K = new kind
		if (istext(K.id) && length(K.id))
			heteromorph_kinds[K.id] = K
	return heteromorph_kinds

/proc/heteromorph_kind(id)
	if (!istext(id))
		return null
	var/list/L = heteromorph_kinds()
	return L[id]

// The planet the current world stands for, or null for Earth worlds. No
// planet exists yet, so every world is Earth until one sets this.
/proc/heteromorph_world_origin()
	return null

/mob/living/human
	var/heteromorph_id = null          // saved: kind id, see heteromorph_kinds()
	var/heteromorph_colour = null      // saved: colour id within that kind
	var/heteromorph_granted_by = null  // saved: ckey of the staff member who granted it
	var/heteromorph_cooldown_until = 0 // saved: world.realtime before the true form can be taken again

// Whether this character is run by someone who holds admin rights now. The
// form stays saved when they lose them, but it goes quiet.
/mob/living/human/proc/heteromorph_staff_run()
	if (!ckey)
		return FALSE
	var/datum/admins/D = admin_datums[ckey]
	return D && (D.rights & R_ADMIN)

// The kind this character may use right now, or null.
/mob/living/human/proc/heteromorph_active()
	var/datum/heteromorph/K = heteromorph_kind(heteromorph_id)
	if (!K)
		return null
	if (K.staff_only && !heteromorph_staff_run())
		return null
	return K

// Why this kind cannot be granted to this character here, or null.
/mob/living/human/proc/heteromorph_grant_problem(datum/heteromorph/K)
	if (!K)
		return "No such form."
	if (stat == DEAD)
		return "[real_name] is dead."
	if (K.staff_only && !heteromorph_staff_run())
		return "[real_name] is not played by staff. Only a god's own character or a staff-run event character may carry this form."
	if (K.origin && K.origin != heteromorph_world_origin())
		return "This form can only be created on [K.origin]."
	return null

/mob/living/human/proc/heteromorph_grant(datum/heteromorph/K, colour, by_ckey)
	var/problem = heteromorph_grant_problem(K)
	if (problem)
		return problem
	if (!islist(K.colours) || !(colour in K.colours))
		colour = K.default_colour()
	heteromorph_id = K.id
	heteromorph_colour = colour
	heteromorph_granted_by = ckey(by_ckey)
	heteromorph_cooldown_until = 0
	heteromorph_log("[by_ckey] made [key_name(src)] a [K.name] ([colour]).")
	heteromorph_refresh_verbs() // heteromorph_form.dm
	return null

/mob/living/human/proc/heteromorph_revoke(by_ckey)
	var/datum/heteromorph/K = heteromorph_kind(heteromorph_id)
	if (!heteromorph_id)
		return FALSE
	var/mob/living/simple_animal/heteromorph_form/F = loc
	if (istype(F) && F.heteromorph_body == src)
		F.heteromorph_return(FALSE, "Your true form is taken from you.") // heteromorph_form.dm
	heteromorph_log("[by_ckey] took the [K ? K.name : heteromorph_id] form from [key_name(src)].")
	heteromorph_id = null
	heteromorph_colour = null
	heteromorph_granted_by = null
	heteromorph_cooldown_until = 0
	heteromorph_refresh_verbs()
	return TRUE

// Every heteromorph event goes to the admin log and to staff online, so
// other staff always see a god acting in this way.
/proc/heteromorph_log(text)
	log_admin("Heteromorph: [text]")
	message_admins("Heteromorph: [text]")

// One plain line for someone standing next to them (human examine.dm). The
// guise is meant to be noticed by the attentive, never announced.
/mob/living/human/proc/heteromorph_examine(mob/user)
	if (!user || user == src || get_dist(user, src) > 1)
		return ""
	var/datum/heteromorph/K = heteromorph_active()
	if (!K)
		return ""
	var/clue = K.guise_clue(heteromorph_colour)
	return clue ? "<br><i>[clue]</i>" : ""

// Staff overview for Divine Patron > List heteromorphs.
/proc/heteromorph_staff_lines()
	var/list/lines = list()
	for (var/mob/living/human/H in human_mob_list)
		if (QDELETED(H) || !H.heteromorph_id)
			continue
		var/datum/heteromorph/K = heteromorph_kind(H.heteromorph_id)
		lines += "[H.real_name] ([H.ckey ? H.ckey : "no player"]): [K ? K.name : H.heteromorph_id] ([H.heteromorph_colour]), granted by [H.heteromorph_granted_by ? H.heteromorph_granted_by : "unknown"][H.heteromorph_active() ? "" : ", QUIET (not staff-run now)"][H.stat == DEAD ? ", dead" : ""]"
	return lines
