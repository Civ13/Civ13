// Practice rooms: from the lobby, a player takes a throwaway body into a
// private 12 x 12 room and follows short scripted steps (walk, pick up, swap
// hands, wear, doors, intents, bandaging, eating), then returns to the lobby.
// Nothing done there touches the player's real character or the world.
//
// Design reference: CM-SS13's tutorial rooms (code/datums/tutorial/,
// https://github.com/cmss13-devs/cmss13, AGPL-3.0). This is a reimplementation
// for Civ13 without signals, tgui or turf reservations; no CM code is copied.
//
// The rooms live on one extra level appended above the world while anyone
// practises. That level is never saved or built on: a save closes every room
// and removes the level first (begin_persistence_operation), an idle level is
// removed after PRACTICE_IDLE_DROP, and while it exists world_z_budget refuses
// every other new level, so it is always world.maxz and can be removed whole.

#define PRACTICE_ROOM_SIZE 12
#define PRACTICE_ROOM_PITCH 14
#define PRACTICE_MAX_ROOMS 8
#define PRACTICE_IDLE_DROP (5 MINUTES)
// A practice level is Gaia-sized at most. A 500 x 350 open-air plane measured
// 0.3 s and 20 MiB to add (building_admission.dm); this one only exists while
// someone practises and is removed before any save, so it never reaches a load.
#define PRACTICE_MAX_PLANE_CELLS 175000

var/global/practice_room_z = 0
var/global/datum/practice_rooms/practice_rooms = new

/area/caribbean/admin/practice
	name = "Practice Room"
	icon_state = "green1"
	dynamic_lighting = FALSE

/datum/world_z_budget/proc/practice_admitted(target_z)
	return target_z == world.maxz + 1 && world.maxx * world.maxy <= PRACTICE_MAX_PLANE_CELLS && !instance_reserve && !safehouse_reserve && !orbit_world()

/datum/practice_rooms
	var/list/sessions = list() // "[slot]" -> /datum/practice_session
	var/idle_timer
	var/last_error

/datum/practice_rooms/proc/capacity()
	var/cols = round((world.maxx - 1) / PRACTICE_ROOM_PITCH)
	var/rows = round((world.maxy - 1) / PRACTICE_ROOM_PITCH)
	return max(0, min(PRACTICE_MAX_ROOMS, cols * rows))

// Why a lobby player cannot enter now, or null.
/datum/practice_rooms/proc/entry_error()
	if (!map || !ticker || capacity() < 1)
		return "Practice rooms are not available on this map."
	if (orbit_world() || world_z_budget.instance_reserve || world_z_budget.safehouse_reserve || world.maxx * world.maxy > PRACTICE_MAX_PLANE_CELLS)
		return "Practice rooms are not available on this map."
	if (persistence_save_in_progress || persistence_active_operation || persistence_restart.startup_hold || persistence_restart.busy)
		return "The world is saving or loading. Try again in a minute."
	if (sessions.len >= capacity())
		return "All practice rooms are in use. Try again in a few minutes."
	if (!practice_room_z && world_z_budget.error(world.maxz + 1, "practice"))
		return "Practice rooms are unavailable right now. Try again in a few minutes."
	return null

/datum/practice_rooms/proc/free_slot()
	for (var/slot = 1 to capacity())
		if (!sessions["[slot]"])
			return slot
	return 0

/datum/practice_rooms/proc/slot_origin(slot)
	var/cols = round((world.maxx - 1) / PRACTICE_ROOM_PITCH)
	var/col = (slot - 1) % cols
	var/row = round((slot - 1) / cols)
	return list(2 + col * PRACTICE_ROOM_PITCH, 2 + row * PRACTICE_ROOM_PITCH)

/datum/practice_rooms/proc/slot_turfs(slot)
	var/list/O = slot_origin(slot)
	return block(locate(O[1], O[2], practice_room_z), locate(O[1] + PRACTICE_ROOM_SIZE - 1, O[2] + PRACTICE_ROOM_SIZE - 1, practice_room_z))

// Adds the level through the shared budget. No sleeps between admission and
// publication, like the other level owners.
/datum/practice_rooms/proc/ensure_level()
	if (practice_room_z)
		return TRUE
	var/target_z = world.maxz + 1
	var/datum/new_z_reservation/reservation = world_z_budget.reserve(target_z, "practice")
	if (!reservation)
		last_error = world_z_budget.last_error
		return FALSE
	if (!world_z_budget.claim_level(reservation, target_z))
		last_error = world_z_budget.last_error
		world_z_budget.finish(reservation, FALSE)
		return FALSE
	building_allocating_z = target_z
	try
		world.maxz = target_z
	catch (var/exception/allocation_error)
		world_z_budget.finish(reservation, FALSE)
		throw allocation_error
	building_allocating_z = 0
	if (!world_z_budget.finish(reservation, world.maxz == target_z))
		return FALSE
	practice_room_z = target_z
	if (map)
		map.zlevels_without_lighting |= target_z
	log_game("Practice level added at z [target_z].")
	return TRUE

