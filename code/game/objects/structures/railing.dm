/obj/structure/railing
	name = "railing"
	desc = "An ordinary steel railing. Prevents from human stupidity."
	icon = 'icons/obj/railing.dmi'
	density = TRUE
	throwpass = TRUE
	climbable = TRUE
	layer = 3.2//Just above doors
	//pressure_resistance = 4*ONE_ATMOSPHERE
	anchored = TRUE
	flags = ON_BORDER
	icon_state = "railing0"
	var/broken = FALSE
	var/health=70
	var/maxhealth=70
	//var/LeftSide = list(0,0,0)// Нужны для хранения данных
	//var/RightSide = list(0,0,0)
	var/check = FALSE

/obj/structure/railing/New(loc, constructed=0)
	..()
	if (constructed)	//player-constructed railings
		anchored = FALSE
/*	if (climbable)
		verbs += /obj/structure/proc/climb_on*/
	if (anchored)
		spawn(5)
			update_icon(0)

/obj/structure/railing/Destroy()
	anchored = null
	flags = null
	broken = TRUE
	for (var/obj/structure/railing/R in oview(src, TRUE))
		R.update_icon()
	..()

/obj/structure/railing/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (!mover)
		return TRUE

	if (istype(mover) && mover.checkpass(PASSTABLE))
		return TRUE
	if (get_dir(loc, target) == dir)
		return !density
	else
		return TRUE
//32 и 4 - в той же клетке

/obj/structure/railing/examine(mob/user)
	. = ..()
	if (health < maxhealth)
		switch(health / maxhealth)
			if (0.0 to 0.5)
				user << "<span class='warning'>It looks severely damaged!</span>"
			if (0.25 to 0.5)
				user << "<span class='warning'>It looks damaged!</span>"
			if (0.5 to 1.0)
				user << "<span class='notice'>It has a few scrapes and dents.</span>"

/obj/structure/railing/proc/take_damage(amount)
	health -= amount
	if (health <= 0)
		visible_message("<span class='warning'>\The [src] breaks down!</span>")
		playsound(loc, 'sound/effects/grillehit.ogg', 50, TRUE)
		new /obj/item/stack/rods(get_turf(usr))
		qdel(src)

/obj/structure/railing/proc/NeighborsCheck(var/UpdateNeighbors = TRUE)
	check = FALSE
	//if (!anchored) return
	var/Rturn = turn(dir, -90)
	var/Lturn = turn(dir, 90)

	for (var/obj/structure/railing/R in loc)// Анализ клетки, где находится сам объект
		if ((R.dir == Lturn) && R.anchored)//Проверка левой стороны
			//LeftSide[1] = TRUE
			check |= 32
			if (UpdateNeighbors)
				R.update_icon(0)
		if ((R.dir == Rturn) && R.anchored)//Проверка правой стороны
			//RightSide[1] = TRUE
			check |= 2
			if (UpdateNeighbors)
				R.update_icon(0)

	for (var/obj/structure/railing/R in get_step(src, Lturn))//Анализ левой клетки от направления объекта
		if ((R.dir == dir) && R.anchored)
			//LeftSide[2] = TRUE
			check |= 16
			if (UpdateNeighbors)
				R.update_icon(0)
	for (var/obj/structure/railing/R in get_step(src, Rturn))//Анализ правой клетки от направления объекта
		if ((R.dir == dir) && R.anchored)
			//RightSide[2] = TRUE
			check |= TRUE
			if (UpdateNeighbors)
				R.update_icon(0)

	for (var/obj/structure/railing/R in get_step(src, (Lturn + dir)))//Анализ передней-левой диагонали относительно направления объекта.
		if ((R.dir == Rturn) && R.anchored)
			check |= 64
			if (UpdateNeighbors)
				R.update_icon(0)
	for (var/obj/structure/railing/R in get_step(src, (Rturn + dir)))//Анализ передней-правой диагонали относительно направления объекта.
		if ((R.dir == Lturn) && R.anchored)
			check |= 4
			if (UpdateNeighbors)
				R.update_icon(0)


/*	for (var/obj/structure/railing/R in get_step(src, dir))
		if ((R.dir == Lturn) && R.anchored)//Проверка левой стороны
			LeftSide[3] = TRUE
		if ((R.dir == Rturn) && R.anchored)//Проверка правой стороны
			RightSide[3] = TRUE*/
	//check <<"check: [check]"
	//world << "dir = [dir]"
	//world << "railing[LeftSide[1]][LeftSide[2]][LeftSide[3]]-[RightSide[1]][RightSide[2]][RightSide[3]]"

