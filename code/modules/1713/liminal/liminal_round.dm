// Liminal Facility finite escape round (docs/liminal/MODE-DESIGN.md, slice 4).
// The round datum owns all progress and timer state; map objects only report
// to it. Times are elapsed engine time (world.time, deciseconds) passed in by
// the caller, never poll counts. Nothing here runs unless the Liminal map is
// the compiled map, and no map list or vote offers it.

#define LIMINAL_FOUND_MARKER "FOUND_MARKER"
#define LIMINAL_SERVICE_DONE "SERVICE_DONE"

var/global/list/liminal_gates = list()

/proc/liminal_whole(value, low, high)
	return isnum(value) && value >= low && value <= high && round(value) == value

/datum/liminal_round
	var/state = "PLANNED"
	var/list/flags = list()
	var/list/participants = list() // admitted bodies, in admission order
	var/max_participants = 4
	var/admission_window = 600 // 60 s after the first admission
	var/hold_needed = 200 // 20 s, tunable 10-120 s
	var/deadline_length = 9000 // 15 min, tunable 10-30 min
	var/started_at = null
	var/hold_started = null
	var/end_reason = null
	var/list/history = list()
	// Slice 5: at most one sound-hunting threat, never before the arrival grace.
	var/threat_grace = 300 // 30 s after the clock starts
	var/threat_state = "WAITING" // WAITING, SPAWNED or NONE (no site); never reverts

/datum/liminal_round/proc/terminal()
	return state == "ESCAPED" || state == "FAILED"

/datum/liminal_round/proc/note(text)
	history += text

/datum/liminal_round/proc/configure(hold_seconds, deadline_minutes, team_cap = 4)
	if (state != "PLANNED")
		return FALSE
	if (!liminal_whole(hold_seconds, 10, 120) || !liminal_whole(deadline_minutes, 10, 30) || !liminal_whole(team_cap, 1, 4))
		return FALSE
	hold_needed = hold_seconds * 10
	deadline_length = deadline_minutes * 600
	max_participants = team_cap
	state = "VALIDATED"
	note("VALIDATED")
	return TRUE

/datum/liminal_round/proc/ready(datum/liminal_era_policy/policy)
	if (state != "VALIDATED" || !istype(policy) || !policy.admitted)
		return FALSE
	state = "READY"
	note("READY")
	return TRUE

/datum/liminal_round/proc/fail(reason)
	if (terminal())
		return FALSE
	state = "FAILED"
	end_reason = reason
	note("FAILED [reason]")
	return TRUE

/datum/liminal_round/proc/admitted(mob/living/human/H)
	return H && (H in participants)

// Start admission: the first body starts the clock; others may join within
// the admission window, up to the team cap. Late joins are never participants.
/datum/liminal_round/proc/admit(mob/living/human/H, now)
	if (!istype(H) || terminal() || !isnum(now))
		return FALSE
	if (H in participants)
		return TRUE
	if (participants.len >= max_participants)
		return FALSE
	if (state == "READY")
		state = "EXPLORING"
		started_at = now
		note("EXPLORING")
	else if (state != "EXPLORING" || now - started_at > admission_window)
		return FALSE
	participants += H
	return TRUE

// Shared, monotone and idempotent. Returns GRANTED, HELD or REFUSED.
/datum/liminal_round/proc/grant(flag, mob/living/human/H)
	if (terminal() || !(state in list("EXPLORING", "TASKS_DONE", "EXTRACTING")))
		return "REFUSED"
	if (!admitted(H) || H.stat != CONSCIOUS)
		return "REFUSED"
	if (flags[flag])
		return "HELD"
	switch (flag)
		if (LIMINAL_FOUND_MARKER)
			flags[flag] = TRUE
		if (LIMINAL_SERVICE_DONE)
			if (!flags[LIMINAL_FOUND_MARKER])
				return "REFUSED"
			flags[flag] = TRUE
			state = "TASKS_DONE"
			note("TASKS_DONE")
		else
			return "REFUSED"
	note("GRANT [flag]")
	return "GRANTED"

