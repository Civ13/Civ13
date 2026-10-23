// Adapted types only. prepare.py includes unmodified production appearance procs.
// Compile-only by default; native execution requires a separate maintainer grant.
#ifndef FOOTWEAR_COLOR_CONTROL
#define FOOTWEAR_COLOR_CONTROL 0
#endif
/world
	maxx = 3
	maxy = 3
	maxz = 1
	visibility = 0

/world/OpenPort(requested_port)
	return requested_port == "none" ? ..() : 0

/client/New()
	del(src)

/turf/floor/sub_deck
	var/water_depth = 0

/proc/get_turf(var/atom/A)
	while (A && !isturf(A))
		A = A.loc
	return A

/datum/fixture_species
	var/blood_mask = 'icons/mob/human_races/masks/blood_human.dmi'
	var/has_floating_eyes = 0
	var/prone_icon = 0

/datum/fixture_species/proc/get_eyes()
	return null

/datum/fixture_build
	var/shoes_icon = 'icons/mob/feet.dmi'

/obj/item
	var/icon_override
	var/list/blood_DNA
	var/blood_color = "#A10808"
	var/track_blood = 5
	var/dirtyness = 65
	var/flags_inv = 0
	icon_state = "sailorboots2"

/mob/proc/update_icons()
	return

/mob/proc/update_inv_shoes()
	return

/mob/proc/update_fire()
	return

/mob/living/human
	var/list/overlays_standing[TOTAL_LAYERS]
	var/obj/item/shoes
	var/obj/item/wear_suit
	var/datum/fixture_species/species = new
	var/datum/fixture_build/body_build = new
	var/drowning = 0
	var/water_overlay = 0
	var/on_fire = 0
	var/list/feet_blood_DNA
	var/feet_blood_color = "#A10808"
	var/lying = 0
	var/lying_prev = 0
	var/prone = 0
	var/icon_update = 1
	var/stand_icon = 'icons/mob/human.dmi'
	var/size_multiplier = 1
	var/riding = 0
	var/mob/riding_mob

/mob/living/human/proc/find_inv_position()
	return "7,7"

var/global/list/failures = list()
var/global/checks = 0
var/global/color_control_applied = 0

/proc/footwear_rgb_equal(var/actual, var/expected)
	if (!istext(actual) || !istext(expected))
		return 0
	if (length(actual) != 7 || length(expected) != 7)
		return 0
	var/regex/rgb_pattern = regex("^#[0-9A-Fa-f]{6}$")
	if (!rgb_pattern.Find(actual) || !rgb_pattern.Find(expected))
		return 0
	return lowertext(actual) == lowertext(expected)

var/global/color_scene_id = "unset"
var/global/list/color_rows = list()
var/global/color_seen = 0
var/global/color_dropped = 0
var/global/color_truncated = 0

/proc/color_record(var/value)
	if (isnull(value))
		return list("type"="null", "value"=null)
	if (istext(value))
		if (length(value) > 128)
			color_truncated++
		return list("type"="text", "value"=copytext(value,1,129), "length"=length(value))
	if (isnum(value))
		return list("type"="number", "value"=value)
	if (islist(value))
		var/list/input = value
		var/list/items = list()
		if (input.len > 20)
			color_truncated++
		for (var/index = 1, index <= min(input.len,20), index++)
			var/entry = input[index]
			if (isnum(entry) || isnull(entry))
				items.Add(entry)
			else
				color_truncated++
				items.Add("unsupported-matrix-entry")
		return list("type"="list", "value"=items, "length"=input.len)
	color_truncated++
	return list("type"="unsupported", "value"=null)

/proc/record_footwear_color(var/mob/living/human/H, var/image/I, var/stain, var/wet)
	color_seen++
	if (color_rows.len >= 512)
		color_dropped++
		return
	// Detached controls only; do not mutate the cached footwear or stain.
	var/image/direct = image(icon=H.species.blood_mask, icon_state="shoeblood")
	direct.color = H.shoes.blood_color
	var/image/plain_parent = new /image
	plain_parent.overlays += direct
	var/plain_child = plain_parent.overlays[1]
	var/image/copied = new /image(stain)
	var/list/row = list("scene"=color_scene_id, "wet"=wet, "dir"=H.dir, "lying"=H.lying, "prone"=H.prone, "flags"=I.appearance_flags, "filters"=I.filters.len)
	row["actual_cached_child"] = color_record(stain:color)
	row["expected_source_field"] = color_record(H.shoes.blood_color)
	row["direct_image_assignment"] = color_record(direct.color)
	row["plain_overlay_copy"] = color_record(plain_child:color)
	row["image_from_cached_child"] = color_record(copied.color)
	row["footwear_tint"] = color_record(I.color)
	row["strict_equal"] = (stain:color == H.shoes.blood_color)
	row["rgb_equal"] = footwear_rgb_equal(stain:color, H.shoes.blood_color)
	if (length(json_encode(row)) > 4096)
		color_dropped++
		return
	color_rows += list(row)


