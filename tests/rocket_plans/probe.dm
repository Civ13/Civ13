// Rocket plans (code/modules/space/rocket_plan.dm, rocket_plan_checks.dm,
// docs/rocket-plans.md): the three starter rockets pass their checks, read
// back from their codes and each supports its own mission and not the
// others; frame, boosters and stages change what a rocket can do the way
// the plan says; bad codes are refused; each check fires; every piece has a
// part description.
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/rocket_probe
	ordinal_age = 7
/obj/map_metadata/rocket_probe/New()
	return
var/rocket_failures = 0
var/rocket_runtime_error = FALSE
/proc/rocket_check(condition, label)
	if (!condition)
		rocket_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	rocket_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/rocket_report_has(datum/rocket_plan/D, level, text)
	var/datum/design_report/R = D.check_design()
	. = FALSE
	for (var/t in R.texts(level))
		if (findtext(t, text))
			. = TRUE
	qdel(R)

/proc/rocket_legs_text(datum/rocket_plan/D)
	var/list/L = D.legs()
	var/list/parts = list()
	for (var/id in L)
		var/list/leg = L[id]
		parts += "[id]=[leg["ok"] ? "yes" : "no"]"
	return "[jointext(parts, " ")] dv=[rocket_dv_text(D.total_dv())]"

