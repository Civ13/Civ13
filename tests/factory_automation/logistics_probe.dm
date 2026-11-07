// Factory automation phase 4: fast belts, train wagon / cart ports and the
// factory monitor. Runs
// the production sources through the shared resource-extraction fixture with
// ordinary game startup disabled; belt and arm steps are called directly.
/world
	hub = ""
	hub_password = ""
	maxx = 16
	maxy = 16
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/logistics_probe/New()
	return
/mob/living/human/logistics_probe/New()
	return
/mob/living/human/logistics_probe/update_icons()
	return
var/machine_failures = 0
var/machine_runtime_error = FALSE
/proc/machine_check(condition, label)
	if (!condition)
		machine_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	machine_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/proc/belt_floor(x, y)
	var/turf/T = locate(x, y, 1)
	return T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
/proc/belt_run(steps)
	for (var/i in 1 to steps)
		factory_belts_step()
/proc/belt_count(atom/A, type)
	var/total = 0
	for (var/obj/item/stack/S in A)
		if (S.type == type)
			total += S.amount
	return total
/proc/belt_closed_crate(turf/T, capacity = 20)
	var/obj/structure/closet/crate/C = new(T)
	C.opened = FALSE
	C.storage_capacity = capacity
	for (var/obj/item/I in C)
		qdel(I)
	return C
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		populate_material_list()
		build_research_tree()
		map = new /obj/map_metadata/logistics_probe
		map.ordinal_age = 8
		for (var/x in 1 to 16)
			for (var/y in 1 to 16)
				belt_floor(x, y)
		machine_check(!world.port, "fixture has no listening port")
		machine_drive()
		machine_fast_belt_checks()
		machine_wagon_checks()
		machine_cargo_hold_checks()
		machine_monitor_checks()
	catch(var/exception/e)
		machine_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = machine_failures, "runtime_error" = machine_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/machine_power(obj/O, x, y)
	var/obj/structure/cable/C = new(locate(x, y, 1))
	var/obj/structure/engine/E = new(locate(x, y, 1))
	E.on = TRUE
	E.maxpower = 50
	E.connections = list(C)
	C.connections = list(O, E)
	O.powersource = C
	return list(C, E)



/proc/machine_drive()
	var/obj/structure/factory_drive/D = new(locate(16, 16, 1))
	D.drive_range = 30
	var/obj/structure/cable/C = new(locate(16, 16, 1))
	var/obj/structure/engine/E = new(locate(16, 16, 1))
	E.on = TRUE
	E.maxpower = 100
	E.connections = list(C)
	C.connections = list(D, E)
	D.powersource = C
	D.on = TRUE
	D.drive_wake()
	factory_drives_step()
	machine_check(D.powered, "a cabled drive powers the fixture's belts")

/proc/machine_line(y, list/types, obj/structure/closet/crate/end)
	var/x = 2
	for (var/type in types)
		var/obj/structure/factory_belt/B = new type(locate(x, y, 1))
		B.set_dir(EAST)
		x++

/proc/machine_fast_belt_checks()
	var/obj/structure/closet/crate/plain_end = belt_closed_crate(locate(8, 2, 1))
	var/obj/structure/closet/crate/fast_end = belt_closed_crate(locate(8, 4, 1))
	var/obj/structure/closet/crate/mixed_end = belt_closed_crate(locate(8, 6, 1))
	var/plain = /obj/structure/factory_belt
	var/fast = /obj/structure/factory_belt/fast
	machine_line(2, list(plain, plain, plain, plain, plain, plain))
	machine_line(4, list(fast, fast, fast, fast, fast, fast))
	machine_line(6, list(fast, fast, fast, plain, plain, plain))
	new /obj/item/stack/material/steel(locate(2, 2, 1), 1, FALSE)
	new /obj/item/stack/material/steel(locate(2, 4, 1), 1, FALSE)
	new /obj/item/stack/material/steel(locate(2, 6, 1), 1, FALSE)
	var/obj/structure/factory_belt/first_fast = locate() in locate(2, 4, 1)
	machine_check(first_fast.belt_passes == 2 && (first_fast in factory_active_fast_belts), "a fast belt takes two steps a tick and joins the fast list")
	var/plain_steps = 0
	var/fast_steps = 0
	var/mixed_steps = 0
	for (var/i in 1 to 12)
		belt_run(1)
		if (!fast_steps && belt_count(fast_end, /obj/item/stack/material/steel))
			fast_steps = i
		if (!plain_steps && belt_count(plain_end, /obj/item/stack/material/steel))
			plain_steps = i
		if (!mixed_steps && belt_count(mixed_end, /obj/item/stack/material/steel))
			mixed_steps = i
	world.log << "steps to the crate: plain [plain_steps], fast [fast_steps], mixed [mixed_steps]"
	machine_check(plain_steps && fast_steps && fast_steps * 2 <= plain_steps + 1, "cargo on fast belts reaches the crate in about half the steps")
	machine_check(mixed_steps && mixed_steps > fast_steps && mixed_steps < plain_steps, "fast belts hand cargo on to plain belts")
	belt_run(2)
	machine_check(!(first_fast in factory_active_fast_belts) && !first_fast.belt_active, "an empty fast belt sleeps and leaves the fast list")
	var/obj/item/factory_belt_assembly/fast/A = new(locate(10, 2, 1))
	machine_check(A.belt_type == fast && first_fast.assembly_type == /obj/item/factory_belt_assembly/fast, "the fast belt assembly lays and returns a fast belt")
	machine_check(recipe_node_requirements["/obj/item/factory_belt_assembly/fast"] == "automation", "fast belts are gated behind Automation")
	qdel(A)

