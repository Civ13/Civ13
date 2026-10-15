#define TRUE 1
#define FALSE 0
#define EXCEPTION(message) new /exception(message)

/world
	maxx = 8
	maxy = 8
	maxz = 2
	fps = 10
/datum/var/should_save = TRUE
/obj/map_metadata
/obj/map_metadata/fixture_no_parent/New()
	return
/obj/screen
/mob/new_player
/mob/living/human
/obj/fixture_leader
/obj/fixture_other
/map_storage/proc/entry_path(savefile/F, ref)
	return "/entries/[ref]"
var/map_storage/map_storage = new
var/obj/map_metadata/map
var/fixture_checks = 0
var/fixture_failures = 0
/proc/get_turf(atom/A)
	while(A && !isturf(A)) A = A.loc
	return A
/proc/check(condition, message)
	fixture_checks++
	if(condition) return
	fixture_failures++
	world.log << "FAIL: [message]"
/proc/rejected(list/nodes, generation)
	var/datum/durable_save_graph/G = new
	try
		G.validate(nodes, generation)
	catch(var/exception/rejected_error)
		if(!rejected_error) return FALSE
		return TRUE
	return FALSE
/proc/check_alist_semantics()
	// Pin the primitive behavior used by production squad defaults on 516.1681.
	var/alist/A = alist(0 = null, 1 = "one", 7 = "seven")
	var/list/observed = list("alist" = list("islist" = islist(A), "isalist_type" = istype(A, /alist)))
	var/obj/map_metadata/defaults = new(locate(1,1,1))
	for(var/key in list("faction1_squads", "faction2_squads", "faction1_squad_leaders", "faction2_squad_leaders"))
		var/value = defaults.vars[key]
		observed[key] = list("islist" = islist(value), "isalist_type" = istype(value, /alist), "isnull" = isnull(value), "isnum" = isnum(value), "text" = "[value]")
	var/obj/map_metadata/fixture_no_parent/skipped = new(locate(1,1,1))
	var/skipped_value = skipped.faction1_squads
	observed["no_parent_faction1_squads"] = list("islist" = islist(skipped_value), "isalist_type" = istype(skipped_value, /alist), "isnull" = isnull(skipped_value), "text" = "[skipped_value]")
	text2file(json_encode(observed), "alist-semantics.json")
	check(istype(A, /alist), "native alist kind differs")
	var/list/keys = list()
	for(var/key in A) keys += list(key)
	check(keys.len == 3 && (0 in keys) && (1 in keys) && (7 in keys), "native alist key iteration differs")
	check(A[1] == "one" && A[7] == "seven" && (0 in A) && isnull(A[0]), "native alist numeric associations differ")
	A["self"] = A
	var/alist/copied = A.Copy()
	check(istype(copied, /alist) && copied["self"] == A && copied[7] == "seven", "native alist copy semantics differ")
	check("\ref[A]" != "\ref[copied]", "native alist identity differs")
/proc/check_graph()
	map = new(locate(1,1,1))
	var/obj/fixture_leader/leader = new(locate(2,2,2))
	var/list/shared = list("paid" = 7, "prototype" = TRUE)
	var/list/root = list("literal" = "**entry7", "nothing" = null, "number" = 23.5, "path" = /obj/fixture_leader, "first" = shared, "second" = shared, "leader" = leader, "map" = map, "turf" = locate(3,4,2))
	root["self"] = root
	var/datum/durable_save_graph/G = new
	var/root_id = G.encode(root)
	var/unbound_rejected = FALSE
	try
		G.finish_export()
	catch(var/exception/unbound_error)
		if(!unbound_error) return
		unbound_rejected = TRUE
	check(unbound_rejected, "unsaved metadata leader was silently dropped")
	#ifdef DURABLE_BINDING_CONTROL
	// Stop at this control's assertion; do not feed its deliberately unbound
	// graph into later tests and misclassify a caught exception as acceptance.
	return
	#endif
	G.bind_entry(leader, 2, 7)
	var/list/nodes = G.finish_export()
	var/generation = "fixture-round-2"
	var/savefile/F = new("map_saves/2.sav")
	F["/generation"] << generation
	F["/entries/7/type"] << /obj/fixture_leader
	check(!rejected(nodes, generation), "valid graph rejected")
	var/list/disk_nodes = json_decode(json_encode(nodes))
	var/datum/durable_save_graph/R = new
	R.validate(disk_nodes, generation)
	R.accept_entry(2, 7, leader)
	var/list/decoded = R.decode()
	var/list/result = decoded[root_id]
	check(result["literal"] == "**entry7" && result["number"] == 23.5 && isnull(result["nothing"]), "scalar values changed")
	check(result["path"] == /obj/fixture_leader && result["map"] == map && result["turf"] == locate(3,4,2), "typed paths/locations changed")
	check(result["first"] == result["second"] && result["self"] == result, "list alias/cycle changed")
	check(result["leader"] == leader && result["first"]["paid"] == 7, "leader or paid research changed")
	check(!G.atom_pins.len && !G.list_pins.len, "export retained live graph pins")
	F["/generation"] << "another-generation"
	check(rejected(disk_nodes, generation), "cross-generation leader accepted")
	F["/generation"] << generation
	F["/entries/7/type"] << /obj/fixture_other
	check(rejected(disk_nodes, generation), "wrong leader type accepted")
	F["/entries/7/type"] << /obj/fixture_leader
	var/missing_rejected = FALSE
	R = new
	R.validate(disk_nodes, generation)
	try
		R.decode()
	catch(var/exception/missing_error)
		if(!missing_error) return
		missing_rejected = TRUE
	check(missing_rejected, "missing restored leader accepted")
	check(rejected(list(8), generation), "non-node graph member accepted")
	check(rejected(list(list("kind" = "client")), generation), "unknown graph kind accepted")
	check(rejected(list(list("kind" = "value", "value" = list())), generation), "container disguised as scalar accepted")
	check(rejected(list(list("kind" = "list", "keys" = list(2), "values" = list(2))), generation), "dangling graph edge accepted")
	check(rejected(list(list("kind" = "path", "type" = "/client")), generation), "client path accepted")
	check(rejected(list(list("kind" = "value", "value" = 2, "extra" = TRUE)), generation), "extra graph fields accepted")

/world/New()
	..()
	world.OpenPort(0)
	try
		check_alist_semantics()
		check_graph()
	catch(var/exception/E)
		fixture_failures++
		world.log << "FAIL: unexpected exception [E] at [E.file]:[E.line]"
	text2file(json_encode(list("checks" = fixture_checks, "failures" = fixture_failures, "done" = TRUE)), "result.json")
	shutdown()
