// Recipe lessons are live, bounded sessions. No progress or actor references save.
#define NODE_LESSON_DURATION 3000
#define NODE_LESSON_COOLDOWN 600
#define NODE_LESSON_AFK_LIMIT 1200
#define NODE_LESSON_MAX_STATIONS 16
#define NODE_LESSON_MAX_LISTENERS 32
var/global/list/active_node_lesson_stations = list()

/proc/node_lesson_time()
	return world.time

/mob/living/human/proc/node_lesson_active()
	return client && client.inactivity < NODE_LESSON_AFK_LIMIT && stat == CONSCIOUS && !sleeping && !incapacitated()

/obj/structure/telecom/station
	var/tmp/node_lesson_id
	var/tmp/mob/living/human/node_lesson_teacher
	var/tmp/list/node_lesson_listeners = list()
	var/tmp/node_lesson_progress = 0
	var/tmp/node_lesson_last_tick = 0
	var/tmp/node_lesson_cooldown_until = 0

/obj/structure/telecom/station/after_load()
	. = ..()
	stop_node_lesson(FALSE)
	node_lesson_cooldown_until = 0

/obj/structure/telecom/station/Del()
	stop_node_lesson(FALSE)
	return ..()

/obj/structure/telecom/station/proc/node_receiver_available(obj/structure/telecom/R)
	return R && !QDELETED(R) && (R.type in list(/obj/structure/telecom, /obj/structure/telecom/tv)) && R.television == television && R.frequency == frequency && R.z == z && get_dist(R, src) <= 60 && R.operational()

/obj/structure/telecom/station/proc/node_listener_eligible(mob/living/human/H, obj/structure/telecom/R, node_id)
	return H && !QDELETED(H) && H.node_lesson_active() && !H.knows_recipe_node(node_id) && H.can_learn_recipe_node(node_id) && !(H.sdisabilities & DEAF) && !H.ear_deaf && !H.find_trait("Deaf") && node_receiver_available(R) && (H in view(3, R))

/obj/structure/telecom/station/proc/node_teacher_eligible(mob/living/human/H, node_id)
	return H && H == presenter && can_present(H) && H.node_lesson_active() && H.knows_recipe_node(node_id) && H.can_learn_recipe_node(node_id) && operational() && has_antenna()

/obj/structure/telecom/station/proc/stop_presenting(mob/living/human/H)
	if (H != presenter) return FALSE
	stop_node_lesson()
	presenter = null
	return TRUE

// Explicit controls invalidate attendance immediately, even if toggled back
// before the next one-second sample. Physical eligibility is sampled below.
/obj/structure/telecom/proc/interrupt_node_reception()
	for (var/obj/structure/telecom/station/S in active_node_lesson_stations.Copy())
		if (S == src)
			S.stop_node_lesson()
			continue
		for (var/mob/living/human/listener in S.node_lesson_listeners.Copy())
			if (S.node_lesson_listeners[listener] == src)
				S.node_lesson_listeners.Remove(listener)
				if (listener && !QDELETED(listener))
					to_chat(listener, SPAN_WARNING("The receiver change interrupted your recipe lesson."))
		if (!S.node_lesson_listeners.len) S.stop_node_lesson()

/obj/structure/telecom/station/proc/prompt_node_lesson(mob/living/human/H)
	if (!map || !map.recipe_knowledge_enabled() || !can_present(H) || H != presenter)
		to_chat(H, SPAN_WARNING("Present live at this station before starting a recipe lesson."))
		return FALSE
	var/list/options = list()
	for (var/node_id in research_nodes)
		if (H.knows_recipe_node(node_id) && H.can_learn_recipe_node(node_id))
			var/datum/research_node/N = research_nodes[node_id]
			options["[N.name] ([node_id])"] = node_id
	if (!options.len) return FALSE
	var/choice = input(H, "Teach one recipe group for five uninterrupted minutes. Listeners must stay awake and active beside the same tuned receiver. One-minute station cooldown follows.", "Recipe lesson") as null|anything in options
	if (!choice) return FALSE
	return start_node_lesson(H, options[choice])