/proc/machine_arm(x, y)
	var/obj/structure/factory_arm/A = new(locate(x, y, 1))
	A.set_dir(EAST)
	A.on = TRUE
	machine_power(A, x, y + 1)
	return A

/proc/machine_swing(obj/structure/factory_arm/A)
	A.next_swing = 0
	A.arm_step()

/proc/machine_wagon_checks()
	var/obj/structure/closet/crate/source = belt_closed_crate(locate(1, 10, 1), 40)
	for (var/i in 1 to 10)
		new /obj/item/stack/material/steel(source, 1, FALSE)
	var/obj/structure/trains/storage/closed/W = new(locate(3, 10, 1))
	var/obj/structure/closet/crate/dest = belt_closed_crate(locate(5, 10, 1), 40)
	var/obj/structure/factory_arm/load = machine_arm(2, 10)
	var/obj/structure/factory_arm/unload = machine_arm(4, 10)
	unload.on = FALSE
	machine_swing(load)
	machine_check(belt_count(W.storage, /obj/item/stack/material/steel) == 1, "an arm loads a train wagon")
	for (var/i in 1 to 9)
		machine_swing(load)
	machine_check(W.storage.contents.len == W.max_storage && belt_count(source, /obj/item/stack/material/steel) == 2, "a wagon takes only what fits, as by hand")
	var/obj/item/stack/material/steel/extra = locate() in source
	machine_check(!W.factory_accepts(extra), "a full wagon refuses more")
	unload.on = TRUE
	machine_swing(unload)
	machine_check(belt_count(dest, /obj/item/stack/material/steel) == 1 && W.storage.contents.len == W.max_storage - 1, "an arm unloads a train wagon")
	unload.filter_type = /obj/item/stack/material/copper
	machine_check(!W.factory_offer(0, /obj/item/stack/material/copper), "a wagon offers only what a filter asks for")
	var/obj/structure/trains/storage/tender/T = new(locate(3, 12, 1))
	var/obj/item/stack/ore/coal/coal = new(locate(4, 12, 1), 5)
	machine_check(!T.factory_accepts(extra) && T.factory_accepts(coal) == 5, "a tender takes only fuel")
	machine_check(T.factory_insert(coal) == 5 && coal.loc == T.storage, "a tender loads coal from automation")
	var/obj/structure/shopping_cart/cart = new(locate(6, 12, 1))
	var/obj/item/stack/material/steel/loose = new(locate(7, 12, 1), 3, FALSE)
	machine_check(cart.factory_insert(loose) == 3 && loose.loc == cart.storage, "a shopping cart loads from automation")
	var/obj/structure/closet/crate/out = belt_closed_crate(locate(8, 13, 1))
	machine_check(cart.factory_offer() == loose && cart.factory_take(loose, out) && loose.loc == out, "a shopping cart unloads to automation")

/proc/machine_cargo_hold_checks()
	var/obj/structure/closet/crate/source = belt_closed_crate(locate(1, 15, 1), 40)
	for (var/i in 1 to 25)
		new /obj/item/stack/material/steel(source, 1, FALSE)
	var/obj/structure/cargo_hold/H = new(locate(3, 15, 1))
	var/obj/structure/closet/crate/dest = belt_closed_crate(locate(5, 15, 1), 40)
	var/obj/structure/factory_arm/load = machine_arm(2, 15)
	var/obj/structure/factory_arm/unload = machine_arm(4, 15)
	unload.on = FALSE
	machine_swing(load)
	machine_check(belt_count(H.storage, /obj/item/stack/material/steel) == 1, "an arm loads a cargo hold")
	for (var/i in 1 to 24)
		machine_swing(load)
	machine_check(H.storage.contents.len == H.max_storage && H.max_storage == 20 && belt_count(source, /obj/item/stack/material/steel) == 5, "a cargo hold takes twenty items and no more")
	var/obj/item/stack/material/steel/extra = locate() in source
	machine_check(!H.factory_accepts(extra), "a full cargo hold refuses more")
	unload.on = TRUE
	machine_swing(unload)
	machine_check(belt_count(dest, /obj/item/stack/material/steel) == 1 && H.storage.contents.len == H.max_storage - 1, "an arm unloads a cargo hold")
	machine_check(!H.factory_offer(0, /obj/item/stack/material/copper), "a cargo hold offers only what a filter asks for")
	var/obj/item/weapon/wrench/W = new(locate(3, 14, 1))
	machine_check(!H.anchored, "a new cargo hold is loose")
	H.attackby(W, null)
	machine_check(H.anchored, "a wrench bolts a cargo hold down")
	var/obj/structure/vehicleparts/axis/A = new(locate(10, 15, 1))
	var/obj/structure/vehicleparts/frame/F = new(locate(11, 15, 1))
	F.axis = A
	A.components = list(F)
	var/obj/structure/cargo_hold/riding = new(locate(11, 15, 1))
	riding.anchored = TRUE
	A.add_transporting(FALSE)
	machine_check(riding in A.transporting, "a cargo hold on a vehicle frame rides with the vehicle")
	machine_check(recipe_node_requirements["/obj/structure/cargo_hold"] == "automobiles", "the cargo hold unlocks with Automobiles")
	var/found = FALSE
	for (var/line in splittext(file2text("config/crafting/material_recipes_global.txt"), "\n"))
		if (findtext(line, "RECIPE: /material/steel/,cargo hold,/obj/structure/cargo_hold,") == 1)
			found = TRUE
	machine_check(found, "the cargo hold has a steel recipe")
	for (var/obj/O in list(source, H, dest, load, unload, W, riding, F, A))
		qdel(O)

