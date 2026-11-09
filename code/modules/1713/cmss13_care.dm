// Triage tags, blood trails when dragging the wounded, coloured signal smoke
// and a new-player marker for staff. Ideas from CM-SS13 (cmss13-devs/cmss13,
// AGPL-3.0): the medical HUD triage tags, drag blood trails, signal smoke
// grenades and the new-player HUD icon. Reimplemented for Civ13.

//////////////////////////////////////////////////////////////////////////////
// TRIAGE TAGS: medics tag the wounded red, yellow, green or black.
//////////////////////////////////////////////////////////////////////////////

#define TRIAGE_MEDICAL_SKILL 50

/mob/living/human/var/tmp/triage_tag = null // null, "red", "yellow", "green" or "black"
/mob/living/human/var/tmp/image/triage_overlay = null

/mob/living/human/persistence_runtime_var(key)
	return (key in list("triage_tag", "triage_overlay")) || ..()

/proc/triage_tag_meanings()
	return list(
		"red" = "urgent, treat now",
		"yellow" = "serious, can wait a little",
		"green" = "walking wounded",
		"black" = "beyond help or dead")

/proc/can_triage(mob/living/human/M)
	if (!istype(M) || M.stat != CONSCIOUS)
		return FALSE
	if (M.original_job && M.original_job.is_medic)
		return TRUE
	return M.getStat("medical") >= TRIAGE_MEDICAL_SKILL

// colour: one of the keys of triage_tag_meanings(), or null to remove the tag.
/mob/living/human/proc/set_triage_tag(colour)
	if (colour && !(colour in triage_tag_meanings()))
		return FALSE
	if (triage_overlay)
		overlays -= triage_overlay
		triage_overlay = null
	triage_tag = colour
	if (colour)
		triage_overlay = image('icons/obj/cmss13_ports.dmi', icon_state = "triage_[colour]")
		triage_overlay.appearance_flags = KEEP_APART
		overlays += triage_overlay
	return TRUE

/mob/living/human/update_icons()
	. = ..()
	if (triage_overlay)
		overlays |= triage_overlay

/mob/living/human/verb/triage_tag_verb()
	set name = "Triage Tag"
	set category = null
	set src in view(1)
	var/mob/living/human/M = usr
	if (!istype(M) || !M.Adjacent(src))
		return
	if (!can_triage(M))
		to_chat(M, "<span class='warning'>Only medics and people with medical training can triage.</span>")
		return
	var/list/meanings = triage_tag_meanings()
	var/list/choices = list()
	for (var/colour in meanings)
		choices["[capitalize(colour)]: [meanings[colour]]"] = colour
	if (triage_tag)
		choices["Remove the tag"] = "remove"
	var/pick = player_input(M, "Tag [src] as:", "Triage Tag", null, "anything", choices, TRUE)
	if (!pick || !M.Adjacent(src) || !can_triage(M))
		return
	var/colour = choices[pick]
	if (colour == "remove")
		set_triage_tag(null)
		M.visible_message("<span class='notice'>[M] removes the triage tag from [src].</span>", "<span class='notice'>You remove the triage tag from [src].</span>")
		return
	set_triage_tag(colour)
	M.visible_message("<span class='notice'>[M] tags [src] [colour].</span>", "<span class='notice'>You tag [src] [colour]: [meanings[colour]].</span>")

/mob/living/human/examine(mob/user)
	. = ..()
	if (triage_tag)
		var/list/meanings = triage_tag_meanings()
		to_chat(user, "<span class='notice'>[src] wears a <b>[triage_tag]</b> triage tag: [meanings[triage_tag]].</span>")
	if (user && user.client && new_player_marks && new_player_marks.staff_can_see(user.client) && client && new_player_marks.is_new(client))
		to_chat(user, "<span class='notice'>Staff: [key] is a new player ([new_player_marks.age_text(client)]).</span>")

#undef TRIAGE_MEDICAL_SKILL

//////////////////////////////////////////////////////////////////////////////
// DRAG TRAILS: a bleeding body dragged along the ground leaves a smear.
//////////////////////////////////////////////////////////////////////////////

/obj/effect/decal/cleanable/blood/drag
	name = "blood smear"
	dryname = "dried blood smear"
	desc = "Someone was dragged through here, bleeding."
	drydesc = "An old smear of dried blood, as if someone was dragged through here."
	icon = 'icons/obj/cmss13_ports.dmi'
	icon_state = "drag_trail"
	random_icon_states = null
	amount = 0 // too thin to track on boots

/mob/living/human/proc/is_bleeding_out()
	if (species && species.flags & NO_BLOOD)
		return FALSE
	for (var/obj/item/organ/external/E in organs)
		if (E.status & ORGAN_BLEEDING)
			return TRUE
	return FALSE

