// Native probe: limewash, tinting and wall finishes, and their place in home comfort.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/home_finishes/probe.dm
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
/obj/map_metadata/hf_probe/New()
	return
/mob/living/human/hf_probe/New()
	return
/mob/living/human/hf_probe/update_icons()
	return
/obj/covers/wood_wall/hf_wall/New()
	return
/obj/covers/wood/hf_floor/New()
	return
/obj/covers/road/hf_road/New()
	return
/obj/structure/bed/chair/hf_chair
/obj/item/weapon/stool/hf_stool

var/hf_failures = 0
var/hf_runtime_error = FALSE
/proc/hf_check(condition, label)
	if (!condition)
		hf_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	hf_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		map = new /obj/map_metadata/hf_probe
		map.nomads = TRUE
		map.civilizations = TRUE
		hf_checks()
	catch(var/exception/e)
		hf_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = hf_failures, "runtime_error" = hf_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/hf_checks()
	var/mob/living/human/hf_probe/H = new(locate(10, 10, 1))
	H.stat = CONSCIOUS
	var/obj/item/weapon/reagent_containers/glass/bucket/B = new(locate(10, 10, 1))
	var/obj/item/stack/ore/quicklime/Q = new(locate(10, 10, 1))
	Q.amount = 3
	Q.afterattack(B, H, TRUE)
	hf_check(!B.reagents.has_reagent("paint", 1) && Q.amount == 3, "an empty bucket slakes nothing")
	B.reagents.add_reagent("water", 50)
	Q.afterattack(B, H, TRUE)
	hf_check(B.reagents.get_reagent_amount("paint") == 20 && B.reagents.get_reagent_amount("water") == 30 && Q.amount == 2, "quicklime slakes 20 water into limewash")
	hf_check(finish_container_color(B) == "#efe9da", "limewash is lime white ([finish_container_color(B)])")

	var/obj/covers/wood_wall/hf_wall/W = new(locate(5, 5, 1))
	var/obj/covers/wood/hf_floor/F = new(locate(6, 5, 1))
	var/obj/covers/road/hf_road/R = new(locate(7, 5, 1))
	hf_check(W.finish_accepts() && F.finish_accepts() && !R.finish_accepts(), "walls and laid floors take a coat, roads do not")
	hf_check(!W.home_finished() && !W.finish_name(), "a new wall is bare")

	W.finish_color = finish_container_color(B)
	W.finish_applied = world.realtime
	W.update_icon()
	hf_check(W.home_finished() && W.finish_name() == "limewashed" && W.overlays.len >= 1, "a limewashed wall is finished and shows its coat")
	var/image/I = W.finish_overlay(W.finish_color, FALSE)
	hf_check(I && islist(I.color) && length(I.color) == 20 && I.layer > W.layer && I.layer < W.layer + 0.01, "the coat sits under the cracks")
	var/image/I2 = F.finish_overlay("#a0522d", FALSE)
	hf_check(I2 && I2.color[17] == 0, "a wooden floor takes a stain with no flat body")

	var/obj/item/pigment/ochre_red/P = new(H)
	var/uses = P.pigment_uses
	P.afterattack(B, H, TRUE)
	hf_check(finish_container_color(B) == P.pigment_colors[1] && P.pigment_uses == uses - 1, "a pigment tints the limewash ([finish_container_color(B)])")
	F.finish_color = finish_container_color(B)
	F.finish_applied = world.realtime
	hf_check(F.finish_name() == "stained", "on a wood floor it is a stain")

	W.finish_applied = world.realtime - (15 * 24 * 36000)
	hf_check(W.finish_faded() && !W.home_finished(), "after two weeks the coat fades and no longer counts")
	hf_check(W.finish_overlay(W.finish_color, TRUE), "a faded coat still shows")

	B.reagents.remove_reagent("paint", 17)
	hf_check(!finish_container_color(B), "too little paint is no coat")

	// A finished room scores its walls.
	var/area/here = get_area(locate(12, 12, 1))
	here.location = AREA_INSIDE
	var/list/walls = list()
	for (var/x = 12, x <= 16, x++)
		for (var/y = 12, y <= 16, y++)
			if (x == 12 || x == 16 || y == 12 || y == 16)
				walls += new /obj/covers/wood_wall/hf_wall(locate(x, y, 1))
	var/list/judged = home_comfort_judge(locate(14, 14, 1))
	hf_check(("finished walls" in judged["missing"]), "bare walls are not finished")
	for (var/obj/covers/C in walls)
		C.finish_color = "#efe9da"
		C.finish_applied = world.realtime
	judged = home_comfort_judge(locate(14, 14, 1))
	hf_check(!("finished walls" in judged["missing"]), "limewashed walls are")

	// Dyed cloth padding.
	var/obj/structure/bed/chair/hf_chair/chair = new(locate(3, 3, 1), "wood", "cloth")
	hf_check(chair.padding_shade() == chair.padding_material.icon_colour && chair.name == "cloth chair", "undyed cloth padding keeps the cloth colour ([chair.name])")
	chair.padding_color = "#a8342c"
	chair.update_icon()
	hf_check(chair.padding_shade() == "#a8342c" && findtext(chair.name, "madder red cloth") && findtext(chair.desc, "madder red"), "dyed padding shows its dye ([chair.name])")
	chair.remove_padding()
	hf_check(!chair.padding_color && !chair.padding_material, "removing the padding drops the dye")
	var/obj/structure/bed/chair/hf_chair/leather_chair = new(locate(3, 4, 1), "wood", "leather")
	leather_chair.padding_color = "#a8342c"
	hf_check(leather_chair.padding_shade() == leather_chair.padding_material.icon_colour, "leather padding takes no cloth dye")
	var/obj/item/weapon/stool/hf_stool/stool = new(locate(4, 3, 1), "wood", "cloth")
	stool.padding_color = "#3e5a86"
	stool.update_icon()
	hf_check(stool.padding_shade() == "#3e5a86" && findtext(stool.name, "woad blue"), "a stool's padding takes a dye too ([stool.name])")
	hf_check(fabric_dye_label("#ffffff") == null && fabric_dye_label("#123456") == "dyed", "undyed has no label and a mixed colour is just dyed")
