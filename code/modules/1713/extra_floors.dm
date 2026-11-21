// More floors from materials players already work: flagstone, copper, bronze,
// lead, glass block, rush matting, obsidian and steel tread plate, plus pelt
// rugs. The floors are ordinary floor covers laid through normal floor
// placement. A pelt rug is not a floor: it lies on top of whatever floor is
// there and can be taken up again. Art: scripts/draw_extra_floors.py.

/obj/covers/flagstone
	name = "flagstone floor"
	desc = "Rough-split flat stones bedded close together. Cheap, plain and hard to wear out."
	icon = 'icons/turf/flooring/extra_floors.dmi'
	icon_state = "flagstone"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 2
	health = 120
	maxhealth = 120
	hardness = 70
	material = "Stone"
	buildstack = /obj/item/stack/material/stone

/obj/covers/copper_plate
	name = "copper plate floor"
	desc = "Hammered copper sheets nailed down edge to edge. Handsome, fireproof and softer than iron."
	icon = 'icons/turf/flooring/extra_floors.dmi'
	icon_state = "copper_plate"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 2
	health = 100
	maxhealth = 100
	hardness = 55
	material = "Copper"
	buildstack = /obj/item/stack/material/copper

/obj/covers/bronze_plate
	name = "bronze tile floor"
	desc = "Cast bronze tiles, each with a sunk panel and a small boss. A floor for a hall that is meant to impress."
	icon = 'icons/turf/flooring/extra_floors.dmi'
	icon_state = "bronze_plate"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 3
	health = 140
	maxhealth = 140
	hardness = 70
	material = "Bronze"
	buildstack = /obj/item/stack/material/bronze

/obj/covers/lead_sheet
	name = "lead sheet floor"
	desc = "Lead sheet dressed over rolls. It will not burn or rot, but it is soft and dents under a hard blow."
	icon = 'icons/turf/flooring/extra_floors.dmi'
	icon_state = "lead_sheet"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 1
	health = 70
	maxhealth = 70
	hardness = 30
	material = "Lead"
	buildstack = /obj/item/stack/material/lead

/obj/covers/glass_block
	name = "glass block floor"
	desc = "Thick cast glass blocks set in a frame. Bright and easy to clean, and the first floor to break."
	icon = 'icons/turf/flooring/extra_floors.dmi'
	icon_state = "glass_block"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 0
	health = 45
	maxhealth = 45
	hardness = 25
	material = "Glass"
	buildstack = /obj/item/stack/material/glass

/obj/covers/rush_matting
	name = "rush matting"
	desc = "Plaited rushes laid over the ground. The cheapest floor there is, and it burns like one."
	icon = 'icons/turf/flooring/extra_floors.dmi'
	icon_state = "rush_matting"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = TRUE
	explosion_resistance = 0
	health = 30
	maxhealth = 30
	hardness = 10
	material = "Leaf"
	buildstack = /obj/item/stack/material/leaf

/obj/covers/obsidian_tile
	name = "obsidian tile floor"
	desc = "Black volcanic glass, knapped square and polished. Fireproof and very fine, but it shatters under a blast."
	icon = 'icons/turf/flooring/extra_floors.dmi'
	icon_state = "obsidian_tile"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 0
	health = 80
	maxhealth = 80
	hardness = 85
	material = "Obsidian"
	buildstack = /obj/item/stack/material/obsidian

/obj/covers/steel_tread
	name = "steel tread plate"
	desc = "Rolled steel with raised lozenges for grip. The toughest floor a workshop can lay."
	icon = 'icons/turf/flooring/extra_floors.dmi'
	icon_state = "steel_tread"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 4
	health = 220
	maxhealth = 220
	hardness = 100
	material = "Steel"
	buildstack = /obj/item/stack/material/steel

/////////////////////////////// Pelt rugs ///////////////////////////////

/obj/structure/pelt_rug
	name = "bear pelt rug"
	desc = "A whole hide spread fur side up on the floor."
	icon = 'icons/obj/pelt_rugs.dmi'
	icon_state = "bear_brown"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	layer = 2.05 // over the floor, under furniture and what lies on it
	flammable = TRUE
	not_movable = TRUE
	var/pelt = /obj/item/stack/material/pelt/bearpelt/brown
	var/pelts = 2 // what it was made from and gives back when taken up

/obj/structure/pelt_rug/black
	name = "black bear pelt rug"
	icon_state = "bear_black"
	pelt = /obj/item/stack/material/pelt/bearpelt/black

/obj/structure/pelt_rug/white
	name = "white bear pelt rug"
	icon_state = "bear_white"
	pelt = /obj/item/stack/material/pelt/bearpelt/white

/obj/structure/pelt_rug/wolf
	name = "wolf pelt rug"
	icon_state = "wolf"
	pelt = /obj/item/stack/material/pelt/wolfpelt

/obj/structure/pelt_rug/wolf/white
	name = "white wolf pelt rug"
	icon_state = "wolf_white"
	pelt = /obj/item/stack/material/pelt/wolfpelt/white

/obj/structure/pelt_rug/verb/take_up_rug()
	set name = "Take Up Rug"
	set category = null
	set src in view(1)
	var/mob/living/human/H = usr
	if (!istype(H) || H.incapacitated() || !Adjacent(H))
		return
	if (!do_after(H, 20, src))
		return
	if (QDELETED(src))
		return
	H.visible_message(SPAN_NOTICE("[H] takes up \the [src]."), SPAN_NOTICE("You take up \the [src]."))
	new pelt(get_turf(src), pelts)
	qdel(src)

/obj/structure/pelt_rug/ex_act(severity)
	qdel(src)

// Whether a pelt rug lies on T, for home comfort (home_comfort.dm).
/proc/pelt_rug_covers(turf/T)
	return T && (locate(/obj/structure/pelt_rug) in T) ? TRUE : FALSE
