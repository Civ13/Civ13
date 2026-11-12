// Vehicle assembly (code/modules/craft/vehicle_assembly.dm, docs/craft-core.md):
// the survey of frames joined to an axis, its refusals in words, assembling
// in each facing, driving and turning what was assembled, fitting parts
// later and taking a vehicle apart.
/world
	hub = ""
	hub_password = ""
	maxx = 60
	maxy = 60
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/naval_research_done = FALSE
/obj/map_metadata/naval_probe/New()
	return
/obj/map_metadata/naval_probe/is_node_done(faction, node_id)
	return naval_research_done
/mob/living/human/naval_probe/New()
	return
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/T = locate(x, y, 1)
			T.ChangeTurf(/turf/floor/beach/sand)


// Lays w by h loose frames with their south-west corner at x,y.
/proc/assembly_frames(x, y, w, h)
	. = list()
	for (var/dx = 0, dx < w, dx++)
		for (var/dy = 0, dy < h, dy++)
			. += new /obj/structure/vehicleparts/frame(locate(x + dx, y + dy, 1))

// Stands an engine, a tank, a seat and four corner wheels on a w by h bed.
/proc/assembly_parts(x, y, w, h, engine = TRUE)
	if (engine)
		var/obj/structure/engine/internal/E = new /obj/structure/engine/internal/gasoline/premade/v6(locate(x, y + 1, 1))
		E.anchored = FALSE
	new /obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueledgasoline(locate(x + 1, y + 1, 1))
	var/obj/structure/bed/chair/drivers/D = new(locate(x + 1, y, 1))
	D.anchored = FALSE
	for (var/turf/T in list(locate(x, y, 1), locate(x + w - 1, y, 1), locate(x, y + h - 1, 1), locate(x + w - 1, y + h - 1, 1)))
		new /obj/structure/vehicleparts/movement(T)

// The tiles this vehicle's frames stand on, as a sorted text.
/proc/assembly_shape(obj/structure/vehicleparts/axis/A)
	var/min_x = 1000
	var/min_y = 1000
	var/max_x = 0
	var/max_y = 0
	var/n = 0
	for (var/obj/structure/vehicleparts/frame/F in A.components)
		n++
		min_x = min(min_x, F.x)
		max_x = max(max_x, F.x)
		min_y = min(min_y, F.y)
		max_y = max(max_y, F.y)
	return "[n] frames, [max_x - min_x + 1] by [max_y - min_y + 1] at [min_x],[min_y]"

// TRUE while the engine, the seat and every wheel ride on the vehicle's frames.
/proc/assembly_whole(obj/structure/vehicleparts/axis/A)
	if (!A.engine || !(vehicle_assembly_frame(get_turf(A.engine), A) in A.components))
		return FALSE
	if (!A.wheel || !A.wheel.drivingchair || !(vehicle_assembly_frame(get_turf(A.wheel.drivingchair), A) in A.components))
		return FALSE
	if (A.wheels.len != 4)
		return FALSE
	for (var/obj/structure/vehicleparts/movement/M in A.wheels)
		if (!(vehicle_assembly_frame(get_turf(M), A) in A.components))
			return FALSE
	return TRUE

/proc/assembly_person(char_name, faction, turf/T)
	var/mob/living/human/naval_probe/H = new(T)
	H.real_name = char_name
	H.name = char_name
	H.civilization = faction
	return H

