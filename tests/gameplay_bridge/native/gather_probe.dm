// Fixed-loopback guarded fixture. NEVER client/consent/LOS/Life acceptance.
// Generated grass copy substitutes ONLY its connected-client predicate.
// Human New returns without parent; active/visible seams below are headless only.
/world
	hub = ""
	hub_password = ""
	maxx = 9
	maxy = 9
	maxz = 1
	fps = 20
	turf = /turf
	area = /area/caribbean
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/Topic(T, addr, master, key)
	return "Isolated gather fixture; no operations."
/client/New(TopicData)
	return FALSE // Original entries removed from generated source BEFORE include.

var/global/list/gather_probe_checks = list()
var/global/list/gather_probe_ordinary_state = list()
var/global/list/gather_probe_metrics = list()
var/global/gather_probe_failed = ""
var/global/gather_probe_runtime = FALSE
var/global/gather_probe_finished = FALSE

/proc/gather_probe_finish(passed)
	if (gather_probe_finished)
		return
	gather_probe_finished = TRUE
	text2file(json_encode(list("schema"=1, "commit"=world.params["tested_commit"], "profile"=world.params["profile"], "passed"=passed, "failed_assertion"=gather_probe_failed, "runtime_error"=gather_probe_runtime, "byond_version"=world.byond_version, "byond_build"=world.byond_build, "port"=world.port, "dimensions"=list(world.maxx,world.maxy,world.maxz), "positive_client_acceptance"=FALSE, "checks"=gather_probe_checks, "ordinary_state"=gather_probe_ordinary_state, "metrics"=gather_probe_metrics)), "result.json")
	del(world)
	return

/proc/gather_probe_check(ok, label)
	gather_probe_checks += list(list("assertion"=label, "passed"=!!ok, "tick"=world.time))
	if (!ok)
		gather_probe_failed = label
		throw EXCEPTION(label)

/world/Error(exception/e)
	gather_probe_runtime = TRUE
	gather_probe_failed = "runtime_error"
	world.log << "GATHER_PROBE runtime error: [e] at [e.file]:[e.line]"
	gather_probe_finish(FALSE)
	return

/obj/map_metadata/gather_probe/New()
	return // No normal mode scheduler; synthetic map identity only.
/mob/living/human/gather_probe
	var/starts = 0
	var/finishes = 0
#ifdef CIV13_GAMEPLAY_BRIDGE
	var/datum/gameplay_action_lease/finish_cancel
	var/datum/gameplay_action_lease/start_cancel
#endif
/mob/living/human/gather_probe/New()
	return // No normal anatomy, connected client, natural Life or survival proof.
/mob/living/human/gather_probe/survival_action_started()
	starts++
	. = ..() // Real human metabolism callback, unchanged.
#ifdef CIV13_GAMEPLAY_BRIDGE
	if (start_cancel)
		start_cancel.cancelled = TRUE
		start_cancel = null
#endif
/mob/living/human/gather_probe/survival_action_finished()
	finishes++
	. = ..() // Real cleanup first; deterministic final-phase cancellation seam.
#ifdef CIV13_GAMEPLAY_BRIDGE
	if (finish_cancel)
		finish_cancel.cancelled = TRUE
		finish_cancel = null
#endif

/proc/gather_probe_balanced(mob/living/human/gather_probe/H)
	return H.may_do_after && H.starts == H.finishes && !H.survival_actions && !isnull(H.survival_rest_since) && H.survival_rest_since <= world.time

/proc/gather_probe_count(mob/living/human/H)
	var/total = 0
	var/visited = 0
	for (var/obj/item/stack/grass_cuttings/G in H.loc)
		if (++visited > 64)
			return -1
		total += G.amount
	return total

/proc/gather_probe_site()
	var/turf/floor/grass/G = new(locate(5,4,1))
	var/area/caribbean/A = get_area(G)
	A.climate = "temperate"
	return G

