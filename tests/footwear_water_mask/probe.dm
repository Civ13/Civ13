// Adapted types only. prepare.py includes unmodified production appearance procs.
// Compile-only by default; native execution requires a separate maintainer grant.
/world
	maxx = 3
	maxy = 3
	maxz = 1
	visibility = 0

/world/OpenPort()
	return 0

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

/proc/check(var/condition, var/message)
	checks++
	if (!condition)
		failures += message

/proc/check_footwear(var/mob/living/human/H, var/wet, var/stained)
	var/image/I = H.overlays_standing[SHOES_LAYER]
	check(!!I, "footwear image exists")
	if (!I)
		return
	check(!!(I.appearance_flags & KEEP_TOGETHER) == wet, "group only while wet")
	check(I.filters.len == wet, "one water filter, no stacking")
	check(I.overlays.len == stained, "nested stain retained")
	check(H.overlays.len >= 1, "appearance published")
	if (stained)
		var/stain = I.overlays[1]
		check(stain:icon_state == "shoeblood", "actual worn stain state")
		check(stain:color == H.shoes.blood_color, "blood or brown mud color retained")
		check(stain:plane == I.plane, "stain inherits footwear plane")
	check(I.layer == H.layer + 0.01, "footwear layer retained")
	check(H.shoes.dirtyness == 65 && H.shoes.track_blood == 5, "persistent dirt and tracks unchanged")
	check(H.shoes.blood_DNA.len == 1, "persistent stain DNA unchanged")

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
				check_footwear(H, 0, 1)
				H.water_overlay = 1
				H.update_fire()
				check_mask(H, "seashallow_over2")
				check_footwear(H, 1, 1)
				H.drowning = 1
				H.update_fire()
				check_mask(H, "seashallow_over3")
				var/turf/floor/sub_deck/T = new(H.loc)
				for (var/depth in list(1,29,30,99,100,120,30,1,0))
					T.water_depth = depth
					H.update_fire()
					check_mask(H, depth >= 100 ? "seashallow_over3" : (depth >= 30 ? "seashallow_over2" : (depth > 0 ? "seashallow_over1" : null)))
					check_footwear(H, depth > 0, 1)
					// Rebuild after water update, including deferred publication.
					H.update_inv_shoes(0)
					H.update_icons()
					check_footwear(H, depth > 0, 1)
				H.drowning = 0
				H.water_overlay = 0
				H.update_fire()
				check_footwear(H, 0, 1)
				var/turf/dry = new /turf(H.loc)
				H.loc = dry
	// Icon override, clean replacement, suit hiding, and bare-foot fallback.
	H.water_overlay = 1
	H.shoes.icon_override = 'icons/mob/feet.dmi'
	H.update_inv_shoes()
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
	text2file(json_encode(list("checks"=checks, "failures"=failures, "scope"="adapted appearance state, no client pixels")), "result.json")
	del(world)
	return
