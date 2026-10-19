// PREPARED ONLY. No client/LOS/hearing/Life/survival acceptance is claimed here.
// Real do_after, item handlers, recipe resolver/producer, tent/roof constructors.
// Seams: startup isolation; constructor-only human; synthetic lease ownership.
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
	return "No remote operations in the closed-port gameplay packet."

var/global/list/gameplay_packet_checks = list()
var/global/gameplay_packet_runtime_error = FALSE
var/global/gameplay_packet_failed = ""
var/global/list/gameplay_packet_ordinary_state = list()

/world/Error(exception/e)
	gameplay_packet_runtime_error = TRUE
	gameplay_packet_failed = "runtime_error"
	world.log << "GAMEPLAY PACKET runtime error: [e] at [e.file]:[e.line]"
	gameplay_packet_finish(FALSE)

/obj/map_metadata/gameplay_packet/New()
	return
/mob/living/human/gameplay_packet/New()
	return // Deliberate constructor seam; NOT a normally initialized player.
/mob/living/human/gameplay_packet/put_in_any_hand_if_possible(obj/item/W, del_on_fail=FALSE, disable_warning=TRUE, redraw_mob=TRUE, prioritize_active_hand=FALSE)
	return FALSE // Produced cord remains on its real spawn turf; no equipment UI.
/mob/living/human/gameplay_packet/update_icons()
	return // Presentation only; real item removal/loc/amount handlers are retained.
/mob/living/human/gameplay_packet/update_inv_l_hand(update_icons=1)
	return
/mob/living/human/gameplay_packet/update_inv_r_hand(update_icons=1)
	return

// Identity only. Production ready(), action lease, stop(), handlers and waits
// are inherited. This cannot establish active()/client/consent/visibility parity.
/datum/gameplay_bridge/gameplay_packet/active(run_generation)
	return enabled && generation == run_generation && actor && actor.loc && !actor.gcDestroyed && !actor.gc_destroyed

// Only used to detect entry/final omission in the REAL zero-duration do_after.
/datum/gameplay_action_lease/gameplay_packet_phase
	var/checks = 0
	var/invalid_at = 1
/datum/gameplay_action_lease/gameplay_packet_phase/valid()
	checks++
	return checks < invalid_at

/proc/gameplay_packet_assert(condition, label)
	gameplay_packet_checks += list(list("assertion"=label, "passed"=!!condition, "tick"=world.time))
	if (!condition)
		gameplay_packet_failed = label
		throw EXCEPTION(label)

/proc/gameplay_packet_finish(passed)
	text2file(json_encode(list("schema"=1, "commit"=world.params["tested_commit"], "profile"=world.params["profile"], "passed"=passed, "failed_assertion"=gameplay_packet_failed, "runtime_error"=gameplay_packet_runtime_error, "byond_version"=world.byond_version, "byond_build"=world.byond_build, "port"=world.port, "map"=map ? map.ID : null, "dimensions"=list(world.maxx, world.maxy, world.maxz), "checks"=gameplay_packet_checks, "ordinary_state"=gameplay_packet_ordinary_state, "positive_client_acceptance"=FALSE)), "result.json")
	del(world)

/proc/gameplay_packet_owner(mob/living/human/H)
	var/datum/gameplay_bridge/gameplay_packet/B = new
	B.enabled = TRUE
	B.generation = 10
	B.actor = H
	gameplay_bridge = B // Real do_after uses this one fixture-owned service.
	return B

/proc/gameplay_packet_hold(mob/living/human/H, obj/item/I)
	H.l_hand = I
	H.hand = TRUE
	I.loc = H // Fixture setup only. Production handlers own all tested mutations.

/proc/gameplay_packet_retired(atom/A)
	return !A || !A.loc || A.gcDestroyed || A.gc_destroyed