// alive: admitted bodies not dead. in_zone: admitted conscious bodies in the
// extraction zone. Escape is checked before the deadline on the same step.
/datum/liminal_round/proc/advance(now, alive, in_zone)
	if (terminal() || !isnum(now) || !(state in list("EXPLORING", "TASKS_DONE", "EXTRACTING")))
		return state
	if (state == "EXTRACTING")
		if (!in_zone)
			state = "TASKS_DONE"
			hold_started = null
			note("HOLD_BROKEN")
		else if (now - hold_started >= hold_needed)
			state = "ESCAPED"
			end_reason = "EXTRACTED"
			note("ESCAPED")
			return state
	if (!alive)
		fail("NO_SURVIVORS")
		return state
	if (now - started_at >= deadline_length)
		fail("DEADLINE")
		return state
	if (state == "TASKS_DONE" && in_zone)
		state = "EXTRACTING"
		hold_started = now
		note("EXTRACTING")
	return state

// True once the arrival grace has passed in a live round and no threat was
// placed yet. The caller still checks the site is out of everyone's sight.
/datum/liminal_round/proc/threat_due(now)
	if (threat_state != "WAITING" || terminal() || !isnum(now) || !(state in list("EXPLORING", "TASKS_DONE", "EXTRACTING")))
		return FALSE
	return now - started_at >= threat_grace

/datum/liminal_round/proc/threat_placed(spawned)
	if (threat_state != "WAITING")
		return FALSE
	threat_state = spawned ? "SPAWNED" : "NONE"
	note(spawned ? "THREAT" : "THREAT_NONE")
	return TRUE

// Explicit early-1990s policy. Only listed types may be issued to participants
// or stand on the map; recipes and research are closed by the map metadata.
/datum/liminal_era_policy
	var/scenario_year = 1990
	var/admitted = FALSE
	var/list/equipment = list(
		/obj/item/clothing/under/mechanic_outfit,
		/obj/item/clothing/shoes/laceup,
		/obj/item/flashlight/flashlight,
		/obj/item/weapon/paper)
	var/list/props = list(
		/obj/structure/table/modern/table,
		/obj/structure/bed/chair/office/dark,
		/obj/structure/telecom/terminal,
		/obj/item/weapon/paper,
		/obj/structure/filingcabinet,
		/obj/structure/bookcase,
		/obj/structure/plant_pot/clay/light/filled,
		/obj/structure/noticeboard,
		/obj/structure/closet,
		/obj/structure/table/rack,
		/obj/structure/vending/sales/food/snacks,
		/obj/structure/vending/sales/drinks/hot,
		/obj/structure/sink,
		/obj/structure/lamp/lamp_big/alwayson/white,
		/obj/structure/lamp/lamp_small/alwayson/white,
		/obj/structure/liminal_marker,
		/obj/structure/liminal_marker/service,
		/obj/structure/liminal_gate)
	var/list/refused = list()

/datum/liminal_era_policy/New(year = 1990)
	..()
	scenario_year = year

/datum/liminal_era_policy/proc/permits_equipment(path)
	return ispath(path) && (path in equipment)

/datum/liminal_era_policy/proc/permits_prop(path)
	return ispath(path) && (path in props)

// Admits the policy only when the year is in range and every map object on z
// is an allowlisted prop or the map's own machinery; items carried by mobs are
// checked when issued instead.
/datum/liminal_era_policy/proc/admit_z(z)
	refused = list()
	if (!liminal_whole(scenario_year, 1990, 1993))
		refused += "scenario year [scenario_year]"
	for (var/obj/O in world)
		if (O.z != z || !isturf(O.loc))
			continue
		if (istype(O, /obj/map_metadata) || istype(O, /obj/effect))
			continue
		if (!permits_prop(O.type))
			refused |= "[O.type]"
	admitted = !refused.len
	return admitted

/datum/liminal_era_policy/proc/issue(path, mob/living/human/H, slot)
	if (!permits_equipment(path) || !istype(H))
		return FALSE
	var/obj/item/I = new path(H)
	return H.equip_to_slot_or_del(I, slot)

