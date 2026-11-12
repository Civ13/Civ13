// Native probe for the shared open-flame check and candle lighting.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/candle_lighting/probe.dm
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
/obj/map_metadata/candle_probe/New()
	return
var/eco_failures = 0
var/eco_runtime_error = FALSE
/proc/eco_check(condition, label)
	if (!condition)
		eco_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	eco_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/candle_probe
		candle_flame_source_checks()
		candle_lighting_checks()
	catch(var/exception/e)
		eco_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = eco_failures, "runtime_error" = eco_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/candle_probe_lit(path, on = TRUE)
	var/turf/T = locate(5, 5, 1)
	var/atom/A = new path(T)
	if (istype(A, /obj/item/flashlight))
		var/obj/item/flashlight/F = A
		F.on = on
	else if (istype(A, /obj/item/weapon/flame))
		var/obj/item/weapon/flame/W = A
		W.lit = on
	else if (istype(A, /obj/structure/oven))
		var/obj/structure/oven/O = A
		O.on = on
	else if (istype(A, /obj/structure/furnace))
		var/obj/structure/furnace/FU = A
		FU.on = on
	else if (istype(A, /obj/structure/brazier))
		var/obj/structure/brazier/B = A
		B.on = on
	return A

/proc/candle_flame_source_checks()
	var/list/flames = list(
		/obj/item/flashlight/tiki_torch,
		/obj/item/flashlight/torch,
		/obj/item/flashlight/lantern,
		/obj/item/flashlight/lantern/copper,
		/obj/item/flashlight/lantern/bronze,
		/obj/item/flashlight/flare,
		/obj/item/weapon/flame/candle,
		/obj/item/weapon/flame/candle/lard,
		/obj/item/weapon/flame/match,
		/obj/item/weapon/flame/lighter,
		/obj/structure/oven/fireplace,
		/obj/structure/oven/woodstove,
		/obj/structure/oven,
		/obj/structure/furnace,
		/obj/structure/brazier)
	for (var/path in flames)
		eco_check(isflamesource(candle_probe_lit(path, TRUE)), "lit [path] is an open flame")
		eco_check(!isflamesource(candle_probe_lit(path, FALSE)), "unlit [path] is not a flame")
	var/list/not_flames = list(
		/obj/item/flashlight/flashlight,
		/obj/item/flashlight/modern,
		/obj/item/flashlight/lamp/oldlamp,
		/obj/item/flashlight/japflashlight,
		/obj/item/flashlight/flare/glowstick,
		/obj/structure/oven/stove,
		/obj/structure/oven/griddle,
		/obj/structure/oven/fryer)
	for (var/path in not_flames)
		eco_check(!isflamesource(candle_probe_lit(path, TRUE)), "lit [path] is not an open flame")
	eco_check(!isflamesource(null), "null is not a flame")
	eco_check(!isflamesource("fire"), "text is not a flame")
	eco_check(isflamesource(new /obj/effect/fire(locate(6, 6, 1))), "a burning fire is an open flame")
	var/obj/structure/torch_stand/S = new(locate(7, 7, 1))
	S.storage = new /obj/item/weapon/storage/internal(S)
	eco_check(!isflamesource(S), "an empty torch mount is not a flame")
	var/obj/item/flashlight/torch/T = candle_probe_lit(/obj/item/flashlight/torch, TRUE)
	T.loc = S.storage
	eco_check(isflamesource(S), "a torch mount holding a lit torch is a flame")
	T.on = FALSE
	eco_check(!isflamesource(S), "a torch mount holding an unlit torch is not a flame")

/proc/candle_lighting_checks()
	var/turf/T = locate(10, 10, 1)
	// A lit tiki torch held against a placed candle.
	var/obj/item/weapon/flame/candle/C = new(T)
	var/obj/item/flashlight/tiki_torch/tiki = candle_probe_lit(/obj/item/flashlight/tiki_torch, TRUE)
	eco_check(C.attackby(tiki, null) == TRUE, "candle attackby a lit tiki torch resolves")
	eco_check(C.lit, "a lit tiki torch lights a placed candle")
	eco_check(findtext(C.icon_state, "_lit"), "the lit candle shows its flame")
	// A lard candle held against a placed lit tiki torch.
	var/obj/item/weapon/flame/candle/lard/L = new(T)
	eco_check(L.resolve_attackby(tiki, null) == TRUE, "lard candle against a lit tiki torch resolves")
	eco_check(L.lit, "a lit tiki torch lights a held lard candle")
	eco_check(findtext(L.icon_state, "_lit_lard"), "the lit lard candle keeps its lard sprite")
	// A candle against a campfire is lit, not cooked.
	var/obj/structure/oven/fireplace/F = candle_probe_lit(/obj/structure/oven/fireplace, TRUE)
	var/obj/item/weapon/flame/candle/C2 = new(T)
	eco_check(C2.resolve_attackby(F, null) == TRUE && C2.lit, "a lit campfire lights a held candle")
	eco_check(!(C2 in F.contents), "the campfire does not take the candle")
	// Candle to candle.
	var/obj/item/weapon/flame/candle/C3 = new(T)
	eco_check(C3.attackby(C, null) == TRUE && C3.lit, "a lit candle lights another candle")
	// Things that are not a flame leave the candle unlit.
	var/obj/item/weapon/flame/candle/C4 = new(T)
	var/obj/item/flashlight/modern/E = candle_probe_lit(/obj/item/flashlight/modern, TRUE)
	C4.attackby(E, null)
	eco_check(!C4.lit, "an electric flashlight does not light a candle")
	var/obj/item/flashlight/tiki_torch/cold = candle_probe_lit(/obj/item/flashlight/tiki_torch, FALSE)
	C4.resolve_attackby(cold, null)
	eco_check(!C4.lit, "an unlit tiki torch does not light a candle")
	C4.resolve_attackby(C4, null)
	eco_check(!C4.lit, "a candle cannot light itself")
