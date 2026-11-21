/obj/covers/roads
	name = "road"
	icon = 'icons/turf/roads.dmi'
	icon_state = "road"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.98
	flammable = FALSE
	explosion_resistance = 10
	material = "Stone"
	var/vertical = FALSE
	buildstack = null
	var/roadtype = "road"

/obj/covers/roads/modern
	name = "modern road"
	icon_state = "tarmac"
	roadtype = "tarmac"

/obj/covers/roads/dirt
	name = "dirt road"
	icon_state = "d_road"
	roadtype = "d_road"

// Separate provenance: authored and legacy dirt roads keep their old behavior.
/obj/covers/roads/dirt/worked
	name = "packed dirt road"
	desc = "A dirt road packed flat by a plough. Use a plough on Help intent to reclaim it as a garden, or a shovel to remove the road."

/obj/covers/roads/dirt/worked/attackby(obj/O as obj, mob/living/human/user as mob)
	if (!istype(O, /obj/item/weapon/plough) || !istype(user) || user.a_intent != I_HELP)
		return ..()
	var/obj/item/weapon/plough/tool = O
	var/turf/floor/ground = loc
	var/problem = garden_reclaim_problem(ground, user, tool)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return TRUE
	to_chat(user, SPAN_NOTICE("You start loosening the packed dirt for a garden."))
	var/duration = ground.type == /turf/floor/grass ? 120 : 70
	if (!do_after(user, work_delay(user, duration, WORK_TILL, tool), src))
		return TRUE
	problem = garden_reclaim_problem(ground, user, tool)
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return TRUE
	var/turf/floor/dirt/old_soil = ground
	var/old_nutrition = istype(old_soil) ? old_soil.soil_nutrition : null
	var/old_dirt = istype(old_soil) ? old_soil.available_dirt : null
	var/recovery_delay = null
	if (istype(old_soil) && old_soil.soil_recovery_deadline)
		recovery_delay = max(1, old_soil.soil_recovery_deadline - world.time)
	// ChangeTurf preserves terrain grade and pollution. Restore soil stocks rather
	// than let a road-to-garden loop refill exhausted ground.
	var/turf/floor/dirt/ploughed/garden = ground.ChangeTurf(/turf/floor/dirt/ploughed)
	if (!istype(garden))
		return TRUE
	if (!isnull(old_nutrition))
		garden.soil_nutrition = old_nutrition
		garden.soil_recovery_schedule(recovery_delay)
	if (!isnull(old_dirt))
		garden.available_dirt = old_dirt
	amount = 0
	qdel(src)
	user.adaptStat("farming", 2)
	to_chat(user, SPAN_NOTICE("You reclaim the old road as a ploughed garden. Plant and water it like any other plot."))
	return TRUE

/obj/covers/roads/dirt/worked/proc/garden_reclaim_problem(turf/floor/ground, mob/living/human/user, obj/item/weapon/plough/tool)
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		return "Wait until the world finishes saving or loading."
	if (QDELETED(src) || !istype(ground) || loc != ground || !istype(user) || user.incapacitated() || user.restrained() || user.a_intent != I_HELP || !user.Adjacent(src) || QDELETED(tool) || tool.loc != user || user.get_active_hand() != tool)
		return "Stay beside the road with the plough in your active hand and use Help intent."
	// Do not broaden the farmable terrain roster (sand, jungle, wetlands, caves, ship decks).
	if (ground.density || !(ground.type in list(/turf/floor/grass, /turf/floor/dirt, /turf/floor/dirt/fertile, /turf/floor/dirt/medium_fertile, /turf/floor/dirt/infertile)) || (ground.flooring && ground.flooring.type != ground.initial_flooring))
		return "You can only reclaim a road laid over ordinary grass or bare soil."
	if (ground.weather_snow > 0 || ground.water_level > 0 || origin_water_level > 0 || flood_depth_at(ground) > 0)
		return "Clear the snow or water before reclaiming this road."
	for (var/obj/blocker in ground)
		if (blocker != src && (blocker.density || istype(blocker, /obj/covers) || istype(blocker, /obj/structure) || istype(blocker, /obj/roof)))
			return "Clear what is built or growing on the road before reclaiming it."
	return null

