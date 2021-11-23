/obj/structure/window/barrier/ship
	name = "wall"
	desc = "A thin wood ship wall."
	icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'

/obj/structure/barricade/ship
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
	icon_state = "boat1"
	material_name = "wood"
	protection_chance = 60
	var/ispartial = FALSE
	opacity = TRUE
	dir = NORTH
	New()
		..()
		spawn(10)
			if (dir == NORTH && ispartial)
				layer = 4.5
				update_icon()

/obj/structure/barricade/ship/dismantle()
	new/obj/effect/decal/cleanable/debris(loc)
	if(prob(50))
		var/x1 = src.x+pick(-1,1)
		var/y1 = src.y+pick(-1,1)
		new/obj/effect/decal/cleanable/debris(locate(x1,y1,src.z))
	..()
	return
/obj/effect/decal/cleanable/debris
	name = "ship debris"
	desc = "Bits and pieces blown off a ship."
	density = FALSE
	anchored = TRUE
	icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
	icon_state = "debris0"

	New()
		..()
		icon_state = pick("debris0","debris1","debris2","debris3")
		dir = pick(NORTH,SOUTH,EAST,WEST)

//copied from sandbags
/obj/structure/barricade/ship/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)

	if (!ispartial)
		return ..()

	for (var/obj/covers/repairedfloor/rope/R in loc)
		return TRUE

	if (istype(mover, /obj/effect/effect/smoke))
		return TRUE

	else if (!istype(mover, /obj/item))
		if (get_dir(loc, target) & dir)
			return FALSE
		else
			return TRUE
	else
		if (istype(mover, /obj/item/projectile))
			var/obj/item/projectile/proj = mover
			proj.throw_source = proj.starting

			if (ishuman(proj.firer) && (proj.firer.lying || proj.firer.prone))
				visible_message("<span class = 'warning'>[mover] hits the [src]!</span>")
				if (istype(mover, /obj/item/projectile))
					var/obj/item/projectile/B = mover
					if (B.atype == "chainshot")
						if (ispartial)
							return TRUE
						else
							return FALSE
					else if (B.atype == "grapeshot")
						if (ispartial)
							return TRUE
						else
							return FALSE
					else
						if (ispartial)
							if (prob(70))
								return TRUE
						return prob(100-protection_chance-(B.penetrating*4))
				return FALSE
		if (!mover.throw_source)
			if (get_dir(loc, target) & dir)
				return FALSE
			else
				return TRUE
		else
			switch (get_dir(mover.throw_source, get_turf(src)))
				if (NORTH, NORTHEAST)
					if (dir == EAST || dir == WEST || dir == NORTH)
						return TRUE
				if (SOUTH, SOUTHEAST)
					if (dir == EAST || dir == WEST || dir == SOUTH)
						return TRUE
				if (EAST)
					if (dir != WEST)
						return TRUE
				if (WEST)
					if (dir != EAST)
						return TRUE

			if (check_cover(mover, mover.throw_source) && prob(bullet_deflection_chance(mover)))
				visible_message("<span class = 'warning'>[mover] hits the [src]!</span>")
				if (istype(mover, /obj/item/projectile))
					var/obj/item/projectile/B = mover
					B.damage = 0 // make sure we can't hurt people after hitting a sandbag
					B.invisibility = 101
					B.loc = null
					qdel(B) // because somehow we were still passing the sandbag
				return FALSE
			else
				return TRUE

/obj/structure/barricade/ship/proc/check_cover(obj/item/projectile/P, turf/from)
	var/turf/cover = get_turf(src)
	if (!cover)
		return FALSE
	if (!istype(P, /obj/item/projectile))
		return FALSE
	if (get_dist(P.starting, loc) <= 1) //Tables won't help you if people are THIS close
		return FALSE
	// can't hit legs or feet when they're behind a sandbag
	if (list("r_leg", "l_leg", "r_foot", "l_foot").Find(P.def_zone))
		return TRUE

	var/base_chance = 40
	var/extra_chance = 0

	if (ismob(P.original)) // what the firer clicked
		var/mob/m = P.original
		if (m.lying || m.prone)
			extra_chance += 60
		if (ishuman(m))
			var/mob/living/human/H = m
			if (H.crouching && !H.lying)
				extra_chance += 20

	var/chance = base_chance + extra_chance

	chance = min(chance, 98)

	if (prob(chance))
		return TRUE
	else
		return FALSE

