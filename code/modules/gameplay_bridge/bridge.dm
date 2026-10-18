#include "catalog.dm"
// Private opt-in module. Intentionally NOT included in civ13.dme until runtime
// owner coordination and native acceptance. No Topic handler or admin possession.
var/datum/gameplay_bridge/gameplay_bridge = new

/client/var/gameplay_bridge_consent = FALSE
/client/var/mob/gameplay_bridge_consent_mob

/client/verb/gameplay_bridge_consent_toggle()
	set name = "LLM gameplay consent / STOP"
	set category = "OOC"
	gameplay_bridge_consent = !gameplay_bridge_consent
	gameplay_bridge_consent_mob = gameplay_bridge_consent ? mob : null
	if (gameplay_bridge.actor_client == src)
		gameplay_bridge.stop("consent_changed")
	to_chat(src, "LLM gameplay consent: [gameplay_bridge_consent ? "on (operator assignment required)" : "off"].")

/client/verb/gameplay_bridge_stop()
	set name = "Stop LLM gameplay bridge"
	set category = "OOC"
	if (src == gameplay_bridge.actor_client || (holder && check_rights(R_ADMIN, 0, mob)))
		gameplay_bridge.stop("operator_stop")

// Local, existing R_ADMIN operator only. Config has no account or possession
// semantics. Never invoke this from model output, an HTTP request or law text.
/client/verb/gameplay_bridge_assign()
	set name = "Assign LLM gameplay bridge"
	set category = "Admin"
	if (!holder || !check_rights(R_ADMIN, 0, mob) || (address && address != "127.0.0.1" && address != "::1"))
		return
	var/list/choices = list()
	var/list/chosen_bodies = list()
	var/expected_generation = gameplay_bridge.generation
	for (var/client/C in clients)
		if (!C.holder && C.gameplay_bridge_consent && C.gameplay_bridge_consent_mob == C.mob && istype(C.mob, /mob/living/human))
			choices += C
			chosen_bodies[C] = C.mob
	var/client/chosen = input(src, "Assign an opted-in ordinary character", "Private LLM bridge") as null|anything in choices
	if (!chosen)
		return
	var/list/caps = list("observe")
	for (var/cap in list("move", "examine", "use", "say", "pickup", "drop", "swap_hands", "consume", "equip", "gather", "refill", "drink", "craft", "intent"))
		if (alert(src, "Permit [cap] for this assignment?", "Server capability limit", "No", "Yes") == "Yes")
			caps += cap
	// Input dialogs yielded: authority and target are checked again below.
	if (!holder || !check_rights(R_ADMIN, 0, mob) || (address && address != "127.0.0.1" && address != "::1"))
		return
	if (gameplay_bridge.generation != expected_generation || chosen.mob != chosen_bodies[chosen])
		return
	gameplay_bridge.assign(chosen, caps)

/datum/gameplay_bridge
	should_save = FALSE
	var/enabled = FALSE
	var/client/actor_client
	var/mob/living/human/actor
	var/assignment
	var/epoch
	var/token
	var/generation = 0
	var/observation_seq = 0
	var/action_seq = 1
	var/next_action = 0
	var/list/capabilities = list()
	var/list/entities = list()
	var/list/entity_ids = list()
	var/list/next_entity_ids = list()
	var/entity_serial = 0
	var/list/seen = list()
	var/list/receipt
	var/list/current_observation
	var/snapshot_time = -1000
	var/datum/gameplay_action_lease/action_lease
	var/list/speech_events = list()
	var/event_seq = 0
	var/own_speech_seq = 0

/datum/gameplay_bridge/proc/audit(decision)
	// Fixed server decisions only. No request strings, names, chat or credentials.
	world.log << "GAMEPLAY_BRIDGE [decision] generation=[generation] seq=[action_seq]"

/datum/gameplay_bridge/proc/stop(reason)
	enabled = FALSE
	generation++
	if (action_lease)
		action_lease.cancelled = TRUE
	if (actor_client)
		actor_client.gameplay_bridge_consent = FALSE
		actor_client.gameplay_bridge_consent_mob = null
	actor_client = null
	actor = null
	token = null
	entities = list()
	entity_ids = list()
	next_entity_ids = list()
	seen = list()
	capabilities = list()
	receipt = null
	current_observation = null
	speech_events = list()
	audit(reason)