/obj/covers/roads/roman
	name = "roman road"
	icon_state = "r_road"
	roadtype = "r_road"

/obj/covers/roads/cobble
	name = "cobble street"
	icon_state = "street"
	roadtype = "street"

/obj/covers/roads/sandstone
	name = "sandstone road"
	icon_state = "s_stone"
	roadtype = "s_stone"

/obj/covers/roads/update_icon()
	..()
	spawn(1)
		overlays.Cut()
		var/list/sideslist = list()
		for (var/direction in list(NORTH,SOUTH,EAST,WEST))
			for(var/obj/covers/roads/R in get_step(src,direction))
				sideslist += direction
				continue
		for (var/direction in list(NORTHEAST,NORTHWEST,SOUTHEAST,SOUTHWEST))
			var/turf/T = null
			switch(direction)
				if (NORTHEAST)
					T = locate(src.x+1,src.y+1,src.z)
				if (NORTHWEST)
					T = locate(src.x-1,src.y+1,src.z)
				if (SOUTHEAST)
					T = locate(src.x+1,src.y-1,src.z)
				if (SOUTHWEST)
					T = locate(src.x-1,src.y-1,src.z)
			if (T)
				for(var/obj/covers/roads/R in T)
					sideslist += direction
					continue

		if ((NORTHWEST in sideslist) && (NORTH in sideslist) && (WEST in sideslist))
			overlays += image(icon=src.icon, icon_state = "[roadtype]nwc")
		if ((NORTHEAST in sideslist) && (NORTH in sideslist) && (EAST in sideslist))
			overlays += image(icon=src.icon, icon_state = "[roadtype]nec")
		if ((SOUTHEAST in sideslist) && (SOUTH in sideslist) && (EAST in sideslist))
			overlays += image(icon=src.icon, icon_state = "[roadtype]sec")
		if ((SOUTHWEST in sideslist) && (SOUTH in sideslist) && (WEST in sideslist))
			overlays += image(icon=src.icon, icon_state = "[roadtype]swc")

		if ((WEST in sideslist) && (EAST in sideslist) && (NORTH in sideslist) && (SOUTH in sideslist))
			icon_state = "[roadtype]+" //4 sides
			base_icon_state = icon_state
			return

		if (icon_state == "[roadtype]vr")
			if (WEST in sideslist)
				if (!(NORTH in sideslist))
					if (EAST in sideslist)
						icon_state = "[roadtype]tswe" //T, SOUTH EAST WEST
						base_icon_state = icon_state
					else
						icon_state = "[roadtype]sw" //Turn, SOUTH-WEST
						base_icon_state = icon_state
				else if (!(SOUTH in sideslist))
					if (EAST in sideslist)
						icon_state = "[roadtype]tnwe" //T, NORTH EAST WEST
						base_icon_state = icon_state
					else
						icon_state = "[roadtype]nw" //Turn, NORTH-WEST
						base_icon_state = icon_state
				else if ((SOUTH in sideslist) && (NORTH in sideslist))
					icon_state = "[roadtype]tnsw" //T, NORTH SOUTH WEST
					base_icon_state = icon_state
			else if (EAST in sideslist)
				if (!(NORTH in sideslist))
					icon_state = "[roadtype]se" //Turn, SOUTH-EAST
					base_icon_state = icon_state
					return
				else if (!(SOUTH in sideslist))
					icon_state = "[roadtype]ne" //Turn, NORTH-EAST
					base_icon_state = icon_state
				else if ((SOUTH in sideslist) && (NORTH in sideslist))
					icon_state = "[roadtype]tnse" //T, NORTH SOUTH EAST
					base_icon_state = icon_state
		else
			if (NORTH in sideslist)
				if (!(EAST in sideslist))
					icon_state = "[roadtype]nw" //Turn, NORTH-WEST
					base_icon_state = icon_state
				else if (!(WEST in sideslist))
					if (SOUTH in sideslist)
						icon_state = "[roadtype]tnse" //T, NORTH SOUTH EAST
						base_icon_state = icon_state
					else
						icon_state = "[roadtype]ne" //Turn, NORTH-EAST
						base_icon_state = icon_state
				else if ((WEST in sideslist) && (EAST in sideslist))
					icon_state = "[roadtype]tnwe" //T, NORTH EAST WEST
					base_icon_state = icon_state
			else if (SOUTH in sideslist)
				if (!(EAST in sideslist))
					icon_state = "[roadtype]sw" //Turn, SOUTH-WEST
					base_icon_state = icon_state
				else if (!(WEST in sideslist))
					icon_state = "[roadtype]se" //Turn, SOUTH-EAST
					base_icon_state = icon_state
				else if ((WEST in sideslist) && (EAST in sideslist))
					icon_state = "[roadtype]tswe" //T, EAST SOUTH WEST
					base_icon_state = icon_state
		if ((WEST in sideslist) && (NORTH in sideslist) && (SOUTH in sideslist))
			icon_state = "[roadtype]tnsw" //T, NORTH SOUTH WEST
			base_icon_state = icon_state
		if ((WEST in sideslist) && (NORTH in sideslist) && (EAST in sideslist))
			icon_state = "[roadtype]tnwe" //T, NORTH EAST WEST
			base_icon_state = icon_state
		if ((WEST in sideslist) && (EAST in sideslist) && (SOUTH in sideslist))
			icon_state = "[roadtype]tswe" //T, SOUTH EAST WEST
			base_icon_state = icon_state
		if ((EAST in sideslist) && (NORTH in sideslist) && (SOUTH in sideslist))
			icon_state = "[roadtype]tnse" //T, NORTH SOUTH EAST
			base_icon_state = icon_state

