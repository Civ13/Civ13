// Native associative graph coverage, separate from ordinary-list controls.
/proc/check_alist_graph()
	map = new(locate(1,1,1))
	var/obj/fixture_leader/leader = new(locate(2,2,2))
	var/list/shared = list("paid" = 7)
	var/area/source_area = get_turf(map).loc
	var/alist/root = map.faction1_squads
	var/alist/leaders = map.faction1_squad_leaders
	check(istype(root, /alist) && root.len == 7 && islist(root[7]), "actual squad defaults differ")
	check(istype(leaders, /alist) && leaders.len == 7 && (7 in leaders) && isnull(leaders[7]), "actual leader defaults differ")
	root[0] = null
	root[1] = shared
	root[7] = shared
	leaders[7] = leader
	root["leaders"] = leaders
	root["self"] = root
	shared["back"] = root
	root[leader] = map
	root[map] = locate(3,4,2)
	root[locate(3,4,2)] = leader
	root[source_area] = /obj/fixture_leader
	var/datum/durable_save_graph/G = new
	var/id = G.encode(root)
	var/list/root_node = G.nodes[id]
	check(root_node["kind"] == "alist", "alist graph kind lost")
	#ifdef DURABLE_ALIST_KIND_CONTROL
	return
	#endif
	var/unbound_rejected = FALSE
	try
		G.finish_export()
	catch(var/exception/E)
		unbound_rejected = !!E
	check(unbound_rejected, "alist unsaved leader was silently dropped")
	#ifdef DURABLE_ALIST_BINDING_CONTROL
	return
	#endif
	G.bind_entry(leader, 2, 7)
	var/list/nodes = G.finish_export()
	text2file(json_encode(nodes), "alist-graph.json")
	var/list/disk = json_decode(file2text("alist-graph.json"))
	var/generation = "alist-generation"
	var/savefile/F = new("map_saves/2.sav")
	F["/generation"] << generation
	F["/entries/7/type"] << /obj/fixture_leader
	var/datum/durable_save_graph/R = new
	R.validate(disk, generation)
	R.accept_entry(2, 7, leader)
	var/list/decoded = R.decode()
	var/alist/result = decoded[id]
	check(istype(result, /alist), "alist restored kind lost")
	check((0 in result) && isnull(result[0]) && result[1] && result[1] == result[7] && result[1]["paid"] == 7, "alist numeric associations lost")
	#ifdef DURABLE_ALIST_VALUES_CONTROL
	return
	#endif
	check(result["self"] == result && result[1]["back"] == result, "alist alias or mixed cycle lost")
	var/alist/restored_leaders = result["leaders"]
	check(istype(restored_leaders, /alist) && restored_leaders[7] == leader && (1 in restored_leaders) && isnull(restored_leaders[1]), "alist leader binding or null value lost")
	check(result[leader] == map && result[map] == locate(3,4,2) && result[locate(3,4,2)] == leader && result[source_area] == /obj/fixture_leader, "alist typed keys or values changed")
	check(!G.atom_pins.len && !G.list_pins.len, "alist graph retained pins")
	check(rejected(list(list("kind" = "alist", "keys" = list(2), "values" = list(99)), list("kind" = "value", "value" = 7)), generation), "alist dangling association accepted")
	check(rejected(list(list("kind" = "alist", "keys" = list(2,3), "values" = list(2,3)), list("kind" = "value", "value" = 7), list("kind" = "value", "value" = 7)), generation), "alist duplicate numeric key accepted")
	F["/generation"] << "another-generation"
	check(rejected(disk, generation), "alist cross-generation entry accepted")
	F["/generation"] << generation
	R = new
	R.validate(disk, generation)
	var/missing_rejected = FALSE
	try
		R.decode()
	catch(var/exception/missing_error)
		missing_rejected = !!missing_error
	check(missing_rejected, "alist unbound restored entry accepted")