/proc/naval_checks()
	naval_fixture()

	// ---- What cannot be a vehicle ----
	var/obj/structure/vehicleparts/axis/car/bare = new(locate(5, 5, 1))
	var/datum/vehicle_survey/S = new(bare)
	naval_check(findtext(S.refusal, "must stand on one of the vehicle's frames") && findtext(bare.assemble(), "must stand"), "an axis on bare ground is told to stand on a frame")
	assembly_frames(5, 5, 1, 3)
	S = new(bare)
	naval_check(findtext(S.refusal, "1 by 3") && findtext(S.refusal, "2 by 2 at least"), "a single row of frames is too narrow ([S.refusal])")
	assembly_frames(6, 5, 1, 2)
	S = new(bare)
	naval_check(findtext(S.refusal, "fill a rectangle") && findtext(S.refusal, "1 of the 2 by 3 tiles has no frame"), "an L of frames is told which rectangle it must fill ([S.refusal])")
	naval_check(findtext(S.report(), "cannot be made into a vehicle") && !bare.components.len, "and the build sheet says so, binding nothing")
	var/obj/structure/vehicleparts/axis/heavy/big = new(locate(10, 40, 1))
	assembly_frames(10, 40, 6, 2)
	S = new(big)
	naval_check(findtext(S.refusal, "6 by 2") && findtext(S.refusal, "5 long and wide at most"), "six frames in a row are too long ([S.refusal])")

	// ---- A full bed facing north ----
	assembly_frames(20, 20, 2, 3)
	assembly_parts(20, 20, 2, 3)
	var/obj/structure/vehicleparts/axis/car/A = new(locate(21, 21, 1))
	S = new(A)
	naval_check(isnull(S.refusal) && S.frames.len == 6 && S.width == 2 && S.height == 3 && S.engine && S.tank && S.seat && S.movers.len == 4 && !S.missing().len, "a 2 by 3 bed with its parts surveys complete from an axis on any frame")
	naval_check(findtext(S.report(), "2 by 3 frames") && findtext(S.report(), "everything a vehicle needs"), "the build sheet says what was found ([S.report()])")
	A.name = "Mule"
	naval_check(isnull(A.assemble(NORTH)) && A.hand_built && A.dir == NORTH, "the bed assembles facing north")
	// A second bed laid against it is its own vehicle.
	var/list/others = assembly_frames(22, 20, 2, 2)
	var/obj/structure/vehicleparts/axis/car/other = new(locate(22, 20, 1))
	var/why_other = other.assemble(NORTH)
	var/own = 0
	for (var/obj/structure/vehicleparts/frame/F in other.components)
		own++
	naval_check(isnull(why_other) && own == 4, "a second bed laid against it surveys as its own four frames ([why_other], [own])")
	var/frames = 0
	for (var/obj/structure/vehicleparts/frame/F in A.components)
		frames++
	var/obj/structure/vehicleparts/frame/taken = others[1]
	naval_check(frames == 6 && taken.axis == other && A.components.len == 9, "and the first keeps its six frames and its turning square ([frames], [A.components.len])")
	naval_check(get_turf(A) == locate(20, 22, 1) && A.corners[2] == vehicle_assembly_frame(locate(20, 22, 1), A), "the axis moves itself to the front left corner")
	naval_check(A.engine && A.engine.fueltank && A.wheel && A.wheel.control && A.wheels.len == 4 && assembly_whole(A), "engine, tank, seat and four wheels are fitted in the same step")
	var/obj/structure/vehicleparts/frame/any = A.components[1]
	naval_check(any.name == "Mule" && any.axis == A && findtext(A.build_sheet(), "everything a vehicle needs"), "its frames take its name and the sheet reads ready")
	naval_check(findtext(A.assemble(NORTH), "assembled already"), "it cannot be assembled twice")
	qdel(other)
	for (var/obj/O in others)
		qdel(O)

	// ---- It drives and turns ----
	naval_check(A.do_move() && assembly_shape(A) == "6 frames, 2 by 3 at 20,21" && assembly_whole(A), "driven a tile north everything rides along ([assembly_shape(A)])")
	naval_check(A.do_matrix(A.dir, TURN_LEFT(A.dir), "left"), "it turns left")
	sleep(20)
	naval_check(A.dir == WEST && findtext(assembly_shape(A), "6 frames, 3 by 2") && assembly_whole(A), "and is a 3 by 2 body facing west with every part aboard ([assembly_shape(A)])")
	var/before = assembly_shape(A)
	naval_check(A.do_move() && assembly_shape(A) != before && assembly_whole(A), "it drives on west")
	naval_check(A.do_matrix(A.dir, TURN_RIGHT(A.dir), "right"), "it turns right")
	sleep(20)
	naval_check(A.dir == NORTH && findtext(assembly_shape(A), "6 frames, 2 by 3") && assembly_whole(A), "and faces north again, whole ([assembly_shape(A)])")

	// ---- The other facings ----
	var/n = 0
	for (var/facing in list(EAST, SOUTH, WEST))
		n++
		var/bx = 10 + n * 12
		var/wide = (facing == EAST || facing == WEST)
		assembly_frames(bx, 45, wide ? 3 : 2, wide ? 2 : 3)
		assembly_parts(bx, 45, wide ? 3 : 2, wide ? 2 : 3)
		var/obj/structure/vehicleparts/axis/car/V = new(locate(bx, 45, 1))
		var/why = V.assemble(facing)
		naval_check(isnull(why) && V.dir == facing && assembly_whole(V) && V.components.len == 9, "a bed assembles facing [dir2text(facing)] ([why])")
		var/turf/was = get_turf(V)
		naval_check(V.do_move() && get_turf(V) == get_step(was, facing) && assembly_whole(V), "and drives a tile that way")
		naval_check(V.do_matrix(V.dir, TURN_LEFT(V.dir), "left"), "it turns left")
		sleep(20)
		naval_check(V.dir == TURN_LEFT(facing) && findtext(assembly_shape(V), "6 frames, [wide ? "2 by 3" : "3 by 2"]") && assembly_whole(V), "and stays whole facing [dir2text(V.dir)] ([assembly_shape(V)])")
		naval_check(V.do_move() && assembly_whole(V), "and drives on")

	// ---- Parts fitted afterwards ----
	assembly_frames(40, 10, 2, 2)
	assembly_parts(40, 10, 2, 2, FALSE)
	var/obj/structure/vehicleparts/axis/car/late = new(locate(40, 10, 1))
	S = new(late)
	naval_check(isnull(S.refusal) && S.missing().len == 1 && findtext(S.report(), "still needs an engine"), "a bed without an engine says what it still needs")
	naval_check(isnull(late.assemble(SOUTH)) && !late.engine && late.wheel && late.wheels.len == 4 && findtext(late.build_sheet(), "still needs an engine"), "it assembles all the same, and its sheet keeps saying so")
	naval_check(late.fit_parts() == 0, "with nothing new on its frames nothing is fitted")
	var/obj/structure/engine/internal/spare = new /obj/structure/engine/internal/gasoline/premade/v6(locate(40, 11, 1))
	spare.anchored = FALSE
	naval_check(late.fit_parts() == 2 && late.engine == spare && spare.anchored && spare.fueltank && findtext(late.build_sheet(), "everything a vehicle needs"), "an engine stood on a frame later is fitted with its tank")
	var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/joined = spare.fueltank
	joined.forceMove(spare)
	S = new(late)
	naval_check(S.tank == joined && !S.missing().len && late.fit_parts() == 0, "a tank connected into the engine by hand still counts")
	var/obj/structure/vehicleparts/movement/extra = new(locate(41, 10, 1))
	naval_check(late.fit_parts() == 0 && !(extra in late.wheels), "a fifth wheel is not fitted")
	qdel(extra)

	// ---- Taking it apart ----
	var/mob/living/human/naval_probe/ann = assembly_person("Ann", "Reds", locate(39, 10, 1))
	var/mob/living/human/naval_probe/bob = assembly_person("Bob", "Blues", locate(39, 11, 1))
	var/obj/structure/vehicleparts/axis/car/made = new /obj/structure/vehicleparts/axis/car(locate(50, 50, 1))
	naval_check(findtext(made.take_apart_refusal(ann), "not assembled"), "a loose axis has nothing to take apart")
	late.engine.on = TRUE
	naval_check(findtext(late.take_apart_refusal(ann), "switch the engine off"), "a running vehicle is not taken apart")
	late.engine.on = FALSE
	var/datum/craft/vehicle/C = craft_of_axis(late)
	C.register = new /datum/craft_register
	C.register.claim(ann)
	naval_check(findtext(late.take_apart_refusal(bob), "registered to") && isnull(late.take_apart_refusal(ann)), "a registered vehicle is taken apart by its owners only ([late.take_apart_refusal(bob)])")
	late.hand_built = FALSE
	naval_check(findtext(late.take_apart_refusal(ann), "not built by hand"), "a works-built vehicle is not taken apart this way")
	late.hand_built = TRUE
	var/list/old_wheels = late.wheels.Copy()
	late.take_apart()
	var/loose = 0
	for (var/obj/structure/vehicleparts/frame/F in range(3, locate(40, 10, 1)))
		if (!F.axis && !F.mwheel)
			loose++
	var/out = 0
	for (var/obj/structure/vehicleparts/movement/M in old_wheels)
		if (isturf(M.loc) && !M.axis && !M.connected)
			out++
	naval_check(loose == 4 && out == 4 && !late.components.len && !late.wheels.len && !late.engine && !late.wheel && !spare.anchored && !(locate(/obj/effect/pseudovehicle) in range(4, locate(40, 10, 1))), "taken apart, its frames, wheels, engine and seat stand loose and its turning square is gone ([loose], [out])")
	naval_check(isnull(late.assemble(EAST)) && late.dir == EAST && assembly_whole(late), "and the same parts assemble again, facing another way")
	naval_check(craft_of_axis(late) == C && C.register.is_owner(ann), "its papers outlast the rebuild")

	// ---- A boat of ship frames ----
	for (var/x = 2, x <= 16, x++)
		for (var/y = 12, y <= 30, y++)
			var/turf/sea = locate(x, y, 1)
			sea.ChangeTurf(/turf/floor/beach/water)
	// On the sand a boat is refused, and each kind of axis takes its own frames.
	for (var/dx = 0, dx < 2, dx++)
		for (var/dy = 0, dy < 2, dy++)
			new /obj/structure/vehicleparts/frame/ship(locate(30 + dx, 30 + dy, 1))
	var/obj/structure/vehicleparts/axis/ship/beached = new(locate(30, 30, 1))
	S = new(beached)
	naval_check(S.ship && findtext(S.refusal, "must lie on water: 4 do not") && findtext(S.report(), "cannot be made into a boat"), "ship frames on dry land are refused as a boat ([S.refusal])")
	var/obj/structure/vehicleparts/axis/car/wrong = new(locate(31, 31, 1))
	S = new(wrong)
	naval_check(!S.ship && findtext(S.refusal, "must stand on one of the vehicle's frames"), "a car axis does not take ship frames")
	var/list/hull = list()
	for (var/dx = 0, dx < 3, dx++)
		for (var/dy = 0, dy < 4, dy++)
			hull += new /obj/structure/vehicleparts/frame/ship(locate(6 + dx, 18 + dy, 1))
	var/obj/structure/vehicleparts/axis/ship/R = new(locate(7, 19, 1))
	var/obj/structure/vehicleparts/shipwheel/helm = new(locate(7, 18, 1))
	S = new(R)
	naval_check(isnull(S.refusal) && S.ship && S.frames.len == 12 && S.helm == helm && S.missing().len == 1 && findtext(S.report(), "still needs a mast or an engine"), "a 3 by 4 hull on the water with a wheel still needs a mast or an engine ([S.report()])")
	var/obj/structure/vehicleparts/movement/sail/premade/mast = new(locate(7, 20, 1))
	S = new(R)
	naval_check(!S.missing().len && S.masts.len == 1 && !S.movers.len && findtext(S.report(), "everything a boat needs to sail"), "with a mast it surveys ready to sail")
	R.name = "Teal"
	var/why_boat = R.assemble(EAST)
	var/planks = 0
	for (var/obj/structure/vehicleparts/frame/ship/F in R.components)
		planks++
	naval_check(isnull(why_boat) && R.dir == EAST && planks == 12 && R.components.len == 16 && R.hand_built, "the hull assembles facing east with its turning square ([why_boat], [planks], [R.components.len])")
	naval_check(helm.ship == R && helm.anchored && (mast in R.masts) && mast.axis == R && get_turf(R) == locate(8, 21, 1), "wheel and mast are fitted and the rudder axis moves to the front left corner")
	var/turf/helm_was = get_turf(helm)
	var/turf/mast_was = get_turf(mast)
	naval_check(R.do_move() && assembly_shape(R) == "12 frames, 3 by 4 at 7,18" && get_turf(helm) == get_step(helm_was, EAST) && get_turf(mast) == get_step(mast_was, EAST), "she moves a tile east with her wheel and mast ([assembly_shape(R)])")
	naval_check(R.do_matrix(R.dir, TURN_LEFT(R.dir), "left"), "she turns left")
	sleep(20)
	naval_check(R.dir == NORTH && findtext(assembly_shape(R), "12 frames, 4 by 3") && (vehicle_assembly_frame(get_turf(helm), R) in R.components) && (vehicle_assembly_frame(get_turf(mast), R) in R.components), "and is a 4 by 3 hull facing north with wheel and mast aboard ([assembly_shape(R)])")
	naval_check(isnull(R.take_apart_refusal(ann)), "at rest she can be taken apart")
	R.take_apart()
	naval_check(!R.components.len && !R.masts.len && isnull(helm.ship) && !helm.anchored && isnull(mast.axis) && !mast.anchored, "taken apart, her wheel and mast are loose again")
	naval_check(isnull(R.assemble(SOUTH)) && R.dir == SOUTH && helm.ship == R && (mast in R.masts), "and she assembles again facing south")

	// ---- A built turret ----
	assembly_frames(50, 20, 3, 3)
	assembly_parts(50, 20, 3, 3)
	var/obj/structure/vehicleparts/axis/heavy/tank = new(locate(50, 20, 1))
	var/turf/ring = locate(51, 21, 1)
	var/obj/structure/turret/built/turret = new(ring)
	S = new(tank)
	naval_check(S.turrets.len == 1 && findtext(S.report(), "turret cannot fire yet") && findtext(S.report(), "a tank cannon and a gunner's seat") && findtext(turret.fitting_text(), "Nothing is fitted"), "an empty turret on the bed says what it needs ([turret.fitting_text()])")
	var/obj/structure/cannon/modern/tank/gun = new(ring)
	var/obj/structure/bed/chair/gunner/gseat = new(ring)
	var/obj/structure/bed/chair/loader/lseat = new(ring)
	S = new(tank)
	naval_check(findtext(S.report(), "Its turret has a gun and a gunner's seat"), "with a cannon and a gunner's seat on its tile the sheet reads ready")
	tank.name = "Ox"
	naval_check(isnull(tank.assemble(NORTH)) && assembly_whole(tank), "the tank assembles")
	naval_check(gun.loc == turret && (gun in turret.weapons) && turret.gunner_seat == gseat && gseat.turret == turret && gseat.controls.turret == turret && turret.loader_seat == lseat && lseat.turret == turret && gseat.anchored, "its cannon and seats are taken into the turret")
	naval_check(findtext(turret.fitting_text(), "a gunner's seat") && !findtext(turret.fitting_text(), "still needs") && !turret.lacking().len && findtext(tank.build_sheet(), "Its turret has a gun"), "and the turret reads fitted ([turret.fitting_text()])")
	naval_check(tank.fit_parts() == 0, "nothing is fitted twice")
	var/obj/structure/bed/chair/commander/cseat = new(ring)
	naval_check(tank.fit_parts() == 1 && turret.commander_seat == cseat && cseat.turret == turret, "a commander's seat stood there later is fitted too")
	naval_check(tank.do_move() && get_turf(turret) == get_step(ring, NORTH) && get_turf(gseat) == get_turf(turret) && gun.loc == turret, "the turret, its gun and its seats ride along when she drives")
	var/list/styles = built_turret_styles()
	naval_check(styles["plain"] == "tank_turret" && styles["round"] == "round_tank_turret" && styles.len == 2, "before the tank ages a builder has the plain and the round turret")
	map.ordinal_age = 6
	styles = built_turret_styles()
	naval_check(styles["T34"] == "t34_turret" && styles.len == 8, "in a later age there are more to pick ([styles.len])")
	map.ordinal_age = 0
	tank.take_apart()
	naval_check(isturf(gun.loc) && get_turf(gun) == get_turf(turret) && !turret.weapons.len && isnull(turret.gunner_seat) && isnull(gseat.turret) && isnull(gseat.controls.turret) && !gseat.anchored && isnull(lseat.turret) && isnull(cseat.turret) && turret.lacking().len == 2, "taken apart, the gun and the seats stand loose by the turret")
	naval_check(isnull(tank.assemble(WEST)) && (gun in turret.weapons) && turret.gunner_seat == gseat, "and are fitted again when she is rebuilt")

/proc/naval_run()
	try
		naval_checks()
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = naval_failures, "runtime_error" = naval_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/naval_probe
		naval_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