/obj/covers/roads/New()
	..()
	spawn(2)
		if (vertical)
			dir = 1
		else
			dir = 4
		for(var/obj/covers/roads/R in range(1,src))
			R.update_icon()
		update_icon()

/* Road Destruction*/

/obj/covers/roads/modern/attackby(obj/O as obj, mob/living/human/user as mob)
	if (is_tool(O, TOOL_PICKAXE))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		to_chat(user, SPAN_NOTICE("You begin breaking apart \the [src]."))
		if (do_after(user, work_delay(user, 45, WORK_MINE, O), src))
			to_chat(user, SPAN_NOTICE("You break apart \the [src]."))
			new /obj/item/stack/material/stone(loc)
			qdel(src)

/obj/covers/roads/dirt/attackby(obj/O as obj, mob/living/human/user as mob)
	if (is_tool(O, TOOL_SHOVEL))
		playsound(src, 'sound/effects/shovelling.ogg', 85, 1)
		to_chat(user, SPAN_NOTICE("You begin filling over in the earth of \the [src]."))
		if (do_after(user, work_delay(user, 30, WORK_SHIFT, O), src))
			to_chat(user, SPAN_NOTICE("You finish filling over \the [src]."))
			qdel(src)

/obj/covers/roads/roman/attackby(obj/O as obj, mob/living/human/user as mob)
	if (is_tool(O, TOOL_PICKAXE))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		to_chat(user, SPAN_NOTICE("You begin breaking apart \the [src]."))
		if (do_after(user, work_delay(user, 45, WORK_MINE, O), src))
			to_chat(user, SPAN_NOTICE("You break apart \the [src]."))
			new /obj/item/stack/material/stone(loc)
			qdel(src)

/obj/covers/roads/cobble/attackby(obj/O as obj, mob/living/human/user as mob)
	if (is_tool(O, TOOL_PICKAXE))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		to_chat(user, SPAN_NOTICE("You begin breaking apart \the [src]."))
		if (do_after(user, work_delay(user, 45, WORK_MINE, O), src))
			to_chat(user, SPAN_NOTICE("You break apart \the [src]."))
			new /obj/item/stack/material/stone(loc)
			qdel(src)

/obj/covers/roads/sandstone/attackby(obj/O as obj, mob/living/human/user as mob)
	if (is_tool(O, TOOL_PICKAXE))
		playsound(src, 'sound/effects/pickaxe.ogg', 85, 1)
		to_chat(user, SPAN_NOTICE("You begin breaking apart \the [src]."))
		if (do_after(user, work_delay(user, 45, WORK_MINE, O), src))
			to_chat(user, SPAN_NOTICE("You break apart \the [src]."))
			new /obj/item/stack/material/sandstone(loc)
			qdel(src)