/world/New()
	OpenPort("none")
	spawn(800)
		gameplay_packet_failed = "world_tick_ceiling"
		gameplay_packet_finish(FALSE)
	try
		gameplay_packet_assert(!world.port && !OpenPort(0), "closed_port_refuses_reopen")
		GLOB.all_observable_events = list()
		GLOB.moved_event = new /decl/observ/moved
		GLOB.dir_set_event = new /decl/observ/dir_set
		GLOB.name_set_event = new /decl/observ/name_set
		GLOB.stat_set_event = new /decl/observ/stat_set
		map = new /obj/map_metadata/gameplay_packet
		map.ID = MAP_NOMADS_CONTINENTAL
		map.ordinal_age = 0
		map.civilizations = TRUE
		map.default_research = 0
		populate_material_list()
		build_research_tree()
		load_recipes() // Real production recipe-file loader; not fabricated recipes.
		var/turf/site = new /turf/floor/plating(locate(4,4,1))
		var/area/caribbean/A = get_area(site)
		A.climate = "temperate"
		A.location = AREA_OUTSIDE
		var/mob/living/human/gameplay_packet/H = new(site)
		H.canmove = TRUE
		H.m_intent = "walk"
		H.a_intent = I_HELP
		H.civilization = "none"
		usr = H
		var/datum/gameplay_bridge/ordinary = new
		var/obj/item/flashlight/light = new(site)
		ordinary.actor = H
		gameplay_packet_assert(!ordinary.active(ordinary.generation) && !ordinary.visible(light), "disconnected_fail_closed_only")
		gameplay_packet_assert(do_after(H, 0, progress=FALSE), "ordinary_zero_wait")
		spawn(1)
			H.loc = locate(5,4,1)
		gameplay_packet_assert(!do_after(H, 5, progress=FALSE) && H.may_do_after, "ordinary_move_cancels_and_releases_lock")
		H.loc = site
		var/obj/item/stack/grass_cuttings/G = new(H, 2)
		gameplay_packet_hold(H,G)
		G.attack_self(H)
		var/obj/item/stack/crude_twine/twine = locate() in site
		if (!twine)
			twine = locate() in H
		gameplay_packet_assert(gameplay_packet_retired(G) && twine && twine.amount == 1, "ordinary_two_cuttings_one_twine")
		var/obj/item/weapon/flint/sharpened/F = new(H)
		gameplay_packet_hold(H,F)
		var/obj/item/weapon/branch/stick = new(H)
		H.r_hand = stick
		var/start = world.time
		stick.attackby(F,H)
		gameplay_packet_assert(stick.sharpened && world.time-start >= 80 && !gameplay_packet_retired(F), "ordinary_sharpen_real_80_tick_handler")
		gameplay_packet_ordinary_state = list("cuttings_retired"=gameplay_packet_retired(G),"twine_amount"=twine.amount,"stick_sharpened"=stick.sharpened,"head_retired"=gameplay_packet_retired(F),"wait_lock_released"=H.may_do_after,"sharpen_ticks"=world.time-start)
#ifdef GAMEPLAY_PACKET_ORDINARY
		gameplay_packet_assert(!ordinary.wait_guards_ready(), "disabled_marker_absent")
		gameplay_packet_finish(TRUE)
		return
#endif
#ifdef GAMEPLAY_PACKET_NO_HOOK
		var/list/no_hook_recipes = ordinary.recipes_for(stick)
		gameplay_packet_assert(!ordinary.wait_guards_ready() && !no_hook_recipes.len, "missing_hook_timed_affordances_fail_closed")
		gameplay_packet_finish(TRUE)
		return
