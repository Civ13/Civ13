// Practice rooms: from the lobby, a player takes a throwaway body into a
// private 17 x 12 room and follows short scripted steps, then returns to the
// lobby. The west part teaches the controls (walk, pick up, swap hands, wear,
// doors), the middle part fighting and bandaging, and the east camp what a new
// character needs to survive the first day: lighting a campfire, cooking raw
// meat, boiling water before drinking it, washing clothes (fleas spread
// typhus), washing with soap, and resting in a bed when ill.
// Nothing done there touches the player's real character or the world.
//
// Design reference: CM-SS13's tutorial rooms (code/datums/tutorial/,
// https://github.com/cmss13-devs/cmss13, AGPL-3.0). This is a reimplementation
// for Civ13 without signals, tgui or turf reservations; no CM code is copied.
//
// The rooms live on one extra level appended above the world while anyone
// practises. That level is never saved or built on: a save closes every room
// and removes the level first (begin_persistence_operation), the level is
// removed as soon as the last player leaves, and while it exists world_z_budget
// refuses every other new level, so it is always world.maxz and can be removed
// whole. Every room is rebuilt from scratch when it is opened, so nothing a
// player left behind reaches the next one.

#define PRACTICE_ROOM_WIDTH 17
#define PRACTICE_ROOM_HEIGHT 12
#define PRACTICE_ROOM_PITCH_X 19
#define PRACTICE_ROOM_PITCH_Y 14
#define PRACTICE_MAX_ROOMS 8
// A tutorial region (tutorial_region.dm) only runs rooms, so it holds more
// (its 116 x 60 map fits 24 of the wider camp rooms).
#define PRACTICE_MAX_ROOMS_TUTORIAL 32
// Retry while a save holds the level (a save removes it itself).
#define PRACTICE_IDLE_DROP (30 SECONDS)
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
	var/cols = round((world.maxx - 1) / PRACTICE_ROOM_PITCH_X)
	var/rows = round((world.maxy - 1) / PRACTICE_ROOM_PITCH_Y)
	return max(0, min(tutorial_region_here() ? PRACTICE_MAX_ROOMS_TUTORIAL : PRACTICE_MAX_ROOMS, cols * rows))

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
	var/cols = round((world.maxx - 1) / PRACTICE_ROOM_PITCH_X)
	var/col = (slot - 1) % cols
	var/row = round((slot - 1) / cols)
	return list(2 + col * PRACTICE_ROOM_PITCH_X, 2 + row * PRACTICE_ROOM_PITCH_Y)

/datum/practice_rooms/proc/slot_turfs(slot)
	var/list/O = slot_origin(slot)
	return block(locate(O[1], O[2], practice_room_z), locate(O[1] + PRACTICE_ROOM_WIDTH - 1, O[2] + PRACTICE_ROOM_HEIGHT - 1, practice_room_z))

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
	evacuate_level()
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

// Anyone still on the level (an admin ghost watching a room) is moved to the
// first level, so removing the level never deletes a connected player's mob.
/datum/practice_rooms/proc/evacuate_level()
	var/turf/safe = locate(round(world.maxx / 2), round(world.maxy / 2), 1)
	for (var/client/C in clients)
		var/mob/M = C.mob
		if (M && M.z == practice_room_z && safe)
			M.forceMove(safe)

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