/obj/structure/barricade/ship/New(var/newloc, var/material_name)
	return
/obj/structure/barricade/ship/get_material()
	return material

/obj/structure/barricade/ship/north
	icon_state = "boat1_up"

/obj/structure/barricade/ship/north/corners
	icon_state = "boat1_up_corners"


/obj/structure/barricade/ship/wall1
	name = "wall"
	desc = "A wooden ship wall."
	icon_state = "boat1_a"
	opacity = FALSE
/obj/structure/barricade/ship/wall2
	name = "wall"
	desc = "A wooden ship wall."
	icon_state = "boat2"

/obj/structure/barricade/ship/wall2/doorway
	name = "doorway"
	desc = "A wooden ship doorway."
	icon_state = "boat2_doorway"
	density = FALSE
	opacity = FALSE


/obj/structure/barricade/ship/blue
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b1"

/obj/structure/barricade/ship/blue/b1
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b1"
	opacity = TRUE
/obj/structure/barricade/ship/blue/b2
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b2"
	opacity = TRUE
/obj/structure/barricade/ship/blue/b3
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b3"
	opacity = TRUE
/obj/structure/barricade/ship/blue/b4
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b4"
/obj/structure/barricade/ship/blue/b5
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b5"
	opacity = TRUE
/obj/structure/barricade/ship/blue/b6
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b6"
	opacity = TRUE
/obj/structure/barricade/ship/blue/b7
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b7"
	opacity = TRUE
/obj/structure/barricade/ship/blue/b8
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b8"
	opacity = TRUE
/obj/structure/barricade/ship/blue/b9
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b9"
	opacity = TRUE
/obj/structure/barricade/ship/blue/b10
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b10"
	opacity = TRUE
/obj/structure/barricade/ship/blue/b11
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b11"
	opacity = TRUE
/obj/structure/barricade/ship/blue/b12
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b12"
	opacity = TRUE
/obj/structure/barricade/ship/blue/b13
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b13"
	opacity = TRUE
/obj/structure/barricade/ship/blue/b14
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b14"
	opacity = TRUE
/obj/structure/barricade/ship/blue/b15
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b15"
	opacity = TRUE
/obj/structure/barricade/ship/blue/b16
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b16"
	opacity = TRUE
/obj/structure/barricade/ship/blue/b17
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b17"
/obj/structure/barricade/ship/blue/b18
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b18"
	opacity = TRUE
/obj/structure/barricade/ship/blue/b19
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b19"

/obj/structure/barricade/ship/blue/b20
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b20"
	opacity = TRUE

/obj/structure/window/barrier/ship/blue/bport0
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_port0"
	opacity = FALSE

/obj/structure/window/barrier/ship/blue/bport0/south/New()
	..()
	dir = SOUTH

/obj/structure/window/barrier/ship/blue/bport9
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_port9"
	opacity = FALSE

/obj/structure/window/barrier/ship/blue/bport5
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_port5"
	opacity = FALSE

/obj/structure/window/barrier/ship/blue/bport5
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_port5"
	opacity = FALSE

/obj/structure/window/barrier/ship/blue/bport_north
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_port_1"
	opacity = FALSE

/obj/structure/window/barrier/ship/blue/bport_10
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_port_10"
	opacity = FALSE

/obj/structure/window/barrier/ship/blue/bport_6
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_port_6"
	opacity = FALSE

/obj/structure/window/barrier/ship/blue/bport_6/corner
	icon_state = "boat_b_port_6-2"
/obj/structure/window/barrier/ship/blue/bport_10/corner
	icon_state = "boat_b_port_10-2"
/obj/structure/window/barrier/ship/blue/bport5/corner
	icon_state = "boat_b_port5-2"
/obj/structure/window/barrier/ship/blue/bport9/corner
	icon_state = "boat_b_port9-2"

/obj/structure/window/barrier/ship/blue/bport1
	name = "holed wall"
	desc = "A thin wood ship wall, with a lower part to fire through."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_port1"
	opacity = FALSE

/obj/structure/window/barrier/ship/blue/bport3
	name = "crenelated wall"
	desc = "A thin wood ship wall, with a lower part to fire through."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_port3"
	opacity = FALSE
	density = FALSE