// Removes the level once no room is in use. Returns TRUE when it is gone.
/datum/practice_rooms/proc/drop_level()
	if (!practice_room_z)
		return TRUE
	if (sessions.len)
		return FALSE
	if (practice_room_z != world.maxz)
		log_game("Practice level z [practice_room_z] is not the top level ([world.maxz]); kept.")
		return FALSE
	for (var/slot = 1 to capacity())
		wipe_room(slot)
		for (var/turf/T in slot_turfs(slot))
			turfs -= T
			turf_registry_members -= T
			new_turfs -= T
	var/z = practice_room_z
	practice_room_z = 0
	if (map)
		map.zlevels_without_lighting -= z
	world.maxz = z - 1
	log_game("Practice level z [z] removed.")
	return TRUE

/datum/practice_rooms/proc/schedule_idle_drop()
	if (idle_timer)
		deltimer(idle_timer)
	idle_timer = addtimer(CALLBACK(src, PROC_REF(idle_drop)), PRACTICE_IDLE_DROP, TIMER_STOPPABLE)

/datum/practice_rooms/proc/idle_drop()
	idle_timer = null
	if (!sessions.len && !persistence_save_in_progress)
		drop_level()

// Deletes everything movable in a room except player-controlled mobs.
/datum/practice_rooms/proc/wipe_room(slot)
	for (var/turf/T in slot_turfs(slot))
		for (var/atom/movable/AM in T)
			if (ismob(AM) && AM:client)
				continue
			if (istype(AM, /atom/movable/lighting_overlay))
				continue
			qdel(AM)

// Builds one room: wall ring, wooden floor, a partition with a door, and the
// props each step needs. Returns the session's prop list.
/datum/practice_rooms/proc/build_room(slot)
	var/list/O = slot_origin(slot)
	var/x1 = O[1]
	var/y1 = O[2]
	var/x2 = x1 + PRACTICE_ROOM_SIZE - 1
	var/y2 = y1 + PRACTICE_ROOM_SIZE - 1
	var/z = practice_room_z
	var/split = x1 + 6
	var/area/A = locate(/area/caribbean/admin/practice) in area_list
	if (!A)
		A = new /area/caribbean/admin/practice
	A.contents.Add(slot_turfs(slot))
	wipe_room(slot)
	var/old_bulk = wall_bulk_placement
	wall_bulk_placement = TRUE
	for (var/turf/T in slot_turfs(slot))
		if (T.x == x1 || T.x == x2 || T.y == y1 || T.y == y2 || (T.x == split && T.y != y1 + 5))
			if (!istype(T, /turf/wall/indestructable))
				new /turf/wall/indestructable(T)
		else if (!istype(T, /turf/floor/wood))
			new /turf/floor/wood(T)
	wall_bulk_placement = old_bulk
	var/list/props = list()
	props["start"] = locate(x1 + 2, y1 + 2, z)
	props["marker"] = new /obj/effect/practice_marker(locate(x1 + 4, y1 + 8, z))
	props["knife"] = new /obj/item/weapon/material/kitchen/utensil/knife(locate(x1 + 2, y1 + 8, z))
	props["hat"] = new /obj/item/clothing/head/strawhat(locate(x1 + 4, y1 + 4, z))
	props["door"] = new /obj/structure/simple_door/key_door/anyone/wood(locate(split, y1 + 5, z))
	props["dummy"] = new /obj/structure/practice_dummy/indestructible/practice_room(locate(x1 + 9, y1 + 9, z))
	props["gauze"] = new /obj/item/stack/medical/bruise_pack(locate(x1 + 8, y1 + 3, z))
	props["bread"] = new /obj/item/weapon/reagent_containers/food/snacks/breadslice(locate(x1 + 10, y1 + 3, z))
	props["exit"] = new /obj/effect/practice_marker/exit(locate(x1 + 10, y1 + 6, z))
	props["split"] = split
	return props