// Builds one room: wall ring, wooden floor, two partitions with a door each
// (controls | fighting and bandaging | camp), and the props each step needs.
// Returns the session's prop list.
/datum/practice_rooms/proc/build_room(slot)
	var/list/O = slot_origin(slot)
	var/x1 = O[1]
	var/y1 = O[2]
	var/x2 = x1 + PRACTICE_ROOM_WIDTH - 1
	var/y2 = y1 + PRACTICE_ROOM_HEIGHT - 1
	var/z = practice_room_z
	var/split = x1 + 6
	var/camp = x1 + 11
	var/area/A = locate(/area/caribbean/admin/practice) in area_list
	if (!A)
		A = new /area/caribbean/admin/practice
	A.contents.Add(slot_turfs(slot))
	wipe_room(slot)
	var/old_bulk = wall_bulk_placement
	wall_bulk_placement = TRUE
	for (var/turf/T in slot_turfs(slot))
		// Always a fresh turf: blood, footprints and other marks on the old one go.
		if (T.x == x1 || T.x == x2 || T.y == y1 || T.y == y2 || ((T.x == split || T.x == camp) && T.y != y1 + 5))
			new /turf/wall/indestructable(T)
		else
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
	// The camp: first-day survival.
	props["camp_door"] = new /obj/structure/simple_door/key_door/anyone/wood(locate(camp, y1 + 5, z))
	props["fire"] = new /obj/structure/oven/fireplace/practice(locate(x1 + 14, y1 + 8, z))
	var/obj/item/stack/material/wood/firewood = new(locate(x1 + 12, y1 + 8, z))
	firewood.amount = 10
	props["firewood"] = firewood
	props["meat"] = new /obj/item/weapon/reagent_containers/food/snacks/meat(locate(x1 + 12, y1 + 9, z))
	props["pot"] = new /obj/item/weapon/reagent_containers/glass/small_pot(locate(x1 + 12, y1 + 3, z))
	props["puddle"] = new /obj/structure/sink/puddle/practice(locate(x1 + 14, y1 + 3, z))
	props["soap"] = new /obj/item/weapon/soap(locate(x1 + 15, y1 + 2, z))
	props["bed"] = new /obj/structure/bed/wood(locate(x1 + 13, y1 + 1, z))
	props["exit"] = new /obj/effect/practice_marker/exit(locate(x1 + 15, y1 + 6, z))
	props["split"] = split
	props["camp"] = camp
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
	// The last player out resets everything: the whole level goes now, and the
	// next player gets a freshly built one. A save in progress removes it itself.
	if (!sessions.len && practice_room_z)
		if (persistence_save_in_progress || !drop_level())
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
	// In a tutorial region the player goes back to the group, not into a new room.
	var/home = tutorial_region_here()
	if (home)
		lobby.tutorial_returning = TRUE
	lobby.key = C.key
	if (home && C)
		to_chat(C, SPAN_NOTICE("Taking you back to [tutorial_region_return_name()]."))
		tutorial_region_send_home(C)

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
	var/obj/item/clothing/shirt // the worn uniform the wash steps use
	var/pot_heated = FALSE // the pot sat on the lit campfire
	var/pot_water = 0 // water in the pot when the drink step began
	var/list/steps = list(
		"walk" = "Walk onto the glowing marker. Use W, A, S, D or the arrow keys.",
		"pick_up" = "Pick up the knife: click it while your active hand is empty.",
		"swap" = "Swap hands with X, or click the other hand on your HUD.",
		"wear" = "Pick up the straw hat, then click your head slot on the HUD (or use it in hand) to wear it.",
		"door" = "Click the door in the middle wall to open it, then walk through to the east half of the room.",
		"harm" = "Choose the red Harm intent (press 4, or click the intent box on your HUD), then hit the practice dummy.",
		"bandage" = "You have a cut on your left arm. Pick up the gauze, select your left arm on the body doll (bottom right of the HUD), then click yourself with the gauze.",
		"camp" = "Switch back to the green Help intent (press 1): on Harm you would splash drinks and hit people. Then open the second door and walk into the camp. The rest of the room teaches you how to get through your first day.",
		"fire" = "Every camp needs a fire. Put the firewood into the campfire (click the campfire with the wood in hand), then click the campfire with an empty hand to light it. Don't step into a lit fire!",
		"cook" = "Raw meat can give you food poisoning or worms, so always cook it. Put the raw meat into the lit campfire and wait until it is roasted and drops beside the fire.",
		"eat" = "Your hunger is shown on the HUD. Pick up the roasted meat and click yourself with it to eat.",
		"fill" = "Water from puddles, rivers and wells can carry cholera. Fill the pot: click the puddle with the pot in hand.",
		"boil" = "Boiling kills the germs. Put the pot on the lit campfire and wait until it finishes boiling.",
		"drink" = "Your thirst is shown on the HUD too. Pick up the pot of boiled water and click yourself with it to drink. Never drink straight from a puddle or river.",
		"clothes" = "After a day outdoors you are filthy, and your shirt is crawling with fleas, which spread typhus. Take off your shirt (click it on your HUD with an empty hand), then click the puddle with it to wash it.",
		"wash" = "Now wash yourself: while undressed, stand in the puddle, pick up the soap and click yourself with it. Being dirty sours your mood and makes your clothes dirty faster.",
		"dress" = "Put your clean shirt back on (click your uniform slot on the HUD, or use it in hand).",
		"rest" = "If you fall ill, rest in a bed: you recover faster, and you should keep away from people who are coughing. Drag yourself onto the bed (click-drag your character onto it) to lie down.",
		"exit" = "Well done! You know how to survive your first day. Get up (click the bed), then walk onto the exit marker, or use the Leave Practice Room verb, to return to the lobby.")

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
	to_chat(body, "<span class='notice'><b>Welcome to your practice room.</b> Nothing here affects your real character. Follow the steps below. To go back to the lobby at any time, [leave_link()], press Esc and pick <b>Leave practice room</b>, or click the blue exit marker.</span>")
	advance()
	timer = addtimer(CALLBACK(src, PROC_REF(tick)), 1 SECOND, TIMER_LOOP | TIMER_STOPPABLE)
	return TRUE

// A chat link that returns the player to the lobby.
/datum/practice_session/proc/leave_link()
	return "<a href='byond://?src=\ref[src];practice_leave=1'>click here to leave</a>"

/datum/practice_session/Topic(href, list/href_list)
	if (href_list["practice_leave"] && body && usr == body)
		leave()

// Any of the player's ways out: chat link, Esc menu, verb or exit marker.
/datum/practice_session/proc/leave()
	end("You left the practice room.")

