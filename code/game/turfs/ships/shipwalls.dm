/obj/structure/barricade/ship
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat1"
	material = "wood"
	var/cover = 80 //probability of bullets passing through


/obj/structure/barricade/ship/New(var/newloc, var/material_name)
	return
/obj/structure/barricade/ship/get_material()
	return material

/obj/structure/barricade/ship/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)//So bullets will fly over and stuff.
	if (istype(mover, /obj/item/projectile))
		return prob(cover)
	else
		return FALSE

/obj/structure/barricade/ship/wall1
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat1_a"
/obj/structure/barricade/ship/wall2
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat2"


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
/obj/structure/barricade/ship/blue/b2
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b2"
/obj/structure/barricade/ship/blue/b3
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b3"
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
/obj/structure/barricade/ship/blue/b6
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b6"
/obj/structure/barricade/ship/blue/b7
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b7"
/obj/structure/barricade/ship/blue/b8
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b8"
/obj/structure/barricade/ship/blue/b9
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b9"
/obj/structure/barricade/ship/blue/b10
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b10"
/obj/structure/barricade/ship/blue/b11
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b11"
/obj/structure/barricade/ship/blue/b12
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b12"
/obj/structure/barricade/ship/blue/b13
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b13"
/obj/structure/barricade/ship/blue/b14
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b14"
/obj/structure/barricade/ship/blue/b15
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b15"
/obj/structure/barricade/ship/blue/b16
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b16"
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
/obj/structure/barricade/ship/blue/b19
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b19"

/obj/structure/barricade/ship/blue/bport0
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_port0"
	cover = 40

/obj/structure/barricade/ship/blue/bport1
	name = "holed wall"
	desc = "A thin wood ship wall, with a lower part to fire through."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_port1"
	cover = 25

/obj/structure/barricade/ship/blue/bport3
	name = "crenelated wall"
	desc = "A thin wood ship wall, with a lower part to fire through."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_port3"
	cover = 20


/obj/structure/barricade/ship/blue/bwest
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_west"

/obj/structure/barricade/ship/blue/bwest2
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_west2"

/obj/structure/barricade/ship/blue/beast
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_east"

/obj/structure/barricade/ship/blue/beast2
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_east2"

/obj/structure/barricade/ship/wood
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a1"


/obj/structure/barricade/ship/wood/a1
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a1"
/obj/structure/barricade/ship/wood/a2
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a2"
/obj/structure/barricade/ship/wood/a3
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a3"
/obj/structure/barricade/ship/wood/a4
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a4"
/obj/structure/barricade/ship/wood/a5
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a5"
/obj/structure/barricade/ship/wood/a6
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a6"
/obj/structure/barricade/ship/wood/a7
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a7"
/obj/structure/barricade/ship/wood/a8
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a8"
/obj/structure/barricade/ship/wood/a9
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a9"
/obj/structure/barricade/ship/wood/a10
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a10"
/obj/structure/barricade/ship/wood/a11
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a11"
/obj/structure/barricade/ship/wood/a12
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a12"

/obj/structure/barricade/ship/wood/a12
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a12"

/obj/structure/barricade/ship/wood/port0
	name = "wall"
	desc = "A thin wood ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_port0"
	cover = 40

/obj/structure/barricade/ship/wood/port1
	name = "holed wall"
	desc = "A thin wood ship wall, with a hole to fire through."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_port1"
	cover = 25

/obj/structure/barricade/ship/wood/port2
	name = "crenelated wall"
	desc = "A thin wood ship wall, with a lower part to fire through."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_port2"
	cover = 20

/obj/structure/barricade/ship/aport0
	name = "closed cannon port"
	desc = "A port used to fire cannons out of. This one is closed."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat1_port0"

/obj/structure/barricade/ship/aport1
	name = "open cannon port"
	desc = "A port used to fire cannons out of. This one is open."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat1_port1"

/obj/structure/barricade/ship/aport2
	name = "open cannon port"
	desc = "A port used to fire cannons out of. This one is open and has a cannon poking out."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat1_port2"

/obj/structure/barricade/ship/cport0
	name = "closed cannon port"
	desc = "A port used to fire cannons out of. This one is closed."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat2_port0"

/obj/structure/barricade/ship/cport1
	name = "open cannon port"
	desc = "A port used to fire cannons out of. This one is open."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat2_port1"