/proc/gather_probe_ordinary(mob/living/human/gather_probe/H, obj/item/weapon/flint/F)
	var/turf/floor/grass/G = gather_probe_site()
	var/before = gather_probe_count(H)
	var/start = world.time
	G.gather_grass_cuttings(H,F) // Ordinary null-context canonical handler.
	var/turf/after = locate(5,4,1)
	gather_probe_metrics["ordinary_gather_ticks"] = world.time-start
	gather_probe_check(world.time-start >= 30 && gather_probe_count(H) == before+2 && after.type == /turf/floor/dirt && gather_probe_balanced(H), "ordinary_paid_gather")
	// Record logical state; scheduler phase/time origin are not parity inputs.
	gather_probe_ordinary_state["duration_at_least_30"] = world.time-start >= 30
	gather_probe_ordinary_state["cuttings_added"] = gather_probe_count(H)-before
	gather_probe_ordinary_state["turf_is_dirt"] = after.type == /turf/floor/dirt
	gather_probe_ordinary_state["tool_retained"] = H.get_active_hand() == F && F.loc == H && F.sharpened
	gather_probe_check(do_after(H,0,progress=FALSE) && gather_probe_balanced(H), "ordinary_zero_delay")
	var/list/state = list("done"=FALSE,"ok"=TRUE)
	spawn(1)
		state["ok"] = do_after(H,30,progress=FALSE)
		state["done"] = TRUE
	start = world.time
	gather_probe_check(do_after(H,5,progress=FALSE,check_for_repeats=FALSE), "ordinary_false_first_returns")
	gather_probe_check(!state["done"] && H.may_do_after, "stock_false_first_early_unlock")
	gather_probe_check(do_after(H,5,progress=FALSE), "stock_overlap_after_early_unlock")
	while (!state["done"] && world.time-start < 40)
		sleep(1)
	gather_probe_check(state["done"] && state["ok"] && gather_probe_balanced(H), "ordinary_overlap_balanced")
	gather_probe_ordinary_state["callback_starts"] = H.starts
	gather_probe_ordinary_state["callback_finishes"] = H.finishes
	gather_probe_ordinary_state["balanced"] = gather_probe_balanced(H)

#ifdef CIV13_GAMEPLAY_BRIDGE
/datum/gameplay_bridge/gather_probe/active(run_generation)
	return enabled && generation == run_generation && actor && actor.loc && !actor.gcDestroyed && !actor.gc_destroyed
/datum/gameplay_bridge/gather_probe/visible(atom/A)
	return actor && A && A.type == /turf/floor/grass && get_dist(actor,A) <= 1

/proc/gather_probe_owner(mob/living/human/gather_probe/H)
	var/datum/gameplay_bridge/gather_probe/B = new
	B.enabled = TRUE
	B.generation = 10
	B.actor = H
	gameplay_bridge = B
	return B

/proc/gather_probe_lease(datum/gameplay_bridge/B, turf/floor/grass/G)
	var/datum/gameplay_action_lease/L = new(B,B.generation,"gather",G,null)
	L.request_id = "synthetic_gather"
	B.action_lease = L
	return L

/proc/gather_probe_cancel_case(mob/living/human/gather_probe/H, datum/gameplay_bridge/B, mode)
	var/turf/floor/grass/G = gather_probe_site()
	var/datum/gameplay_action_lease/L = gather_probe_lease(B,G)
	var/start = world.time
	var/starts = H.starts
	if (mode == "entry")
		L.cancelled = TRUE
		var/result = do_after(H,30,G,progress=FALSE,gameplay_context=L)
		gather_probe_metrics["entry_ticks"] = world.time-start
		gather_probe_check(!result && world.time == start && H.starts == starts && gather_probe_balanced(H), "entry_denied_before_callbacks")
	else if (mode == "final" || mode == "final_wait")
		H.finish_cancel = L
		var/delay = mode == "final" ? 0 : 30
		var/result = do_after(H,delay,G,progress=FALSE,gameplay_context=L)
		gather_probe_metrics[mode+"_ticks"] = world.time-start
		gather_probe_check(!result && world.time-start >= delay && gather_probe_balanced(H), mode == "final" ? "zero_delay_final_denied" : "positive_delay_final_denied")
	else if (mode == "first_wake")
		H.start_cancel = L
		var/result = do_after(H,30,G,progress=FALSE,gameplay_context=L)
		gather_probe_metrics["first_wake_ticks"] = world.time-start
		gather_probe_check(!result && world.time-start < 3 && gather_probe_balanced(H), "first_wake_cancelled")
	else
		spawn(2)
			L.cancelled = TRUE
			if (mode == "old_new")
				gather_probe_lease(B,G)
		var/result = do_after(H,30,G,progress=FALSE,gameplay_context=L)
		gather_probe_metrics[mode+"_ticks"] = world.time-start
		var/label = mode == "old_new" ? "old_context_stays_revoked" : "wake_cancel_before_completion"
		gather_probe_check(!result && world.time-start < 30 && gather_probe_balanced(H), label)
		if (mode == "old_new")
			gather_probe_check(B.action_lease != L && !B.action_lease.wait_claimed, "new_context_not_claimed")
	B.action_lease = null

