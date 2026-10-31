// Prepared only by prepare_connected_scene.py; never a production include.
#ifdef CIV13_FLAX_CONNECTED_SCENE
var/global/datum/flax_client_scene/flax_scene

/proc/flax_scene_ref(value)
	return value ? "\ref[value]" : ""

/world
	hub = ""
	hub_password = ""
	visibility = 0
	maxx = 8
	maxy = 8
	maxz = 1
	view = 3
	turf = /turf/floor/plating
	area = /area
	mob = /mob

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/world/Export()
	return null

/world/Topic()
	return null

/world/New()
	if (world.params["flax_scene_enabled"] != "1" || world.params["tested_commit"] != FLAX_SCENE_REVIEWED_HEAD)
		OpenPort("none")
		text2file("disabled: no reviewed connected-scene activation", "connected-disabled.txt")
		return
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.stat_set_event = new
	GLOB.name_set_event = new
	makeDatumRefLists()
	map = new /obj/map_metadata/flax_scene
	flax_scene = new
	flax_scene.record("waiting_real_client", list())
	spawn(9000)
		if (flax_scene)
			flax_scene.fail("scene wall deadline")
		OpenPort("none")
		shutdown()

// Startup/connection adapters only. Full base-human New(), organs, inventory,
// click, drop, hand/HUD updates and original do_after bodies are not replaced.
/obj/map_metadata/flax_scene/New()
	return
/datum/preferences/flax_scene/New()
	return
/mob/Login()
	return
/mob/living/human/Login()
	return
/mob/living/human/proc/nomads_spawn()
	return
/obj/structure/table/flax_scene/New()
	return

/client/New()
	if (!flax_scene || flax_scene.viewer || connection != "seeker" || (address && address != "127.0.0.1") || byond_version != 516 || byond_build != 1688)
		return FALSE
	prefs = new /datum/preferences/flax_scene
	flax_scene.bind(src)
	chat = new /datum/chat(src)
	chat.load()
	winset(src, "browser_chat", "is-visible=true")
	return TRUE

/client/Del()
	if (flax_scene && flax_scene.viewer == src)
		flax_scene.fail("real client disconnected")
	return

// Documented native client callbacks. Only the inherited engine event path is
// invoked; this scene never calls ClickOn/afterattack/MouseDrop_T/reattach itself.
/client/Click(atom/object, location, control, params)
	if (!flax_scene || !flax_scene.owns(src))
		return
	var/token = flax_scene.begin_input("click", object, null, control, params)
	. = ..()
	flax_scene.end_input(token)
	return .

/client/MouseDrop(atom/src_object, atom/over_object, src_location, over_location, src_control, over_control, params)
	if (!flax_scene || !flax_scene.owns(src))
		return
	var/token = flax_scene.begin_input("drag", src_object, over_object, over_control, params)
	. = ..()
	// Production atom.MouseDrop forwards to MouseDrop_T in spawn(0).
	spawn(1)
		if (flax_scene)
			flax_scene.end_input(token)
	return .

/client/Topic(href, href_list, hsrc)
	if (!flax_scene || !flax_scene.owns(src) || usr != mob)
		return
	if (href_list["chat_ready"])
		chat.on_ready()
		flax_scene.ready()
	else if (href_list["flax_notice"])
		flax_scene.dom_notice(href_list)

/datum/flax_client_scene
	var/client/viewer
	var/mob/living/human/actor
	var/scene_id
	var/state = "waiting_real_client"
	var/case_index = 1
	var/sequence = 0
	var/active_action
	var/list/actions = list()
	var/list/water_sites = list()
	var/turf/floor/beach/water/water
	var/obj/item/flax_bundle/bundle
	var/obj/item/stack/material/flax/raw
	var/obj/structure/table/flax_scene/table
	var/obj/item/weapon/tool
	var/obj/item/weapon/defibrillator/base
	var/notice_dom_seen = FALSE
	var/paddle_state_seen = FALSE

/datum/flax_client_scene/New()
	scene_id = "flax-[world.realtime]-[rand(100000,999999)]"

/datum/flax_client_scene/proc/owns(client/C)
	return C && C == viewer && actor && actor.type == /mob/living/human && actor.client == C && C.mob == actor && state != "failed"

/datum/flax_client_scene/proc/record(kind, list/data)
	if (sequence >= 256)
		state = "failed"
		text2file(json_encode(list("state" = state, "reason" = "event limit", "acceptance_complete" = FALSE)), "connected-failure.json")
		return
	sequence++
	data["kind"] = kind
	data["sequence"] = sequence
	data["world_time"] = world.time
	data["scene_id"] = scene_id
	data["head_sha"] = FLAX_SCENE_REVIEWED_HEAD
	data["client_ref"] = flax_scene_ref(viewer)
	data["body_ref"] = flax_scene_ref(actor)
	data["body_type"] = actor ? "[actor.type]" : ""
	data["case_index"] = case_index
	data["acceptance_complete"] = FALSE
	text2file(json_encode(data), "connected-events.jsonl")
	text2file(json_encode(list("head_sha" = FLAX_SCENE_REVIEWED_HEAD, "scene_id" = scene_id, "state" = state, "event_count" = sequence, "acceptance_complete" = FALSE, "capture_review" = "required", "case_index" = case_index)), "connected-state.jsonl")