/obj/structure/barricade/ship/cport2
	name = "open cannon port"
	desc = "A port used to fire cannons out of. This one is open and has a cannon poking out."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat2_port2"

/obj/structure/barricade/ship/mast
	name = "mast"
	desc = "A wooden ship mast."
	icon = 'icons/turf/walls.dmi'
	icon_state = "wood_mast"
	cover = 60
/*/obj/structure/barricade/ship
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat1"

/obj/structure/barricade/ship/wall1
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat1_a"
/obj/structure/barricade/ship/wall2
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat2"


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
/obj/structure/barricade/ship/blue/b2
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b2"
/obj/structure/barricade/ship/blue/b3
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b3"
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
/obj/structure/barricade/ship/blue/b6
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b6"
/obj/structure/barricade/ship/blue/b7
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b7"
/obj/structure/barricade/ship/blue/b8
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b8"
/obj/structure/barricade/ship/blue/b9
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b9"
/obj/structure/barricade/ship/blue/b10
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b10"
/obj/structure/barricade/ship/blue/b11
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b11"
/obj/structure/barricade/ship/blue/b12
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b12"
/obj/structure/barricade/ship/blue/b13
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b13"
/obj/structure/barricade/ship/blue/b14
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b14"
/obj/structure/barricade/ship/blue/b15
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b15"
/obj/structure/barricade/ship/blue/b16
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b16"
/obj/structure/barricade/ship/blue/b17
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b17"

/obj/structure/barricade/ship/blue/bport0
	name = "closed cannon port"
	desc = "A port used to fire cannons out of. This one is closed."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_port0"

/obj/structure/barricade/ship/blue/bport1
	name = "open cannon port"
	desc = "A port used to fire cannons out of. This one is open."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_port1"

/obj/structure/barricade/ship/blue/bport2
	name = "open cannon port"
	desc = "A port used to fire cannons out of. This one is open and has a cannon poking out."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_port2"

/obj/structure/barricade/ship/blue/bwest
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_west"

/obj/structure/barricade/ship/blue/bwest2
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_west2"

/obj/structure/barricade/ship/blue/beast
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_east"

/obj/structure/barricade/ship/blue/beast2
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat_b.dmi'
	icon_state = "boat_b_east2"

/obj/structure/barricade/ship/wood
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a1"


/obj/structure/barricade/ship/wood/a1
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a1"
/obj/structure/barricade/ship/wood/a2
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a2"
/obj/structure/barricade/ship/wood/a3
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a3"
/obj/structure/barricade/ship/wood/a4
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a4"
/obj/structure/barricade/ship/wood/a5
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a5"
/obj/structure/barricade/ship/wood/a6
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a6"
/obj/structure/barricade/ship/wood/a7
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a7"
/obj/structure/barricade/ship/wood/a8
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a8"
/obj/structure/barricade/ship/wood/a9
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a9"
/obj/structure/barricade/ship/wood/a10
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a10"
/obj/structure/barricade/ship/wood/a11
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a11"
/obj/structure/barricade/ship/wood/a12
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a12"

/obj/structure/barricade/ship/wood/a12
	name = "wall"
	desc = "A wooden ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_a12"

/obj/structure/barricade/ship/wood/port0
	name = "wall"
	desc = "A thin wood ship wall."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_port0"

/obj/structure/barricade/ship/wood/port0
	name = "cannon port"
	desc = "A thin wood ship wall, with a hole to fire through."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat_port1"

/obj/structure/barricade/ship/aport0
	name = "closed cannon port"
	desc = "A port used to fire cannons out of. This one is closed."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat1_port0"

/obj/structure/barricade/ship/aport1
	name = "open cannon port"
	desc = "A port used to fire cannons out of. This one is open."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat1_port1"

/obj/structure/barricade/ship/aport2
	name = "open cannon port"
	desc = "A port used to fire cannons out of. This one is open and has a cannon poking out."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat1_port2"

/obj/structure/barricade/ship/cport0
	name = "closed cannon port"
	desc = "A port used to fire cannons out of. This one is closed."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat2_port0"

/obj/structure/barricade/ship/cport1
	name = "open cannon port"
	desc = "A port used to fire cannons out of. This one is open."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat2_port1"

/obj/structure/barricade/ship/cport2
	name = "open cannon port"
	desc = "A port used to fire cannons out of. This one is open and has a cannon poking out."
	icon = 'icons/turf/boat.dmi'
	icon_state = "boat2_port2" */