/datum/gameplay_bridge/proc/assign(client/C, list/caps)
	if (!C || C.holder || !C.gameplay_bridge_consent || C.gameplay_bridge_consent_mob != C.mob || !istype(C.mob, /mob/living/human))
		return FALSE
	if (enabled || action_lease)
		return FALSE // Explicit STOP and fresh consent before reassignment.
	var/list/cfg
	try
		cfg = json_decode(file2text("data/gameplay-bridge.json"))
	catch
		return FALSE
	if (!islist(cfg) || cfg.len != 3 || cfg["enabled"] != TRUE || !valid_id(cfg["assignment"]) || !istext(cfg["game_token"]) || length(cfg["game_token"]) < 32 || length(cfg["game_token"]) > 256)
		return FALSE
	for (var/cap in caps)
		if (!(cap in list("observe", "move", "examine", "use", "say", "pickup", "drop", "swap_hands", "consume", "equip", "gather", "refill", "drink", "craft", "intent")))
			return FALSE
	if (!("observe" in caps))
		return FALSE
	stop("assignment_reset")
	actor_client = C
	actor = C.mob
	assignment = cfg["assignment"]
	token = cfg["game_token"]
	epoch = md5("[world.realtime]-[world.time]-[rand(1,1000000000)]-[generation]")
	event_seq = 0
	capabilities = caps.Copy()
	observation_seq = 0
	entity_serial = 0
	action_seq = 1
	next_action = 0
	enabled = TRUE
	var/run_generation = generation
	audit("assigned")
	spawn(0)
		exchange_loop(run_generation)
	return TRUE

/datum/gameplay_bridge/proc/valid_id(value)
	if (!istext(value) || !length(value) || length(value) > 64)
		return FALSE
	for (var/i = 1, i <= length(value), i++)
		if (!findtext("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-", copytext(value,i,i+1)))
			return FALSE
	return TRUE

/datum/gameplay_bridge/proc/active(run_generation)
	return enabled && generation == run_generation && actor_client && !actor_client.holder && actor_client.gameplay_bridge_consent && actor_client.gameplay_bridge_consent_mob == actor && actor && actor_client.mob == actor && actor.client == actor_client && actor.loc && !actor.gcDestroyed && !actor.gc_destroyed

/datum/gameplay_bridge/proc/ready(run_generation)
	return active(run_generation) && !actor.stat && !actor.paralysis && !actor.stunned && !actor.weakened && !actor.restrained() && !actor.lying && !actor.prone && !actor.resting && !actor.sleeping && actor.canmove && isturf(actor.loc) && !actor.control_object && !actor.using_drone && !actor.incorporeal_move && !actor.transforming && !(actor.status_flags & GODMODE) && !actor.football && !actor.aimed.len

// Only floor-level entities, never inventories of other mobs, containers,
// type paths, refs, ckeys, minds, organs, roles, access codes or admin fields.
/datum/gameplay_bridge/proc/visible(atom/A)
	if (!actor || !actor_client || is_blind(actor) || actor.stat || (actor.sight & (SEE_TURFS|SEE_MOBS|SEE_OBJS)) || actor.see_invisible != SEE_INVISIBLE_LIVING || actor_client.eye != actor)
		return FALSE
	if (!A || A == actor || A.invisibility || A.alpha < 255 || A.gcDestroyed || A.gc_destroyed)
		return FALSE
	if (!isturf(A) && !ishuman(A) && !safe_item(A) && A.type != /obj/structure/tent && !istype(A, /obj/structure/wild))
		return FALSE
	if (!A.icon && !A.overlays.len)
		return FALSE
	if (!isturf(A) && !isturf(A.loc))
		return FALSE
	if (!(A in view(3, actor)) || get_dist(actor, A) > 3 || A.z != actor.z)
		return FALSE
	var/turf/T = get_turf(A)
	// Conservative darkness rule. Night/thermal vision is not implemented.
	if (!T || T.get_lumcount() < 0.5)
		return FALSE
	if (ismob(A) && ((A in actor_client.hidden_mobs) || (get_dist(actor, A) > 1 && A.InCone(actor, OPPOSITE_DIR(actor.dir)))))
		return FALSE
	return TRUE

/datum/gameplay_bridge/proc/plain(value, maximum = 80)
	// Data remains untrusted even after markup/control-character removal.
	var/source = copytext(strip_html_properly("[value]"), 1, maximum + 1)
	var/result = ""
	for (var/i = 1, i <= length(source), i++)
		var/char = copytext(source, i, i+1)
		if (text2ascii(char) >= 32 && text2ascii(char) != 127)
			result += char
	return result