/proc/machine_monitor_row(list/rows, kind, x, y)
	for (var/list/row in rows)
		if (row[2] == kind && row[3] == x && row[4] == y)
			return row
	return null

/proc/machine_monitor_checks()
	var/datum/factory_rate/R = new
	R.add(10)
	machine_check(R.per_minute() == 10, "a fresh rate counts what it has seen")
	R.start = world.time - 700
	var/rate = R.per_minute()
	machine_check(rate > 8 && rate < 9 && R.current == 0 && R.previous == 10, "a rate rolls into the previous minute and averages over the window ([rate])")
	R.start = world.time - 1300
	machine_check(!R.per_minute(), "a rate idle for two minutes reads zero")
	var/obj/structure/factory_fabricator/F = new(locate(12, 12, 1))
	F.set_recipe("barbwire")
	F.fab_step()
	var/obj/structure/factory_monitor/M = new(locate(9, 9, 1))
	var/list/rows = M.report_rows()
	var/list/arm_row = machine_monitor_row(rows, "arm", 2, 10)
	machine_check(arm_row && arm_row[5] == "waiting" && arm_row[6] == 8, "the monitor lists the loading arm, its state and the eight items it moved this minute ([arm_row ? "[arm_row[5]] [arm_row[6]]" : "missing"])")
	var/list/fab_row = machine_monitor_row(rows, "fabricator", 12, 12)
	machine_check(fab_row && fab_row[5] == "starved" && findtext(fab_row[7], "barbwire"), "the monitor shows a fabricator without inputs as starved")
	var/list/drive_row = machine_monitor_row(rows, "drive", 16, 16)
	machine_check(drive_row && drive_row[5] == "running", "the monitor lists the belt drive")
	var/list/belt_row = machine_monitor_row(rows, "belts", null, null)
	machine_check(belt_row && findtext(belt_row[7], " belts"), "the monitor sums up the belts in range")
	var/obj/structure/factory_drive/drive = locate(/obj/structure/factory_drive) in locate(16, 16, 1)
	machine_check(drive_row && drive && drive_row[8] == drive.powerneeded && drive.powerneeded > 0, "the monitor shows the drive's power draw ([drive_row ? drive_row[8] : "missing"])")
	var/obj/structure/factory_arm/loader = locate(/obj/structure/factory_arm) in locate(2, 10, 1)
	machine_check(arm_row && loader && arm_row[8] == factory_power_draw(loader), "the monitor shows the arm's reserved power ([arm_row ? arm_row[8] : "missing"])")
	machine_check(fab_row && fab_row[8] == 0, "an unpowered fabricator draws no power on the monitor")
	machine_check(belt_row && belt_row[8] == 0, "belts draw through their drive, not on their own")
	var/list/power = M.power_summary(rows)
	var/total = 0
	for (var/list/row in rows)
		total += row[8]
	machine_check(power[1] == total && total >= drive.powerneeded, "the monitor totals the machines' power ([power[1]])")
	var/found_drive_grid = FALSE
	for (var/list/grid in power[2])
		if (grid[2] == 100 && grid[1] >= drive.powerneeded)
			found_drive_grid = TRUE
	machine_check(found_drive_grid, "the monitor shows the drive's grid use against its capacity")
	var/html = M.report_html()
	machine_check(findtext(html, "Power (PU)") && findtext(html, "PU in use"), "the monitor page shows power use")
	machine_check(findtext(html, "Items/min") && findtext(html, "feeder arm") && findtext(html, "starved"), "the monitor page shows the table")
	machine_check(recipe_node_requirements["/obj/structure/factory_monitor"] == "automation", "the monitor is gated behind Automation")
	qdel(F)
	qdel(M)
