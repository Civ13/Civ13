// Fixed production mechanics only. Timed affordances fail closed unless the
// owner-approved do_after guard is compiled in the approved isolated build.
/datum/gameplay_bridge/proc/wait_guards_ready()
#ifdef CIV13_GAMEPLAY_WAIT_GUARDS
	return TRUE
#else
	return FALSE
#endif

/datum/gameplay_bridge/proc/sharp_flint()
	var/obj/item/weapon/flint/F = actor ? actor.get_active_hand() : null
	return F && (F.type == /obj/item/weapon/flint || F.type == /obj/item/weapon/flint/sharpened) && F.loc == actor && F.sharpened ? F : null

/datum/gameplay_bridge/proc/grass_target(atom/A)
	return A && (A.type == /turf/floor/grass || A.type == /obj/structure/wild/tallgrass || A.type == /obj/structure/wild/tallgrass2)

/datum/gameplay_bridge/proc/held_cup()
	var/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/C = actor ? actor.get_active_hand() : null
	return C && C.type == /obj/item/weapon/reagent_containers/food/drinks/drinkingglass && C.loc == actor && C.is_open_container() && C.reagents && C.reagents.total_volume < C.volume ? C : null

/datum/gameplay_bridge/proc/water_target(atom/A)
	// Do not filter by hidden water chemistry/contamination. Normal handlers
	// preserve salt, disease and radiation risks; affordances are not safety claims.
	return A && (A.type == /turf/floor/beach/water || A.type == /turf/floor/beach/water/coastwater)

// Resolve only this reviewed production recipe. Never accept UI indexes, paths,
// quantities or an old material menu as authority. Resolve once for a lease;
// wake checks below are pure and never regenerate the material recipe menu.
/datum/gameplay_bridge/proc/canopy_recipe(atom/A)
	if (!actor || !A || A.type != /obj/item/stack/material/leather || actor.get_active_hand() != A || A.loc != actor || !map)
		return null
	var/obj/item/stack/material/leather/L = A
	if (!L.material || L.material.type != /material/leather || L.amount < 5 || actor.getStatCoeff("strength") <= 0 || actor.getStatCoeff("crafting") <= 0)
		return null
	var/list/available = L.material.get_recipes_civs(actor)
	var/visited = 0
	for (var/datum/stack_recipe_list/category in available)
		if (++visited > 64)
			return null
		if (category.title != "furniture")
			continue
		for (var/datum/stack_recipe/R in category.recipes)
			if (++visited > 256)
				return null
			if (R.result_type == /obj/item/weapon/tent && R.title == "foldable canopy" && R.req_amount == 5 && R.res_amount == 1 && R.max_res_amount == 1 && R.time == 75 && !R.one_per_turf && R.on_floor && !R.use_material)
				var/duration = round(R.time / actor.getStatCoeff("strength") / (actor.getStatCoeff("crafting") * actor.getStatCoeff("crafting")))
				if (duration >= 0 && duration <= 110 && isfloor(actor.loc) && !water_target(actor.loc))
					return R
	return null

/datum/gameplay_bridge/proc/canopy_context()
	return actor && map ? "[map.ID]|[map.ordinal_age]|[map.civilizations]|[map.override_global_recipes]|[actor.civilization]|[actor.original_job_title]|[actor.faction_text]|[actor.orc]|[actor.ant]|[actor.lizard]|[actor.gorillaman]|[actor.crab]|[actor.wolfman]|[actor.s_tone]" : null

/datum/gameplay_bridge/proc/canopy_plan_valid(atom/A, datum/stack_recipe/R)
	if (!actor || !map || !A || A.type != /obj/item/stack/material/leather || actor.get_active_hand() != A || A.loc != actor || !isfloor(actor.loc) || water_target(actor.loc))
		return FALSE
	var/obj/item/stack/material/leather/L = A
	if (!L.material || L.material.type != /material/leather || L.amount < 5 || !R || R.result_type != /obj/item/weapon/tent || R.title != "foldable canopy" || R.req_amount != 5 || R.res_amount != 1 || R.max_res_amount != 1 || R.time != 75 || R.one_per_turf || !R.on_floor || R.use_material)
		return FALSE
	if (actor.getStatCoeff("strength") <= 0 || actor.getStatCoeff("crafting") <= 0)
		return FALSE
	// Pure equivalent of the existing node check: do not lazily create/freeze a
	// faction baseline or regenerate global material recipes inside do_after.
	var/datum/research_node/N = research_nodes["weaving"]
	if (!N || map.ordinal_age > 8)
		return FALSE
	if (N.tree == "Main")
		var/baseline = (!actor.civilization || actor.civilization == "none") ? map.ordinal_age : map.faction_baseline_era[actor.civilization]
		if (isnull(baseline))
			baseline = map.ordinal_age
		if (N.era_tier <= baseline)
			return TRUE
	var/list/entry = map.get_node_entry(actor.civilization, "weaving")
	return entry && entry[RNODE_ENTRY_STATUS] == RNODE_DONE

