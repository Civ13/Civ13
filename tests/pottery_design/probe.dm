// Native probe: a designed clay vessel keeps its shape, band and glaze
// through firing, and a decorated pot set down counts as art.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/pottery_design/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 5
	maxy = 5
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

var/pd_failures = 0
var/pd_runtime_error = FALSE
/proc/pd_check(condition, label)
	if (!condition)
		pd_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	pd_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		pd_checks()
	catch(var/exception/e)
		pd_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = pd_failures, "runtime_error" = pd_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/pd_checks()
	var/turf/T = locate(2, 2, 1)
	for (var/id in pottery_shapes)
		var/list/rect = pottery_shapes[id]["band"]
		pd_check(("[id]_unfired" in icon_states('icons/obj/pottery_designs.dmi')) && ("[id]_glaze" in icon_states('icons/obj/pottery_designs.dmi')) && ("[id]_shade" in icon_states('icons/obj/pottery_designs.dmi')) && (id in icon_states('icons/obj/pottery_designs.dmi')), "[id] has all four sprites")
		pd_check(rect[1] >= 0 && rect[2] >= 0 && rect[1] + rect[3] <= 32 && rect[2] + rect[4] <= 32, "[id]'s band fits the sprite")

	var/obj/item/weapon/clay/vessel/V = new(T)
	pd_check(V.name == "unfired clay jar" && V.icon_state == "jar_unfired", "a new vessel is an unfired jar ([V.name])")
	V.shape = "amphora"
	V.update_icon()
	pd_check(V.name == "unfired clay amphora" && V.w_class == ITEM_SIZE_NORMAL, "it can be thrown into an amphora")

	// The band: a 12x5 canvas, bisque left bare, two colours painted.
	var/obj/item/canvas/pottery_band/C = new(null)
	C.target = V
	V.band_canvas = C
	C.canvas_w = 12
	C.canvas_h = 5
	var/plain = ""
	for (var/i = 1, i <= 60, i++)
		plain += i <= 12 ? "1" : (i > 48 ? "2" : "0")
	C.palette = "#c97b52,#2e2927,#e9dcc0"
	C.paint_data = painting_pack(plain)
	var/mob/painter = new
	painter.real_name = "Ada Potter"
	C.on_finished(painter)
	pd_check(QDELETED(C) && V.band_data && V.band_by == "Ada Potter" && !V.band_canvas, "finishing the band puts it on the pot")
	var/icon/B = pottery_band_icon("amphora", V.band_palette, V.band_data)
	pd_check(B && B.GetPixel(11, 32 - 13) == "#2e2927" && B.GetPixel(11, 32 - 15) == null && B.GetPixel(11, 32 - 17) == "#e9dcc0", "the band draws painted rows and leaves bisque bare")
	pd_check(!pottery_band_icon("amphora", "#c97b52", painting_pack("000000000000000000000000000000000000000000000000000000000000")), "an unpainted band draws nothing")

	// Glazes: slips for anyone, others need research.
	pd_check(pottery_glaze_allowed(painter, "white slip") && pottery_glaze_allowed(painter, "red ochre slip"), "slips need no research")
	pd_check(!pottery_glaze_allowed(painter, "cobalt blue") && !pottery_glaze_allowed(painter, "no such glaze"), "cobalt needs fine arts")
	V.glaze = "black gloss"

	// Firing.
	var/obj/item/weapon/reagent_containers/food/drinks/clay/designed/P = V.fired_result(T)
	pd_check(istype(P) && P.shape == "amphora" && P.glaze == "black gloss" && P.band_data == V.band_data && P.band_by == "Ada Potter", "firing keeps the design")
	pd_check(P.volume == 150 && P.reagents && P.reagents.maximum_volume == 150, "an amphora holds 150")
	pd_check(P.name == "black gloss amphora" && P.icon_state == "amphora" && length(P.overlays) == 3, "it shows glaze, band and shading ([P.name] [length(P.overlays)])")
	var/obj/item/weapon/clay/vase/plain_vase = new(T)
	var/obj/O = plain_vase.fired_result(T)
	pd_check(istype(O, /obj/item/weapon/reagent_containers/food/drinks/clay/clayvase), "ordinary clay still fires as before")

	// Art.
	pd_check(mood_is_art(P), "a decorated pot on the floor is art")
	P.loc = painter
	pd_check(!mood_is_art(P), "but not while carried")
	var/obj/item/weapon/reagent_containers/food/drinks/clay/designed/bare = new(T)
	pd_check(!mood_is_art(bare), "a bare pot is not art")