// Lobby entry. Returns TRUE when the player is now in a room.
/datum/practice_rooms/proc/enter(mob/new_player/lobby)
	if (!istype(lobby) || !lobby.client || lobby.spawning)
		return FALSE
	var/reason = entry_error()
	if (reason)
		to_chat(lobby, SPAN_WARNING(reason))
		return FALSE
	if (!ensure_level())
		to_chat(lobby, SPAN_WARNING("Practice rooms are unavailable right now. Try again in a few minutes."))
		return FALSE
	if (idle_timer)
		deltimer(idle_timer)
		idle_timer = null
	var/slot = free_slot()
	if (!slot)
		return FALSE
	var/datum/practice_session/S = new(src, slot, build_room(slot))
	sessions["[slot]"] = S
	if (!S.start(lobby))
		finish(S)
		return FALSE
	log_game("[key_name(S.body)] entered practice room [slot].")
	return TRUE

/datum/practice_rooms/proc/finish(datum/practice_session/S)
	for (var/key in sessions)
		if (sessions[key] == S)
			sessions -= key
			break
	wipe_room(S.slot)
	if (!sessions.len && practice_room_z)
		schedule_idle_drop()

// Before every save: send everyone back to the lobby and remove the level.
/datum/practice_rooms/proc/close_all(reason)
	for (var/key in sessions.Copy())
		var/datum/practice_session/S = sessions[key]
		S.end(reason)
	if (idle_timer)
		deltimer(idle_timer)
		idle_timer = null
	return drop_level()

// Lets the persistence admission ask for the level to go before a save.
/proc/practice_rooms_close_for_save()
	if (!practice_room_z && !practice_rooms.sessions.len)
		return TRUE
	return practice_rooms.close_all("The world is saving, so the practice room closed. You are back in the lobby.")

/proc/practice_send_to_lobby(client/C)
	set waitfor = FALSE
	if (!C)
		return
	var/mob/new_player/lobby = new
	lobby.key = C.key

// ---- Steps ----

/datum/practice_session
	var/datum/practice_rooms/owner
	var/slot
	var/list/props
	var/mob/living/human/practice/body
	var/step = 0
	var/start_hand
	var/timer
	var/ending = FALSE
	var/list/steps = list(
		"walk" = "Walk onto the glowing marker. Use W, A, S, D or the arrow keys.",
		"pick_up" = "Pick up the knife: click it while your active hand is empty.",
		"swap" = "Swap hands with X, or click the other hand on your HUD.",
		"wear" = "Pick up the straw hat, then click your head slot on the HUD (or use it in hand) to wear it.",
		"door" = "Click the door in the middle wall to open it, then walk through to the east half of the room.",
		"harm" = "Choose the red Harm intent (press 4, or click the intent box on your HUD), then hit the practice dummy.",
		"bandage" = "You have a cut on your left arm. Pick up the gauze, select your left arm on the body doll (bottom right of the HUD), then click yourself with the gauze.",
		"eat" = "Pick up the bread slice and click yourself with it to take a bite.",
		"exit" = "Well done! Walk onto the exit marker, or use the Leave Practice Room verb, to return to the lobby.")

/datum/practice_session/New(datum/practice_rooms/rooms, room_slot, list/room_props)
	..()
	owner = rooms
	slot = room_slot
	props = room_props

/datum/practice_session/proc/start(mob/new_player/lobby)
	var/client/C = lobby.client
	if (!C)
		return FALSE
	body = new /mob/living/human/practice(props["start"])
	body.practice = src
	body.gender = C.prefs ? C.prefs.gender : MALE
	body.real_name = "Trainee"
	body.name = body.real_name
	body.equip_to_slot_or_del(new /obj/item/clothing/under/civ1(body), slot_w_uniform)
	lobby.spawning = TRUE
	lobby.close_spawn_windows()
	lobby << sound(null, repeat = FALSE, wait = FALSE, volume = 85, channel = TRUE)
	body.key = lobby.key
	qdel(lobby)
	to_chat(body, "<span class='notice'><b>Welcome to your practice room.</b> Nothing here affects your real character. Follow the steps below; use <b>Leave Practice Room</b> (IC tab) at any time.</span>")
	advance()
	timer = addtimer(CALLBACK(src, PROC_REF(tick)), 1 SECOND, TIMER_LOOP | TIMER_STOPPABLE)
	return TRUE

/datum/practice_session/proc/step_id()
	return step >= 1 && step <= steps.len ? steps[step] : null

/datum/practice_session/proc/show_step()
	var/id = step_id()
	if (body && id)
		to_chat(body, "<span class='notice'><b>Practice step [step] of [steps.len]:</b> [steps[id]]</span>")

