var/list/global/floor_cache = list()

/turf/floor/trench
	name = "trench"
	icon = 'icons/turf/trench.dmi'
	icon_state = "trench"
	base_icon_state = "trench"
	//var/image/over_OS_darkness = null
	plane = UNDERFLOOR_PLANE
	initial_flooring = /decl/flooring/trench
	var/trench_filling = 0

/turf/floor/trench/New()
	if (!icon_state)
		icon_state = "trench"
	//over_OS_darkness = image('icons/turf/floors.dmi', "black_open")
	//over_OS_darkness.plane = GAME_PLANE
	//over_OS_darkness.layer = 25
	//over_OS_darkness.blend_mode = BLEND_MULTIPLY
	..()
	spawn(4)
		if (src)
			update_icon()
			for (var/direction in list(1,2,4,8,5,6,9,10))
				if (istype(get_step(src,direction),/turf/floor))
					var/turf/floor/FF = get_step(src,direction)
					FF.update_icon() //so siding get updated properly

/turf/floor/trench/make_grass()
	overlays.Cut()
	if (islist(decals))
		decals.Cut()
		decals = null

	set_light(0)
	levelupdate()

	ChangeTurf(/turf/floor/trench)

/turf/floor/trench/attackby(obj/item/C as obj, mob/user as mob)
	if (istype (C, /obj/item/weapon/sandbag) && !istype(C, /obj/item/weapon/sandbag/sandbag))
		var/choice = WWinput(user, "Do you want to start filling up the trench with \the [C]?","Trench","Yes",list("Yes","No"))
		if (choice == "Yes")
			user << "You shove some dirt into the trench."
			trench_filling++
			qdel(C)
			check_filling()
			return
		else
			return

	else
		..()

/turf/floor/trench/proc/check_filling()
	if (trench_filling < 0)
		trench_filling = 0
	if (trench_filling >= 2)
		ChangeTurf(get_base_turf_by_area(src))
	return
/decl/flooring/trench
	name = "trench"
	desc = "Hole in the ground."
	icon = 'icons/turf/trench.dmi'
	icon_base = "trench"
	flags = TURF_HAS_EDGES | SMOOTH_ONLY_WITH_ITSELF

/turf/floor/dirt
	var/trench_stage = 0
	available_dirt = 2
/turf/floor/trench/Enter(atom/movable/O, atom/oldloc)
	if(isliving(O))
		var/mob/living/L = O
		var/message_cooldown
		if(!istype(oldloc, /turf/floor/trench))
			if(L.grabbed_by && L.grabbed_by.len)
				var/mob/living/L2 = L.grabbed_by[1].assailant
				visible_message("<span class = 'notice'>[L2] starts pulling [L] out of trench.</span>")
				if(!do_after(L2, 20, oldloc))
					return FALSE
				if(..())
					visible_message("<span class = 'notice'>[L2] pulls [L] out of trench.</span>")
					L.forceMove(src)
					return TRUE
				return FALSE
			if(world.time > message_cooldown + 30)
				visible_message("<span class = 'notice'>[L] starts to enter a trench.</span>")
				message_cooldown = world.time
			if (!do_after(L, 5, src, needhand = FALSE))
				return FALSE
			if(..())
				visible_message("<span class = 'notice'>[L] enters a trench.</span>")
				L.forceMove(src)
				return 1

	return ..()

/turf/floor/trench/Exit(atom/movable/O, atom/newloc)
	if(isliving(O))
		var/mob/living/L = O
		var/message_cooldown
		if(!istype(newloc, /turf/floor/trench))
			if(L.grabbed_by && L.grabbed_by.len)
				var/mob/living/L2 = L.grabbed_by[1].assailant
				visible_message("<span class = 'notice'>[L2] starts pulling [L] out of trench.</span>")
				if(!do_after(L2, 35, src))
					return FALSE
				if(..())
					visible_message("<span class = 'notice'>[L2] pulls [L] out of trench.</span>")
					L.forceMove(newloc)
					return TRUE
				return FALSE
			var/atom/newlocation = get_step(L,L.dir)
			if (newlocation.density)
				return FALSE
			for (var/atom/A in newlocation)
				if (A.density)
					return FALSE
			if(world.time > message_cooldown + 30)
				visible_message("<span class = 'notice'>[L] starts to exit a trench.</span>")
				message_cooldown = world.time
			if (!do_after(L, 20, src, needhand = FALSE))
				return FALSE
			if(..())
				visible_message("<span class = 'notice'>[L] exits a trench.</span>")
				var/turf/T = newloc
				if(T.Enter(O, src))
					L.forceMove(newloc)
				return TRUE

	return ..()

