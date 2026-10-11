#ifndef CRAFTING_EVIDENCE_TOKEN
#error Define CRAFTING_EVIDENCE_TOKEN before including this local-only adapter.
#endif
var/obj/item/stack/material/crafting_evidence_input
var/obj/structure/anvil/steel/crafting_evidence_anvil
var/turf/crafting_evidence_tile
var/crafting_evidence_case = ""
var/crafting_evidence_prompt_mode = FALSE
var/list/crafting_evidence_prompt_trace = list()

/world/Topic(T, addr, master, key)
	var/list/request = params2list(T)
	if (request["crafting-evidence"] != CRAFTING_EVIDENCE_TOKEN)
		return ..()
	var/list/address_parts = splittext(addr, ":")
	if (addr && addr != "::1" && !(address_parts.len >= 1 && address_parts.len <= 2 && address_parts[1] == "127.0.0.1"))
		return "LOCAL ONLY"
	var/client/C
	for (var/client/local_client in clients)
		if (local_client.holder && (!local_client.address || local_client.address == "127.0.0.1" || local_client.address == "::1"))
			C = local_client
			break
	var/list/result = list("commit" = CRAFTING_EVIDENCE_COMMIT, "map" = map ? map.title : "", "dimensions" = list(world.maxx,world.maxy,world.maxz), "client" = !!C, "state" = ticker ? ticker.current_state : -1)
	if (!C || clients.len != 1)
		return json_encode(result)
	usr = C.mob
	var/action = request["action"]
	if (action == "prepare" && ticker && ticker.current_state == GAME_STATE_PREGAME)
		round_progressing = TRUE
		ticker.pregame_timeleft = 1
		ticker.admin_started = TRUE
	if (action == "join" && ticker && ticker.current_state == GAME_STATE_PLAYING && ticker.players_can_join && istype(C.mob, /mob/new_player))
		var/mob/new_player/player = C.mob
		player.close_spawn_windows()
		player.AttemptLateSpawn("Nomad")
		C << browse(null, "window=memory")
		to_chat(C, "LOCAL CRAFTING evidence commit: [CRAFTING_EVIDENCE_COMMIT]")
	if ((action == "road" || action == "helmet") && istype(C.mob, /mob/living/human))
		var/mob/living/human/H = C.mob
		C << browse(null, "window=playersetup")
		C << browse(null, "window=memory")
		C.eye = H
		C.perspective = MOB_PERSPECTIVE
		H.invisibility = 0
		H.see_in_dark = 8
		H.sight = SEE_TURFS | SEE_MOBS | SEE_OBJS
		H.update_icons()
		var/turf/center = locate(round(world.maxx/2),round(world.maxy/2),1)
		H.forceMove(locate(center.x,center.y-1,1))
		for (var/atom/movable/object in center)
			if (!ismob(object))
				qdel(object)
		crafting_evidence_tile = new /turf/floor/dirt(center)
		H.forceMove(crafting_evidence_tile)
		H.original_job_title = "Blacksmith"
		H.setStat("crafting", 200)
		map.ordinal_age = 5
		for (var/node_id in research_nodes)
			var/list/entry = map.ensure_node_entry("recipe_ci", node_id)
			entry[RNODE_ENTRY_STATUS] = RNODE_DONE
		if (H.get_active_hand())
			H.drop_from_inventory(H.get_active_hand())
		crafting_evidence_case = action
		if (action == "road")
			crafting_evidence_input = new /obj/item/stack/material/stone(crafting_evidence_tile,10,FALSE)
			crafting_evidence_input.material.generate_recipes_civs(list(1000,1000,1000),"global","recipe_ci")
			crafting_evidence_input.recipes = crafting_evidence_input.material.recipes
			H.put_in_active_hand(crafting_evidence_input)
			crafting_evidence_input.attack_self(H)
			to_chat(C, "LOCAL TEST: real stone crafting menu; open roads and craft smooth modern road (1 stone). Initial amount 10. Supplies/research are test setup; output is created by the normal menu interaction.")
		else
			crafting_evidence_input = new /obj/item/stack/material/steel(crafting_evidence_tile,20,FALSE)
			crafting_evidence_anvil = new(crafting_evidence_tile)
			H.put_in_active_hand(crafting_evidence_input)
			to_chat(C, "LOCAL TEST: steel anvil, age 5, trained blacksmith, 20 steel. Use steel on the anvil, choose helmets, then Mesh Pickelhaube Helmet (6 steel). Stand still through the normal timed craft.")
	if (action == "road-procedure" && crafting_evidence_case == "road" && crafting_evidence_input && istype(C.mob,/mob/living/human))
		var/datum/stack_recipe/chosen
		for (var/datum/stack_recipe_list/group in crafting_evidence_input.recipes)
			for (var/datum/stack_recipe/recipe in group.recipes)
				if (recipe.title == "smooth modern road" && recipe.result_type == /obj/covers/roads/modern)
					chosen = recipe
		if (chosen)
			to_chat(C, "PROCEDURE TEST: calling production produce_recipe for the real catalog row. This is an adapter call, not a menu click.")
			crafting_evidence_input.produce_recipe(chosen,1,C.mob)
		else
			result["error"] = "Real road menu entry missing"
	if (action == "helmet-procedure" && crafting_evidence_case == "helmet" && crafting_evidence_input && crafting_evidence_anvil && istype(C.mob,/mob/living/human))
		if (!crafting_evidence_prompt_mode && !crafting_evidence_anvil.in_use)
			crafting_evidence_prompt_mode = TRUE
			crafting_evidence_prompt_trace = list()
			to_chat(C, "PROCEDURE TEST: calling production anvil attackby. Only the two dialog selections are injected; crafting time, checks, consumption and output creation remain production behavior. No menu clicks are claimed.")
			spawn(0)
				usr = C.mob
				crafting_evidence_anvil.attackby(crafting_evidence_input,C.mob)
				crafting_evidence_prompt_mode = FALSE
				world.log << "CRAFTING PROCEDURE completed: [json_encode(crafting_evidence_prompt_trace)]"
	if (action == "inspect" && crafting_evidence_tile)
		var/list/outputs = list()
		for (var/atom/movable/output in crafting_evidence_tile)
			if (istype(output,/obj/covers/roads/modern) || istype(output,/obj/item/clothing/head/helmet/ww/pickelhaube2))
				outputs += "[output.type]"
				output.examine(C.mob)
		result["outputs"] = outputs
		result["prompt_trace"] = crafting_evidence_prompt_trace
		result["case"] = crafting_evidence_case
		result["input_remaining"] = crafting_evidence_input ? crafting_evidence_input.amount : -1
		to_chat(C, "LOCAL CRAFTING observed [crafting_evidence_case]: input remaining [result["input_remaining"]], outputs [json_encode(outputs)].")
	world.log << "LOCAL CRAFTING EVIDENCE [action]: [json_encode(result)]"
	return json_encode(result)

// The isolated build wires only anvil dialog calls to this selector. Outside
// the explicit procedure-test action it delegates to the original WWinput.
/proc/crafting_evidence_prompt(client, message, title, default, toc1, toc2)
	if (!crafting_evidence_prompt_mode)
		return WWinput(client,message,title,default,toc1,toc2)
	var/list/options = islist(toc1) ? toc1 : null
	var/selection
	if (options && ("helmets" in options))
		selection = "helmets"
	else if (options && ("Mesh Pickelhaube Helmet - 6 steel" in options))
		selection = "Mesh Pickelhaube Helmet - 6 steel"
	crafting_evidence_prompt_trace += list(list("offered"=options,"selected"=selection))
	to_chat(client,"PROCEDURE TEST offered: [html_encode(json_encode(options))]; injected selection: [selection]")
	var/preview = "<html><body><h3>TEST dialog adapter (not clicked)</h3><pre>[html_encode(json_encode(options))]</pre><p>Injected selection: [html_encode(selection)]</p></body></html>"
	client << browse(preview,"window=crafting_procedure;size=640x420")
	return selection ? selection : default