#endif
		gameplay_packet_assert(ordinary.wait_guards_ready(), "enabled_implementation_marker")
		var/datum/gameplay_bridge/B = gameplay_packet_owner(H)
		var/datum/gameplay_action_lease/gameplay_packet_phase/P = new(B,B.generation,"use",F,null)
		B.action_lease = P
		start = world.time
		gameplay_packet_assert(!do_after(H,5,progress=FALSE) && world.time == start, "entry_revoke_immediate")
		P = new(B,B.generation,"use",F,null)
		P.invalid_at = 2
		B.action_lease = P
		gameplay_packet_assert(!do_after(H,0,progress=FALSE) && H.may_do_after, "zero_delay_final_revoke")
		var/datum/gameplay_action_lease/old_lease = new(B,B.generation,"use",F,null)
		B.action_lease = old_lease
		gameplay_packet_assert(old_lease.valid(),"old_lease_initially_valid")
		spawn(2)
			old_lease.cancelled = TRUE
			B.action_lease = new(B,B.generation,"use",F,null)
		start = world.time
		gameplay_packet_assert(!do_after(H,10,progress=FALSE) && world.time-start <= 3, "old_cancelled_new_lease_never_borrowed")
		B.action_lease = null
		stick = new /obj/item/weapon/branch(H)
		H.r_hand = stick
		B.action_lease = new(B,B.generation,"craft",stick,"sharpen_stick")
		gameplay_packet_assert(B.action_lease.valid(), "real_sharpen_lease_entry")
		spawn(2)
			B.stop("packet_stop")
		start = world.time
		stick.attackby(F,H)
		gameplay_packet_assert(world.time-start <= 3 && !stick.sharpened && H.may_do_after && !gameplay_packet_retired(F), "wake_revoke_immediate")
		sleep(85) // Past the normal completion time: detect delayed effects.
		gameplay_packet_assert(!stick.sharpened && !B.enabled && !B.receipt, "no_sharpen_effect_or_receipt_after_stop")
		B = gameplay_packet_owner(H)
		var/obj/item/stack/material/leather/L = new(H,10)
		gameplay_packet_hold(H,L)
		var/datum/stack_recipe/R = B.canopy_recipe(L)
		gameplay_packet_assert(R && R.req_amount == 5 && R.time == 75, "production_canopy_recipe_available")
		B.action_lease = new(B,B.generation,"craft",L,"leather_canopy")
		gameplay_packet_assert(B.action_lease.valid(), "real_canopy_lease_entry")
		spawn(2)
			B.stop("packet_stop")
		L.produce_recipe(R,1,H)
		sleep(80)
		gameplay_packet_assert(L.amount == 10 && !(locate(/obj/item/weapon/tent) in site) && H.may_do_after, "stop_preserves_material_no_late_canopy")
		B = gameplay_packet_owner(H)
		B.action_lease = null
		R = B.canopy_recipe(L)
		start = world.time
		var/duration = round(R.time/H.getStatCoeff("strength")/(H.getStatCoeff("crafting")*H.getStatCoeff("crafting")))
		L.produce_recipe(R,1,H)
		var/obj/item/weapon/tent/T = locate() in site
		gameplay_packet_assert(T && L.amount == 5 && world.time-start >= duration, "production_canopy_pays_five_real_duration")
		gameplay_packet_hold(H,T)
		B.action_lease = new(B,B.generation,"craft",T,"deploy_canopy")
		spawn(2)
			B.stop("packet_stop")
		T.attack_self(H)
		sleep(40)
		gameplay_packet_assert(!gameplay_packet_retired(T) && !(locate(/obj/structure/tent) in site) && !(locate(/obj/roof/canopy) in site), "stop_no_late_deployment")
		B = gameplay_packet_owner(H)
		B.action_lease = null
		start = world.time
		T.attack_self(H)
		A = get_area(site)
		gameplay_packet_assert(gameplay_packet_retired(T) && (locate(/obj/structure/tent) in site) && (locate(/obj/roof/canopy) in site) && A.location == AREA_INSIDE && world.time-start >= 35, "production_deployment_roof_inside_real_duration")
		gameplay_packet_assert(B.safe_clutter(locate(/obj/structure/tent) in site) && B.safe_clutter(locate(/obj/roof/canopy) in site), "exact_canopy_clutter_admitted_not_movement_proof")
		gameplay_packet_finish(TRUE)
	catch(var/exception/e)
		world.log << "GAMEPLAY PACKET failed: [e] at [e.file]:[e.line]"
		gameplay_packet_finish(FALSE)