/proc/gather_probe_invalid(mob/living/human/gather_probe/H, datum/gameplay_bridge/B)
	var/turf/floor/grass/G = gather_probe_site()
	var/starts = H.starts
	var/forged = list("forged"=TRUE)
	var/result = do_after(H,30,G,progress=FALSE,gameplay_context=forged)
	gather_probe_check(!result && H.starts == starts, "forged_type_denied")
	for (var/fault in list("body","target","kind","owner","generation","pointer","request"))
		var/datum/gameplay_action_lease/L = gather_probe_lease(B,G)
		switch (fault)
			if ("body")
				L.body = new /mob/living/human/gather_probe(locate(7,7,1))
			if ("target")
				L.target = H.loc
			if ("kind")
				L.kind = "refill"
			if ("owner")
				L.owner = new /datum/gameplay_bridge
			if ("generation")
				L.run_generation--
			if ("pointer")
				B.action_lease = null
			if ("request")
				L.request_id = ""
		result = do_after(H,30,G,progress=FALSE,gameplay_context=L)
		gather_probe_check(!result && H.starts == starts, "invalid_[fault]_denied")
	var/datum/gameplay_action_lease/L = gather_probe_lease(B,G)
	gather_probe_check(do_after(H,0,G,progress=FALSE,gameplay_context=L) && L.wait_claimed, "one_use_first_claim")
	starts = H.starts
	gather_probe_check(!do_after(H,0,G,progress=FALSE,gameplay_context=L) && H.starts == starts, "one_use_replay_denied")
	L = gather_probe_lease(B,G)
	var/list/nested = list("done"=FALSE,"ok"=TRUE)
	spawn(1)
		nested["ok"] = do_after(H,0,G,progress=FALSE,gameplay_context=L)
		nested["done"] = TRUE
	gather_probe_check(do_after(H,5,G,progress=FALSE,check_for_repeats=FALSE,gameplay_context=L) && nested["done"] && !nested["ok"] && gather_probe_balanced(H), "one_use_nested_denied")
	B.action_lease = null

/proc/gather_probe_isolation(mob/living/human/gather_probe/H, datum/gameplay_bridge/B)
	var/turf/floor/grass/G = gather_probe_site()
	var/datum/gameplay_action_lease/L = gather_probe_lease(B,G)
	var/list/state = list("done"=FALSE,"ok"=TRUE)
	spawn(1)
		state["ok"] = do_after(H,30,G,progress=FALSE,gameplay_context=L)
		state["done"] = TRUE
	spawn(3)
		L.cancelled = TRUE
	var/result = do_after(H,40,G,progress=FALSE,check_for_repeats=FALSE)
	gather_probe_check(result && state["done"] && !state["ok"] && gather_probe_balanced(H), "ordinary_wait_isolated")
	B.action_lease = null

