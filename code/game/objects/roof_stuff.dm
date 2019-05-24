/obj/roof

	name = "wood roof"
	desc = "A wooden roof."
	icon = 'icons/turf/floors.dmi'
	icon_state = "roof"
	var/passable = TRUE
	var/origin_density = FALSE
	var/not_movable = TRUE //if it can be removed by wrenches
	var/health = 100
	is_cover = TRUE
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	layer = 2.1
	level = 2
	var/amount = FALSE
	var/wall = FALSE
	var/wood = TRUE
	var/onfire = FALSE
//	invisibility = 101
	flammable = TRUE
	var/current_area_type = /area/caribbean

/obj/roof/New()
	..()
	var/area/caribbean/CURRENTAREA = get_area(src)
//	var/oldclimate = CURRENTAREA.climate
	if (CURRENTAREA.location == AREA_OUTSIDE)
		current_area_type = CURRENTAREA.type
		new/area/caribbean/roofed(get_turf(src))
// TODO: Different roofed climates
//		var/area/caribbean/roofed/A = new/area/caribbean/roofed(src.loc)
//		A.climate = oldclimate
	for (var/atom/movable/lighting_overlay/LO in get_turf(src))
		LO.update_overlay()
	spawn(50)
		collapse_check()
/obj/roof/Destroy()
	new current_area_type(get_turf(src))
	for (var/atom/movable/lighting_overlay/LO in get_turf(src))
		LO.update_overlay()
	..()

/obj/roof/proc/collapse_check()
	var/supportfound = FALSE
	spawn(50)
		for (var/obj/structure/roof_support/RS in range(2, src))
			supportfound = TRUE
		for (var/obj/structure/mine_support/stone/SS in range(2, src))
			supportfound = TRUE
		for (var/turf/wall/W in range(1, src))
			supportfound = TRUE
		for (var/obj/covers/C in range(1, src))
			if (C.wall == TRUE)
				supportfound = TRUE
	//if no support >> roof falls down
		if (!supportfound)
			playsound(src,'sound/effects/rocksfalling.ogg',100,0,6)
			for (var/mob/living/carbon/human/M in range(1, src))
				M.adjustBruteLoss(rand(17,27))
				M.Weaken(15)
				M << "The roof collapses!"
			Destroy()
			qdel(src)
		else
			collapse_check()

/obj/item/weapon/roofbuilder
	name = "roof builder"
	desc = "Use this to build roofs."
	icon = 'icons/turf/floors.dmi'
	icon_state = "roof_builder"
	w_class = 2.0
	flammable = TRUE
	var/done = FALSE
/obj/item/weapon/roofbuilder/clay
	name = "clay roofing"
	desc = "Use this to build roofs."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "clayroofing"
	w_class = 2.0
	flammable = FALSE

/obj/item/weapon/roofbuilder/attack_self(mob/user)
	var/your_dir = "NORTH"

	switch (user.dir)
		if (NORTH)
			your_dir = "NORTH"
		if (SOUTH)
			your_dir = "SOUTH"
		if (EAST)
			your_dir = "EAST"
		if (WEST)
			your_dir = "WEST"

	var/covers_time = 80

	if (ishuman(user))
		var/mob/living/carbon/human/H = user
		covers_time /= H.getStatCoeff("strength")
		covers_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))
	var/area/currentarea = get_area(get_step(user, user.dir))
	if (istype(currentarea, /area/caribbean/no_mans_land/invisible_wall))
		user << "You cannot build a roof here."
		return
	for (var/obj/roof/RF in get_step(user, user.dir))
		user << "That area is already roofed!"
		return
	var/confirm = FALSE
	for(var/obj/structure/roof_support/RS in range(2, get_step(user, user.dir)))
		confirm = TRUE
	for(var/obj/structure/mine_support/stone/SS in range(2, get_step(user, user.dir)))
		confirm = TRUE
	for(var/obj/covers/CV in range(1, get_step(user, user.dir)))
		if (CV.wall)
			confirm = TRUE
	if (!confirm)
		user << "This area doesn't have a support for the roof! Build one first!"
		return
	if (WWinput(user, "This will start building a roof [your_dir] of you.", "Roof Construction", "Continue", list("Continue", "Stop")) == "Continue")
		visible_message("<span class='danger'>[user] starts building the roof.</span>", "<span class='danger'>You start building the roof.</span>")
		if (do_after(user, covers_time, user.loc) && src && !done)
			done = TRUE
			new/obj/roof(get_step(user, user.dir), user)
			visible_message("<span class='danger'>[user] finishes building the roof.</span>")
			if (ishuman(user))
				var/mob/living/carbon/human/H = user
				H.adaptStat("crafting", 1)
			qdel(src)
		return

/obj/structure/roof_support
	name = "roof support"
	desc = "A thick wood beam, used to support roofs in large buildings."
	icon_state = "support_h"
	flammable = TRUE
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	var/health = 100
	not_movable = TRUE
	not_disassemblable = FALSE

/obj/structure/mine_support
	name = "mine support"
	desc = "A set of wood beams placed to support the mine shaft. Prevents cave-ins."
	icon_state = "support_v"
	flammable = TRUE
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	var/health = 100
	not_movable = TRUE
	not_disassemblable = FALSE

/obj/structure/mine_support/stone
	name = "stone pillar"
	desc = "A stone pillar that can support roofs and mine shafts."
	icon_state = "support_st1"
	flammable = FALSE
	anchored = TRUE
	opacity = FALSE
	density = FALSE
	health = 180
	not_movable = TRUE
	not_disassemblable = TRUE

/obj/structure/mine_support/stone/New()
	..()
	icon_state = pick("support_st1","support_st2")
	update_icon()

/obj/structure/mine_support/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon))
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		switch(W.damtype)
			if ("fire")
				health -= W.force * TRUE
			if ("brute")
				health -= W.force * 0.20
		playsound(get_turf(src), 'sound/effects/wood_cutting.ogg', 100)
		user.do_attack_animation(src)
		try_destroy()
	..()

/obj/structure/mine_support/proc/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>[src] is broken into pieces!</span>")
		Destroy()
		return

/obj/structure/roof_support/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon))
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		switch(W.damtype)
			if ("fire")
				health -= W.force * TRUE
			if ("brute")
				health -= W.force * 0.20
		playsound(get_turf(src), 'sound/effects/wood_cutting.ogg', 100)
		user.do_attack_animation(src)
		try_destroy()
	..()

/obj/structure/roof_support/proc/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>[src] is broken into pieces!</span>")
		Destroy()
		return


/obj/structure/mine_support/Destroy()
	if (istype(get_turf(src), /turf/floor))
		var/turf/floor/T = get_turf(src)
		T.collapse_check()
	..()