/turf/open/trench/update_icon()
	..()
	//Trench needs open_space like system or some object upon it so the objects inside get shaded
	//overlays.Cut()
	//var/image/over_OS_darkness = image('icons/turf/floors.dmi', "black_open")
	//over_OS_darkness.plane = GAME_PLANE
	//over_OS_darkness.layer = 25
	//overlays += over_OS_darkness

/turf/floor/dirt/attackby(obj/item/C as obj, mob/user as mob)
	if (istype(C, /obj/item/weapon/shovel/trench))
		var/obj/item/weapon/shovel/trench/S = C
		visible_message("<span class = 'notice'>[user] starts to dig a trench.</span>")
		if (!do_after(user, (10 - S.dig_speed)*10, src))
			return
		trench_stage++
		switch(trench_stage)
			if(1)
				//icon_state = ""
				visible_message("<span class = 'notice'>[user] digs.</span>")
				user << ("<span class = 'notice'>You need to dig this tile one more time to make a trench.</span>")
				return
			if(2)
				visible_message("<span class = 'notice'>[user] makes a trench.</span>")
				ChangeTurf(/turf/floor/trench)
		return
	..()

/turf/floor/beach/sand
	var/trench_stage = 0
/turf/floor/beach/sand/attackby(obj/item/C as obj, mob/user as mob)
	if (istype(C, /obj/item/weapon/shovel/trench))
		var/obj/item/weapon/shovel/trench/S = C
		visible_message("<span class = 'notice'>[user] starts to dig a trench.</span>")
		if (!do_after(user, (10 - S.dig_speed)*10, src))
			return
		trench_stage++
		switch(trench_stage)
			if(1)
				//icon_state = ""
				visible_message("<span class = 'notice'>[user] digs.</span>")
				user << ("<span class = 'notice'>You need to dig this tile one more time to make a trench.</span>")
				return
			if(2)
				visible_message("<span class = 'notice'>[user] makes a trench.</span>")
				ChangeTurf(/turf/floor/trench)
		return
	..()

/turf/floor/dirt/attackby(obj/item/C as obj, mob/user as mob)
	if (istype(C, /obj/item/weapon/shovel/trench))
		var/obj/item/weapon/shovel/trench/S = C
		visible_message("<span class = 'notice'>[user] starts to dig a trench.</span>")
		if (!do_after(user, (10 - S.dig_speed)*10, src))
			return
		if (istype(src,/turf/floor/dirt))
			trench_stage++
			switch(trench_stage)
				if(1)
					//icon_state = ""
					visible_message("<span class = 'notice'>[user] digs.</span>")
					user << ("<span class = 'notice'>You need to dig this tile one more time to make a trench.</span>")
					return
				if(2)
					visible_message("<span class = 'notice'>[user] makes a trench.</span>")
					ChangeTurf(/turf/floor/trench)
		return
	..()

/turf/floor/grass/attackby(obj/item/C as obj, mob/user as mob)
	if (istype(C, /obj/item/weapon/shovel/trench))
		var/obj/item/weapon/shovel/trench/S = C
		visible_message("<span class = 'notice'>[user] starts to remove grass layer.</span>")
		if (!do_after(user, (10 - S.dig_speed)*10, src))
			return
		visible_message("<span class = 'notice'>[user] removes grass layer.</span>")
		ChangeTurf(/turf/floor/dirt)
		return
	..()

/turf/floor/winter/attackby(obj/item/C as obj, mob/user as mob)
	if (istype(C, /obj/item/weapon/shovel/trench))
		var/obj/item/weapon/shovel/trench/S = C
		visible_message("<span class = 'notice'>[user] starts to remove snow layer.</span>")
		if (!do_after(user, (10 - S.dig_speed)*10, src))
			return
		visible_message("<span class = 'notice'>[user] removes snow layer.</span>")
		ChangeTurf(/turf/floor/dirt)
		return
	..()