// Indoors: half the (night) daylight reaches the floor, so the exported steady
// tubes and the issued flashlights carry the light. No looping ambience; the
// carpeted-hallway reverb preset is BYOND's environment 11.
/area/caribbean/liminal
	name = "facility"
	icon_state = "red2"
	location = AREA_INSIDE
	sound_env = 11
	ambience = list()

/area/caribbean/liminal/extraction
	name = "facility egress"
	icon_state = "green1"

/proc/liminal_round_for_map()
	var/obj/map_metadata/liminal_facility/M = map
	return istype(M) ? M.liminal : null

/obj/structure/liminal_marker
	name = "route marker"
	desc = "A board of hand-drawn arrows and room numbers. Someone has circled one of them."
	icon = 'icons/obj/structures.dmi'
	icon_state = "nboard01"
	anchored = TRUE
	density = FALSE
	var/flag = LIMINAL_FOUND_MARKER
	var/done_message = "You trace the circled route and commit it to memory. The way to the service gallery is clear now."
	var/held_message = "Your team already knows this route."
	var/refused_message = "You can't make sense of it right now."

/obj/structure/liminal_marker/attack_hand(mob/living/human/H)
	if (!istype(H) || !Adjacent(H))
		return
	var/datum/liminal_round/R = liminal_round_for_map()
	if (!R)
		return
	switch (R.grant(flag, H))
		if ("GRANTED")
			to_chat(H, SPAN_NOTICE(done_message))
			if (flag == LIMINAL_SERVICE_DONE)
				liminal_open_gates()
				to_chat(world, "<font size=3><span class='notice'>Somewhere ahead, a heavy door unlocks.</span></font>")
			update_icon()
		if ("HELD")
			to_chat(H, SPAN_NOTICE(held_message))
		else
			to_chat(H, SPAN_WARNING(refused_message))

/obj/structure/liminal_marker/attackby(obj/item/W, mob/user)
	return attack_hand(user)

/obj/structure/liminal_marker/ex_act()
	return

/obj/structure/liminal_marker/update_icon()
	var/datum/liminal_round/R = liminal_round_for_map()
	if (R && R.flags[flag])
		icon_state = "nboard02"

/obj/structure/liminal_marker/service
	name = "service panel"
	desc = "An old control console wired into the wall. The reset switch is still labelled."
	icon = 'icons/obj/computers.dmi'
	icon_state = "1980_computer_off"
	flag = LIMINAL_SERVICE_DONE
	done_message = "You throw the reset switch. Relays clatter somewhere behind the wall."
	held_message = "The panel has already been reset."
	refused_message = "None of the labels match anything you have seen. You need to find the route marker first."

/obj/structure/liminal_marker/service/update_icon()
	var/datum/liminal_round/R = liminal_round_for_map()
	if (R && R.flags[flag])
		icon_state = "1980_computer_on"

// The final aperture is sealed until SERVICE_DONE; it cannot be opened,
// damaged or unlocked any other way.
/obj/structure/liminal_gate
	name = "service door"
	desc = "A heavy door with no handle on this side."
	icon = 'icons/obj/doors/material_doors_leonister.dmi'
	icon_state = "metal"
	anchored = TRUE
	density = TRUE
	opacity = TRUE
	var/open = FALSE

/obj/structure/liminal_gate/New()
	..()
	liminal_gates += src

/obj/structure/liminal_gate/Destroy()
	liminal_gates -= src
	return ..()

/obj/structure/liminal_gate/ex_act()
	return

/obj/structure/liminal_gate/attackby(obj/item/W, mob/user)
	to_chat(user, SPAN_WARNING("It doesn't budge."))
	return

/obj/structure/liminal_gate/proc/release()
	if (open)
		return FALSE
	open = TRUE
	density = FALSE
	set_opacity(FALSE)
	icon_state = "metalopen"
	return TRUE

/proc/liminal_open_gates()
	. = 0
	for (var/obj/structure/liminal_gate/G in liminal_gates)
		if (G.release())
			.++