/proc/gather_probe_canonical(mob/living/human/gather_probe/H, datum/gameplay_bridge/B, obj/item/weapon/flint/F, cancel=FALSE)
	var/turf/floor/grass/G = gather_probe_site()
	var/datum/gameplay_action_lease/L = gather_probe_lease(B,G)
	var/before = gather_probe_count(H)
	var/start = world.time
	if (cancel)
		spawn(2)
			L.cancelled = TRUE
	G.gather_grass_cuttings(H,F,L)
	var/elapsed = world.time-start
	gather_probe_metrics[cancel ? "canonical_cancel_ticks" : "explicit_gather_ticks"] = elapsed
	if (cancel)
		gather_probe_check(elapsed < 30 && gather_probe_count(H) == before && !G.busy && gather_probe_balanced(H), "cancelled_canonical_gather_stops_early")
		sleep(35)
		gather_probe_check(gather_probe_count(H) == before && G.type == /turf/floor/grass && !G.busy && gather_probe_balanced(H), "cancelled_canonical_no_late_effect")
	else
		var/turf/after = locate(5,4,1)
		gather_probe_check(elapsed >= 30 && L.wait_claimed && gather_probe_count(H) == before+2 && after.type == /turf/floor/dirt && H.get_active_hand() == F && F.loc == H && gather_probe_balanced(H), "explicit_gather_paid_output")
	B.action_lease = null
#endif

/world/New()
	OpenPort("none")
	spawn(800)
		gather_probe_failed = "world_tick_ceiling"
		gather_probe_finish(FALSE)
		return
	try
		gather_probe_check(!OpenPort(0), "requested_reopen_denied")
		GLOB.all_observable_events = list()
		GLOB.moved_event = new /decl/observ/moved
		GLOB.dir_set_event = new /decl/observ/dir_set
		GLOB.name_set_event = new /decl/observ/name_set
		GLOB.stat_set_event = new /decl/observ/stat_set
		map = new /obj/map_metadata/gather_probe
		map.ID = MAP_NOMADS_CONTINENTAL
		populate_material_list()
		var/turf/site = new /turf/floor/plating(locate(4,4,1))
		var/mob/living/human/gather_probe/H = new(site)
		H.canmove = TRUE
		H.aimed = list()
		H.hand = TRUE
		var/obj/item/weapon/flint/sharpened/F = new(H)
		H.l_hand = F
		usr = H
		gather_probe_check(H.get_active_hand() == F && F.sharpened && !H.client, "headless_setup")
		gather_probe_ordinary(H,F)
#ifdef CIV13_GAMEPLAY_BRIDGE
		if (world.params["profile"] != "enabled_null")
			var/datum/gameplay_bridge/B = gather_probe_owner(H)
			gather_probe_check(B.ready(B.generation) && B.wait_guards_ready("gather") && !B.wait_guards_ready("craft") && !B.wait_guards_ready("refill") && !B.wait_guards_ready("drink"), "typed_gather_setup")
			switch (world.params["profile"])
				if ("omit_entry")
					gather_probe_cancel_case(H,B,"entry")
				if ("omit_wake")
					gather_probe_cancel_case(H,B,"wake")
				if ("omit_final")
					gather_probe_cancel_case(H,B,"final")
				if ("reacquire")
					gather_probe_cancel_case(H,B,"old_new")
				if ("ambient")
					gather_probe_isolation(H,B)
				if ("omit_forward")
					gather_probe_canonical(H,B,F,TRUE)
				else
					gather_probe_invalid(H,B)
					gather_probe_cancel_case(H,B,"entry")
					gather_probe_cancel_case(H,B,"wake")
					gather_probe_cancel_case(H,B,"first_wake")
					gather_probe_cancel_case(H,B,"final")
					gather_probe_cancel_case(H,B,"final_wait")
					gather_probe_cancel_case(H,B,"old_new")
					gather_probe_isolation(H,B)
					gather_probe_canonical(H,B,F,TRUE)
					gather_probe_canonical(H,B,F,FALSE)
#endif
		gather_probe_finish(TRUE)
		return
	catch (var/exception/e)
		world.log << "GATHER_PROBE failed: [e] at [e.file]:[e.line]"
		gather_probe_finish(FALSE)
		return