/datum/gameplay_bridge/proc/canopy_site()
	if (!actor || !isturf(actor.loc) || !(actor.loc.type in list(/turf/floor, /turf/floor/plating, /turf/floor/grass, /turf/floor/dirt)))
		return FALSE
	var/area/caribbean/A = get_area(actor)
	if (!istype(A) || A.location != AREA_OUTSIDE || !(A.climate in list("tundra", "taiga", "temperate", "sea", "semiarid", "desert", "savanna", "jungle")))
		return FALSE
	var/visited = 0
	for (var/obj/O in actor.loc)
		if (++visited > 64 || istype(O, /obj/structure/tent) || istype(O, /obj/roof))
			return FALSE
	return TRUE

/datum/gameplay_bridge/proc/recipes_for(atom/A)
	var/list/result = list()
	if (!A || !actor || !safe_item(A) || A.gcDestroyed || A.gc_destroyed)
		return result
	if (wait_guards_ready())
		if (canopy_recipe(A) && actor.can_build_recipe)
			result += "leather_canopy"
		if (A.type == /obj/item/weapon/tent && A == actor.get_active_hand() && canopy_site())
			result += "deploy_canopy"
	if (A.type == /obj/item/stack/grass_cuttings && actor.get_active_hand() == A)
		var/obj/item/stack/grass_cuttings/G = A
		if (G.amount >= 2)
			result += "grass_twine"
	if (wait_guards_ready() && (A.type == /obj/item/weapon/branch || A.type == /obj/item/weapon/branch/sharpened) && sharp_flint() && (A.loc == actor || (visible(A) && get_dist(A, actor) <= 1)))
		var/obj/item/weapon/branch/B = A
		if (!B.sharpened)
			result += "sharpen_stick"
		else
			var/obj/item/stack/binding = B.axe_binding(actor)
			if (binding && binding.type == /obj/item/stack/crude_twine && binding.amount >= 1 && ((binding.loc == actor && (binding == actor.l_hand || binding == actor.r_hand)) || (visible(binding) && binding.loc == actor.loc)))
				result += "bind_flint_axe"
	return result

// This hook receives the exact listener-rendered message after hear_say has
// applied language/nonverbal/deafness/sleep filtering. Never capture message2,
// which may still contain the original unscrumbled utterance.
/mob/living/human/on_hear_say(message, mob/speaker = null, message2 = "")
	gameplay_bridge.capture_speech(src, speaker, message)
	return ..()

/datum/gameplay_bridge/proc/capture_speech(mob/listener, mob/speaker, rendered)
	if (!active(generation) || listener != actor || !speaker || actor.stat || actor.sleeping || !isturf(actor.loc) || !isturf(speaker.loc) || speaker.z != actor.z || get_dist(speaker, actor) > 7 || actor_client.eye != actor)
		return
	if (speaker == actor)
		own_speech_seq++
		return
	// No speaker identity/coordinates are added. Only text the player received.
	event_seq++
	speech_events += list(list("event_seq"=event_seq, "text"=plain(rendered, 256), "expires"=world.time+600))
	if (speech_events.len > 8)
		speech_events.Cut(1, speech_events.len-7)
	current_observation = null

/datum/gameplay_bridge/proc/messages()
	var/list/result = list()
	while (speech_events.len)
		var/list/first = speech_events[1]
		if (world.time <= first["expires"])
			break
		speech_events.Cut(1,2)
	for (var/list/event in speech_events)
		result += list(list("event_seq"=event["event_seq"], "text"=event["text"]))
	return result

// do_after's reviewed overlay captures this datum once, then checks it after
// every sleep and at return. STOP cannot replace the old lease with a new one.
/datum/gameplay_action_lease
	should_save = FALSE
	var/datum/gameplay_bridge/owner
	var/mob/living/human/body
	var/run_generation
	var/atom/target
	var/atom/target_loc
	var/turf/site
	var/obj/item/tool
	var/obj/item/stack/binding
	var/atom/binding_loc
	var/kind
	var/recipe
	var/intent
	var/deadline
	var/cancelled = FALSE
	var/request_id
	var/datum/stack_recipe/canopy_plan
	var/obj/map_metadata/canopy_map
	var/canopy_context