// One smear per turf, pointing the way the body went.
/mob/living/human/proc/leave_drag_trail(turf/T, direction)
	if (!isturf(T) || !direction)
		return null
	if (locate(/obj/effect/decal/cleanable/blood/drag) in T)
		return null
	var/obj/effect/decal/cleanable/blood/drag/D = new(T)
	D.dir = direction
	if (species)
		D.basecolor = species.get_blood_colour(src)
	D.update_icon()
	if (dna && dna.unique_enzymes)
		D.blood_DNA[dna.unique_enzymes] = dna.b_type
	return D

/mob/living/human/Move()
	var/turf/old_turf = loc
	. = ..()
	if (pulledby && lying && isturf(old_turf) && loc != old_turf && is_bleeding_out())
		leave_drag_trail(old_turf, get_dir(old_turf, loc))

//////////////////////////////////////////////////////////////////////////////
// SIGNAL SMOKE: coloured smoke to mark a position. No supply drop.
//////////////////////////////////////////////////////////////////////////////

/obj/item/weapon/grenade/smokebomb/marker
	name = "signal smoke grenade"
	desc = "Thick coloured smoke for marking a position, a landing zone or a target. It is set to detonate in 3 seconds."
	det_time = 30
	var/smoke_colour_type = null

/obj/item/weapon/grenade/smokebomb/marker/New()
	..()
	if (smoke_colour_type)
		qdel(smoke)
		smoke = PoolOrNew(smoke_colour_type)
		smoke.attach(src)

/obj/item/weapon/grenade/smokebomb/marker/red
	name = "red signal smoke grenade"
	icon_state = "m18smoke_red"
	item_state = "m18smoke_red"
	smoke_colour_type = /datum/effect/effect/system/smoke_spread/red

/obj/item/weapon/grenade/smokebomb/marker/green
	name = "green signal smoke grenade"
	icon = 'icons/obj/cmss13_ports.dmi'
	icon_state = "m18smoke_green"
	item_state = "m18smoke"
	smoke_colour_type = /datum/effect/effect/system/smoke_spread/green

/obj/item/weapon/grenade/smokebomb/marker/yellow
	name = "yellow signal smoke grenade"
	icon_state = "rdg2_yellow"
	item_state = "rdg2_yellow"
	smoke_colour_type = /datum/effect/effect/system/smoke_spread/yellow

/obj/item/weapon/grenade/smokebomb/marker/purple
	name = "purple signal smoke grenade"
	icon_state = "m18smoke_purple"
	item_state = "m18smoke_purple"
	smoke_colour_type = /datum/effect/effect/system/smoke_spread/purple

//////////////////////////////////////////////////////////////////////////////
// NEW-PLAYER MARKER: admins and mentors see a sprout over players first seen
// less than two days ago, so they can offer help.
//////////////////////////////////////////////////////////////////////////////

#define NEW_PLAYER_AGE (2 * 24 * 60 * 60 * 10) // deciseconds

/client/var/tmp/player_age_known = FALSE

var/global/datum/new_player_marks/new_player_marks = new

/datum/new_player_marks
	var/list/marks = list() // ckey -> image over that player's mob

/datum/new_player_marks/proc/staff_can_see(client/C)
	return istype(C) && C.holder

/datum/new_player_marks/proc/is_new(client/C)
	return istype(C) && C.player_age_known && isnum(C.player_age) && C.player_age < NEW_PLAYER_AGE

/datum/new_player_marks/proc/age_text(client/C)
	var/hours = round(C.player_age / 36000)
	return hours < 1 ? "first seen this hour" : "first seen [hours] hour\s ago"

/datum/new_player_marks/proc/make_mark(mob/M)
	var/image/I = image('icons/obj/cmss13_ports.dmi', M, "new_player")
	I.layer = FLY_LAYER
	I.appearance_flags = RESET_TRANSFORM | KEEP_APART
	return I

// Put the mark on the player's current mob, or take it away once they are
// no longer new. Called when the age is known and on every login.
/datum/new_player_marks/proc/refresh(client/C)
	if (!istype(C) || !C.ckey)
		return null
	var/image/I = marks[C.ckey]
	if (!is_new(C) || !C.mob)
		if (I)
			drop(C.ckey)
		return null
	if (!I)
		I = make_mark(C.mob)
		marks[C.ckey] = I
		for (var/client/S in clients)
			if (staff_can_see(S))
				S.images |= I
	else
		I.loc = C.mob
	return I

/datum/new_player_marks/proc/drop(ckey)
	var/image/I = marks[ckey]
	marks -= ckey
	if (I)
		for (var/client/S in clients)
			S.images -= I

/datum/new_player_marks/proc/show_to(client/S)
	if (!staff_can_see(S))
		return
	for (var/ckey in marks)
		S.images |= marks[ckey]

/client/proc/player_age_logged()
	player_age_known = TRUE
	if (new_player_marks)
		new_player_marks.refresh(src)

/mob/Login()
	. = ..()
	if (client && new_player_marks)
		new_player_marks.refresh(client)
		new_player_marks.show_to(client)

#undef NEW_PLAYER_AGE
