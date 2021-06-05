// Red Earth Render

/obj/covers/clay_wall/redearth
	name = "red earthern bordered wall"
	desc = "A red earthen bordered wall."
	icon_state = "red_earth_smooth_b"
	health = 1050
	explosion_resistance = 7

/* Additional red-earth types seperately defined for mapping/spawning purposes*/

/obj/covers/clay_wall/redearth/smooth
	name = "red earthern smooth wall"
	desc = "A red earthen smooth wall."
	icon_state = "red_earth_smooth"

/obj/covers/clay_wall/redearth/pillared
	name = "red earthern pillared wall"
	desc = "A red earthen pillared wall."
	icon_state = "red_earth_pillared"

/obj/covers/clay_wall/redearth_doorway
	name = "red earthern doorway"
	desc = "A red earthen doorway."
	icon_state = "red_earth_doorway"
	density = FALSE
	opacity = FALSE

/* Red Earth Types -End*/

/obj/covers/clay_wall/attackby(obj/item/W as obj, mob/user as mob)  //this list doesn't like multi arguements, single type per stucco catalyst unless you know what you're doing please.
	if (istype(W, /obj/item/weapon/stucco/generic))
		user << "You start adding stucco to the wall..."
		if (do_after(user, 20, src))
			user << "You finish adding stucco to the wall, rendering it."
			qdel(W)
			var/obj/covers/clay_wall/redearth/S = new /obj/covers/clay_wall/redearth(loc)
			qdel(src)
			var/choice = WWinput(user, "What type of wall?","Red Earth Walls Walls","Normal",list("Red Earth Bordered Wall","Red Earth Smooth Wall","Red Earth Wall","Red Earth Pillared Wall"))
			if (choice == "Red Earth Bordered Wall")
				return
			else if (choice == "Red Earth Smooth Wall")
				S.icon_state = "red_earth_smooth"
				base_icon_state = icon_state
				S.name = "red earthen smooth wall"
				var/choice1 = WWinput(user, "Which orientation?","Red Earth Smooth Wall","Direction",list("Vertical","Horizontal"))
				if (choice1 == "Vertical")
					S.dir = SOUTH
				else if (choice1 == "Horizontal")
					S.dir = EAST
			else if (choice == "Red Earth Wall")
				S.icon_state = "red_earth_wall"
				base_icon_state = icon_state
				S.name = "red earthen wall"
			else if (choice == "Red Earth Pillared Wall")
				S.icon_state = "red_earth_pillared"
				base_icon_state = icon_state
				S.name = "red earthen pillared wall"
			return
	..()

/obj/covers/claydoorway/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/stucco/generic))
		user << "You start adding stucco to the doorway..."
		if (do_after(user, 20, src))
			user << "You finish adding stucco to the doorway, rendering over it."
			qdel(W)
			new /obj/covers/clay_wall/redearth_doorway(loc)
			qdel(src)

// Roman Render

/obj/covers/stone_wall/classic/villa
	name = "villa wall"
	desc = "A roman style villa wall."
	icon_state = "villa_wall"
	adjusts = FALSE

/obj/covers/stone_wall/classic/villa/relief
	name = "villa wall relief"
	desc = "A roman style villa wall with a large empty relief."
	icon_state = "villa_wall_l_relief"


/* Additional roman villa types seperately defined for mapping/spawning purposes*/

/obj/covers/stone_wall/classic/villa/pillared
	name = "pillared villa wall"
	desc = "A roman style pillared villa wall."
	icon_state = "villa_pillared"

/obj/covers/stone_wall/classic/villa/relief/gladiator
	name = "villa wall relief of a gladiator"
	desc = "A roman style villa wall with a chiselled relief of a gladiator."
	icon_state = "villa_wall_l_relief_gladiator"

/obj/covers/stone_wall/classic/villa/relief/aquila
	name = "villa wall relief of a aquila"
	desc = "A roman style villa wall with a chiselled relief of a aquila."
	icon_state = "villa_wall_l_relief_aquila"

/obj/covers/stone_wall/classic/villa/relief/greek
	name = "villa wall relief of a hoplite"
	desc = "A roman style villa wall with a chiselled relief of a hoplite."
	icon_state = "villa_wall_l_relief_greek"

/obj/covers/stone_wall/classic/villa_doorway
	name = "villa doorway"
	desc = "A roman style villa doorway."
	icon_state = "villa_door"
	base_icon_state = "villa_door"
	adjusts = FALSE
	density = FALSE
	opacity = FALSE

/* Additional roman villa types - End*/

/obj/covers/stone_wall/classic/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/stucco/roman))
		user << "You start adding roman stucco to the wall..."
		if (do_after(user, 20, src))
			user << "You finish adding roman stucco to the wall, rendering it."
			qdel(W)
			var/obj/covers/stone_wall/classic/villa/S = new /obj/covers/stone_wall/classic/villa(loc)
			qdel(src)
			var/choice = WWinput(user, "What type of wall?","Roman Villa Walls","Normal",list("Villa Wall","Villa Pillared Wall","Villa Wall With Clear Relief", "Villa Wall With Gladiator Relief", "Villa Wall With Aquila Relief", "Villa Wall With Hoplite Relief"))
			if (choice == "Villa Wall")
				return
			else if (choice == "Villa Pillared Wall")
				S.icon_state = "villa_pillared"
				base_icon_state = icon_state
				S.name = "pillared villa wall"
				S.desc = "A roman style pillared villa wall."
			else if (choice == "Villa Wall With Clear Relief")
				S.icon_state = "villa_wall_l_relief"
				base_icon_state = icon_state
				S.name = "villa wall relief"
				S.desc = "A roman style villa wall with a large empty relief."
			else if (choice == "Villa Wall With Gladiator Relief")
				S.icon_state = "villa_wall_l_relief_gladiator"
				base_icon_state = icon_state
				S.name = "villa wall relief of a gladiator"
				S.desc = "A roman style villa wall with a chiselled relief of a gladiator."
			else if (choice == "Villa Wall With Aquila Relief")
				S.icon_state = "villa_wall_l_relief_aquila"
				base_icon_state = icon_state
				S.name = "villa wall relief of a aquila"
				S.desc = "A roman style villa wall with a chiselled relief of a aquila."
			else if (choice == "Villa Wall With Hoplite Relief")
				S.icon_state = "villa_wall_l_relief_greek"
				base_icon_state = icon_state
				S.name = "villa wall relief of a hoplite"
				S.desc = "A roman style villa wall with a chiselled relief of a hoplite."
			return
	..()

/obj/covers/stone_wall/classic/archway/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/stucco/roman))
		user << "You start adding roman stucco to the archway..."
		if (do_after(user, 20, src))
			user << "You finish adding roman stucco to the archway, rendering over it."
			qdel(W)
			new /obj/covers/stone_wall/classic/villa_doorway(loc)
			qdel(src)
			return