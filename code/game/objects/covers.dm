/obj/covers

	name = "floor covers"
	desc = "A floor cover."
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood_ship"
	var/passable = TRUE
	var/origin_covered = FALSE
	var/origin_water_level = 0
	var/not_movable = FALSE //if it can be removed by wrenches
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
	flammable = TRUE
	var/current_area_type = /area/caribbean
	var/incomplete = FALSE
	explosion_resistance = TRUE
//	invisibility = 101 //starts invisible


/obj/covers/wood
	name = "wood floor"
	icon = 'icons/turf/flooring/wood.dmi'
	icon_state = "wood"
	passable = TRUE
	amount = 1
	layer = 1.99

/obj/covers/wood/stairs
	name = "wood stairs"
	icon = 'icons/obj/stairs.dmi'
	icon_state = "wood2_stairs"

/obj/covers/cobblestone
	name = "cobblestone floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "cobble_vertical_dark"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 2

/obj/covers/cobblestone/stairs
	name = "stone stairs"
	icon = 'icons/obj/stairs.dmi'
	icon_state = "rampup"


/obj/covers/sandstone
	name = "sandstone floor"
	icon = 'icons/turf/floors.dmi'
	icon_state = "sandstone_floor"
	passable = TRUE
	not_movable = TRUE
	amount = 0
	wood = FALSE
	layer = 1.99
	flammable = FALSE
	explosion_resistance = 2

/obj/covers/wood_ship
	name = "wood floor"
	icon_state = "wood_ship"
	passable = TRUE
	not_movable = TRUE
	amount = 1
	layer = 1.99

/obj/covers/saloon_door
	name = "saloon door"
	desc = "A wood door."
	icon = 'icons/obj/doors/material_doors.dmi'
	icon_state = "saloon"
	passable = TRUE
	not_movable = TRUE
	density = FALSE
	opacity = FALSE
	amount = 2
	layer = 3
	health = 90
	wall = FALSE
	explosion_resistance = 3


/obj/covers/saloon_door/Crossed(mob/living/carbon/M as mob )
	visible_message("[M] pushes \the [src].","You push \the [src]")
	icon_state = "saloon_opening"
	update_icon()
	spawn(20)
		icon_state = "saloon"
		update_icon()

/obj/covers/wood_wall
	name = "soft wood wall"
	desc = "A wood wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "b_wood_wall"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 4
	layer = 3
	health = 150
	wall = TRUE
	explosion_resistance = 5

/obj/covers/stone_wall
	name = "stone wall"
	desc = "A stone wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "b_stone_wall"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 300
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 10

/obj/covers/dirt_wall
	name = "dirt wall"
	desc = "A dirt wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "drydirt_wall"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 90
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 3

/obj/covers/straw_wall
	name = "straw wall"
	desc = "A straw wall. Looks flimsy."
	icon = 'icons/turf/walls.dmi'
	icon_state = "straw_wallh"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 1
	layer = 3
	health = 75
	wood = TRUE
	wall = TRUE
	explosion_resistance = 2

/obj/covers/dirt_wall/blocks
	name = "dirt blocks wall"
	desc = "A dirt blocks wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "drysod_wall"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 110
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 4

/obj/covers/dirt_wall/blocks/incomplete
	name = "dirt blocks wall"
	desc = "A dirt blocks wall."
	icon = 'icons/turf/walls.dmi'
	icon_state = "drysod_wall_inc1"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = FALSE
	incomplete = TRUE
	amount = 0
	layer = 3
	health = 30
	var/stage = 1
	wood = FALSE
	wall = TRUE
	flammable = FALSE

/obj/covers/dirt_wall/blocks/incomplete/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/sandbag))
		if (stage == 3)
			user << "You start adding dirt to the wall..."
			if (do_after(user, 20, src))
				user << "You finish adding dirt to the wall, completing it."
				qdel(W)
				new /obj/covers/dirt_wall/blocks(loc)
				qdel(src)
				return
		else if (stage <= 2)
			user << "You start adding dirt to the wall..."
			if (do_after(user, 20, src))
				user << "You finish adding dirt to the wall."
				stage = (stage+1)
				icon_state = "drysod_wall_inc[stage]"
				health = (20*stage)
				qdel(W)
				return
	..()


/obj/covers/clay_wall
	name = "clay block wall"
	desc = "A clay block wall."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "claybrickwall"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 150
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 6

/obj/covers/clay_wall/incomplete
	name = "clay block wall"
	desc = "A clay block wall."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "claybrickwall_inc1"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = FALSE
	incomplete = TRUE
	amount = 0
	layer = 3
	health = 40
	var/stage = 1
	wood = FALSE
	wall = TRUE
	flammable = FALSE

/obj/covers/clay_wall/incomplete/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/clay/claybricks/fired))
		if (stage >= 2)
			user << "You start adding clay blocks to the wall..."
			if (do_after(user, 20, src))
				user << "You finish adding clay blocks to the wall, completing it."
				qdel(W)
				new /obj/covers/clay_wall(loc)
				qdel(src)
				return
		else if (stage <= 1)
			user << "You start adding clay blocks to the wall..."
			if (do_after(user, 20, src))
				user << "You finish clay block to the wall."
				stage += 1
				icon_state = "claybrickwall_inc[stage]"
				health = (30*stage)
				qdel(W)
				return
	..()