/datum/flax_client_scene/proc/fail(reason)
	state = "failed"
	record("failed", list("reason" = reason))

/datum/flax_client_scene/proc/bind(client/C)
	viewer = C
	actor = new /mob/living/human(locate(3,3,1))
	actor.name = "FLAX SCENE production human"
	actor.real_name = actor.name
	actor.stat = CONSCIOUS
	actor.lying = FALSE
	actor.sleeping = 0
	C.mob = actor
	C.eye = actor
	C.perspective = MOB_PERSPECTIVE
	C.view = 3
	actor.defaultHUD = "1713Style"
	actor.create_HUD()
	actor.show_HUD()
	table = new(locate(2,3,1))
	table.name = "FLAX SCENE TABLE"
	record("base_human_bound", list("real_client" = owns(C)))

/datum/flax_client_scene/proc/ready()
	if (state != "waiting_real_client" || !owns(viewer))
		return
	to_chat(viewer, "SCENE-ID [scene_id] | SOURCE [FLAX_SCENE_REVIEWED_HEAD]")
	prepare_case()

/datum/flax_client_scene/proc/snapshot(obj/item/I)
	return list("left_hand" = flax_scene_ref(actor.l_hand), "right_hand" = flax_scene_ref(actor.r_hand), "active_hand" = flax_scene_ref(actor.get_active_hand()), "item_ref" = flax_scene_ref(I), "item_loc" = I ? flax_scene_ref(I.loc) : "", "screen_loc" = I ? I.screen_loc : null, "client_screen_has_item" = I ? (I in viewer.screen) : FALSE)

/datum/flax_client_scene/proc/amount(turf/T)
	var/count = 0
	for (var/obj/item/stack/rotten_flax/F in T)
		count += F.amount
	return count

/datum/flax_client_scene/proc/prepare_case()
	if (!owns(viewer) || actor.l_hand || actor.r_hand)
		fail("case setup requires actual empty hands")
		return
	active_action = null
	state = "awaiting_client_input"
	actor.hand = case_index == 2
	if (case_index <= 2)
		// Fresh distinct owned water, retaining the first hand's two outputs.
		water = new(case_index == 1 ? locate(4,3,1) : locate(3,4,1))
		water.salty = FALSE
		water.radiation = 0
		water.name = "FLAX SCENE WATER [case_index]"
		water_sites += water
		if (water_sites.len != case_index || amount(water))
			fail("water is not a fresh owned per-hand site")
			return
		raw = new(locate(3,3,1), 2, FALSE)
		raw.name = "FLAX SCENE RAW [case_index]"
		bundle = null
		to_chat(viewer, "SCENE [case_index]: click raw flax, use its Tie Flax Bundle verb, then click WATER [case_index] while holding the paid bundle. Let all three waits finish.")
		record("fresh_water_setup", list("water_ref" = flax_scene_ref(water), "coordinates" = "[water.x],[water.y],[water.z]", "pre_output" = amount(water), "hand" = actor.hand))
	else if (case_index <= 4)
		tool = new /obj/item/weapon(locate(3,3,1))
		tool.name = "FLAX SCENE TABLE TOOL [case_index]"
		tool.nodrop = case_index == 4
		to_chat(viewer, "SCENE [case_index]: click TABLE TOOL [case_index] to pick it up; drag it from your hand onto TABLE. Case 4 must refuse.")
	else if (case_index == 5)
		base = new(locate(3,3,1))
		base.name = "FLAX SCENE PADDLE BASE"
		base.paddles.name = "FLAX SCENE LINKED PADDLES"
		actor.equip_to_slot(base, slot_back)
		if (actor.back != base || base.loc != actor)
			fail("production base-unit setup failed")
			return
		to_chat(viewer, "SCENE 5: click the equipped PADDLE BASE to take paddles; click it again while holding them. Capture the actual snap-back notice and HUD cleanup.")
	else
		state = "observations_complete_pending_capture_review"
		record("observations_complete", list("rendered_pixels_verified" = FALSE))

/datum/flax_client_scene/proc/bound_bundle(obj/item/flax_bundle/B, mob/U)
	if (U == actor && case_index <= 2 && state == "awaiting_client_input")
		bundle = B
		B.name = "FLAX SCENE PAID BUNDLE [case_index]"
		record("paid_bundle_created", snapshot(B))

/datum/flax_client_scene/proc/begin_input(kind, atom/source, atom/destination, control, params)
	var/token = "[scene_id]-[sequence+1]"
	var/obj/item/held = actor.get_active_hand()
	var/armed = (case_index <= 2 && kind == "click" && source == water && held == bundle && bundle) || (case_index >= 3 && case_index <= 4 && kind == "drag" && source == tool && destination == table && held == tool) || (case_index == 5 && kind == "click" && source == base && held == base.paddles)
	var/list/event = list("token" = token, "input_kind" = kind, "source_ref" = flax_scene_ref(source), "destination_ref" = flax_scene_ref(destination), "control" = copytext("[control]",1,129), "params" = copytext("[params]",1,1025), "armed" = armed, "dispatches" = 0, "waits" = 0, "completed_waits" = 0, "before" = snapshot(held))
	actions[token] = event
	if (armed)
		if (active_action)
			fail("overlapping client action")
		else
			active_action = token
			to_chat(viewer, "INPUT-ID [token]")
	record("native_client_input", event.Copy())
	return token

