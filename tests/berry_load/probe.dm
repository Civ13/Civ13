// Berry effects across a whole-world save/load on a synthetic 4x1x1 world.
/obj/map_metadata/berry_fixture/New()
	return
/proc/berry_check(condition, message)
	if(!condition)
		text2file("FAIL: [message]", "berry_result.txt")
		del(world)
		sleep(1)
/proc/berry_reagents(obj/item/weapon/reagent_containers/R)
	var/list/out = list()
	if(R && R.reagents)
		for(var/datum/reagent/X in R.reagents.reagent_list)
			out += "[X.id]=[X.volume]"
	return jointext(out, ",")
/world
	hub = ""
	hub_password = ""
	maxx = 4
	maxy = 1
	maxz = 1
	fps = 20
	turf = /turf
/world/Topic(T, addr, master, key)
	return "Berry fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e] on [e.file]:[e.line]"
	text2file("FAIL: runtime [e] on [e.file]:[e.line]", "berry_result.txt")
	del(world)
	sleep(1)
/world/New()
	generate_gameid()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	map = new /obj/map_metadata/berry_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.persistence = TRUE
	season = "SUMMER"
	var/area/caribbean/nomads/semiarid/base = locate(/area/caribbean/nomads/semiarid)
	if(!base) base = new /area/caribbean/nomads/semiarid
	for(var/turf/T in world)
		ChangeArea(T, base)
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	// The world's berry configuration when the berries were picked.
	map.berryeffects = list(list("tinto","poisonous","cyanide"), list("amar","tasty","water"), list("majo","neutral","water"), list("azul","disgusting","water"))
	var/obj/item/weapon/reagent_containers/food/snacks/grown/berries/tinto/tinto = new(locate(1,1,1))
	var/obj/item/weapon/reagent_containers/food/snacks/grown/berries/amar/amar = new(locate(2,1,1))
	var/obj/item/weapon/reagent_containers/food/snacks/grown/berries/majo/majo = new(locate(3,1,1))
	var/obj/item/weapon/reagent_containers/food/snacks/grown/berries/azul/azul = new(locate(4,1,1))
	sleep(10)
	var/tinto_before = berry_reagents(tinto)
	var/majo_before = berry_reagents(majo)
	berry_check(findtext(tinto_before, "cyanide=5"), "picked tinto berries carry the world's poison ([tinto_before])")
	berry_check(amar.satisfaction == 6 && azul.satisfaction == -6 && majo.satisfaction == 3, "picked berries taste as configured ([amar.satisfaction], [azul.satisfaction], [majo.satisfaction])")
	// The world save carries map.berryeffects through the durable metadata graph.
	// Smell notes compare a context hash, which must survive that round trip.
	var/context_before = berry_discovery_context()
	var/datum/durable_save_graph/G = new
	var/root = G.encode(map.berryeffects)
	var/datum/durable_save_graph/R = new
	R.nodes = json_decode(json_encode(G.nodes))
	var/list/decoded = R.decode()[root]
	berry_check(decoded.len == 4 && decoded[1][3] == "cyanide" && decoded[2][2] == "tasty", "decoded berry configuration keeps its rows")
	var/list/saved_effects = map.berryeffects
	map.berryeffects = decoded
	var/context_after = berry_discovery_context()
	map.berryeffects = list(list("tinto","healing","paracetamol"), list("amar","tasty","water"), list("majo","neutral","water"), list("azul","disgusting","water"))
	var/context_other = berry_discovery_context()
	map.berryeffects = saved_effects
	berry_check(context_after == context_before, "smell notes keep their berry context across a load")
	berry_check(context_other != context_before, "a different berry configuration has a different context")
	berry_check(map_storage.Save_World(), "production whole-world export succeeds")
	berry_check(map_storage.validate_world_save(), "production preflight accepts the save: [map_storage.last_error]")
	// A restart builds a fresh map controller, which rolls a new configuration
	// before the save is read. Restored berries must not take it.
	map.berryeffects = list(list("tinto","healing","paracetamol"), list("amar","disgusting","water"), list("majo","tasty","water"), list("azul","drug","peyote"))
	map_storage.ClearMap()
	berry_check(map_storage.Load_World(), "production whole-world import succeeds: [map_storage.last_error]")
	sleep(20)
	tinto = locate(/obj/item/weapon/reagent_containers/food/snacks/grown/berries/tinto) in locate(1,1,1)
	amar = locate(/obj/item/weapon/reagent_containers/food/snacks/grown/berries/amar) in locate(2,1,1)
	majo = locate(/obj/item/weapon/reagent_containers/food/snacks/grown/berries/majo) in locate(3,1,1)
	azul = locate(/obj/item/weapon/reagent_containers/food/snacks/grown/berries/azul) in locate(4,1,1)
	berry_check(tinto && amar && majo && azul, "berries are restored")
	var/tinto_after = berry_reagents(tinto)
	var/majo_after = berry_reagents(majo)
	var/azul_after = berry_reagents(azul)
	berry_check(tinto_after == tinto_before, "restored tinto berries keep their chemicals ([tinto_before] -> [tinto_after])")
	berry_check(majo_after == majo_before, "restored majo berries keep their chemicals ([majo_before] -> [majo_after])")
	berry_check(!findtext(azul_after, "peyote"), "restored azul berries do not gain the new roll's drug ([azul_after])")
	berry_check(amar.satisfaction == 6 && azul.satisfaction == -6 && majo.satisfaction == 3, "restored berries keep their taste ([amar.satisfaction], [azul.satisfaction], [majo.satisfaction])")
	text2file("PASS: picked berries keep their chemicals and taste across save/load", "berry_result.txt")
	del(world)