/obj/covers/brick_wall
	name = "brick wall"
	desc = "A clay brick wall."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "brickwall"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = TRUE
	amount = 0
	layer = 3
	health = 190
	wood = FALSE
	wall = TRUE
	flammable = FALSE
	explosion_resistance = 6

/obj/covers/brick_wall/incomplete
	name = "brick wall"
	desc = "A clay brick wall."
	icon = 'icons/obj/claystuff.dmi'
	icon_state = "brickwall_inc1"
	passable = TRUE
	not_movable = TRUE
	density = TRUE
	opacity = FALSE
	incomplete = TRUE
	amount = 0
	layer = 3
	health = 80
	var/stage = 1
	wood = FALSE
	wall = TRUE
	flammable = FALSE

/obj/covers/brick_wall/incomplete/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/clay/advclaybricks/fired))
		user << "You start adding bricks to the wall..."
		if (do_after(user, 20, src))
			user << "You finish adding bricks to the wall, completing it."
			qdel(W)
			new /obj/covers/brick_wall(loc)
			qdel(src)
			return
			return
	..()



/obj/covers/New()
	..()
	if (wall && !incomplete)
		var/area/caribbean/CURRENTAREA = get_area(src)
		if (CURRENTAREA.location == AREA_OUTSIDE)
			current_area_type = CURRENTAREA.type
			new/obj/roof(get_turf(src))

	spawn(5)
		updateturf()
	return TRUE


/obj/covers/updateturf()
	..()
	var/turf/T = get_turf(src)
	origin_water_level = T.water_level
	T.water_level = 0
	T.move_delay = 0
	origin_covered = T.iscovered
	T.iscovered = TRUE
	return TRUE


/obj/covers/Destroy()
	if (wall && !incomplete)
		new current_area_type(get_turf(src))
		visible_message("The roof collapses!")
	var/turf/floor/T = get_turf(loc)
	T.iscovered = origin_covered
	T.water_level = origin_water_level
	T.move_delay = T.get_move_delay()
	if (amount > 0)
		var/obj/item/stack/material/wood/wooddrop = new /obj/item/stack/material/wood
		wooddrop.amount = amount
	if (wall == TRUE)
		for(var/obj/roof/R in range(2,src))
			R.collapse_check()
	..()
	return TRUE

// the item you can use to repair a hole
/obj/item/weapon/covers
	name = "floor cover"
	desc = "Use this to cover holes."
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood_ship_repaired2"
	w_class = 2.0
	flammable = TRUE
	value = 0
/obj/covers/repairedfloor
	name = "repaired floor"
	desc = "a repaired wood floor."
	icon = 'icons/turf/floors.dmi'
	icon_state = "wood_ship_repaired"
	layer = 1.98
	flammable = TRUE
	explosion_resistance = FALSE

/obj/item/weapon/covers/attack_self(mob/user)
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
	if (WWinput(user, "This will start building a floor cover [your_dir] of you.", "Floor Cover Construction", "Continue", list("Continue", "Stop")) == "Continue")
		visible_message("<span class='danger'>[user] starts constructing the floor cover.</span>", "<span class='danger'>You start constructing the floor cover.</span>")
		if (do_after(user, covers_time, user.loc) && src)
			qdel(src)
			new/obj/covers/repairedfloor(get_step(user, user.dir), user)
			visible_message("<span class='danger'>[user] finishes placing the floor cover.</span>")
			if (ishuman(user))
				var/mob/living/carbon/human/H = user
				H.adaptStat("crafting", 3)
		return


/obj/covers/fire_act(temperature)
	if (prob(35 * (temperature/500)) && wood == TRUE)
		visible_message("<span class = 'warning'>[src] is burned away.</span>")
		qdel(src)



/obj/covers/CanPass(var/atom/movable/mover)
	if (istype(mover, /obj/effect/effect/smoke))
		return TRUE
	else if (istype(mover, /obj/item/projectile))
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
			if (do_after(user, 70, src))
				user << "You removed \the [src] from the floor."
				qdel(src)
				return
	if (wall)
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)

		if (istype(W, /obj/item/flashlight/torch) && wood == TRUE)
			var/obj/item/flashlight/torch/T = W
			if (prob(33) && T.on)
				onfire = TRUE
				visible_message("<span class='danger'>\The [src] catches fire!</span>")
				start_fire()
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
		health -= proj.damage * 0.1
		try_destroy()
		return

/obj/covers/proc/start_fire()
	if (onfire && wood)
		var/obj/small_fire/NF = new/obj/small_fire(src.loc)
		NF.set_light(3)
		NF.origin = src
		start_fire_dmg(NF)
		spawn(400)
			NF.icon_state = "fire_big"
			NF.set_light(4)
/obj/covers/proc/start_fire_dmg(var/obj/small_fire/SF)
	spawn(80)
		if (health > 0)
			health -= 10
			start_fire_dmg()
			return
		else
			try_destroy()
			qdel(SF)
			return
