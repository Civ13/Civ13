// Native synthetic ruby regression probe. Run with tests/ecology_spawning/run_linux.py.
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/ruby_probe/New()
	return
/obj/map_metadata/ruby_probe/is_node_done(faction, node_id)
	return TRUE
/obj/map_metadata/ruby_probe/recipe_knowledge_enabled()
	return FALSE
/obj/map_metadata/ruby_probe/book_research_enabled()
	return FALSE
/obj/structure/window/ruby_probe/New()
	return
/mob/living/human/ruby_probe
	var/atom/last_work_target
	var/obj/item/last_output
/mob/living/human/ruby_probe/New()
	icon_update = FALSE
	hand = FALSE
/mob/living/human/ruby_probe/survival_action_started(atom/target, datum/pickaxe_mining_action/mining_context)
	last_work_target = target
	return ..()
/mob/living/human/ruby_probe/put_in_hands(obj/item/W)
	last_output = W
	W.forceMove(src)
	return TRUE

var/ruby_failures = 0
var/ruby_runtime_error = FALSE
/proc/ruby_check(condition, label)
	if (!condition)
		ruby_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ruby_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.global_listen_count = list()
		GLOB.event_sources_count = list()
		GLOB.event_listen_count = list()
		movementMachine = new
		initialize_chemical_reagents()
		initialize_chemical_reactions()
		map = new /obj/map_metadata/ruby_probe
		build_research_tree()
		ruby_probe_actions()
	catch(var/exception/e)
		ruby_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ruby_failures, "runtime_error" = ruby_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/ruby_probe_actions()
	var/mob/living/human/ruby_probe/H = new(locate(6, 6, 1))
	var/turf/work = locate(7, 6, 1)
	new /obj/structure/furnace(work)
	new /obj/structure/furnace(locate(5, 6, 1))
	var/list/furnaces = list()
	for (var/obj/structure/furnace/F in range(1, H))
		F.on = TRUE
		furnaces += F
	var/obj/structure/furnace/blocked = furnaces[1]
	var/obj/structure/furnace/reachable = furnaces[2]
	var/obj/structure/window/ruby_probe/blocker = new(blocked.loc)
	blocker.dir = get_dir(blocked, H)
	var/obj/structure/window/ruby_probe/gate = new(reachable.loc)
	gate.dir = NORTH
	var/obj/item/stack/emery_powder/emery = new(H)
	emery.amount = 12
	H.r_hand = emery
	ruby_check(!blocked.Adjacent(H) && reachable.Adjacent(H), "first scanned lit furnace is blocked; second is reachable")
	emery.attack_self(H)
	ruby_check(H.last_work_target == reachable && istype(H.last_output, /obj/item/ruby_boule) && emery.amount == 8, "fusion skips the first furnace and uses the reachable one")
	H.last_output = null
	spawn(1)
		gate.dir = get_dir(reachable, H)
	emery.attack_self(H)
	ruby_check(H.last_work_target == reachable && !H.last_output && emery.amount == 8, "losing access to the selected furnace preserves emery")
	qdel(gate)
	qdel(blocker)
	qdel(blocked)
	qdel(reachable)

	var/obj/item/weapon/chisel/chisel = new(H)
	var/obj/item/weapon/hammer/hammer = new(H)
	var/obj/item/weapon/hammer/substitute = new(H)
	var/obj/item/ruby_boule/floor_boule = new(work)
	var/obj/structure/window/ruby_probe/edge = new(work)
	edge.dir = NORTH
	H.r_hand = chisel
	H.l_hand = hammer
	spawn(1)
		edge.dir = WEST
	floor_boule.attackby(chisel, H)
	ruby_check(!QDELETED(floor_boule) && !(locate(/obj/item/stack/jewel_bearing) in work), "losing reach preserves the floor boule and makes no bearings")
	edge.dir = NORTH
	spawn(1)
		H.l_hand = null
	floor_boule.attackby(chisel, H)
	ruby_check(!QDELETED(floor_boule) && !(locate(/obj/item/stack/jewel_bearing) in work), "stowing the hammer preserves the boule")
	H.l_hand = hammer
	spawn(1)
		H.l_hand = substitute
	floor_boule.attackby(chisel, H)
	ruby_check(!QDELETED(floor_boule) && !(locate(/obj/item/stack/jewel_bearing) in work), "a different valid hammer cannot finish the original action")
	H.l_hand = hammer
	var/obj/item/ruby_boule/held_boule = new(H)
	held_boule.attackby(chisel, H)
	var/obj/item/stack/jewel_bearing/bearings = locate() in get_turf(H)
	ruby_check(QDELETED(held_boule) && bearings?.amount == 10, "the held workpiece route still makes ten bearings with the original tools")

	var/obj/structure/lapping_wheel/wheel = new(work)
	wheel.charges = 4
	var/obj/item/ruby_boule/for_wheel = new(H)
	H.r_hand = for_wheel
	spawn(1)
		edge.dir = WEST
	wheel.make_ruby_rod(for_wheel, H)
	ruby_check(!QDELETED(for_wheel) && wheel.charges == 4, "losing wheel reach preserves its charges and the boule")
	edge.dir = NORTH

	var/obj/item/ruby_rod/rod = new(H)
	var/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars/floor_glasses = new(work)
	H.r_hand = rod
	spawn(1)
		edge.dir = WEST
	floor_glasses.attackby(rod, H)
	ruby_check(!QDELETED(floor_glasses) && !QDELETED(rod) && !H.last_output, "losing reach preserves both retrofit inputs")
	edge.dir = NORTH

	var/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars/held_glasses = new(H)
	H.l_hand = held_glasses
	held_glasses.attackby(rod, H)
	ruby_check(QDELETED(held_glasses) && QDELETED(rod) && istype(H.last_output, /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars/rangefinder) && H.last_output.loc == H, "held retrofit consumes both parts and hands back a rangefinder")
