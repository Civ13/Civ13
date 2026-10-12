// Real production accounts and spool, driven by an isolated PHP client.
/world
	hub = ""
	hub_password = ""
	maxx = 8
	maxy = 8
	maxz = 1
	turf = /turf
	area = /area

/world/OpenPort(port)
	if (port == "none") return ..()
	return FALSE

/world/Error(exception/E)
	world.log << "Runtime error: [E] at [E.file]:[E.line]"

/proc/economic_spool_assert(condition, message)
	if (!condition) throw EXCEPTION(message)

/world/New()
	world.OpenPort("none")
	spawn(2)
		try
			run_economic_spool_probe()
			text2file("PASS: native economic spool phase", "result.txt")
		catch (var/exception/E)
			world.log << "FAIL: [E] at [E.file]:[E.line]"
			text2file("FAIL: native economic spool phase", "result.txt")
		shutdown()

/proc/run_economic_spool_probe()
	makeDatumRefLists()
	GLOB.all_observable_events = list()
	GLOB.global_listen_count = list()
	GLOB.event_sources_count = list()
	GLOB.event_listen_count = list()
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.moved_event = new /decl/observ/moved
	GLOB.destroyed_event = new /decl/observ/destroyed
	var/list/params = world.params
	var/phase = params["phase"]
	var/datum/extraction_service/game = new
	game.store.root = "data/economic_accounts/"
	var/datum/extraction_ipc_service/ipc = new(game.store)
	ipc.enabled = TRUE
	ipc.key = "0123456789abcdef0123456789abcdef"
	economic_spool_assert(ipc.ready(), "isolated native IPC account store ready")
	var/datum/extraction_ipc_economy/economy = new(game)
	ipc.economic_adapter = economy
	economic_spool_assert(economy.ready(), "native settlement repair and finite treasury ready")
	if (phase == "init")
		ipc.profile["links"]["123"] = "spoolseller"
		ipc.profile["owners"]["spoolseller"] = "123"
		ipc.profile["links"]["456"] = "spoolbuyer"
		ipc.profile["owners"]["spoolbuyer"] = "456"
		economic_spool_assert(ipc.commit(json_decode(json_encode(ipc.profile))), "synthetic bindings committed")
		var/list/seller = game.store.load_profile("spoolseller")
		var/list/buyer = game.store.load_profile("spoolbuyer")
		var/datum/extraction_equipment_codec/codec = new
		var/obj/item/extraction_salvage/part = new(locate(1,1,1))
		economic_spool_assert(codec.set_raid_provenance(part, TRUE), "native raid provenance")
		var/list/graph = codec.encode(part)
		graph["nodes"][1]["id"] = "spool-part"
		economic_spool_assert(codec.validate(graph), "native complete gear graph")
		seller["stash"] = list(list("id" = "spool-part", "equipment" = graph))
		buyer["credits"] = 100
		economic_spool_assert(game.store.commit_profile("spoolseller", seller) && game.store.commit_profile("spoolbuyer", buyer), "temporary funded profiles committed")
		text2file(md5(json_encode(graph)), "graph-digest.txt")
	else if (phase == "upgrade-stock")
		var/list/buyer = game.store.load_profile("spoolbuyer")
		var/datum/extraction_equipment_codec/codec = new
		for (var/i in 1 to 5)
			var/obj/item/extraction_salvage/part = new(locate(1,1,1))
			var/list/graph = codec.encode(part)
			var/id = "room-part-[i]"
			graph["nodes"][1]["id"] = id
			buyer["stash"] += list(list("id" = id, "equipment" = graph, "salvage" = TRUE))
			qdel(part)
		economic_spool_assert(game.store.commit_profile("spoolbuyer", buyer), "isolated paid upgrade stock")
	else
		var/datum/extraction_ipc_spool/spool = new(ipc)
		spool.root = "data/economic_spool/"
		spool.enabled = TRUE
		economic_spool_assert(spool.ready(), "isolated native spool writer ready")
		if (phase == "interrupt") game.settlement.test_fail_at = "after_receipt"
		// Visit every bounded request, including completed immutable replies.
		var/visited = 0
		for (var/name in flist(spool.root))
			if (length(name) == 72 && copytext(name, 65) == ".request")
				visited++
				var/id = copytext(name, 1, 65)
				var/wire = spool.read(spool.path(id, "request"))
				var/list/bytes = extraction_ipc_verify(wire, ipc.key, "1000")
				economic_spool_assert(islist(bytes), "actual PHP envelope MAC and time validation")
				var/list/request = extraction_ipc_request(bytes)
				economic_spool_assert(islist(request), "actual PHP request canonical digest and schema")
				var/processed = spool.process(id, "1000")
				if (phase != "interrupt") economic_spool_assert(processed, "native spool published the matching durable PHP response")
		economic_spool_assert(visited, "native spool found PHP immutable request files")
		if (phase == "interrupt") economic_spool_assert(!game.open("spoolbuyer"), "uncertain shared settlement blocks game account access")
		if (phase == "verify")
			var/list/seller = game.store.load_profile("spoolseller")
			var/list/buyer = game.store.load_profile("spoolbuyer")
			var/list/vendor = game.store.load_profile("extractionvendor")
			var/list/market = game.store.load_profile("extractionmarket")
			economic_spool_assert(seller["credits"] == 20 && buyer["credits"] == 90 && vendor["credits"] == 999990, "native list-buy-cancel-buyback conserves all wallet balances")
			economic_spool_assert(!length(seller["stash"]) && !length(buyer["stash"]) && !length(market["stash"]) && length(vendor["stash"]) == 1, "native ownership moves exactly once through escrow into vendor")
			economic_spool_assert(vendor["stash"][1]["id"] == "spool-part" && md5(json_encode(vendor["stash"][1]["equipment"])) == trim(file2text("graph-digest.txt")), "original full gear identity and condition survive native PHP roundtrip")
		if (phase == "upgrade-verify")
			var/list/buyer = game.store.load_profile("spoolbuyer")
			economic_spool_assert(buyer["level"] == 2 && buyer["credits"] == 90 && !length(buyer["stash"]), "PHP room upgrade consumes paid native parts once and preserves wallet")