/obj/structure/window/barrier/ship/blue/bport3/south/New()
	..()
	dir = SOUTH

/obj/structure/barricade/ship/blue/bwest
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_west"
	opacity = FALSE
	dir = NORTH

/obj/structure/barricade/ship/blue/bwest2
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_west2"
	opacity = FALSE

/obj/structure/barricade/ship/blue/beast
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_east"
	opacity = FALSE

/obj/structure/barricade/ship/blue/beast2
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_east2"
	opacity = FALSE

/obj/structure/barricade/ship/wood
	name = "wall"
	desc = "A wooden ship wall."
	icon_state = "boat_a1"
	opacity = TRUE


/obj/structure/barricade/ship/wood/a1
	name = "wall"
	desc = "A wooden ship wall."
	icon_state = "boat_a1"
/obj/structure/barricade/ship/wood/a2
	name = "wall"
	desc = "A wooden ship wall."
	icon_state = "boat_a2"
/obj/structure/barricade/ship/wood/a3
	name = "wall"
	desc = "A wooden ship wall."
	icon_state = "boat_a3"
/obj/structure/barricade/ship/wood/a4
	name = "wall"
	desc = "A wooden ship wall."
	icon_state = "boat_a4"
/obj/structure/barricade/ship/wood/a5
	name = "wall"
	desc = "A wooden ship wall."
	icon_state = "boat_a5"
/obj/structure/barricade/ship/wood/a6
	name = "wall"
	desc = "A wooden ship wall."
	icon_state = "boat_a6"
/obj/structure/barricade/ship/wood/a7
	name = "wall"
	desc = "A wooden ship wall."
	icon_state = "boat_a7"
/obj/structure/barricade/ship/wood/a8
	name = "wall"
	desc = "A wooden ship wall."
	icon_state = "boat_a8"
/obj/structure/barricade/ship/wood/a9
	name = "wall"
	desc = "A wooden ship wall."
	icon_state = "boat_a9"
/obj/structure/barricade/ship/wood/a10
	name = "wall"
	desc = "A wooden ship wall."
	icon_state = "boat_a10"
/obj/structure/barricade/ship/wood/a11
	name = "wall"
	desc = "A wooden ship wall."
	icon_state = "boat_a11"
/obj/structure/barricade/ship/wood/a12
	name = "wall"
	desc = "A wooden ship wall."
	icon_state = "boat_a12"

/obj/structure/barricade/ship/wood/a12
	name = "wall"
	desc = "A wooden ship wall."
	icon_state = "boat_a12"

/obj/structure/window/barrier/ship/wood/port0
	name = "wall"
	desc = "A thin wood ship wall."
	icon_state = "boat_port0"
	opacity = FALSE
	dir = NORTH

/obj/structure/window/barrier/ship/wood/port0/north/New()
	..()
	dir = NORTH
/obj/structure/window/barrier/ship/wood/port0/south/New()
	..()
	dir = SOUTH

/obj/structure/window/barrier/ship/wood/portl1
	name = "wall"
	desc = "A thin wood ship wall."
	icon_state = "boat_portl1"
	opacity = FALSE
	dir = EAST

/obj/structure/window/barrier/ship/wood/portl2
	name = "wall"
	desc = "A thin wood ship wall."
	icon_state = "boat_portl2"
	opacity = FALSE
	dir = WEST

/obj/structure/window/barrier/ship/wood/portl3
	name = "wall"
	desc = "A thin wood ship wall."
	icon_state = "boat_portl3"
	opacity = FALSE

/obj/structure/window/barrier/ship/wood/port1
	name = "holed wall"
	desc = "A thin wood ship wall, with a hole to fire through."
	icon_state = "boat_port1"
	opacity = FALSE
	dir = NORTH

/obj/structure/window/barrier/ship/wood/port2
	name = "crenelated wall"
	desc = "A thin wood ship wall, with a lower part to fire through."
	icon_state = "boat_port2"
	density = FALSE
	opacity = FALSE
	dir = NORTH
/obj/structure/window/barrier/ship/wood/port2/north/New()
	..()
	dir = NORTH
/obj/structure/window/barrier/ship/wood/port2/south/New()
	..()
	dir = SOUTH


