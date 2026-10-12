var/global/list/civ_landlines = list()
var/global/civ_landline_cursor = 1

// Wired telephones and terminals share the native electricity cable graph.
// This is a gameplay abstraction, not a physical mains/VoIP simulation.
/obj/proc/civ_network_connected(obj/target)
	if (!target || !anchored || !target.anchored || !draw_cable_power() || !target.draw_cable_power())
		return FALSE
	// Both power checks refresh identities from the live reciprocal graph.
	// No second route traversal or arbitrary cable-count cutoff is needed.
	return powersource.component_id && powersource.component_id == target.powersource.component_id

/proc/civ_phone_route(obj/item/weapon/telephone/landline/A, obj/item/weapon/telephone/landline/B)
	return A && B && A != B && !A.retired && !B.retired && (A in civ_landlines) && (B in civ_landlines) && A.civ_network_connected(B)

/obj/item/weapon/telephone/landline
	name = "network landline telephone"
	desc = "A wired telephone. Drag an adjacent electricity cable onto it; calls require powered phones on the same connected cable network."
	anchored = TRUE
	powerneeded = 2
	var/tmp/retired = FALSE
	var/tmp/call_deadline = 0
	var/tmp/registered_number = 0

// Bound allocation even if legacy phones have exhausted the number space.
/obj/item/weapon/telephone/landline/new_phonenumber()
	for (var/number = 1000, number <= 9999, number++)
		if (!(number in phone_numbers))
			phonenumber = number
			registered_number = number
			phone_numbers |= number
			return
	phonenumber = 0
	registered_number = 0

/obj/item/weapon/telephone/landline/after_load()
	. = ..()
	phone_numbers -= registered_number
	registered_number = 0
	if (!isnum(phonenumber) || phonenumber < 1000 || phonenumber > 9999 || phonenumber != round(phonenumber) || (phonenumber in phone_numbers))
		new_phonenumber()
	else
		registered_number = phonenumber
		phone_numbers |= phonenumber
	hang_up()

/obj/item/weapon/telephone/landline/examine(mob/user)
	. = ..()
	to_chat(user, "Telephone number: [phonenumber ? phonenumber : "unavailable"].")

/obj/item/weapon/telephone/landline/attack_hand(mob/living/human/H)
	attack_self(H)

/obj/item/weapon/telephone/landline/MouseDrop_T(atom/movable/O, mob/living/human/H)
	civ_attach_cable(O, H)

/obj/item/weapon/telephone/landline/New()
	..()
	if (civ_landlines.len < CIV_TELECOM_LIMIT)
		civ_landlines |= src

/obj/item/weapon/telephone/landline/proc/hang_up()
	var/obj/item/weapon/telephone/landline/P = origincall
	origincall = null
	connected = FALSE
	ringing = FALSE
	ringingnum = FALSE
	call_deadline = 0
	if (P && P.origincall == src)
		P.origincall = null
		P.connected = FALSE
		P.ringing = FALSE
		P.ringingnum = FALSE
		P.call_deadline = 0

/obj/item/weapon/telephone/landline/Destroy()
	retired = TRUE
	hang_up()
	civ_landlines -= src
	phone_numbers -= registered_number
	registered_number = 0
	return ..()

/obj/item/weapon/telephone/landline/Del()
	hang_up()
	civ_landlines -= src
	phone_numbers -= registered_number
	registered_number = 0
	..()

/obj/item/weapon/telephone/landline/persistence_runtime_var(var_name)
	if (var_name in list("retired", "call_deadline", "registered_number", "origincall", "connected", "ringing", "ringingnum"))
		return TRUE
	return ..()

/obj/item/weapon/telephone/landline/proc/dial(number)
	if (retired || origincall || !registered_number || !phonenumber || !(src in civ_landlines) || !isnum(number) || number < 1000 || number > 9999 || number != round(number))
		return FALSE
	for (var/obj/item/weapon/telephone/landline/P in civ_landlines)
		if (P.phonenumber != number || P.origincall || !civ_phone_route(src, P))
			continue
		origincall = P
		P.origincall = src
		ringing = TRUE
		P.ringing = TRUE
		P.ringingnum = phonenumber
		call_deadline = world.time + 200
		P.call_deadline = call_deadline
		P.ring(phonenumber)
		return TRUE
	return FALSE

/obj/item/weapon/telephone/landline/proc/answer()
	var/obj/item/weapon/telephone/landline/P = origincall
	if (!ringingnum || !P || world.time >= call_deadline || !civ_phone_route(src, P))
		hang_up()
		return FALSE
	ringing = FALSE
	P.ringing = FALSE
	connected = P.phonenumber
	P.connected = phonenumber
	call_deadline = 0
	P.call_deadline = 0
	return TRUE

/obj/item/weapon/telephone/landline/attack_self(mob/living/human/H)
	if (!istype(H) || H.stat != CONSCIOUS || !H.can_use_hands() || H.z != z || get_dist(H, src) > 1)
		return
	if (ringingnum)
		to_chat(H, answer() ? "You answer the call." : "The call has lost its connection.")
		return
	if (origincall)
		hang_up()
		to_chat(H, "You hang up.")
		return
	var/number = input(H, "Telephone number (1000-9999)", name) as num|null
	if (isnull(number) || !H || H.stat != CONSCIOUS || !H.can_use_hands() || H.z != z || get_dist(H, src) > 1)
		return
	to_chat(H, dial(sanitize_integer(number, 1000, 9999, 0)) ? "Calling [number]..." : "Busy, missing infrastructure, or no route.")

/obj/item/weapon/telephone/landline/broadcast(msg, mob/living/human/speaker, verbage = "says")
	var/obj/item/weapon/telephone/landline/P = origincall
	if (!speaker || !connected || !P || P.origincall != src || !civ_phone_route(src, P))
		hang_up()
		return
	if (dd_hasprefix(msg, "*"))
		return
	var/count = 0
	for (var/mob/living/human/H in view(3, get_turf(P)))
		if (++count > 32)
			break
		if (H.stat == CONSCIOUS)
			H.hear_phone(msg, verbage, speaker.default_language, speaker, src, P)

/proc/civ_check_landlines()
	var/checks = min(16, civ_landlines.len)
	while (checks-- > 0 && civ_landlines.len)
		if (civ_landline_cursor > civ_landlines.len)
			civ_landline_cursor = 1
		var/obj/item/weapon/telephone/landline/P = civ_landlines[civ_landline_cursor++]
		if (P.origincall && ((P.call_deadline && world.time >= P.call_deadline) || !civ_phone_route(P, P.origincall)))
			P.hang_up()