/obj/structure/telecom/station/proc/start_node_lesson(mob/living/human/H, node_id)
	if (node_lesson_id || active_node_lesson_stations.len >= NODE_LESSON_MAX_STATIONS || node_lesson_time() < node_lesson_cooldown_until || !node_teacher_eligible(H, node_id))
		return FALSE
	var/list/audience = list()
	for (var/obj/structure/telecom/R in civ_telecom_devices)
		if (audience.len >= NODE_LESSON_MAX_LISTENERS) break
		if (!node_receiver_available(R)) continue
		for (var/mob/living/human/listener in view(3, R))
			if (audience.len >= NODE_LESSON_MAX_LISTENERS) break
			if (!(listener in audience) && node_listener_eligible(listener, R, node_id))
				audience[listener] = R
	if (!audience.len)
		to_chat(H, SPAN_WARNING("No eligible listeners are beside a tuned receiver."))
		return FALSE
	node_lesson_id = node_id
	node_lesson_teacher = H
	node_lesson_listeners = audience
	node_lesson_progress = 0
	node_lesson_last_tick = node_lesson_time()
	active_node_lesson_stations |= src
	var/datum/research_node/N = get_research_node(node_id)
	for (var/mob/living/human/listener in node_lesson_listeners)
		listener.hear_station_line("[broadcast_label()]: Five-minute [N.name] lesson begins. Stay awake and active beside this receiver for the entire lesson.")
	civ_relay_log_line("NODE LESSON", "[key_name(H)] at [broadcast_label()]: started [node_id] for [audience.len] listeners")
	return TRUE

/obj/structure/telecom/station/proc/stop_node_lesson(announce = TRUE)
	active_node_lesson_stations -= src
	if (node_lesson_id)
		node_lesson_cooldown_until = node_lesson_time() + NODE_LESSON_COOLDOWN
		if (announce)
			for (var/mob/living/human/listener in node_lesson_listeners)
				if (listener && !QDELETED(listener)) to_chat(listener, SPAN_WARNING("The recipe broadcast ended before you completed the lesson."))
	node_lesson_id = null
	node_lesson_teacher = null
	node_lesson_listeners = list()
	node_lesson_progress = 0
	node_lesson_last_tick = 0

/obj/structure/telecom/station/proc/tick_node_lesson()
	if (!node_lesson_id) return
	var/now = node_lesson_time()
	var/elapsed = now - node_lesson_last_tick
	// A stalled process must not credit an unobserved gap as attendance.
	if (elapsed < 0 || elapsed > 20 || !node_teacher_eligible(node_lesson_teacher, node_lesson_id))
		stop_node_lesson()
		return
	node_lesson_last_tick = now
	for (var/mob/living/human/listener in node_lesson_listeners.Copy())
		if (!node_listener_eligible(listener, node_lesson_listeners[listener], node_lesson_id))
			node_lesson_listeners.Remove(listener)
	if (!node_lesson_listeners.len)
		stop_node_lesson()
		return
	node_lesson_progress += elapsed
	if (node_lesson_progress < NODE_LESSON_DURATION) return
	var/completed_node = node_lesson_id
	var/mob/living/human/teacher = node_lesson_teacher
	var/list/completed = node_lesson_listeners.Copy()
	// Retire the session before learn callbacks can reenter it.
	stop_node_lesson(FALSE)
	var/taught = 0
	for (var/mob/living/human/listener in completed)
		if (node_listener_eligible(listener, completed[listener], completed_node) && listener.learn_recipe_node(completed_node))
			taught++
			var/datum/research_node/learned_node = get_research_node(completed_node)
			to_chat(listener, SPAN_NOTICE("You learned [learned_node.name] from the complete broadcast lesson."))
	civ_relay_log_line("NODE LESSON", "[key_name(teacher)] at [broadcast_label()]: completed [completed_node] for [taught] listeners")

/proc/civ_tick_node_lessons()
	for (var/obj/structure/telecom/station/S in active_node_lesson_stations.Copy())
		if (!S || QDELETED(S))
			active_node_lesson_stations -= S
			continue
		S.tick_node_lesson()

#undef NODE_LESSON_DURATION
#undef NODE_LESSON_COOLDOWN
#undef NODE_LESSON_AFK_LIMIT
#undef NODE_LESSON_MAX_STATIONS
#undef NODE_LESSON_MAX_LISTENERS