/datum/practice_session/proc/step_id()
	return step >= 1 && step <= steps.len ? steps[step] : null

/datum/practice_session/proc/show_step()
	var/id = step_id()
	if (body && id)
		to_chat(body, "<span class='notice'><b>Practice step [step] of [steps.len]:</b> [steps[id]] <span style='font-size:85%'>([leave_link()] to the lobby)</span></span>")

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
		if ("drink")
			body.water = min(body.water, 100)
			var/obj/item/weapon/reagent_containers/glass/small_pot/pot = props["pot"]
			pot_water = pot && !QDELETED(pot) ? pot.reagents.total_volume : 0
		if ("clothes")
			shirt = body.w_uniform
			if (shirt)
				shirt.dirtyness = 95
				shirt.fleas = TRUE
			body.hygiene = HYGIENE_LEVEL_DIRTY - 1
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
		if ("camp")
			return body.a_intent == I_HELP && body.x > props["camp"]
		if ("fire")
			var/obj/structure/oven/fireplace/practice/fire = props["fire"]
			return fire && fire.on
		if ("cook")
			var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = props["meat"]
			return !meat || QDELETED(meat) || (meat.roasted && meat.loc != props["fire"])
		if ("eat")
			var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = props["meat"]
			return !meat || QDELETED(meat) || meat.bitecount > 0
		if ("fill")
			var/obj/item/weapon/reagent_containers/glass/small_pot/pot = props["pot"]
			return !pot || QDELETED(pot) || pot.reagents.has_reagent("water")
		if ("boil")
			var/obj/item/weapon/reagent_containers/glass/small_pot/pot = props["pot"]
			if (!pot || QDELETED(pot))
				return TRUE
			if (pot.on_stove)
				pot_heated = TRUE
				return FALSE
			return pot_heated && !pot.reagents.has_reagent("cholera")
		if ("drink")
			var/obj/item/weapon/reagent_containers/glass/small_pot/pot = props["pot"]
			return !pot || QDELETED(pot) || pot.reagents.total_volume < pot_water || !pot_water
		if ("clothes")
			return !shirt || QDELETED(shirt) || (!shirt.fleas && shirt.dirtyness < 90)
		if ("wash")
			return body.hygiene >= HYGIENE_LEVEL_NORMAL
		if ("dress")
			return !!body.w_uniform
		if ("rest")
			return body.resting_in_bed()
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
	// Fleas on the practice shirt must not give the trainee a real illness.
	if (body.disease)
		body.clear_disease()
	var/id = step_id()
	if (!id || !step_done(id))
		return
	if (id == "exit")
		end(tutorial_region_here() ? "Practice complete." : "Practice complete. Welcome back to the lobby - press Join when you are ready.")
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
		// A player who dropped out of the room must not reconnect into the
		// deleted, nullspace body (Gaia 2026-11-08): clear its key first so a
		// returning client gets a fresh lobby.
		if (body.key)
			body.key = null
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
		practice.leave()

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
	desc = "Click it to return to the lobby at any time."
	color = "#66aaff"
	mouse_opacity = TRUE

// Clicking the exit leaves at any step; walking onto it finishes the last one.
/obj/effect/practice_marker/exit/Click()
	var/mob/living/human/practice/H = usr
	if (!istype(H) || !H.practice || H.practice.ending)
		return
	if (H.practice.step_id() != "exit" && alert(H, "Leave the practice room and return to the lobby?", "Practice Room", "Leave", "Stay") != "Leave")
		return
	if (H.practice && !H.practice.ending)
		H.practice.leave()

// The camp's campfire cooks quickly and never burns away. Anything put on it
// while it burns starts a fresh cooking cycle, so nobody waits a minute for
// the next one.
/obj/structure/oven/fireplace/practice
	fuel = 0
	consume_itself = FALSE
	cooking_time = 50
	should_save = FALSE

/obj/structure/oven/fireplace/practice/attackby(obj/item/I, mob/living/human/H)
	. = ..()
	if (on && fuel > 0 && !QDELETED(src))
		stone_boil_epoch++
		var/epoch = ++fire_epoch
		keep_fire_on(epoch)
		keep_sound_on(epoch)

// A puddle that neither refills forever nor breeds mosquitoes, so a wiped
// room leaves no loop behind.
/obj/structure/sink/puddle/practice
	should_save = FALSE
	volume = 500

/obj/structure/sink/puddle/practice/refill()
	return

/obj/structure/sink/puddle/practice/mosquito_proc()
	return

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

#undef PRACTICE_ROOM_WIDTH
#undef PRACTICE_ROOM_HEIGHT
#undef PRACTICE_ROOM_PITCH_X
#undef PRACTICE_ROOM_PITCH_Y
#undef PRACTICE_MAX_ROOMS
#undef PRACTICE_MAX_ROOMS_TUTORIAL
#undef PRACTICE_IDLE_DROP