/datum/gameplay_bridge/proc/safe_item(atom/A)
	return A && (A.type in list(/obj/item/flashlight, /obj/item/weapon/reagent_containers/food/snacks/grown/sapote, /obj/item/weapon/reagent_containers/food/drinks/drinkingglass, /obj/item/weapon/flint, /obj/item/weapon/flint/sharpened, /obj/item/weapon/branch, /obj/item/weapon/branch/sharpened, /obj/item/stack/grass_cuttings, /obj/item/stack/crude_twine, /obj/item/weapon/material/hatchet/tribal/flint, /obj/item/stack/material/leather, /obj/item/weapon/tent))

/datum/gameplay_bridge/proc/affordances(atom/A, inventory)
	var/list/actions = list()
	if (!inventory && get_dist(A, actor) <= 1)
		if (isturf(A) && abs(A.x-actor.x) + abs(A.y-actor.y) == 1 && safe_step(A))
			actions += "move"
		if (wait_guards_ready())
			if (A.type == /turf/floor/grass && sharp_flint())
				actions += "gather"
			if (water_target(A))
				if (held_cup())
					actions += "refill"
				if (actor.a_intent == I_GRAB && !actor.get_active_hand())
					actions += "drink"
	var/list/available_recipes = recipes_for(A)
	if (available_recipes.len)
		actions += "craft"
	if (!safe_item(A))
		return actions
	actions += "examine"
	if (!inventory)
		actions += "pickup"
	else if (actor.get_active_hand() == A)
		actions += "drop"
		if (A.type == /obj/item/flashlight)
			actions += "use"
			actions += "equip"
		else if (A.type == /obj/item/weapon/reagent_containers/food/snacks/grown/sapote || A.type == /obj/item/weapon/reagent_containers/food/drinks/drinkingglass)
			actions += "consume"
	return actions

/datum/gameplay_bridge/proc/row(atom/A, inventory = FALSE)
	var/id = entity_ids[A]
	if (!id)
		entity_serial++
		id = "e[entity_serial]"
	next_entity_ids[A] = id
	entities[id] = A
	var/display_name = A.name
	if (istype(A, /mob/living/human))
		var/mob/living/human/H = A
		display_name = H.get_visible_name()
	return list("id"=id, "name"=plain(display_name), "kind"=(isturf(A) ? "tile" : (ishuman(A) ? "person" : (inventory ? "item" : "entity"))), "dx"=(inventory ? 0 : A.x - actor.x), "dy"=(inventory ? 0 : A.y - actor.y), "actions"=affordances(A, inventory), "recipes"=recipes_for(A))

/datum/gameplay_bridge/proc/observe()
	// No numeric ID wrap/reuse: a new assignment is required at exhaustion.
	if (entity_serial >= 999870)
		stop("entity_counter_exhausted")
		return null
	observation_seq++
	entities = list()
	next_entity_ids = list()
	var/list/nearby = list()
	var/list/inventory = list()
	var/visited = 0
	var/complete = TRUE
	var/limit_reason = "none"
	// Fixed geometry first; bounded remainder cannot displace cardinal cells.
	for (var/turf/T in list(get_turf(actor), get_step(actor,NORTH), get_step(actor,SOUTH), get_step(actor,EAST), get_step(actor,WEST)))
		visited++
		if (visible(T))
			nearby += list(row(T))
	for (var/atom/A in view(3, actor))
		if (++visited > 256 || nearby.len >= 128)
			complete = FALSE
			limit_reason = visited > 256 ? "visit_limit" : "entity_limit"
			break
		if (!next_entity_ids[A] && visible(A))
			nearby += list(row(A))
	// Only the two held items in v1. No recursive contents/hidden pockets.
	for (var/obj/item/I in list(actor.l_hand, actor.r_hand))
		if (I && I.loc == actor)
			inventory += list(row(I, TRUE))
	snapshot_time = world.time
	entity_ids = next_entity_ids
	next_entity_ids = list()
	var/list/snapshot = list("version"=3, "complete"=complete, "limit_reason"=limit_reason, "assignment"=assignment, "epoch"=epoch, "observation_seq"=observation_seq, "next_action_seq"=action_seq, "capabilities"=capabilities.Copy(), "status"=list("conscious"=!!(!actor.stat), "mobile"=!!ready(generation), "hungry"=!!(actor.nutrition < 150), "thirsty"=!!(actor.water < 150)), "entities"=nearby, "inventory"=inventory, "messages"=messages(), "laws"=null)
	if (length(json_encode(snapshot)) > 24576)
		snapshot["entities"] = list()
		snapshot["inventory"] = list()
		snapshot["complete"] = FALSE
		snapshot["limit_reason"] = "output_limit"
		entities = list()
		entity_ids = list()
	return snapshot

