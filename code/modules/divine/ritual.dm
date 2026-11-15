// Server-owned channel context, not a player entrypoint or spell dispatcher.
// The adapter supplies only explicitly enrolled participants, never nearby crowds.
// No effects, slots, resources, timers or channel UI are created by this datum.
/datum/divine_use_request/ritual
	var/list/participants = list()
	var/list/participant_sessions = list()
	var/list/participant_origins = list()
	var/obj/item/focus
	var/channel_radius = 3
	var/channel_duration = 300
	var/channel_started = FALSE
	var/channel_ready_at = 0
	var/roster_ready = FALSE
	var/roster_count = 0

/datum/divine_use_request/ritual/New(datum/divine_covenant_runtime/grant, spell, atom/destination, scope, list/enrolled, obj/item/held_focus, duration = 300, radius = 3, lifetime = 600)
	..(grant, spell, destination, scope, lifetime)
	if (state != "requested")
		return
	// Proposed prototype bounds: the leader plus two to seven other players.
	if (!islist(enrolled) || enrolled.len < 3 || enrolled.len > 8 || !(grant.caster in enrolled))
		invalidate_channel()
		return
	if (!isnum(duration) || duration != round(duration) || duration < 1 || duration > 300 || !isnum(radius) || radius != round(radius) || radius < 1 || radius > 3)
		invalidate_channel()
		return
	channel_duration = duration
	channel_radius = radius
	focus = held_focus
	var/list/sessions = list()
	for (var/entry in enrolled)
		if (!istype(entry, /mob/living))
			invalidate_channel()
			return
		var/mob/living/member = entry
		var/session = participant_identity(member)
		if (!participant_ready(member) || !session || (session in sessions) || (member in participants))
			invalidate_channel()
			return
		participants += member
		sessions += session
		participant_sessions[member] = session
		participant_origins[member] = get_turf(member)
	roster_count = participants.len
	roster_ready = TRUE
	current()

// Kept separate for the isolated native probe. Production requires a live body
// and its own connected client; NPCs and disconnected bodies cannot contribute.
/datum/divine_use_request/ritual/proc/participant_identity(mob/living/member)
	return member.client

/datum/divine_use_request/ritual/proc/participant_ready(mob/living/member)
	return member && !QDELETED(member) && member.stat == CONSCIOUS && !member.incapacitated(INCAPACITATION_DISABLED_NO_REST) && member.client && member.client.mob == member

/datum/divine_use_request/ritual/proc/invalidate_channel()
	if (state == "requested" || state == "approved")
		state = "cancelled"
	return FALSE

/datum/divine_use_request/ritual/current()
	if (!..())
		return FALSE
	if (!roster_ready || !focus || QDELETED(focus) || (covenant.caster.get_active_hand() != focus && covenant.caster.get_inactive_hand() != focus))
		return invalidate_channel()
	if (participants.len != roster_count || participant_sessions.len != roster_count || participant_origins.len != roster_count)
		return invalidate_channel()
	// One bounded visibility query and at most eight roster checks.
	var/list/visible_members = view(channel_radius, caster_origin)
	for (var/entry in participants)
		if (!istype(entry, /mob/living))
			return invalidate_channel()
		var/mob/living/member = entry
		var/turf/location = get_turf(member)
		if (!participant_ready(member) || participant_identity(member) != participant_sessions[member] || !location || location != participant_origins[member])
			return invalidate_channel()
		if (location.z != caster_origin.z || get_dist(location, caster_origin) > channel_radius || !(member in visible_members))
			return invalidate_channel()
	return TRUE

// Approval must already exist. Never refresh or extend its deadline to start.
/datum/divine_use_request/ritual/proc/start_channel()
	if (!current() || state != "approved" || channel_started)
		return FALSE
	if (world.time + channel_duration >= deadline)
		return invalidate_channel()
	channel_started = TRUE
	channel_ready_at = world.time + channel_duration
	return TRUE

// A reviewed gameplay adapter checks eligibility/costs, then consumes, charges
// and dispatches synchronously with no yield. This method never applies effects.
/datum/divine_use_request/ritual/consume(mob/subject, spell, atom/destination, scope)
	if (!current() || !channel_started || world.time < channel_ready_at)
		return FALSE
	return ..(subject, spell, destination, scope)

/datum/divine_use_request/ritual/Destroy()
	invalidate_channel()
	participants = null
	participant_sessions = null
	participant_origins = null
	focus = null
	return ..()