/obj/structure/railing/update_icon(var/UpdateNeighgors = TRUE)
	NeighborsCheck(UpdateNeighgors)
	//icon_state = "railing[LeftSide[1]][LeftSide[2]][LeftSide[3]]-[RightSide[1]][RightSide[2]][RightSide[3]]"
	overlays.Cut()
	if (!check || !anchored)//|| !anchored
		icon_state = "railing0"
	else
		icon_state = "railing1"
		//левая сторона
		if (check & 32)
			overlays += image ('icons/obj/railing.dmi', src, "corneroverlay")
			//world << "32 check"
		if ((check & 16) || !(check & 32) || (check & 64))
			overlays += image ('icons/obj/railing.dmi', src, "frontoverlay_l")
			//world << "16 check"
		if (!(check & 2) || (check & TRUE) || (check & 4))
			overlays += image ('icons/obj/railing.dmi', src, "frontoverlay_r")
			//world << "no 4 or 2 check"
			if (check & 4)
				switch (dir)
					if (NORTH)
						overlays += image ('icons/obj/railing.dmi', src, "mcorneroverlay", pixel_x = 32)
					if (SOUTH)
						overlays += image ('icons/obj/railing.dmi', src, "mcorneroverlay", pixel_x = -32)
					if (EAST)
						overlays += image ('icons/obj/railing.dmi', src, "mcorneroverlay", pixel_y = -32)
					if (WEST)
						overlays += image ('icons/obj/railing.dmi', src, "mcorneroverlay", pixel_y = 32)


//obj/structure/railing/proc/NeighborsCheck2()


/obj/structure/railing/CheckExit(atom/movable/O as mob|obj, target as turf)
	if (istype(O) && O.checkpass(PASSTABLE))
		return TRUE
	if (get_dir(O.loc, target) == dir)
		return FALSE
	return TRUE

/obj/structure/railing/attackby(obj/item/W as obj, mob/user as mob)
	// Dismantle
	if (istype(W, /obj/item/weapon/wrench) && !anchored)
		playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
		if (do_after(user, 20, src))
			user.visible_message("<span class='notice'>\The [user] dismantles \the [src].</span>", "<span class='notice'>You dismantle \the [src].</span>")
			new /obj/item/stack/material/steel(get_turf(usr))
			new /obj/item/stack/material/steel(get_turf(usr))
			qdel(src)
			return

	// Repair
	if (health < maxhealth && istype(W, /obj/item/weapon/weldingtool))
		var/obj/item/weapon/weldingtool/F = W
		if (F.welding)
			playsound(loc, 'sound/items/Welder.ogg', 50, TRUE)
			if (do_after(user, 20, src))
				user.visible_message("<span class='notice'>\The [user] repairs some damage to \the [src].</span>", "<span class='notice'>You repair some damage to \the [src].</span>")
				health = min(health+(maxhealth/5), maxhealth)//max(health+(maxhealth/5), maxhealth) // 20% repair per application
				return

	// Install
	if (istype(W, /obj/item/weapon/screwdriver))
		user.visible_message(anchored ? "<span class='notice'>\The [user] begins unscrew \the [src].</span>" : "<span class='notice'>\The [user] begins fasten \the [src].</span>" )
		playsound(loc, 'sound/items/Screwdriver.ogg', 75, TRUE)
		if (do_after(user, 10, src))
			user << (anchored ? "<span class='notice'>You have unfastened \the [src] from the floor.</span>" : "<span class='notice'>You have fastened \the [src] to the floor.</span>")
			anchored = !anchored
			update_icon()
			return

	// Handle harm intent grabbing/tabling.
	if (istype(W, /obj/item/weapon/grab) && get_dist(src,user)<2)
		var/obj/item/weapon/grab/G = W
		if (istype(G.affecting, /mob/living))
			var/mob/living/M = G.affecting
			var/obj/occupied = turf_is_crowded()
			if (occupied)
				user << "<span class='danger'>There's \a [occupied] in the way.</span>"
				return
			if (G.state < 2)
				if (user.a_intent == I_HURT)
					if (prob(15))	M.Weaken(5)
					M.apply_damage(8,def_zone = "head")
					take_damage(8)
					visible_message("<span class='danger'>[G.assailant] slams [G.affecting]'s face against \the [src]!</span>")
					playsound(loc, 'sound/effects/grillehit.ogg', 50, TRUE)
				else
					user << "<span class='danger'>You need a better grip to do that!</span>"
					return
			else
				if (get_turf(G.affecting) == get_turf(src))
					G.affecting.forceMove(get_step(src, dir))
				else
					G.affecting.forceMove(get_turf(src))
				G.affecting.Weaken(5)
				visible_message("<span class='danger'>[G.assailant] throws [G.affecting] over \the [src]!</span>")
			qdel(W)
			return

	else
		playsound(loc, 'sound/effects/grillehit.ogg', 50, TRUE)
		take_damage(W.force)

	return ..()

/obj/structure/railing/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			qdel(src)
			return
		if (3.0)
			qdel(src)
			return
		else
	return

/obj/structure/railing/do_climb(var/mob/living/user)
	if (!can_climb(user))
		return
	if (map.check_prishtina_block(user, get_turf(src)))
		return

	usr.visible_message("<span class='warning'>[user] starts climbing onto \the [src]!</span>")
	climbers |= user

	if (!do_after(user,(issmall(user) ? 20 : 34), src))
		climbers -= user
		return

	if (!can_climb(user, post_climb_check=1))
		climbers -= user
		return

	if (!neighbor_turf_passable())
		user << "<span class='danger'>You can't climb there, the way is blocked.</span>"
		climbers -= user
		return

	if (get_turf(user) == get_turf(src))
		usr.forceMove(get_step(src, dir))
	else
		usr.forceMove(get_turf(src))

	usr.visible_message("<span class='warning'>[user] climbed over \the [src]!</span>")
	if (!anchored)	take_damage(maxhealth) // Fatboy
	climbers -= user