/datum/gameplay_bridge/proc/exchange_loop(run_generation)
	while (active(run_generation))
		if (actor.stat == DEAD)
			stop("actor_dead")
			return
		if (!current_observation || world.time - snapshot_time >= 150)
			current_observation = observe()
		if (!current_observation)
			return
		var/old_seq = observation_seq
		var/old_time = snapshot_time
		var/list/old_entities = entities
		var/list/packet = list("observation"=current_observation, "receipt"=receipt)
		receipt = null
		var/encoded_packet = json_encode(packet)
		if (length(encoded_packet) > 32768)
			stop("output_limit")
			return
		var/datum/http_request/request = new
		request.prepare("POST", "http://127.0.0.1:9847/v1/game/exchange", encoded_packet, list("Authorization"="Bearer [token]", "Content-Type"="application/json"))
		request.begin_async()
		var/deadline = world.time + 20
		while (!request.is_complete() && world.time < deadline && active(run_generation))
			sleep(1)
		// Network yield: revoke, ownership, life, freshness and target are checked
		// again before any mechanic is called. No model response is authorization.
		if (!active(run_generation))
			return
		if (!request.is_complete())
			stop("transport_timeout")
			return
		var/datum/http_response/response = request.into_response()
		if (response.error || !istext(response.body) || length(response.body) > 32768)
			stop("transport_error")
			return
		var/list/reply
		try
			reply = json_decode(response.body)
		catch
			stop("invalid_reply")
			return
		if (!islist(reply) || reply.len != 3 || isnull(reply["stop"]))
			stop("invalid_reply")
			return
		if (!isnull(reply["cancel"]) && (!valid_id(reply["cancel"]) || !action_lease || action_lease.request_id != reply["cancel"]))
			stop("invalid_cancel_scope")
			return
		if (action_lease && reply["cancel"] == action_lease.request_id)
			action_lease.cancelled = TRUE
		if (reply["stop"])
			stop("remote_stop")
			return
		if (!isnull(reply["action"]))
			launch_action(reply["action"], run_generation, old_seq, old_time, old_entities)
		sleep(10)
	if (generation == run_generation)
		stop("ownership_lost")