/proc/check(var/condition, var/message)
	checks++
	if (!condition)
		failures += message

/proc/check_footwear(var/mob/living/human/H, var/wet, var/stained)
	var/image/I = H.overlays_standing[SHOES_LAYER]
	check(!!I, "footwear image exists")
	if (!I)
		return
	var/list/control_overlays
	if (stained && !color_control_applied && FOOTWEAR_COLOR_CONTROL)
		color_control_applied = 1
		control_overlays = I.overlays.Copy()
		if (FOOTWEAR_COLOR_CONTROL == 1 && I.overlays.len)
			var/image/wrong_rgb = new /image(I.overlays[1])
			wrong_rgb.color = "#A10809"
			I.overlays.Cut()
			I.overlays += wrong_rgb
		else if (FOOTWEAR_COLOR_CONTROL == 2)
			I.overlays.Cut()
	check(!!(I.appearance_flags & KEEP_TOGETHER) == wet, "group only while wet")
	check(I.filters.len == wet, "one water filter, no stacking")
	check(I.overlays.len == stained, "nested stain retained")
	check(H.overlays.len >= 1, "appearance published")
	if (stained && I.overlays.len)
		var/stain = I.overlays[1]
		check(stain:icon_state == "shoeblood", "actual worn stain state")
		check(footwear_rgb_equal(stain:color, H.shoes.blood_color), "blood or brown mud color retained")
		record_footwear_color(H, I, stain, wet)
		check(stain:plane == I.plane, "stain inherits footwear plane")
	check(I.layer == H.layer + 0.01, "footwear layer retained")
	check(H.shoes.dirtyness == 65 && H.shoes.track_blood == 5, "persistent dirt and tracks unchanged")
	check(H.shoes.blood_DNA.len == 1, "persistent stain DNA unchanged")
	// Controls affect only one assertion view; restore before later snapshots.
	if (control_overlays)
		I.overlays = control_overlays

/proc/check_mask(var/mob/living/human/H, var/state)
	var/icon/actual = H.get_water_mask_icon()
	if (!state)
		check(!actual, "dry mask absent")
		return
	check(!!actual, "wet mask present")
	if (!actual)
		return
	var/icon/expected = icon('icons/turf/beach.dmi', state)
	var/equal = 1
	for (var/x in 1 to 32)
		for (var/y in 1 to 32)
			if (actual.GetPixel(x,y) != expected.GetPixel(x,y))
				equal = 0
	check(equal, "current depth chooses [state] pixels")