/datum/gameplay_action_lease/New(datum/gameplay_bridge/service, generation, action_kind, atom/action_target, recipe_id)
	owner = service
	body = service.actor
	run_generation = generation
	target = action_target
	target_loc = target ? target.loc : null
	site = get_turf(body)
	tool = body ? body.get_active_hand() : null
	intent = body ? body.a_intent : null
	kind = action_kind
	recipe = recipe_id
	deadline = world.time + 120
	if (recipe == "leather_canopy")
		canopy_plan = owner.canopy_recipe(target)
		canopy_map = map
		canopy_context = owner.canopy_context()
	if (target && recipe == "bind_flint_axe" && (target.type == /obj/item/weapon/branch || target.type == /obj/item/weapon/branch/sharpened))
		var/obj/item/weapon/branch/B = target
		binding = B.axe_binding(body)
		binding_loc = binding ? binding.loc : null

/datum/gameplay_action_lease/proc/valid()
	if (cancelled || !owner || owner.action_lease != src || !owner.ready(run_generation) || owner.actor != body || world.time > deadline || body.loc != site || body.get_active_hand() != tool || body.a_intent != intent)
		return FALSE
	if (kind != "gather" && kind != "refill" && kind != "drink" && kind != "craft")
		return TRUE
	if (!target || target.gcDestroyed || target.gc_destroyed || target.loc != target_loc || !((target.loc == body && (target == body.l_hand || target == body.r_hand)) || (owner.visible(target) && get_dist(body, target) <= 1)))
		return FALSE
	if (kind == "gather")
		return owner.grass_target(target) && owner.sharp_flint() == tool
	if (kind == "refill")
		return owner.wait_guards_ready() && owner.water_target(target) && owner.held_cup() == tool
	if (kind == "drink")
		return owner.wait_guards_ready() && owner.water_target(target) && !tool && intent == I_GRAB
	if (recipe == "bind_flint_axe")
		var/obj/item/weapon/branch/B = target
		return binding && binding.type == /obj/item/stack/crude_twine && !binding.gcDestroyed && !binding.gc_destroyed && binding.loc == binding_loc && binding.amount >= 1 && B.axe_binding(body) == binding && ((binding.loc == body && (binding == body.l_hand || binding == body.r_hand)) || (owner.visible(binding) && binding.loc == site)) && owner.sharp_flint() == tool && B.sharpened
	if (recipe == "leather_canopy")
		// can_build_recipe is held FALSE by the normal crafting lock during wait.
		return owner.wait_guards_ready() && map == canopy_map && owner.canopy_context() == canopy_context && owner.canopy_plan_valid(target, canopy_plan)
	return (recipe in owner.recipes_for(target))

/datum/gameplay_bridge/proc/wait_lease(mob/user)
	return action_lease && action_lease.body == user ? action_lease : null

/datum/gameplay_bridge/proc/launch_action(list/R, run_generation, old_seq, old_time, list/old_entities)
	if (!active(run_generation) || action_lease || !islist(R) || !islist(R["action"]))
		return
	var/list/A = R["action"]
	var/atom/target = valid_id(A["target"]) ? old_entities[A["target"]] : null
	var/datum/gameplay_action_lease/L = new(src, run_generation, A["type"], target, A["recipe"])
	L.request_id = R["request_id"]
	action_lease = L
	spawn(0)
		var/list/completed
		try
			completed = execute(R, run_generation, old_seq, old_time, old_entities)
		catch
			if (generation == run_generation)
				stop("action_error")
		if (action_lease == L)
			action_lease = null
			if (active(run_generation))
				if (R["version"] == 3 && islist(completed) && isnull(completed["reason"]))
					var/old_status = completed["status"]
					completed["status"] = old_status == "executed" ? "completed" : "denied"
					completed["reason"] = old_status == "executed" ? "none" : (old_status == "stale" ? "stale_observation" : (old_status == "unsupported" ? "unsupported_action" : (old_status == "invalid" ? "invalid_request" : "no_verified_state_change")))
					// Cancellation is terminal only after this original worker returned.
					if (L.cancelled && old_status != "executed")
						completed["status"] = "cancelled"
						completed["reason"] = "cancelled"
				receipt = completed
				current_observation = null
		L.owner = null
		L.body = null
		L.target = null
		L.target_loc = null
		L.site = null
		L.tool = null
		L.binding = null
		L.binding_loc = null
		L.canopy_plan = null
		L.canopy_map = null

/datum/gameplay_bridge/proc/stock(typepath)
	// Used only as a bounded local postcondition; no quantities are exported.
	var/total = 0
	var/visited = 0
	for (var/obj/item/I in list(actor.l_hand, actor.r_hand) + actor.loc.contents)
		if (++visited > 64)
			return -1
		if (I && I.type == typepath && !I.gcDestroyed && !I.gc_destroyed && ((I.loc == actor && (I == actor.l_hand || I == actor.r_hand)) || visible(I)))
			if (istype(I, /obj/item/stack))
				var/obj/item/stack/S = I
				total += S.amount
			else
				total++
	return total

