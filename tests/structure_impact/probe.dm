// Native probe for structure impacts (code/game/objects/structure_impact.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/structure_impact/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 16
	maxy = 8
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/structure_impact_probe/New()
	return
var/si_failures = 0
var/si_runtime_error = FALSE
/proc/si_check(condition, label)
	if (!condition)
		si_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	si_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/structure_impact_probe
		si_checks()
	catch(var/exception/e)
		si_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = si_failures, "runtime_error" = si_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/si_checks()
	// Materials: thatch < wood < clay < stone < concrete < steel.
	var/list/order = list("thatch", "Wood", "Clay", "Stone", "concrete", "Steel")
	var/ordered = TRUE
	for (var/i in 2 to order.len)
		if (structure_material_resistance(order[i]) <= structure_material_resistance(order[i - 1]))
			ordered = FALSE
	si_check(ordered, "material resistance rises from thatch to steel")
	si_check(structure_material_resistance(null) == 1 && structure_material_resistance("Wood") == 1, "wood and unknown materials are the unit")

	// A wooden wall takes the force as damage and holds a small knock.
	var/obj/covers/wood_wall/WW = new /obj/covers/wood_wall(locate(2, 2, 1))
	si_check(is_structure_impact_part(WW), "a player wall is a building part")
	var/left = WW.structure_impact(50)
	si_check(left == 0 && WW.health == 250, "a wooden wall holds a 50 knock and loses 50 health ([WW.health], left [left])")
	si_check(WW.impact_crack_stage() == 0, "a lightly hit wall shows no cracks")
	WW.structure_impact(120)
	si_check(WW.impact_crack_stage() == 2, "a wall at half health shows heavier cracks ([WW.impact_crack_stage()])")
	left = WW.structure_impact(400)
	si_check(QDELETED(WW) && left == 270, "a big hit breaks it and the rest carries on (left [left])")

	// Stone shrugs off more: the same force does 2.5 times less damage.
	var/obj/covers/stone_wall/SW = new /obj/covers/stone_wall(locate(3, 2, 1))
	var/sh = SW.health
	left = SW.structure_impact(100)
	si_check(left == 0 && SW.health == sh - 40, "a stone wall takes force / 2.5 ([sh] -> [SW.health])")
	var/raw_before = SW.health
	SW.structure_impact(10, IMPACT_RAW)
	si_check(SW.health == raw_before - 10, "raw siege force is not scaled by material")

	// Mapped walls take impacts and fall; the world edge does not.
	var/turf/wall/wood/TW = locate(4, 4, 1)
	TW.ChangeTurf(/turf/wall/wood)
	TW = locate(4, 4, 1)
	si_check(is_structure_impact_part(TW), "a mapped wall is a building part")
	var/cap = TW.material ? TW.material.integrity : 150
	left = TW.structure_impact(10)
	si_check(left == 0 && TW.damage > 0, "a mapped wall takes damage from a knock ([TW.damage])")
	left = TW.structure_impact(cap * 2 * 3)
	var/turf/after = locate(4, 4, 1)
	si_check(!istype(after, /turf/wall/wood) && left > 0, "a hard enough hit brings a mapped wall down (now [after.type], left [left])")
	var/turf/wall/indestructable/IW = locate(6, 6, 1)
	IW.ChangeTurf(/turf/wall/indestructable)
	IW = locate(6, 6, 1)
	si_check(IW.structure_impact(1000000) == 0 && istype(IW, /turf/wall/indestructable), "an indestructible wall stops everything")

	// Roofs cave in by their own material.
	var/obj/roof/thatch/RT = new /obj/roof/thatch(locate(8, 2, 1))
	si_check(RT.structure_impact_material() == "thatch", "a thatch roof counts as thatch")
	left = RT.structure_impact(1000)
	si_check(QDELETED(RT) && left > 0, "a big hit caves in a thatch roof")

	// Pillars, doors and barricades.
	var/obj/structure/roof_support/RS = new /obj/structure/roof_support(locate(10, 2, 1))
	si_check(is_structure_impact_part(RS), "a roof support is a building part")
	left = RS.structure_impact(1000)
	si_check(QDELETED(RS) && left == 900, "a hit beyond its 100 health breaks a wooden pillar (left [left])")
	var/obj/structure/gate/G = new /obj/structure/gate(locate(12, 2, 1))
	var/gh = G.health
	siege_hit(G, 5)
	si_check(G.health == gh - 5, "siege damage still lands on a gate unscaled")

	// Things that are not building parts pass the force on untouched.
	var/obj/item/stack/material/wood/I = new /obj/item/stack/material/wood(locate(14, 2, 1))
	si_check(!is_structure_impact_part(I) && I.structure_impact(77) == 77, "an item is not a building part")
	si_check(!is_structure_impact_part(null), "nothing is not a building part")
