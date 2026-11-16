// Native probe for siege engines and castle defences (code/modules/1713/siege/siege_engines.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/siege_engines/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 16
	maxy = 8
	maxz = 2
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/siege_probe/New()
	return
var/sg_failures = 0
var/sg_runtime_error = FALSE
/proc/sg_check(condition, label)
	if (!condition)
		sg_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	sg_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/siege_probe
		sg_checks()
	catch(var/exception/e)
		sg_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = sg_failures, "runtime_error" = sg_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)


/proc/sg_checks()
	// A gate at (8,4); a ram at (7,4) facing east.
	var/obj/structure/gate/G = new /obj/structure/gate(locate(8, 4, 1))
	var/obj/structure/siege_engine/ram/R = new /obj/structure/siege_engine/ram(locate(7, 4, 1))
	R.set_dir(EAST)
	sg_check(R.target() == G, "a ram faced at a gate finds it")
	sg_check(R.crew() == 0, "nobody at the ropes counts no crew")
	var/before = G.health
	var/dealt = R.swing(G)
	sg_check(dealt > 0 && G.health == before - dealt, "a swing takes health off the gate ([before] -> [G.health])")
	for (var/i in 1 to 20)
		if (QDELETED(G))
			break
		R.swing(G)
	sg_check(QDELETED(G), "enough swings break the gate")
	R.set_dir(NORTH)
	sg_check(!R.target(), "a ram faced at open ground has nothing to hit")

	// Walls and barricades take siege damage too.
	var/obj/structure/barricade/B = new /obj/structure/barricade(locate(3, 2, 1))
	var/bh = B.health
	siege_hit(B, 10)
	sg_check(QDELETED(B) || B.health == bh - 10, "siege damage reaches a barricade")
	sg_check(siege_wall_at(locate(3, 3, 1)) == null, "bare ground is no wall")

	// Ballista: load, fasten, aim down its line.
	var/obj/structure/siege_engine/ballista/BA = new /obj/structure/siege_engine/ballista(locate(2, 6, 1))
	BA.set_dir(EAST)
	var/obj/item/ballista_bolt/bolt = new /obj/item/ballista_bolt(BA.loc)
	BA.loaded = bolt
	bolt.forceMove(BA)
	BA.update_icon()
	sg_check(BA.icon_state == "ballista_loaded", "a loaded ballista shows its bolt")
	var/turf/aim = BA.aim_turf()
	sg_check(aim && aim.y == 6 && aim.x > 2, "a ballista aims straight down the line it faces ([aim ? aim.x : 0],[aim ? aim.y : 0])")
	var/obj/item/projectile/arrow/ballista_bolt/P = new
	sg_check(P.damage >= 80 && P.penetrating >= 2, "a ballista bolt hits hard and goes through")
	qdel(P)

	// Siege tower against a wall: lower the bridge, cross, and moving it raises it.
	var/obj/structure/barricade/W = new /obj/structure/barricade(locate(12, 2, 1))
	var/obj/structure/siege_engine/tower/T = new /obj/structure/siege_engine/tower(locate(11, 2, 1))
	T.set_dir(EAST)
	sg_check(T.wall() == W, "a tower faced at a wall finds it")
	sg_check(T.landing() == locate(13, 2, 1), "the landing is the clear tile beyond the wall")
	T.set_bridge(TRUE)
	sg_check(T.icon_state == "siege_tower_bridge", "a lowered bridge shows")
	var/mob/living/simple_animal/sheep/C = new /mob/living/simple_animal/sheep(locate(10, 2, 1))
	sg_check(T.cross(C, TRUE) && C.loc == locate(13, 2, 1), "a man crosses the bridge over the wall")
	T.Move(locate(11, 1, 1))
	sg_check(!T.bridge, "moving the tower raises its bridge")

	// Trebuchet: a bigger catapult.
	var/obj/structure/catapult/trebuchet/TB = new /obj/structure/catapult/trebuchet(locate(14, 6, 1))
	sg_check(TB.max_range > 80 && TB.min_range >= 30 && TB.blast[2] >= 3, "a trebuchet throws farther and harder than a catapult")
	sg_check(TB.icon_state == "trebuchet0", "a trebuchet uses its own sprite")

	// Castle gates on a winch.
	var/obj/structure/castle_gate/portcullis/PC = new /obj/structure/castle_gate/portcullis(locate(5, 4, 1))
	var/obj/structure/castle_gate/drawbridge/DB = new /obj/structure/castle_gate/drawbridge(locate(5, 3, 1))
	var/obj/structure/castle_winch/WN = new /obj/structure/castle_winch(locate(4, 4, 1))
	sg_check(PC.density && DB.density && DB.opacity, "a portcullis and a raised drawbridge start shut")
	var/obj/item/projectile/arrow/A2 = new
	sg_check(PC.CanPass(A2, locate(5, 5, 1)), "arrows pass through a shut portcullis")
	sg_check(!PC.CanPass(C, locate(5, 5, 1)), "men don't pass a shut portcullis")
	qdel(A2)
	WN.work(TRUE)
	sg_check(PC.open && !PC.density && DB.open && !DB.density && !DB.opacity, "winding the winch raises the portcullis and lowers the bridge")
	WN.work(FALSE)
	sg_check(!PC.open && PC.density && !DB.open, "letting it out shuts them again")
	sg_check(siege_wall_at(get_turf(PC)) == PC, "a ram can work against a castle gate")
	var/ph = PC.health
	siege_hit(PC, 100)
	sg_check(PC.health == ph - 100, "siege damage reaches a portcullis")

	// Murder hole: cold liquid does no harm.
	var/obj/structure/murder_hole/MH = new /obj/structure/murder_hole(locate(9, 8, 1))
	MH.set_dir(SOUTH)
	var/obj/item/weapon/reagent_containers/glass/bucket/BK = new /obj/item/weapon/reagent_containers/glass/bucket(MH.loc)
	BK.reagents.add_reagent("water", 50)
	sg_check(pour_burn_damage(pour_liquid_of(BK), BK.is_hot()) == 0, "cold water through a murder hole doesn't burn")
	sg_check(MH.drop_turf() == locate(9, 7, 1), "with no level below, it pours on the tile it faces")

	// Undermining: a tunnel dug under a wall on the level above.
	z_levels = 1
	var/obj/structure/barricade/UW = new /obj/structure/barricade(locate(6, 6, 2))
	var/turf/U = locate(6, 6, 1)
	sg_check(GetAbove(U) == locate(6, 6, 2), "the probe has a level above")
	sg_check(siege_undermine_target(U) == UW, "an open, unpropped tile under a wall threatens it")
	var/obj/structure/mine_support/MS = new /obj/structure/mine_support(locate(6, 5, 1))
	sg_check(!siege_undermine_target(U) && !siege_undermine(U), "a mine support beside the tunnel holds the wall up")
	qdel(MS)
	sg_check(siege_undermine(U) && QDELETED(UW), "with the prop gone the wall collapses into the mine")