/datum/practice_session/proc/advance()
	step++
	var/id = step_id()
	if (!id || !body)
		return
	switch (id)
		if ("swap")
			start_hand = body.hand
		if ("bandage")
			var/obj/item/organ/external/arm = body.get_organ("l_arm")
			if (arm)
				arm.createwound(CUT, 5)
				body.UpdateDamageIcon()
				body.updatehealth()
		if ("eat")
			body.nutrition = min(body.nutrition, 100)
	body << sound('sound/effects/pop.ogg', volume = 40)
	show_step()

/datum/practice_session/proc/holding(obj/item/I)
	return I && !QDELETED(I) && (body.l_hand == I || body.r_hand == I)

/datum/practice_session/proc/step_done(id)
	switch (id)
		if ("walk")
			var/obj/marker = props["marker"]
			return marker && body.loc == marker.loc
		if ("pick_up")
			return holding(props["knife"])
		if ("swap")
			return body.hand != start_hand
		if ("wear")
			return body.head && body.head == props["hat"]
		if ("door")
			return body.x > props["split"]
		if ("harm")
			var/obj/structure/practice_dummy/indestructible/practice_room/D = props["dummy"]
			return D && D.harm_hit_by == body
		if ("bandage")
			for (var/obj/item/organ/external/E in body.organs)
				for (var/datum/wound/W in E.wounds)
					if (!W.internal && !W.bandaged)
						return FALSE
			return TRUE
		if ("eat")
			var/obj/item/weapon/reagent_containers/food/snacks/bread = props["bread"]
			return !bread || QDELETED(bread) || bread.bitecount > 0
		if ("exit")
			var/obj/exit = props["exit"]
			return exit && body.loc == exit.loc
	return FALSE

/datum/practice_session/proc/tick()
	if (ending)
		return
	if (!body || QDELETED(body) || body.stat == DEAD)
		end("Your practice body was lost. You are back in the lobby.")
		return
	if (!body.client)
		end(null)
		return
	var/id = step_id()
	if (!id || !step_done(id))
		return
	if (id == "exit")
		end("Practice complete. Welcome back to the lobby - press Join when you are ready.")
		return
	to_chat(body, "<span class='good'>Done!</span>")
	advance()

/datum/practice_session/proc/end(reason)
	if (ending)
		return
	ending = TRUE
	if (timer)
		deltimer(timer)
		timer = null
	var/client/C = body && !QDELETED(body) ? body.client : null
	if (C)
		if (reason)
			to_chat(C, SPAN_NOTICE(reason))
		practice_send_to_lobby(C)
	if (body && !QDELETED(body))
		body.practice = null
		for (var/obj/item/I in body.GetAllContents())
			qdel(I)
		body.loc = null
		qdel(body)
	body = null
	owner.finish(src)

// ---- Body, props and verbs ----

/mob/living/human/practice
	should_save = FALSE
	var/tmp/datum/practice_session/practice

// The real character keeps its saved owner; this body is never a character.
/mob/living/human/practice/record_persistence_owner()
	persistence_owner_ckey = null

/mob/living/human/practice/Logout()
	. = ..()
	if (practice && !practice.ending)
		addtimer(CALLBACK(practice, TYPE_PROC_REF(/datum/practice_session, tick)), 1)

/mob/living/human/practice/verb/leave_practice_room()
	set name = "Leave Practice Room"
	set category = "IC"
	set src = usr
	if (practice)
		practice.end("You left the practice room.")

/mob/living/human/practice/verb/practice_instructions()
	set name = "Practice Instructions"
	set category = "IC"
	set src = usr
	if (practice)
		practice.show_step()

/obj/effect/practice_marker
	name = "practice marker"
	desc = "Step here."
	icon = 'icons/effects/effects.dmi'
	icon_state = "greenglow"
	anchored = TRUE
	mouse_opacity = FALSE
	should_save = FALSE

/obj/effect/practice_marker/exit
	name = "exit marker"
	desc = "Step here to return to the lobby."
	color = "#66aaff"

/obj/structure/practice_dummy/indestructible/practice_room
	should_save = FALSE
	not_movable = TRUE
	var/mob/harm_hit_by

/obj/structure/practice_dummy/indestructible/practice_room/attackby(obj/item/W, mob/living/human/user)
	if (istype(user) && user.a_intent == I_HARM)
		harm_hit_by = user
	return ..()

/obj/structure/practice_dummy/indestructible/practice_room/attack_hand(mob/living/human/user)
	if (istype(user) && user.a_intent == I_HARM)
		harm_hit_by = user
	return ..()

#undef PRACTICE_ROOM_SIZE
#undef PRACTICE_ROOM_PITCH
#undef PRACTICE_MAX_ROOMS
#undef PRACTICE_IDLE_DROP