/world/New()
	// Test-only entry contract, matching the existing loopback-admitting runner.
	OpenPort("none")
	check(port == 0, "fixture entry closes native startup listener")
	check(OpenPort(59474) == 0 && port == 0, "fixture refuses reopening")
	if (failures.len)
		world.log << "FAIL diagnostic: fixture closure failed"
		del(world)
		return
	text2file("closed", "port-closed.txt")
	var/list/rgb_cases = json_decode(file2text('rgb_cases.json'))
	for (var/list/rgb_case in rgb_cases)
		check(footwear_rgb_equal(rgb_case["actual"], rgb_case["expected"]) == rgb_case["equal"], "RGB text contract: [rgb_case["name"]]")
	var/mob/living/human/H = new(locate(2,2,1))
	H.shoes = new /obj/item(H)
	H.shoes.blood_DNA = list("sample" = "O+")
	H.shoes.color = "#B0A090"
	// Both genuine blood and mud use this nested appearance. Four directions,
	// standing/lying/prone, repeated entry/exit and depth changes on one turf.
	for (var/stain_color in list("#A10808", "#70543E"))
		H.shoes.blood_color = stain_color
		for (var/facing in list(NORTH,SOUTH,EAST,WEST))
			H.dir = facing
			for (var/stance in 0 to 2)
				H.lying = stance == 1
				H.prone = stance == 2
				H.water_overlay = 0
				H.drowning = 0
				H.update_inv_shoes()
				color_scene_id = "stain=[stain_color];dir=[facing];stance=[stance];stage=dry_initial"
				check_footwear(H, 0, 1)
				var/image/dry_footwear = H.overlays_standing[SHOES_LAYER]
				var/dry_appearance = dry_footwear.appearance
				H.water_overlay = 1
				H.update_fire()
				check_mask(H, "seashallow_over2")
				color_scene_id = "stain=[stain_color];dir=[facing];stance=[stance];stage=wading"
				check_footwear(H, 1, 1)
				H.drowning = 1
				H.update_fire()
				check_mask(H, "seashallow_over3")
				var/turf/floor/sub_deck/T = new(H.loc)
				var/depth_step = 0
				for (var/depth in list(1,29,30,99,100,120,30,1,0))
					depth_step++
					T.water_depth = depth
					H.update_fire()
					check_mask(H, depth >= 100 ? "seashallow_over3" : (depth >= 30 ? "seashallow_over2" : (depth > 0 ? "seashallow_over1" : null)))
					color_scene_id = "stain=[stain_color];dir=[facing];stance=[stance];step=[depth_step];depth=[depth];stage=water_update"
					check_footwear(H, depth > 0, 1)
					// Rebuild after water update, including deferred publication.
					H.update_inv_shoes(0)
					H.update_icons()
					color_scene_id = "stain=[stain_color];dir=[facing];stance=[stance];step=[depth_step];depth=[depth];stage=equipment_refresh"
					check_footwear(H, depth > 0, 1)
				H.drowning = 0
				H.water_overlay = 0
				H.update_fire()
				color_scene_id = "stain=[stain_color];dir=[facing];stance=[stance];stage=dry_return"
				check_footwear(H, 0, 1)
				var/image/returned_footwear = H.overlays_standing[SHOES_LAYER]
				check(returned_footwear.appearance == dry_appearance, "dry footwear appearance survives water roundtrip")
				var/turf/dry = new /turf(H.loc)
				H.loc = dry
	// Icon override, clean replacement, suit hiding, and bare-foot fallback.
	H.water_overlay = 1
	H.shoes.icon_override = 'icons/mob/feet.dmi'
	H.update_inv_shoes()
	color_scene_id = "stain=[H.shoes.blood_color];dir=[H.dir];stage=icon_override"
	check_footwear(H, 1, 1)
	H.shoes.blood_DNA = null
	H.update_inv_shoes()
	var/image/clean = H.overlays_standing[SHOES_LAYER]
	check(clean.overlays.len == 0 && clean.filters.len == 1, "clean equipment replacement masked")
	H.wear_suit = new /obj/item(H)
	H.wear_suit.flags_inv = HIDESHOES
	H.update_inv_shoes()
	check(!H.overlays_standing[SHOES_LAYER], "suit hiding retained")
	H.wear_suit = null
	H.shoes = null
	H.feet_blood_DNA = list("sample" = "O+")
	H.update_inv_shoes()
	var/image/feet = H.overlays_standing[SHOES_LAYER]
	check(feet.icon_state == "shoeblood" && feet.filters.len == 1, "bare feet remain masked")
	H.water_overlay = 0
	H.update_fire()
	check(feet.filters.len == 0 && !(feet.appearance_flags & KEEP_TOGETHER), "bare feet dry reset")
	H.feet_blood_DNA = null
	H.update_inv_shoes()
	check(!H.overlays_standing[SHOES_LAYER], "no residual stain after unequipping clean feet")
	text2file(json_encode(list("checks"=checks, "failures"=failures, "scope"="adapted appearance state, no client pixels", "control"=FOOTWEAR_COLOR_CONTROL, "control_applied"=color_control_applied)), "result.json")
	var/diagnostic_json = json_encode(list("schema"=1, "seen"=color_seen, "dropped"=color_dropped, "truncated"=color_truncated, "rows"=color_rows))
	if (length(diagnostic_json) > 3145728)
		world.log << "FAIL diagnostic: color evidence exceeds file bound"
	else
		text2file(diagnostic_json, "color-diagnostics.json")
		if (color_dropped || color_truncated)
			world.log << "FAIL diagnostic: bounded color evidence incomplete"
	del(world)
	return