/obj/structure/barricade/ship/aport0
	name = "closed cannon port"
	desc = "A port used to fire cannons out of. This one is closed."
	icon_state = "boat1_port0"
	opacity = TRUE
	protection_chance = 100
	ispartial = FALSE
	var/open = FALSE
	density = TRUE
	dir = NORTH

	attack_hand(mob/living/human/H)
		..()
		if (open)
			if (do_after(H, 35, src))
				H << "You close the port."
				open = FALSE
				opacity = TRUE
				protection_chance = 100
				ispartial = FALSE
				update_icon()

		else
			if (do_after(H, 35, src))
				H << "You open the port."
				open = TRUE
				opacity = FALSE
				protection_chance = 60
				ispartial = TRUE
				update_icon()
	update_icon()
		if (open)
			icon_state = "boat1_port1"
		else
			icon_state = "boat1_port0"
	verb/open_close()
		set name = "Open/Close"
		set category = null
		set src in range(1, usr)

		if (!istype(usr, /mob/living/human))
			return
		if (open)
			if (do_after(usr, 35, src))
				usr << "You close the port."
				open = FALSE
				opacity = TRUE
				protection_chance = 100
				ispartial = FALSE
				update_icon()

		else
			if (do_after(usr, 35, src))
				usr << "You open the port."
				open = TRUE
				opacity = FALSE
				protection_chance = 60
				ispartial = TRUE
				update_icon()
/obj/structure/barricade/ship/aport0/north
	dir = NORTH
	icon_state = "boat1_port0_up"
	update_icon()
		if (open)
			icon_state = "boat1_port1_up"
		else
			icon_state = "boat1_port0_up"
/obj/structure/barricade/ship/aport1
	name = "open cannon port"
	desc = "A port used to fire cannons out of. This one is open."
	icon_state = "boat1_port1"
	opacity = FALSE
	protection_chance = 30
	ispartial = TRUE

/obj/structure/barricade/ship/aport1/north
	name = "open cannon port"
	desc = "A port used to fire cannons out of. This one is open."
	icon_state = "boat1_port1_up"
	opacity = FALSE
	protection_chance = 30
	ispartial = TRUE

/obj/structure/barricade/ship/aport2
	name = "open cannon port"
	desc = "A port used to fire cannons out of. This one is open and has a cannon poking out."
	icon_state = "boat1_port2"
	opacity = FALSE
	protection_chance = 45
	ispartial = TRUE

/obj/structure/barricade/ship/cport0
	name = "closed cannon port"
	desc = "A port used to fire cannons out of. This one is closed."
	icon_state = "boat2_port0"
	opacity = TRUE
	protection_chance = 60
	ispartial = TRUE
	density = TRUE

/obj/structure/barricade/ship/cport1
	name = "open cannon port"
	desc = "A port used to fire cannons out of. This one is open."
	icon_state = "boat2_port1"
	opacity = FALSE
	protection_chance = 30
	ispartial = TRUE

/obj/structure/barricade/ship/cport2
	name = "open cannon port"
	desc = "A port used to fire cannons out of. This one is open and has a cannon poking out."
	icon_state = "boat2_port2"
	opacity = FALSE
	protection_chance = 45
	ispartial = TRUE

/obj/structure/barricade/ship/ex_act(severity)
	switch(severity)
		if (1.0)
			visible_message("<span class='danger'>\The [src] is blown apart!</span>")
			for(var/obj/structure/barricade/ship/mast/large/L in range(3,src))
				L.sailhealth -= 5
				L.rigginghealth -= 5
				if(L.rigginghealth<0)
					L.rigginghealth = 0
				if(L.sailhealth<0)
					L.sailhealth = 0
			dismantle()
			return
		if (2.0)
			health -= (200 + round(maxhealth * 0.30))
			if (health <= 0)
				visible_message("<span class='danger'>\The [src] is blown apart!</span>")
				for(var/obj/structure/barricade/ship/mast/large/L in range(3,src))
					L.sailhealth -= rand(2,3)
					L.rigginghealth -= rand(2,3)
					if(L.rigginghealth<0)
						L.rigginghealth = 0
					if(L.sailhealth<0)
						L.sailhealth = 0
				dismantle()
			return
		if (3.0)
			health -= (100 + round(maxhealth * 0.10))
			if (health <= 0)
				visible_message("<span class='danger'>\The [src] is blown apart!</span>")
				for(var/obj/structure/barricade/ship/mast/large/L in range(3,src))
					L.sailhealth -= rand(1,2)
					L.rigginghealth -= rand(1,2)
					if(L.rigginghealth<0)
						L.rigginghealth = 0
					if(L.sailhealth<0)
						L.sailhealth = 0
				dismantle()
			return