/datum/gameplay_bridge/proc/survival_action(kind, atom/target, recipe)
	if (!(kind in affordances(target, target.loc == actor)) || !actor.canClick() || world.time <= actor.next_click || !actor.can_use_hands() || actor.in_throw_mode || actor.using_object)
		return FALSE
	if (kind == "gather" && wait_guards_ready() && grass_target(target))
		var/obj/item/weapon/flint/F = sharp_flint()
		var/before = stock(/obj/item/stack/grass_cuttings)
		if (!F || before < 0)
			return FALSE
		if (isturf(target))
			var/turf/floor/grass/G = target
			G.attackby(F, actor)
		else
			var/obj/structure/wild/G = target
			G.attackby(F, actor)
		return active(action_lease.run_generation) && stock(/obj/item/stack/grass_cuttings) == before + 2
	if (kind == "refill" && wait_guards_ready() && water_target(target))
		var/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/C = held_cup()
		if (!C)
			return FALSE
		var/before = C.reagents.total_volume
		var/turf/floor/W = target
		W.attackby(C, actor)
		return active(action_lease.run_generation) && C && C.reagents && C.reagents.total_volume > before
	if (kind == "drink" && wait_guards_ready() && water_target(target) && actor.a_intent == I_GRAB && !actor.get_active_hand())
		var/before = actor.water
		var/turf/floor/beach/water/W = target
		W.attack_hand(actor)
		return active(action_lease.run_generation) && actor.water > before
	if (kind != "craft" || !(recipe in recipes_for(target)))
		return FALSE
	if (recipe == "leather_canopy")
		var/datum/stack_recipe/R = action_lease.canopy_plan
		var/obj/item/stack/material/leather/L = target
		var/before_output = stock(/obj/item/weapon/tent)
		if (!R || !actor.can_build_recipe || before_output < 0)
			return FALSE
		var/before_input = L.amount
		var/mob/living/human/builder = actor
		builder.can_build_recipe = FALSE
		try
			L.produce_recipe(R, 1, builder)
		catch
			builder.can_build_recipe = TRUE
			throw EXCEPTION("gameplay canopy production failed")
		builder.can_build_recipe = TRUE
		if (!active(action_lease.run_generation))
			return FALSE
		var/remaining = !L || L.gcDestroyed || L.gc_destroyed || !L.loc ? 0 : L.amount
		// Match stack.use's current production religion adjustment at completion.
		var/paid = builder.religion_check() == "Production" ? 4 : 5
		return before_input - remaining == paid && stock(/obj/item/weapon/tent) == before_output + 1
	if (recipe == "deploy_canopy")
		if (!canopy_site() || target.type != /obj/item/weapon/tent || target != actor.get_active_hand())
			return FALSE
		var/turf/site = get_turf(actor)
		var/obj/item/weapon/tent/T = target
		T.attack_self(actor)
		if (!active(action_lease.run_generation))
			return FALSE
		var/area/A = get_area(site)
		return (!T || !T.loc || T.gcDestroyed || T.gc_destroyed) && (locate(/obj/structure/tent) in site) && (locate(/obj/roof/canopy) in site) && A.location == AREA_INSIDE
	if (recipe == "grass_twine" && target.type == /obj/item/stack/grass_cuttings && target == actor.get_active_hand())
		var/obj/item/stack/grass_cuttings/G = target
		var/before_input = G.amount
		var/before_output = stock(/obj/item/stack/crude_twine)
		if (before_output < 0)
			return FALSE
		G.attack_self(actor)
		var/remaining = !G || G.gcDestroyed || G.gc_destroyed || !G.loc ? 0 : G.amount
		return before_input - remaining == 2 && stock(/obj/item/stack/crude_twine) == before_output + 1
	if (!wait_guards_ready() || !sharp_flint())
		return FALSE
	var/obj/item/weapon/branch/B = target
	if (recipe == "sharpen_stick")
		B.attackby(sharp_flint(), actor)
		return active(action_lease.run_generation) && B && B.sharpened
	if (recipe == "bind_flint_axe")
		var/before = stock(/obj/item/weapon/material/hatchet/tribal/flint)
		if (before < 0 || !action_lease.binding || !action_lease.valid())
			return FALSE
		var/obj/item/stack/binding = action_lease.binding
		var/before_binding = binding.amount
		var/obj/item/weapon/flint/head = sharp_flint()
		B.attackby(head, actor)
		if (!active(action_lease.run_generation))
			return FALSE
		var/remaining = !binding || binding.gcDestroyed || binding.gc_destroyed || !binding.loc ? 0 : binding.amount
		return before_binding - remaining == 1 && (!head || !head.loc || !head.sharpened) && (!B || !B.loc) && stock(/obj/item/weapon/material/hatchet/tribal/flint) == before + 1
	return FALSE