/datum/gameplay_bridge/proc/execute(list/R, run_generation, old_seq, old_time, list/old_entities)
	var/list/receipt
	if (!active(run_generation))
		return
	if (!islist(R) || R.len != 7 || (R["version"] != 2 && R["version"] != 3) || R["assignment"] != assignment || R["epoch"] != epoch || !valid_id(R["request_id"]))
		audit("invalid_scope")
		return
	var/id = R["request_id"]
	receipt = list("request_id"=id, "status"="invalid", "detail"="")
	var/fingerprint = md5(json_encode(R))
	if (id in seen)
		var/list/cached = seen[id]
		if (cached["fingerprint"] == fingerprint)
			receipt = cached["receipt"]
		return receipt
	// A bounded cache plus monotonic sequences prevents replay even after eviction.
	if (R["observation_seq"] != old_seq || R["action_seq"] != action_seq || world.time - old_time > 150)
		receipt["status"] = "stale"
		return receipt
	seen[id] = list("fingerprint"=fingerprint, "receipt"=receipt)
	if (seen.len > 64)
		seen.Cut(1,2)
	action_seq++
	var/list/A = R["action"]
	if (!islist(A) || !istext(A["type"]) || !(A["type"] in capabilities))
		receipt["status"] = "unsupported"
		return receipt
	if (!ready(run_generation) || world.time < next_action)
		receipt["status"] = "blocked"
		return receipt
	next_action = world.time + 10
	usr = actor
	var/kind = A["type"]
	var/result = FALSE
	if (!gameplay_action_fields(A))
		return receipt
	if (kind == "gather" || kind == "refill" || kind == "drink" || kind == "craft")
		var/atom/target = valid_id(A["target"]) ? old_entities[A["target"]] : null
		if (target && action_lease && action_lease.valid())
			result = survival_action(kind, target, A["recipe"])
	else if (kind == "intent")
		if (A["intent"] == "help" || A["intent"] == "grab")
			actor.a_intent_change(A["intent"] == "help" ? I_HELP : I_GRAB)
			result = TRUE
		else if (A["intent"] == "walk")
			for (var/i = 1, i <= 4 && actor.m_intent != "walk", i++)
				actor_client.m_intent_change()
			result = actor.m_intent == "walk" && !actor.prone
	else if (kind == "move")
		var/list/directions = list("north"=NORTH, "south"=SOUTH, "east"=EAST, "west"=WEST)
		var/direction = directions[A["direction"]]
		var/turf/destination = direction ? get_step(actor, direction) : null
		if (destination && safe_step(destination) && world.time >= actor_client.move_delay)
			var/turf/before = actor.loc
			actor_client.Move(destination, direction)
			result = actor && actor.loc != before
	else if (kind == "say")
		var/message = A["text"]
		if (safe_speech(message))
			var/before_speech = own_speech_seq
			actor.say(message)
			result = own_speech_seq > before_speech
	else if (kind == "swap_hands")
		if ((!actor.l_hand || safe_item(actor.l_hand)) && (!actor.r_hand || safe_item(actor.r_hand)) && !actor.looking && !actor.using_object)
			var/old_hand = actor.hand
			actor.swap_hand()
			result = actor.hand != old_hand
	else if (kind in list("use", "examine", "pickup", "drop", "consume", "equip"))
		if (!valid_id(A["target"]))
			return receipt
		var/atom/target = old_entities[A["target"]]
		if (safe_item(target) && !target.gcDestroyed && !target.gc_destroyed && ((target.loc == actor && (target == actor.l_hand || target == actor.r_hand)) || (visible(target) && get_dist(actor, target) <= 1)))
			if (kind == "examine")
				target.examine(actor)
				receipt["detail"] = plain(target.desc, 512)
				result = TRUE
			else if (actor.canClick() && world.time > actor.next_click && !actor.in_throw_mode && !actor.using_object && !actor.gloves && !actor.shoes)
				var/obj/item/I = target
				if (kind == "pickup" && isturf(I.loc) && !actor.get_active_hand() && !I.anchored && I.equiptimer == 0)
					I.attack_hand(actor)
					result = I && I.loc == actor && actor.get_active_hand() == I
				else if (actor.get_active_hand() == I)
					if (kind == "drop")
						actor.drop_item()
						result = I && I.loc == actor.loc
					else if (kind == "equip" && I.type == /obj/item/flashlight && A["slot"] == "belt" && !actor.belt)
						actor.attack_ui(slot_belt)
						result = actor.belt == I
					else if (kind == "use" && I.type == /obj/item/flashlight)
						var/obj/item/flashlight/F = I
						var/was_on = F.on
						actor.ClickOn(F, "")
						result = F.on != was_on
					else if (kind == "consume" && (I.type == /obj/item/weapon/reagent_containers/food/snacks/grown/sapote || I.type == /obj/item/weapon/reagent_containers/food/drinks/drinkingglass) && actor.a_intent == I_HELP)
						var/obj/item/weapon/reagent_containers/food/food = I
						var/before_volume = food.reagents ? food.reagents.total_volume : 0
						food.attack(actor, actor)
						result = !food || !food.loc || (food.reagents && food.reagents.total_volume < before_volume)
	if (!active(run_generation))
		return
	receipt["status"] = result ? "executed" : "blocked"
	if (!result)
		receipt["detail"] = "no_verified_state_change"
	audit(result ? "executed" : "blocked")
	return receipt

// Generic interactions may sleep or spawn later mutation and cannot promise
// immediate cancellation. v1 permits only clear, dry basic floors/grass/dirt;
// broader turf/object families need native parity and completion-token review.
/datum/gameplay_bridge/proc/safe_step(turf/destination)
	var/turf/source = actor.loc
	var/list/floors = list(/turf/floor, /turf/floor/plating, /turf/floor/grass, /turf/floor/dirt)
	if (!source || !(source.type in floors) || !(destination.type in floors) || source.wet || destination.wet || destination.density || !visible(destination))
		return FALSE
	if (actor.buckled || actor.pulling || actor.riding_mob || actor.riding || actor.grab_list.len || actor.grabbed_by.len || actor.pinned.len || actor.confused || actor.a_intent == I_HARM || actor.m_intent != "walk" || actor.shoes)
		return FALSE
	var/visited = 0
	for (var/atom/movable/M in actor.loc)
		if (++visited > 32 || (M != actor && !safe_clutter(M)))
			return FALSE
	for (var/atom/movable/M in destination)
		if (++visited > 64 || !safe_clutter(M))
			return FALSE
	return TRUE

/datum/gameplay_bridge/proc/safe_clutter(atom/movable/M)
	return M && !M.density && (M.type == /atom/movable/lighting_overlay || M.type == /obj/structure/tent || M.type == /obj/roof/canopy || safe_item(M))

#include "mechanics.dm"

/datum/gameplay_bridge/proc/safe_speech(message)
	if (!istext(message) || !length(trim(message)) || length(message) > 160)
		return FALSE
	for (var/i = 1, i <= length(message), i++)
		var/char = copytext(message, i, i+1)
		if (text2ascii(char) < 32 || text2ascii(char) == 127 || findtext("*^:;<>", char))
			return FALSE
	return TRUE