/obj/structure/barricade/ship/mast
	name = "mast"
	desc = "A wooden ship mast."
	icon = 'icons/turf/walls.dmi'
	icon_state = "wood_mast"
	protection_chance = 60

/obj/structure/barricade/ship/mast/large
	icon = 'icons/turf/64x64.dmi'
	icon_state = "large_mast"
	var/obj/effect/mast/mast_overlay
	bound_height = 64
	bound_width = 64
	opacity = FALSE
	maxhealth = 10000
	health = 10000

	var/sailhealth = 100
	var/rigginghealth = 100
	var/sailstat = 100
	var/upgrade_mast = 0
	var/mast_is_upgraded = FALSE
	var/owner = "ship"

	New()
		..()
		mast_overlay = new/obj/effect/mast(src.loc)
		mast_overlay.mast = src
		mast_overlay.update_icon()

	examine(mob/user)
		..(user)
		var/sailstat_t = "Full Sail"
		if (sailstat <= 66 && sailstat > 33)
			sailstat_t = "Half Sail"
		else if (sailstat <= 33 && sailstat > 0)
			sailstat_t = "Reduced Sail"
		else if (sailstat <= 0)
			sailstat_t = "Retracted"
		user << "Sails: <b>[sailstat_t]</b>"
		user << "Sail Status: <b>[sailhealth]%</b>"
		user << "Rigging Status: <b>[rigginghealth]%</b>"

	attackby(obj/item/I, mob/living/human/H)
		if (istype(I, /obj/item/stack/material))
			var/obj/item/stack/material/M = I
			if (istype(I,/obj/item/stack/material/cloth))
				if (sailhealth < 100)
					H << "You start patching the sails..."
					if(do_after(H,30,src))
						if(M.amount >= 1)
							M.amount--
							H << "You repair one of the holes."
							if (M.amount <= 0)
								qdel(M)
							sailhealth+=2
							if (sailhealth > 100)
								sailhealth = 100

			else if (istype(I,/obj/item/stack/material/rope))
				if (rigginghealth < 100)
					H << "You start replacing the damaged riggings..."
					if(do_after(H,30,src))
						if(M.amount >= 1)
							M.amount--
							H << "You fix one of the ropes."
							if (M.amount <= 0)
								qdel(M)
							rigginghealth+=2
							if (rigginghealth > 100)
								rigginghealth = 100
			else if (istype(I,/obj/item/stack/material/wood))
				if (upgrade_mast < 500)
					H << "You start upgrading the mast"
					if(do_after(H,30,src))
						if(M.amount >= 1)
							H << "You add some upgrades to the mast"
							if (M.amount <= 0)
								qdel(M)
							upgrade_mast+= M.amount
							if (upgrade_mast >= 500)
								upgrade_mast = 500
								mast_is_upgraded = TRUE
			update_icon()
		else
			..()

	ex_act(severity)
		switch(severity)
			if (1.0)
				sailhealth -= 10
				rigginghealth -= 10
				if(rigginghealth<0)
					rigginghealth = 0
				if(sailhealth<0)
					sailhealth = 0
				update_icon()
				return
			if (2.0)
				sailhealth -= 6
				rigginghealth -= 6
				if(rigginghealth<0)
					rigginghealth = 0
				if(sailhealth<0)
					sailhealth = 0
				update_icon()
				return
			if (3.0)
				sailhealth -= 3
				rigginghealth -= 3
				if(rigginghealth<0)
					rigginghealth = 0
				if(sailhealth<0)
					sailhealth = 0
				update_icon()
				return

/obj/structure/barricade/ship/mast/large/upgraded
	icon = 'icons/turf/64x64.dmi'
	icon_state = "large_mast"
	bound_height = 64
	bound_width = 64
	opacity = FALSE
	maxhealth = 15000
	health = 15000

	sailhealth = 100
	rigginghealth = 100
	sailstat = 100
	owner = "ship"