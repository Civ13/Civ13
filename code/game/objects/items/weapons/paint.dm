//NEVER USE THIS IT SUX	-PETETHEGOAT
//THE GOAT WAS RIGHT - RKF

var/global/list/cached_icons = list()

/obj/item/weapon/reagent_containers/glass/paint
	desc = "It's a paint bucket."
	name = "paint bucket"
	icon = 'icons/obj/items.dmi'
	icon_state = "paint_neutral"
	item_state = "paintcan"

	w_class = ITEM_SIZE_NORMAL
	amount_per_transfer_from_this = 10
	possible_transfer_amounts = list(10,20,30,60)
	volume = 60
	flags = OPENCONTAINER
	var/paint_type = "red"
	var/paint_color = "#FE191A"

// Over-ridden by attack_turf() in parent which does a better job of this old-code.
/*
	afterattack(turf/target, mob/user, proximity)
		if (!proximity) return
		if (istype(target) && reagents.total_volume > 5)
			user.visible_message("<span class='warning'>\The [target] has been splashed with something by [user]!</span>")
			reagents.trans_to_turf(target, 5)
		else
			return ..()
*/
	New()
		if (paint_type && length(paint_type) > 0)
			name = paint_type + " " + name
		..()
		reagents.add_reagent("paint", volume, paint_color)

	red
		icon_state = "paint_red"
		paint_type = "red"

	yellow
		icon_state = "paint_yellow"
		paint_type = "yellow"
		paint_color = "#FDFE7D"

	green
		icon_state = "paint_green"
		paint_type = "green"
		paint_color = "#18A31A"

	blue
		icon_state = "paint_blue"
		paint_type = "blue"
		paint_color = "#247CFF"

	purple
		icon_state = "paint_violet"
		paint_type = "purple"
		paint_color = "#CC0099"

	black
		icon_state = "paint_black"
		paint_type = "black"
		paint_color = "#000000"

	white
		icon_state = "paint_white"
		paint_type = "white"
		paint_color = "#FFFFFF"