/proc/rocket_checks()
	// ---- The starter rockets ----
	var/list/examples = rocket_plan_examples()
	rocket_check(examples.len == 3, "three starter rockets")
	for (var/datum/rocket_plan/E in examples)
		var/list/problems = E.problems()
		rocket_check(!problems.len, "[E.name] has no errors ([jointext(problems, " | ")])")
		var/datum/rocket_plan/back = rocket_plan_from_code(E.to_code())
		rocket_check(back && back.to_code() == E.to_code(), "[E.name] reads back from [E.to_code()]")
		world.log << "[E.name]: [rocket_legs_text(E)]"
	var/datum/rocket_plan/crew = examples[1]
	var/datum/rocket_plan/cargo = examples[2]
	var/datum/rocket_plan/probe = examples[3]
	rocket_check(crew.supports(ROCKET_LEG_ORBIT) && crew.supports(ROCKET_LEG_RETURN), "crew orbiter reaches orbit and brings the crew home")
	rocket_check(!crew.supports(ROCKET_LEG_TRANSFER), "crew orbiter cannot reach the Moon")
	rocket_check(crew.seats() == 3, "crew orbiter seats three")
	rocket_check(cargo.supports(ROCKET_LEG_ORBIT) && !cargo.supports(ROCKET_LEG_TRANSFER), "cargo hauler reaches orbit, not the Moon")
	rocket_check(probe.supports(ROCKET_LEG_TRANSFER) && probe.supports(ROCKET_LEG_LANDING), "lunar probe transfers and lands")
	rocket_check(!probe.supports(ROCKET_LEG_RETURN) && !probe.supports(ROCKET_LEG_LUNAR_RETURN), "lunar probe never comes home")
	var/list/legs = probe.legs()
	var/list/home = legs[ROCKET_LEG_RETURN]
	rocket_check(findtext(home["why"], "crew capsule"), "the planner says a probe has no capsule to come home in")

	// ---- Frames: a cheap heavy frame lifts a small probe, not a crew ----
	var/datum/rocket_plan/steel_crew = rocket_plan_make("steel crew", "s", 0, "ETTTDVTXCRM")
	rocket_check(!steel_crew.supports(ROCKET_LEG_ORBIT), "steel frame cannot lift the crew capsule to orbit ([rocket_legs_text(steel_crew)])")
	rocket_check(rocket_report_has(steel_crew, DESIGN_ERROR, "cannot reach orbit"), "a rocket short of orbit is an error")
	var/datum/rocket_plan/steel_sat = rocket_plan_make("steel probe", "s", 0, "ETTDVTQ")
	rocket_check(steel_sat.supports(ROCKET_LEG_ORBIT), "steel frame lifts a small probe to orbit ([rocket_legs_text(steel_sat)])")
	rocket_check(steel_crew.costs()["steel"] > crew.costs()["steel"] && !steel_crew.costs()["aluminium"] && crew.costs()["aluminium"], "aluminium frames take aluminium in place of steel")

	// ---- Boosters: lift off the pad, not much farther ----
	var/datum/rocket_plan/bare = rocket_plan_make("no boosters", "a", 0, "EETTTTDVTTTKK")
	rocket_check(!bare.supports(ROCKET_LEG_ORBIT), "two cargo bays need boosters ([rocket_legs_text(bare)])")
	var/datum/rocket_plan/big = rocket_plan_make("six boosters", "a", 6, "EETTTTDVTXCRM")
	rocket_check(big.supports(ROCKET_LEG_ORBIT) && !big.supports(ROCKET_LEG_TRANSFER), "six boosters still do not reach the Moon ([rocket_legs_text(big)])")
	var/list/big_burns = big.burns()
	var/list/first = big_burns[1]
	rocket_check(findtext(first["name"], "6 boosters") && first["twr"] > 2, "boosters burn with the first stage and raise liftoff thrust")
	var/datum/rocket_plan/heavy = rocket_plan_make("too heavy", "s", 0, "ETTTTTTDVTTKK")
	rocket_check(!heavy.supports(ROCKET_LEG_LIFTOFF) && rocket_report_has(heavy, DESIGN_ERROR, "cannot lift off"), "a rocket too heavy for its engines cannot lift off")

	// ---- Cargo: planned full on the sheet, real load on the pad ----
	rocket_check(cargo.cargo_mass() == 2 * ROCKET_BAY_TONNES, "cargo bays plan full")
	rocket_check(cargo.total_dv(0) > cargo.total_dv(), "an empty bay leaves more delta-v")

	// ---- Fittings and legs ----
	var/datum/rocket_plan/no_shield = rocket_plan_make("no shield", "a", 0, "ETTTDVTCRM")
	var/list/nsl = no_shield.legs()
	var/list/nsr = nsl[ROCKET_LEG_RETURN]
	rocket_check(!nsr["ok"] && findtext(nsr["why"], "heat shield"), "no heat shield: no return, and the planner says so")
	rocket_check(rocket_report_has(no_shield, DESIGN_WARNING, "cannot come home"), "a crew that cannot come home is a warning")
	var/datum/rocket_plan/light_shield = rocket_plan_make("lunar crew", "a", 0, "ETTTDVTTDVTTXCRM")
	var/list/lsl = light_shield.legs()
	var/list/lsr = lsl[ROCKET_LEG_LUNAR_RETURN]
	rocket_check(findtext(lsr["why"], "heavy heat shield"), "only a heavy heat shield survives the return from the Moon")
	rocket_check(rocket_report_has(rocket_plan_make("loose shield", "a", 0, "ETTTDVTCXRM"), DESIGN_ERROR, "directly under the crew capsule"), "a heat shield above the capsule is an error")
	rocket_check(rocket_report_has(rocket_plan_make("loose chutes", "a", 0, "ETTTDVTRXCM"), DESIGN_ERROR, "Parachutes fit"), "parachutes not over the capsule are an error")
	rocket_check(rocket_report_has(rocket_plan_make("low capsule", "a", 0, "EXCRTTDVTM"), DESIGN_ERROR, "above the last decoupler"), "a capsule below a decoupler is an error")
	rocket_check(rocket_report_has(rocket_plan_make("dead stage", "a", 0, "ETTTDTTDVTQ"), DESIGN_ERROR, "no engine"), "a stage with no engine is an error")
	rocket_check(rocket_report_has(rocket_plan_make("top decoupler", "a", 0, "ETTDVTQD"), DESIGN_ERROR, "decoupler on top"), "a decoupler on top is an error")
	rocket_check(rocket_report_has(rocket_plan_make("upside down", "a", 0, "TETDVTQ"), DESIGN_ERROR, "bottom piece"), "the bottom piece must be a sea-level engine")
	rocket_check(rocket_report_has(rocket_plan_make("empty", "a", 0, "ETTDVT"), DESIGN_ERROR, "carries nothing"), "a rocket with no payload is an error")
	rocket_check(rocket_report_has(rocket_plan_make("two capsules", "a", 0, "ETTTDVTXCRXCR"), DESIGN_ERROR, "crew capsules"), "one capsule per rocket")
	var/datum/rocket_plan/weak = rocket_plan_make("weak upper", "a", 0, "EETTTTDVTTTTTKK")
	var/list/wl = weak.legs()
	var/list/wo = wl[ROCKET_LEG_ORBIT]
	rocket_check(findtext(wo["why"], "Second stage"), "an upper stage too weak for its load is named")
	var/datum/rocket_plan/no_legs = rocket_plan_make("no legs", "a", 0, "EETTTDVTTDVTQ")
	var/list/nll = no_legs.legs()
	var/list/nlland = nll[ROCKET_LEG_LANDING]
	rocket_check(no_legs.supports(ROCKET_LEG_TRANSFER) && findtext(nlland["why"], "landing legs"), "a lunar rocket without legs transfers but cannot land")
	rocket_check(rocket_leg_total_dv(ROCKET_LEG_LUNAR_RETURN) == ROCKET_DV_ORBIT + ROCKET_DV_TRANSFER + ROCKET_DV_LANDING + ROCKET_DV_LUNAR_RETURN, "the Moon legs add up from the pad")

	// ---- Codes ----
	rocket_check(!rocket_plan_from_code("C13ROCKET/1/x/a/0/EZT"), "an unknown piece is refused")
	rocket_check(!rocket_plan_from_code("C13ROCKET/1/x/a/3/ETQ"), "an odd booster count is refused")
	rocket_check(!rocket_plan_from_code("C13ROCKET/1/x/q/0/ETQ"), "an unknown frame is refused")
	rocket_check(!rocket_plan_from_code("C13ROCKET/1/x/a/0/ETTTTTTTTTTTTTTTTTTTQ"), "a stack past the sheet is refused")
	rocket_check(!rocket_plan_from_code("C13STATION/1/x/4,4,C"), "another kind's code is refused")
	var/datum/rocket_plan/lower = rocket_plan_from_code("c13rocket/1/my_rocket/a/2/ettdvtq")
	rocket_check(lower && lower.name == "my rocket" && lower.boosters == 2 && lower.stack.len == 7, "codes read whatever their case")
	rocket_check(draught_kinds["ROCKET"] && draught_kinds["ROCKET"]["read"] == /proc/rocket_plan_from_code, "rocket sheets are a draught kind")
	rocket_check(design_code_kind_name("ROCKET") == "a rocket sheet", "rocket codes have a name for refusals")
	var/obj/item/ship_draught/S = new(locate(5, 5, 1))
	S.take_rocket(crew)
	var/datum/rocket_plan/on_sheet = S.rocket_plan()
	rocket_check(S.rocket_plan_kind() && on_sheet && on_sheet.to_code() == crew.to_code(), "the sheet keeps the rocket")
	rocket_check(findtext(crew.summary_text(), "Come home from orbit: yes"), "the sheet summary carries the launch planner")

	// ---- Part book ----
	var/list/book = design_part_help_for("rocket_plan")
	for (var/key in rocket_plan_pieces())
		rocket_check(islist(book[key]), "part book describes [key]")
	rocket_check(islist(book["B"]), "part book describes boosters")

/proc/rocket_run()
	try
		rocket_checks()
	catch(var/exception/e)
		rocket_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = rocket_failures, "runtime_error" = rocket_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/rocket_probe
	catch(var/exception/e)
		rocket_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		rocket_run()
