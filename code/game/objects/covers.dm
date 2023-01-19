/obj/covers

	name = "floor covers"
	desc = ""
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood_ship"
	var/base_icon_state = "wood_ship"
	var/passable = TRUE
	var/origin_covered = FALSE
	var/origin_water_level = 0
	var/not_movable = FALSE //if it can be removed by wrenches
	var/health = 100
	var/maxhealth = 100
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
	flammable = TRUE
	var/current_area_type = /area/caribbean
	var/incomplete = FALSE
	explosion_resistance = TRUE
	var/list/bullethole_count = list()
	var/list/bullethole_overlays = list()
//	invisibility = 101 //starts invisible
	var/material = "Wood" //Depending on mat, depending on what harms it.
	var/buildstackamount = 8
	var/buildstack = /obj/item/stack/material/wood
	var/adjusts = FALSE //if it adjusts acording to neighbouring sprites

	var/hardness = 50 //for projectile penetration
/*

/obj/covers/attackby(obj/item/W as obj, mob/user as mob)
	switch(material)
		if ("Wood")
			//Do nothing, anything can cut through wood.
		else if ("Stone")
			//Swords no work on stone, unga dunga no knify wifey the wall.
			if(!istype(W, /obj/item/weapon/sledgehammer) && !istype(W, /obj/item/projectile))
				user << "Your [W.name] glances off the [src.name]!"
				return
			else
				//Damage the wall.
		else if ("Metal" || "steel")
			if(!istype(W, /obj/item/weapon/sledgehammer) && !istype(W, /obj/item/projectile))
				user << "Your [W.name] glances off the [src.name]!"
				return
			else
				//Damage the wall.
		else
			//Do nothing, you're not important.
			..()*/

/obj/covers/proc/run_decay()
	if (!src || !wall)
		return
	decay()
	spawn(24000)
		if (src && wall)
			run_decay()
			return
		else
			return

/obj/covers/ex_act(severity)
	switch(severity)
		if (1.0)
			Destroy(src)
			return
		if (2.0)
			health -= initial(health)/2
			try_destroy()
			return
		if (3.0)
			health -= initial(health)/10
			try_destroy()
			return
		else
	return

/obj/covers/New()
	..()
	initial_opacity = opacity
	maxhealth = health
	spawn(5)
		updateturf()
		if (opacity)
			for(var/obj/roof/R in range(1,src))
				R.update_transparency(0)
	return TRUE

/obj/covers/updateturf()
	..()
	var/turf/T = get_turf(src)
	if (T)
		origin_water_level = T.water_level
		T.water_level = 0
		T.move_delay = 0
	return TRUE


/obj/covers/Destroy()
	var/area/caribbean/CURRENTAREA = get_area(src)
	if (!istype(CURRENTAREA, /area/caribbean/void/caves))
		if (wall && !incomplete)
			new current_area_type(get_turf(src))
		var/turf/floor/T = get_turf(loc)
		if (T)
			T.water_level = origin_water_level
			T.move_delay = initial(T.move_delay)
	if (amount > 0)
		var/obj/item/stack/material/wood/wooddrop = new /obj/item/stack/material/wood
		wooddrop.amount = amount
	if (wall == TRUE)
		for(var/obj/roof/R in range(2,src))
			R.collapse_check()
	..()
	spawn(1)
		if (opacity)
			for(var/obj/roof/R in range(1,src))
				R.update_transparency(0)
	return TRUE

/obj/item/weapon/covers/attack_self(mob/user)
	var/covers_time = 80
	if (ishuman(user))
		var/turf/targetfloor = get_turf(get_step(user, user.dir))
		if (istype(targetfloor, /turf/wall) || istype(targetfloor, /turf/floor/beach/water/deep/saltwater))
			if (map && map.ID != MAP_CAMPAIGN)
				visible_message("<span class='notice'>You can't build here!</span>")
				return
		var/mob/living/human/H = user
		covers_time /= H.getStatCoeff("strength")
		covers_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))
	if (WWinput(user, "This will start building a floor cover [dir2text(user.dir)] of you.", "Floor Cover Construction", "Continue", list("Continue", "Stop")) == "Continue")
		visible_message("<span class='danger'>[user] starts constructing the floor cover.</span>", "<span class='danger'>You start constructing the floor cover.</span>")
		if (do_after(user, covers_time, user.loc) && src)
			qdel(src)
			new/obj/covers/repairedfloor(get_step(user, user.dir), user)
			visible_message("<span class='danger'>[user] finishes placing the floor cover.</span>")
			if (ishuman(user))
				var/mob/living/human/H = user
				H.adaptStat("crafting", 3)
		return

/obj/item/weapon/covers/ship/attack_self(mob/user)
	var/covers_time = 80
	if (ishuman(user))
		var/turf/targetfloor = get_turf(get_step(user, user.dir))
		if (istype(targetfloor, /turf/wall))
			visible_message("<span class='notice'>You can't build here!</span>")
			return
		var/mob/living/human/H = user
		covers_time /= H.getStatCoeff("strength")
		covers_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))
	if (WWinput(user, "This will start building a new ship floor [dir2text(user.dir)] of you.", "Ship Floor Repair", "Continue", list("Continue", "Stop")) == "Continue")
		visible_message("<span class='danger'>[user] starts constructing the new floor.</span>", "<span class='danger'>You start constructing the new floor.</span>")
		if (do_after(user, covers_time, user.loc) && src)
			qdel(src)
			new/obj/covers/repairedfloor/ship(get_step(user, user.dir), user)
			visible_message("<span class='danger'>[user] finishes placing the new floor.</span>")
			if (ishuman(user))
				var/mob/living/human/H = user
				H.adaptStat("crafting", 3)
		return

