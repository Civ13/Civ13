// One region of the two-region transfer pilot. The driver (run.py) starts two
// of these, kills them at random moments and restarts them. Only a committed
// save survives a kill, as with the real world save:
//
//   saves/save-N.json   the world state and round_state["transfer"]
//   saves/complete-N    written after save-N.json; a save without it is ignored
//
// The world holds wood stacks on a stock tile and a trade post. It ships stacks
// to its peer's player and collects what arrives for its own player.

/turf

/world
	turf = /turf
	maxx = 3
	maxy = 1
	maxz = 1

var/global/list/pilot_config
var/global/pilot_save_number = 0
var/global/turf/pilot_stock
var/global/obj/structure/transfer_trade_post/pilot_post
var/global/map_storage/pilot_storage

/world/New()
	..()
	spawn(0)
		pilot_main()

/proc/pilot_log(text)
	world.log << "PILOT [pilot_config ? pilot_config["region"] : "?"]: [text]"

/proc/pilot_latest_save()
	var/latest = 0
	for(var/name in flist("saves/"))
		if(copytext(name, 1, 10) == "complete-")
			var/n = text2num(copytext(name, 10))
			if(n && n > latest) latest = n
	return latest

/proc/pilot_main()
	pilot_config = json_decode(file2text("pilot.json"))
	pilot_storage = new
	pilot_stock = locate(1, 1, 1)
	pilot_post = new /obj/structure/transfer_trade_post(locate(2, 1, 1))
	var/list/round_state = null
	pilot_save_number = pilot_latest_save()
	if(pilot_save_number)
		var/list/data = json_decode(file2text("saves/save-[pilot_save_number].json"))
		for(var/amount in data["stacks"])
			new /obj/item/stack/material/wood(pilot_stock, amount)
		pilot_post.holdings = data["holdings"]
		round_state = data["round_state"]
		if(round_state["transfer"] && !valid_transfer_capture(round_state["transfer"]))
			pilot_log("FAIL invalid transfer capture in save [pilot_save_number]")
			shutdown()
			return
		pilot_log("loaded save [pilot_save_number]: [json_encode(pilot_world_count())]")
	else
		for(var/i in 1 to pilot_config["stacks"])
			new /obj/item/stack/material/wood(pilot_stock, pilot_config["stack_size"])
		pilot_log("seeded [json_encode(pilot_world_count())]")
	// The same hook the game calls at the end of a world load.
	pilot_storage.transfer_loaded(round_state)
	spawn(0)
		pilot_save_loop()
	pilot_act_loop()

// Every stack still in the world: on the stock tile, held by the post during
// an escrow request, or put back on the post's tile after a refusal.
/proc/pilot_world_stacks()
	var/list/amounts = list()
	for(var/obj/item/stack/S in world)
		if(S.loc && !S.gcDestroyed) amounts += S.amount
	return amounts

/proc/pilot_world_count()
	var/stock = 0
	var/held = 0
	for(var/amount in pilot_world_stacks())
		stock += amount
	for(var/key in pilot_post.holdings)
		held += pilot_post.holdings[key]
	return list("stock" = stock, "held" = held, "total" = stock + held)

/proc/pilot_draining()
	return fexists("drain.txt")

/proc/pilot_act_loop()
	while(TRUE)
		sleep(rand(1, 4))
		if(!transfer_bridge.ready() || persistence_save_active()) continue
		if(!pilot_draining() && prob(50))
			for(var/obj/item/stack/S in get_turf(pilot_post))
				S.forceMove(pilot_stock)
			var/list/stacks = list()
			for(var/obj/item/stack/S in pilot_stock)
				stacks += S
			if(stacks.len)
				var/obj/item/stack/S = pick(stacks)
				var/result = pilot_post.ship_stack(S, pilot_config["peer"], pilot_config["player"], pilot_config["peer_player"])
				if(result == "sent") pilot_log("shipped [S.amount]")
		else
			var/taken = pilot_post.collect_goods(pilot_config["player"], "wood")
			if(taken)
				// Collected goods join the stock so they can be shipped again.
				for(var/obj/item/stack/S in get_turf(pilot_post))
					S.forceMove(pilot_stock)
				pilot_log("collected [taken]")

/proc/pilot_save_loop()
	while(TRUE)
		sleep(rand(30, 80))
		pilot_save()
		if(fexists("stop.txt") && pilot_quiet())
			pilot_save()
			pilot_log("stopped at save [pilot_save_number]: [json_encode(pilot_world_count())]")
			text2file("[pilot_save_number]", "stopped.txt")
			shutdown()
			return

// Nothing of ours in flight: the driver only writes stop.txt once both agents
// are idle, so one more save after that is final.
/proc/pilot_quiet()
	return !transfer_bridge.applied.len && !pilot_post.busy

/proc/pilot_save()
	pilot_save_active = TRUE
	var/n = pilot_save_number + 1
	var/generation = "[pilot_config["region"]]-[n]-[world.realtime]-[rand(1, 1000000)]"
	// Capture the world in one tick, as no effect can run while saving.
	var/list/stacks = pilot_world_stacks()
	var/list/round_state = list("generation" = generation)
	var/list/capture = pilot_storage.transfer_capture(generation)
	if(capture) round_state["transfer"] = capture
	var/list/data = list("stacks" = stacks, "holdings" = pilot_post.holdings.Copy(), "round_state" = round_state)
	// A real save takes a while; kills land in here too.
	sleep(rand(0, 10))
	fdel("saves/save-[n].json")
	text2file(json_encode(data), "saves/save-[n].json")
	text2file("ok", "saves/complete-[n]")
	pilot_save_number = n
	pilot_save_active = FALSE
	if(capture) pilot_storage.transfer_saved(capture)