/datum/flax_client_scene/proc/dispatch(kind, mob/U, obj/item/I, atom/target)
	if (U != actor || !active_action || !owns(viewer))
		return
	var/list/event = actions[active_action]
	if ((kind == "afterattack" && I == bundle && target == water) || (kind == "table" && I == tool && target == table) || (kind == "paddles" && target == base))
		event["dispatches"]++
		record("production_dispatch", list("token" = active_action, "handler" = kind, "item_ref" = flax_scene_ref(I), "target_ref" = flax_scene_ref(target), "hud" = snapshot(I)))

/datum/flax_client_scene/proc/wait_event(mob/U, obj/item/I, delay, completed, result)
	if (U != actor || I != bundle || !active_action || !owns(viewer))
		return
	var/list/event = actions[active_action]
	if (!completed)
		if (delay != 100 || I.loc != water || actor.item_is_in_hands(I) || (I in viewer.screen) || I.screen_loc)
			fail("wait entry has wrong delay or retained inventory/HUD ownership")
			return
		event["waits"]++
	else if (result)
		event["completed_waits"]++
	record(completed ? "production_wait_exit" : "production_wait_entry", list("token" = active_action, "delay" = delay, "result" = result, "hud" = snapshot(I), "water_ref" = flax_scene_ref(water)))

/datum/flax_client_scene/proc/notice_sent(target, message)
	if (target != viewer || case_index != 5 || !active_action || !findtext(message, "snap back into the main unit") || !findtext(message, base.paddles.name))
		return
	var/list/event = actions[active_action]
	event["notice_sent"] = TRUE
	viewer << output(url_encode(json_encode(list("scene_id" = scene_id, "token" = active_action, "needle" = "snap back into the main unit", "item_label" = base.paddles.name))), "browser_chat:flaxSceneArm")
	record("production_notice_sent", list("token" = active_action, "actual_html" = copytext(message,1,4097)))

/datum/flax_client_scene/proc/dom_notice(list/values)
	var/token = values["token"]
	if (values["scene_id"] != scene_id || token != active_action || !owns(viewer) || !actions[token])
		return
	var/list/event = actions[token]
	var/text = copytext(values["text"],1,1025)
	if (!event["notice_sent"] || !findtext(text, base.paddles.name) || !findtext(text, "snap back into the main unit") || text2num(values["width"]) <= 0 || text2num(values["height"]) <= 0)
		return
	notice_dom_seen = TRUE
	record("client_reported_dom_notice", list("token" = token, "actual_text" = text, "browser_time" = values["browser_time"], "width" = values["width"], "height" = values["height"], "rendered_pixels_verified" = FALSE))
	finish_paddles()

/datum/flax_client_scene/proc/end_input(token)
	if (!owns(viewer) || !actions[token])
		return
	var/list/event = actions[token]
	if (!event["armed"])
		return
	record("post_input_hud", list("token" = token, "hud" = snapshot(case_index <= 2 ? bundle : case_index <= 4 ? tool : base.paddles)))
	if (!event["dispatches"])
		fail("input did not reach the correlated production handler")
		return
	if (case_index <= 2)
		if (event["waits"] != 3 || event["completed_waits"] != 3 || amount(water) != 2 || actor.l_hand || actor.r_hand)
			fail("actual held-item wait/conservation case failed")
			return
		record("flax_observed", list("token" = token, "water_ref" = flax_scene_ref(water), "post_output" = amount(water)))
	else if (case_index <= 4)
		if (case_index == 3 && (tool.loc != table.loc || actor.item_is_in_hands(tool) || (tool in viewer.screen) || tool.screen_loc))
			fail("actual table success case failed")
			return
		if (case_index == 4 && (tool.loc != actor || !actor.item_is_in_hands(tool) || !(tool in viewer.screen) || !tool.screen_loc))
			fail("actual table refusal case failed")
			return
		record("table_observed", list("token" = token, "refused" = case_index == 4))
		if (case_index == 4)
			tool.nodrop = FALSE
			actor.drop_from_inventory(tool, locate(2,2,1)) // setup only, after refusal receipt
	else
		paddle_state_seen = base.paddles.loc == base && !actor.item_is_in_hands(base.paddles) && !(base.paddles in viewer.screen) && !base.paddles.screen_loc
		finish_paddles()
		return
	active_action = null
	case_index++
	prepare_case()

/datum/flax_client_scene/proc/finish_paddles()
	if (paddle_state_seen && notice_dom_seen && case_index == 5)
		record("paddles_observed_pending_capture_review", list("token" = active_action, "rendered_pixels_verified" = FALSE))
		active_action = null
		case_index++
		prepare_case()
#endif