/obj/covers/fire_act(temperature)
	if (prob(20) && flammable == TRUE)
		visible_message("<span class = 'warning'>[src] is burned away.</span>")
		qdel(src)

/obj/covers/CanPass(var/atom/movable/mover)
	if (istype(mover, /obj/effect/effect/smoke))
		return TRUE
	else if (istype(mover, /obj/item/projectile))
		if (istype(mover,/obj/item/projectile/shell))
			var/obj/item/projectile/shell/S = mover
			if(prob(18) && S.atype == "cannonball")
				visible_message("<span class = 'warning'>\The [mover.name] hits \the [src]!</span>")
				return FALSE
		if (prob(75) && density)
			visible_message("<span class = 'warning'>\The [mover.name] hits \the [src]!</span>")
			return FALSE
		else
			return TRUE
	else
		return ..()

/obj/covers/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/wrench) && not_movable == TRUE)
		return
	if (istype(W, /obj/item/weapon/hammer))
		if (!wall)
			user << "You start removing \the [src]..."
			if (do_after(user, 50, src))
				user << "You removed \the [src] from the floor."
				qdel(src)
				return
	if (wall)
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		if (istype(W, /obj/item/weapon/poster/religious))
			user << "You start placing the [W] on the [src]..."
			if (do_after(user, 70, src))
				visible_message("[user] places the [W] on the [src].")
				var/obj/structure/poster/religious/RP = new/obj/structure/poster/religious(get_turf(src))
				var/obj/item/weapon/poster/religious/P = W
				RP.religion = P.religion
				RP.symbol = P.symbol
				RP.color1 = P.color1
				RP.color2 = P.color2
				user.drop_from_inventory(W)
				qdel(W)
				return
		if (istype(W, /obj/item/weapon/poster/faction))
			user << "You start placing the [W] on the [src]..."
			if (do_after(user, 70, src))
				visible_message("[user] places the [W] on the [src].")
				var/obj/structure/poster/faction/RP = new/obj/structure/poster/faction(get_turf(src))
				var/obj/item/weapon/poster/faction/P = W
				RP.faction = P.faction
				RP.bstyle = P.bstyle
				RP.color1 = P.color1
				RP.color2 = P.color2
				user.drop_from_inventory(W)
				qdel(W)
				return
		if (istype(W, /obj/item/flashlight/torch) && wood == TRUE)
			var/obj/item/flashlight/torch/T = W
			if (prob(33) && T.on)
				onfire = TRUE
				visible_message("<span class='danger'>\The [src] catches fire!</span>")
				start_fire()
				message_admins("[user.name] ([user.ckey]) started a fire with a torch at [src.name] ([src.x],[src.y],[src.z]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[user.x];Y=[user.y];Z=[user.z]'>JMP</a>)")
				log_game("[user.name] ([user.ckey]) started a fire with a torch at [src.name] ([src.x],[src.y],[src.z])")
		if (istype(W, /obj/item/stack))
			var/obj/item/stack/S = W
			if (S.amount <= 0)
				qdel(S)
			else
				repair(S, user)
				playsound(get_turf(src), 'sound/weapons/smash.ogg', 100)
				user.do_attack_animation(src)
				return
		else
			switch(W.damtype)
				if ("fire")
					health -= W.force * 0.7
				if ("brute")
					health -= W.force * 0.2

		playsound(get_turf(src), 'sound/weapons/smash.ogg', 100)
		user.do_attack_animation(src)
		try_destroy()
		..()
	else
		return

/obj/covers/proc/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>\The [src] is broken into pieces!</span>")
		if (material == "Wood")
			new /obj/item/stack/material/wood(get_turf(usr))
		qdel(src)
		return

/obj/covers/bullet_act(var/obj/item/projectile/proj)
	if (istype(proj, /obj/item/projectile/arrow/arrow/fire) && wood == TRUE)
		health -= proj.damage * 0.25
		if (prob(25))
			onfire = TRUE
			visible_message("<span class='danger'>\The [src] catches fire!</span>")
			start_fire()
		try_destroy()
	else
		if (istype(proj, /obj/item/projectile/shell))
			var/obj/item/projectile/shell/S = proj
			if (S.atype == "HE" || S.atype == "cannonball")
				visible_message("<span class='danger'>\The [src] is broken into pieces!</span>")
				qdel(src)
				return
			else
				if (prob(60))
					visible_message("<span class='danger'>\The [src] is broken into pieces!</span>")
					qdel(src)
		else
			if (wall)
				if (istype(proj, /obj/item/projectile/bullet) && bullethole_count.len < 13)
					new_bullethole()
				health -= proj.damage * 0.1
				try_destroy()
		return

/obj/covers/proc/start_fire()
	if (onfire && wood)
		var/obj/effect/fire/NF = new/obj/effect/fire(src.loc)
		start_fire_dmg(NF)

/obj/covers/proc/start_fire_dmg(var/obj/effect/fire/SF)
	spawn(80)
		if (!SF)
			return
		if (health > 0)
			health -= 10
			start_fire_dmg(SF)
			return
		else
			try_destroy()
			qdel(SF)
			return
