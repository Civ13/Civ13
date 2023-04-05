/obj/structure/barricade
	name = "wood structure"
	desc = "A wooden frame."
	icon = 'icons/obj/structures.dmi'
	icon_state = "barricade"
	anchored = TRUE

	density = TRUE
	var/health = 100
	var/maxhealth = 100
	var/material/material
	var/material_name = "wood"
	not_movable = TRUE
	not_disassemblable = TRUE
	var/protection_chance = 85 //prob of the projectile hitting the barricade
	var/applies_material_colour = TRUE

/*
/obj/structure/barricade/attackby(obj/item/W as obj, mob/user as mob)
	switch(material)
		if ("wood")
			//Do nothing, anything can cut through wood.
		else if ("stone")
			//Swords no work on stone, unga dunga no knify wifey the wall.
			if(!istype(W, /obj/item/weapon/sledgehammer) && !istype(W, /obj/item/projectile))
				user << "Your [W.name] glances off the [src.name]!"
				return
			else
				//Damage the wall.
		else if ("metal" || "steel")
			if(!istype(W, /obj/item/weapon/sledgehammer) && !istype(W, /obj/item/projectile))
				user << "Your [W.name] glances off the [src.name]!"
				returns
			else
				//Damage the wall.
		..()*/

/obj/structure/barricade/New(var/newloc)
	..(newloc)
	if(!istype(src, /obj/structure/barricade/ship))
		if (!material_name)
			material_name = "wood"
		material = get_material_by_name("[material_name]")
		if (!material)
			qdel(src)
			return
		name = "[material.display_name] barricade"
		if (istype(material, /material/wood))
			icon_state = "wood_barricade"
			flammable = TRUE
		else
			if(!applies_material_colour)
				return
			else
				color = material.icon_colour
		maxhealth = (material.integrity*2.5) + 100
		health = maxhealth

/obj/structure/barricade/get_material()
	return material

/obj/structure/barricade/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack))
		var/obj/item/stack/D = W
		if (material && D.get_material_name() != material.name)
			return //hitting things with the wrong type of stack usually doesn't produce messages, and probably doesn't need to.
		if (health < maxhealth)
			if (D.amount < 1)
				user << "<span class='warning'>You need one sheet of [material.display_name] to repair \the [src].</span>"
				return
			visible_message("<span class='notice'>[user] begins to repair \the [src].</span>")
			if (do_after(user,20,src) && health < maxhealth)
				if (D.use(1))
					health = maxhealth
					visible_message("<span class='notice'>[user] repairs \the [src].</span>")
				return
		return
	else
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
		switch(W.damtype)
			if ("fire")
				health -= W.force * TRUE
			if ("brute")
				health -= W.force * 0.75

		playsound(get_turf(src), 'sound/weapons/smash.ogg', 100)

		user.do_attack_animation(src)

		try_destroy()

		..()

/obj/structure/barricade/proc/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>The barricade is smashed apart!</span>")
		dismantle()
		qdel(src)
		return

/obj/structure/barricade/proc/dismantle()
	qdel(src)
	return

/obj/structure/barricade/ex_act(severity)
	switch(severity)
		if (1.0)
			visible_message("<span class='danger'>\The [src] is blown apart!</span>")
			dismantle()
			return
		if (2.0)
			health -= (200 + round(maxhealth * 0.30))
			if (health <= 0)
				visible_message("<span class='danger'>\The [src] is blown apart!</span>")
				dismantle()
			return
		if (3.0)
			health -= (100 + round(maxhealth * 0.10))
			if (health <= 0)
				visible_message("<span class='danger'>\The [src] is blown apart!</span>")
				dismantle()
			return
/* the only barricades still in the code are wood barricades, which SHOULD
  be hit by bullets, at least sometimes - hence these changes. */

/obj/structure/barricade/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)//So bullets will fly over and stuff.
	if (istype(mover, /obj/item/projectile))
		var/obj/item/projectile/P = mover
		return prob(100-protection_chance-(P.penetrating*4))
	else
		if (density)
			return FALSE
		else
			return TRUE

/obj/structure/barricade/bullet_act(var/obj/item/projectile/proj)
	health -= proj.damage/3
	visible_message("<span class='warning'>\The [src] is hit by the [proj.name]!</span>")
	try_destroy()

/obj/structure/barricade/horizontal
	name = "wood barrier"
	desc = "A wood wall made of vines and logs roped together."
	icon_state = "woodbarricade_horizontal"
	flammable = TRUE
	protection_chance = 85
	layer = 2.98

/obj/structure/barricade/vertical
	name = "wood barrier"
	desc = "A wood wall made of vines and logs roped together."
	icon_state = "woodbarricade_vertical"
	flammable = TRUE
	protection_chance = 85
	layer = 2.98

/obj/structure/barricade/vertical/New()
	..()
	icon_state = "woodbarricade_vertical"

/obj/structure/barricade/horizontal/New()
	..()
	icon_state = "woodbarricade_horizontal"
// steel barricades

/obj/structure/barricade/steel
	material = "steel"
	material_name = "steel"
	name = "steel barrier"
	desc = "A sturdy steel construction."
	flammable = FALSE
	protection_chance = 90
	health = 700
	maxhealth = 700

/obj/structure/barricade/steel/New(_loc)
	..(_loc)

/obj/structure/barricade/sandstone_h
	name = "sandstone wall"
	desc = "A wall of sandstone blocks."
	icon = 'icons/turf/walls.dmi'
	icon_state = "sandstone_brick"
	health = 300
	maxhealth = 300
	material = "stone"
	material_name = "stone"
	protection_chance = 90

/obj/structure/barricade/sandstone_v
	name = "sandstone wall"
	desc = "A wall of sandstone blocks."
	icon = 'icons/turf/walls.dmi'
	icon_state = "sandstone_brick2"
	health = 300
	maxhealth = 300
	material = "stone"
	material_name = "stone"
	protection_chance = 90

/obj/structure/barricade/sandstone_h/crenelated
	name = "crenelated sandstone wall"
	desc = "A wall of sandstone blocks."
	icon = 'icons/turf/walls.dmi'
	icon_state = "sandstone_brick_c"
	health = 300
	maxhealth = 300
	material = "stone"
	material_name = "stone"
	protection_chance = 75

/obj/structure/barricade/sandstone_h/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/siegeladder))
		visible_message(
			"<span class='danger'>\The [user] starts deploying \the [W.name].</span>",
			"<span class='danger'>You start deploying \the [W.name].</span>")
		if (do_after(user, 80, src))
			visible_message(
				"<span class='danger'>\The [user] has deployed \the [W.name]!</span>",
				"<span class='danger'>You have deployed \the [W.name]!</span>")
			qdel(W)
			var/obj/item/weapon/siegeladder/ANCH = new/obj/item/weapon/siegeladder(src.loc)
			ANCH.anchored = TRUE
			src.climbable = TRUE
			ANCH.deployed = TRUE
			ANCH.icon_state = ANCH.depicon
			ANCH.dir = src.dir
			return
	if (istype(W,/obj/item/weapon) || !istype(W,/obj/item/weapon/wrench) || !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You hit the wall uselessly!"//sucker
		return
	else
		..()

/obj/structure/barricade/sandstone_h/crenelated/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/siegeladder))
		visible_message(
			"<span class='danger'>\The [user] starts deploying \the [W.name].</span>",
			"<span class='danger'>You start deploying \the [W.name].</span>")
		if (do_after(user, 80, src))
			visible_message(
				"<span class='danger'>\The [user] has deployed \the [W.name]!</span>",
				"<span class='danger'>You have deployed \the [W.name]!</span>")
			qdel(W)
			var/obj/item/weapon/siegeladder/ANCH = new/obj/item/weapon/siegeladder(src.loc)
			ANCH.anchored = TRUE
			src.climbable = TRUE
			ANCH.deployed = TRUE
			ANCH.icon_state = ANCH.depicon
			ANCH.dir = src.dir
			return
	if (istype(W,/obj/item/weapon) || !istype(W,/obj/item/weapon/wrench) || !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You hit the wall uselessly!"//sucker
		return
	else
		..()

/obj/structure/barricade/sandstone_v/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/siegeladder))
		visible_message(
			"<span class='danger'>\The [user] starts deploying \the [W.name].</span>",
			"<span class='danger'>You start deploying \the [W.name].</span>")
		if (do_after(user, 80, src))
			visible_message(
				"<span class='danger'>\The [user] has deployed \the [W.name]!</span>",
				"<span class='danger'>You have deployed \the [W.name]!</span>")
			qdel(W)
			var/obj/item/weapon/siegeladder/ANCH = new/obj/item/weapon/siegeladder(src.loc)
			ANCH.anchored = TRUE
			src.climbable = TRUE
			ANCH.deployed = TRUE
			ANCH.icon_state = ANCH.depicon
			ANCH.dir = src.dir
			return
	if (istype(W,/obj/item/weapon) || !istype(W,/obj/item/weapon/wrench) || !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You hit the wall uselessly!"//sucker
		return
	else
		..()

/obj/structure/barricade/sandstone_v/crenelated
	name = "crenelated sandstone wall"
	desc = "A wall of sandstone blocks."
	icon = 'icons/turf/walls.dmi'
	icon_state = "sandstone_brick_c2"
	health = 300
	maxhealth = 300
	material = "stone"
	material_name = "stone"
	protection_chance = 75

/obj/structure/barricade/sandstone_v/crenelated/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/siegeladder))
		visible_message(
			"<span class='danger'>\The [user] starts deploying \the [W.name].</span>",
			"<span class='danger'>You start deploying \the [W.name].</span>")
		if (do_after(user, 80, src))
			visible_message(
				"<span class='danger'>\The [user] has deployed \the [W.name]!</span>",
				"<span class='danger'>You have deployed \the [W.name]!</span>")
			qdel(W)
			var/obj/item/weapon/siegeladder/ANCH = new/obj/item/weapon/siegeladder(src.loc)
			ANCH.anchored = TRUE
			src.climbable = TRUE
			ANCH.deployed = TRUE
			ANCH.icon_state = ANCH.depicon
			ANCH.dir = src.dir
			return
	if (istype(W,/obj/item/weapon) || !istype(W,/obj/item/weapon/wrench) || !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You hit the wall uselessly!"//sucker
		return
	else
		..()

/obj/structure/barricade/sandstone_h/New()
	..()
	icon_state = "sandstone_brick"
	name = "sandstone wall"
	health = 300
	maxhealth = 300
	material_name = "stone"
	color = null

/obj/structure/barricade/sandstone_v/New()
	..()
	icon_state = "sandstone_brick2"
	name = "sandstone wall"
	health = 300
	maxhealth = 300
	material_name = "stone"
	color = null

/obj/structure/barricade/sandstone_h/crenelated/New()
	..()
	icon_state = "sandstone_brick_c"
	name = "crenelated sandstone wall"
	health = 300
	maxhealth = 300
	material_name = "stone"
	color = null

/obj/structure/barricade/sandstone_v/crenelated/New()
	..()
	icon_state = "sandstone_brick_c2"
	name = "crenelated sandstone wall"
	health = 300
	maxhealth = 300
	material_name = "stone"
	color = null

/obj/structure/barricade/sandstone_h/ex_act(severity)
	switch(severity)
		if (1.0)
			health -= 150
		if (2.0)
			health -= 100
		if (3.0)
			health -= 50
	if (health <= 0)
		visible_message("<span class='danger'>\The [src] is blown apart!</span>")
		qdel(src)
		return

/obj/structure/barricade/sandstone_v/ex_act(severity)
	switch(severity)
		if (1.0)
			health -= 150
		if (2.0)
			health -= 100
		if (3.0)
			health -= 50
	if (health <= 0)
		visible_message("<span class='danger'>\The [src] is blown apart!</span>")
		qdel(src)
		return

/obj/structure/barricade/sandstone_h/crenelated/ex_act(severity)
	switch(severity)
		if (1.0)
			health -= 150
		if (2.0)
			health -= 100
		if (3.0)
			health -= 50
	if (health <= 0)
		visible_message("<span class='danger'>\The [src] is blown apart!</span>")
		qdel(src)
		return

/obj/structure/barricade/sandstone_v/crenelated/ex_act(severity)
	switch(severity)
		if (1.0)
			health -= 150
		if (2.0)
			health -= 100
		if (3.0)
			health -= 50
	if (health <= 0)
		visible_message("<span class='danger'>\The [src] is blown apart!</span>")
		qdel(src)
		return
/obj/structure/barricade/antitank
	name = "czech hedgehog"
	desc = "A static anti-tank obstacle defense made of metal angle beams."
	icon_state = "antitank"
	material = "steel"
	health = 2709
	maxhealth = 2709
	material_name = "steel"
	protection_chance = 50

/obj/structure/barricade/debris
	name = "debris"
	desc = "A wall of rubble and debris."
	icon = 'icons/obj/structures.dmi'
	icon_state = "debris1"
	material = "stone"
	health = 300
	maxhealth = 300
	material_name = "stone"
	protection_chance = 90
	New()
		..()
		icon_state = "debris[rand(1,4)]"

/obj/structure/barricade/stone_h
	name = "stone wall"
	desc = "A wall of stone blocks."
	icon = 'icons/turf/walls.dmi'
	icon_state = "stone_brick"
	material = "stone"
	health = 300
	maxhealth = 300
	material_name = "stone"
	protection_chance = 90

/obj/structure/barricade/stone_h/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/siegeladder))
		visible_message(
			"<span class='danger'>\The [user] starts deploying \the [W.name].</span>",
			"<span class='danger'>You start deploying \the [W.name].</span>")
		if (do_after(user, 80, src))
			visible_message(
				"<span class='danger'>\The [user] has deployed \the [W.name]!</span>",
				"<span class='danger'>You have deployed \the [W.name]!</span>")
			qdel(W)
			var/obj/item/weapon/siegeladder/ANCH = new/obj/item/weapon/siegeladder(src.loc)
			ANCH.anchored = TRUE
			src.climbable = TRUE
			ANCH.deployed = TRUE
			ANCH.icon_state = ANCH.depicon
			ANCH.dir = src.dir
			return
	if (istype(W,/obj/item/weapon) || !istype(W,/obj/item/weapon/wrench) || !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You hit the wall uselessly!"//sucker
		return
	else
		..()

/obj/structure/barricade/stone_v
	name = "stone wall"
	desc = "A wall of stone blocks."
	icon = 'icons/turf/walls.dmi'
	icon_state = "stone_brick2"
	material = "stone"
	health = 300
	maxhealth = 300
	material_name = "stone"
	protection_chance = 90

/obj/structure/barricade/stone_v/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/siegeladder))
		visible_message(
			"<span class='danger'>\The [user] starts deploying \the [W.name].</span>",
			"<span class='danger'>You start deploying \the [W.name].</span>")
		if (do_after(user, 80, src))
			visible_message(
				"<span class='danger'>\The [user] has deployed \the [W.name]!</span>",
				"<span class='danger'>You have deployed \the [W.name]!</span>")
			qdel(W)
			var/obj/item/weapon/siegeladder/ANCH = new/obj/item/weapon/siegeladder(src.loc)
			ANCH.anchored = TRUE
			src.climbable = TRUE
			ANCH.deployed = TRUE
			ANCH.icon_state = ANCH.depicon
			ANCH.dir = src.dir
			return
	if (istype(W,/obj/item/weapon) || !istype(W,/obj/item/weapon/wrench) || !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You hit the wall uselessly!"//sucker
		return
	else
		..()

/obj/structure/barricade/stone_h/crenelated
	name = "crenelated stone wall"
	desc = "A wall of stone blocks."
	icon = 'icons/turf/walls.dmi'
	icon_state = "stone_brick_c"
	material = "stone"
	health = 300
	maxhealth = 300
	material_name = "stone"
	protection_chance = 75

/obj/structure/barricade/stone_h/crenelated/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/siegeladder))
		visible_message(
			"<span class='danger'>\The [user] starts deploying \the [W.name].</span>",
			"<span class='danger'>You start deploying \the [W.name].</span>")
		if (do_after(user, 80, src))
			visible_message(
				"<span class='danger'>\The [user] has deployed \the [W.name]!</span>",
				"<span class='danger'>You have deployed \the [W.name]!</span>")
			qdel(W)
			var/obj/item/weapon/siegeladder/ANCH = new/obj/item/weapon/siegeladder(src.loc)
			ANCH.anchored = TRUE
			src.climbable = TRUE
			ANCH.deployed = TRUE
			ANCH.icon_state = ANCH.depicon
			ANCH.dir = src.dir
			return
	if (istype(W,/obj/item/weapon) || !istype(W,/obj/item/weapon/wrench) || !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You hit the wall uselessly!"//sucker
		return
	else
		..()

/obj/structure/barricade/stone_v/crenelated
	name = "crenelated stone wall"
	desc = "A wall of stone blocks."
	icon = 'icons/turf/walls.dmi'
	icon_state = "stone_brick_c2"
	material = "stone"
	health = 300
	maxhealth = 300
	material_name = "stone"
	protection_chance = 75

/obj/structure/barricade/stone_v/crenelated/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/siegeladder))
		visible_message(
			"<span class='danger'>\The [user] starts deploying \the [W.name].</span>",
			"<span class='danger'>You start deploying \the [W.name].</span>")
		if (do_after(user, 80, src))
			visible_message(
				"<span class='danger'>\The [user] has deployed \the [W.name]!</span>",
				"<span class='danger'>You have deployed \the [W.name]!</span>")
			qdel(W)
			var/obj/item/weapon/siegeladder/ANCH = new/obj/item/weapon/siegeladder(src.loc)
			ANCH.anchored = TRUE
			src.climbable = TRUE
			ANCH.deployed = TRUE
			ANCH.icon_state = ANCH.depicon
			ANCH.dir = src.dir
			return
	if (istype(W,/obj/item/weapon) || !istype(W,/obj/item/weapon/wrench) || !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You hit the wall uselessly!"//sucker
		return
	else
		..()

/obj/structure/barricade/stone_h/New()
	..()
	icon_state = "stone_brick"
	name = "stone wall"
	health = 300
	maxhealth = 300
	color = null

/obj/structure/barricade/stone_v/New()
	..()
	icon_state = "stone_brick2"
	name = "stone wall"
	health = 300
	maxhealth = 300
	color = null

/obj/structure/barricade/stone_h/crenelated/New()
	..()
	icon_state = "stone_brick_c"
	name = "crenelated stone wall"
	health = 300
	maxhealth = 300
	color = null

/obj/structure/barricade/stone_v/crenelated/New()
	..()
	icon_state = "stone_brick_c2"
	name = "crenelated stone wall"
	health = 300
	maxhealth = 300
	color = null

/obj/structure/barricade/stone_h/ex_act(severity)
	switch(severity)
		if (1.0)
			health -= 150
		if (2.0)
			health -= 100
		if (3.0)
			health -= 50
	if (health <= 0)
		visible_message("<span class='danger'>\The [src] is blown apart!</span>")
		qdel(src)
		return

/obj/structure/barricade/stone_v/ex_act(severity)
	if (map.ID != "WHITERUN")
		switch(severity)
			if (1.0)
				health -= 150
			if (2.0)
				health -= 100
			if (3.0)
				health -= 50
		if (health <= 0)
			visible_message("<span class='danger'>\The [src] is blown apart!</span>")
			qdel(src)
			return
	else
		return

/obj/structure/barricade/stone_h/crenelated/ex_act(severity)
	if (map.ID != "WHITERUN")
		switch(severity)
			if (1.0)
				health -= 150
			if (2.0)
				health -= 100
			if (3.0)
				health -= 50
		if (health <= 0)
			visible_message("<span class='danger'>\The [src] is blown apart!</span>")
			qdel(src)
			return
	else
		return

/obj/structure/barricade/stone_v/crenelated/ex_act(severity)
	if (map.ID != "WHITERUN")
		switch(severity)
			if (1.0)
				health -= 150
			if (2.0)
				health -= 100
			if (3.0)
				health -= 50
		if (health <= 0)
			visible_message("<span class='danger'>\The [src] is blown apart!</span>")
			qdel(src)
			return
	else
		return


/obj/structure/barricade/jap_h
	name = "shingled stone wall"
	desc = "A wall of stone blocks with some red shingles."
	icon = 'icons/turf/walls.dmi'
	icon_state = "jap_wall_h"
	material = "stone"
	health = 2709
	maxhealth = 2709
	material_name = "stone"
	protection_chance = 100

/obj/structure/barricade/jap_h/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/siegeladder))
		visible_message(
			"<span class='danger'>\The [user] starts deploying \the [W.name].</span>",
			"<span class='danger'>You start deploying \the [W.name].</span>")
		if (do_after(user, 80, src))
			visible_message(
				"<span class='danger'>\The [user] has deployed \the [W.name]!</span>",
				"<span class='danger'>You have deployed \the [W.name]!</span>")
			qdel(W)
			var/obj/item/weapon/siegeladder/ANCH = new/obj/item/weapon/siegeladder(src.loc)
			ANCH.anchored = TRUE
			src.climbable = TRUE
			ANCH.deployed = TRUE
			ANCH.icon_state = ANCH.depicon
			ANCH.dir = src.dir
			return
	if (istype(W,/obj/item/weapon) || !istype(W,/obj/item/weapon/wrench) || !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You hit the wall uselessly!"//sucker
		return
	else
		..()
/obj/structure/barricade/jap_h/New()
	..()
	icon_state = "jap_wall_h"
	name = "stone wall"
	health = 2709
	maxhealth = 2709

/obj/structure/barricade/jap_h/ex_act(severity)
	if (map.ID != "WHITERUN")
		switch(severity)
			if (1.0)
				health -= 150
			if (2.0)
				health -= 100
			if (3.0)
				health -= 50
		if (health <= 0)
			visible_message("<span class='danger'>\The [src] is blown apart!</span>")
			qdel(src)
			return
	else
		return

/obj/structure/barricade/jap_h_l
	name = "shingled stone wall"
	desc = "A wall of stone blocks with some red shingles."
	icon = 'icons/turf/walls.dmi'
	icon_state = "jap_wall_h_l"
	material = "stone"
	health = 2709
	maxhealth = 2709
	material_name = "stone"
	protection_chance = 100

/obj/structure/barricade/jap_h_l/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/siegeladder))
		visible_message(
			"<span class='danger'>\The [user] starts deploying \the [W.name].</span>",
			"<span class='danger'>You start deploying \the [W.name].</span>")
		if (do_after(user, 80, src))
			visible_message(
				"<span class='danger'>\The [user] has deployed \the [W.name]!</span>",
				"<span class='danger'>You have deployed \the [W.name]!</span>")
			qdel(W)
			var/obj/item/weapon/siegeladder/ANCH = new/obj/item/weapon/siegeladder(src.loc)
			ANCH.anchored = TRUE
			src.climbable = TRUE
			ANCH.deployed = TRUE
			ANCH.icon_state = ANCH.depicon
			ANCH.dir = src.dir
			return
	if (istype(W,/obj/item/weapon) || !istype(W,/obj/item/weapon/wrench) || !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You hit the wall uselessly!"//sucker
		return
	else
		..()
/obj/structure/barricade/jap_h_l/New()
	..()
	icon_state = "jap_wall_h_l"
	name = "stone wall"
	health = 2709
	maxhealth = 2709

/obj/structure/barricade/jap_h_l/ex_act(severity)
	if (map.ID != "WHITERUN")
		switch(severity)
			if (1.0)
				health -= 150
			if (2.0)
				health -= 100
			if (3.0)
				health -= 50
		if (health <= 0)
			visible_message("<span class='danger'>\The [src] is blown apart!</span>")
			qdel(src)
			return
	else
		return

/obj/structure/barricade/jap_h_r
	name = "shingled stone wall"
	desc = "A wall of stone blocks with some red shingles."
	icon = 'icons/turf/walls.dmi'
	icon_state = "jap_wall_h_r"
	material = "stone"
	health = 2709
	maxhealth = 2709
	material_name = "stone"
	protection_chance = 100

/obj/structure/barricade/jap_h_r/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/siegeladder))
		visible_message(
			"<span class='danger'>\The [user] starts deploying \the [W.name].</span>",
			"<span class='danger'>You start deploying \the [W.name].</span>")
		if (do_after(user, 80, src))
			visible_message(
				"<span class='danger'>\The [user] has deployed \the [W.name]!</span>",
				"<span class='danger'>You have deployed \the [W.name]!</span>")
			qdel(W)
			var/obj/item/weapon/siegeladder/ANCH = new/obj/item/weapon/siegeladder(src.loc)
			ANCH.anchored = TRUE
			src.climbable = TRUE
			ANCH.deployed = TRUE
			ANCH.icon_state = ANCH.depicon
			ANCH.dir = src.dir
			return
	if (istype(W,/obj/item/weapon) || !istype(W,/obj/item/weapon/wrench) || !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You hit the wall uselessly!"//sucker
		return
	else
		..()
/obj/structure/barricade/jap_h_r/New()
	..()
	icon_state = "jap_wall_h_r"
	name = "stone wall"
	health = 2709
	maxhealth = 2709

/obj/structure/barricade/jap_h_r/ex_act(severity)
	if (map.ID != "WHITERUN")
		switch(severity)
			if (1.0)
				health -= 150
			if (2.0)
				health -= 100
			if (3.0)
				health -= 50
		if (health <= 0)
			visible_message("<span class='danger'>\The [src] is blown apart!</span>")
			qdel(src)
			return
	else
		return

/obj/structure/barricade/jap_v
	name = "shingled stone wall"
	desc = "A wall of stone blocks with red shingling."
	icon = 'icons/turf/walls.dmi'
	icon_state = "jap_wall_v"
	material = "stone"
	health = 2709
	maxhealth = 2709
	material_name = "stone"
	protection_chance = 100

/obj/structure/barricade/jap_v/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/siegeladder))
		visible_message(
			"<span class='danger'>\The [user] starts deploying \the [W.name].</span>",
			"<span class='danger'>You start deploying \the [W.name].</span>")
		if (do_after(user, 80, src))
			visible_message(
				"<span class='danger'>\The [user] has deployed \the [W.name]!</span>",
				"<span class='danger'>You have deployed \the [W.name]!</span>")
			qdel(W)
			var/obj/item/weapon/siegeladder/ANCH = new/obj/item/weapon/siegeladder(src.loc)
			ANCH.anchored = TRUE
			src.climbable = TRUE
			ANCH.deployed = TRUE
			ANCH.icon_state = ANCH.depicon
			ANCH.dir = src.dir
			return
	if (istype(W,/obj/item/weapon) || !istype(W,/obj/item/weapon/wrench) || !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You hit the wall uselessly!"//sucker
		return
	else
		..()
/obj/structure/barricade/jap_v/New()
	..()
	icon_state = "jap_wall_v"
	name = "stone wall"
	health = 2709
	maxhealth = 2709

/obj/structure/barricade/jap_v/ex_act(severity)
	if (map.ID != "WHITERUN")
		switch(severity)
			if (1.0)
				health -= 150
			if (2.0)
				health -= 100
			if (3.0)
				health -= 50
		if (health <= 0)
			visible_message("<span class='danger'>\The [src] is blown apart!</span>")
			qdel(src)
			return
	else
		return

/obj/structure/barricade/jap_v_t
	name = "shingled stone wall"
	desc = "A wall of stone blocks with red shingling."
	icon = 'icons/turf/walls.dmi'
	icon_state = "jap_wall_v_t"
	material = "stone"
	health = 2709
	maxhealth = 2709
	material_name = "stone"
	protection_chance = 100

/obj/structure/barricade/jap_v_t/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/siegeladder))
		visible_message(
			"<span class='danger'>\The [user] starts deploying \the [W.name].</span>",
			"<span class='danger'>You start deploying \the [W.name].</span>")
		if (do_after(user, 80, src))
			visible_message(
				"<span class='danger'>\The [user] has deployed \the [W.name]!</span>",
				"<span class='danger'>You have deployed \the [W.name]!</span>")
			qdel(W)
			var/obj/item/weapon/siegeladder/ANCH = new/obj/item/weapon/siegeladder(src.loc)
			ANCH.anchored = TRUE
			src.climbable = TRUE
			ANCH.deployed = TRUE
			ANCH.icon_state = ANCH.depicon
			ANCH.dir = src.dir
			return
	if (istype(W,/obj/item/weapon) || !istype(W,/obj/item/weapon/wrench) || !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You hit the wall uselessly!"//sucker
		return
	else
		..()
/obj/structure/barricade/jap_v_t/New()
	..()
	icon_state = "jap_wall_v_t"
	name = "stone wall"
	health = 2709
	maxhealth = 2709

/obj/structure/barricade/jap_v_t/ex_act(severity)
	if (map.ID != "WHITERUN")
		switch(severity)
			if (1.0)
				health -= 150
			if (2.0)
				health -= 100
			if (3.0)
				health -= 50
		if (health <= 0)
			visible_message("<span class='danger'>\The [src] is blown apart!</span>")
			qdel(src)
			return
	else
		return

/obj/structure/barricade/jap_v_b
	name = "shingled stone wall"
	desc = "A wall of stone blocks with red shingling."
	icon = 'icons/turf/walls.dmi'
	icon_state = "jap_wall_v_b"
	material = "stone"
	health = 2709
	maxhealth = 2709
	material_name = "stone"
	protection_chance = 100

/obj/structure/barricade/jap_v_b/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/siegeladder))
		visible_message(
			"<span class='danger'>\The [user] starts deploying \the [W.name].</span>",
			"<span class='danger'>You start deploying \the [W.name].</span>")
		if (do_after(user, 80, src))
			visible_message(
				"<span class='danger'>\The [user] has deployed \the [W.name]!</span>",
				"<span class='danger'>You have deployed \the [W.name]!</span>")
			qdel(W)
			var/obj/item/weapon/siegeladder/ANCH = new/obj/item/weapon/siegeladder(src.loc)
			ANCH.anchored = TRUE
			src.climbable = TRUE
			ANCH.deployed = TRUE
			ANCH.icon_state = ANCH.depicon
			ANCH.dir = src.dir
			return
	if (istype(W,/obj/item/weapon) || !istype(W,/obj/item/weapon/wrench) || !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You hit the wall uselessly!"//sucker
		return
	else
		..()

/obj/structure/barricade/jap_v_b/New()
	..()
	icon_state = "jap_wall_v_b"
	name = "stone wall"
	health = 2709
	maxhealth = 2709

/obj/structure/barricade/jap_v_b/ex_act(severity)
	if (map.ID != "WHITERUN")
		switch(severity)
			if (1.0)
				health -= 150
			if (2.0)
				health -= 100
			if (3.0)
				health -= 50
		if (health <= 0)
			visible_message("<span class='danger'>\The [src] is blown apart!</span>")
			qdel(src)
			return
	else
		return

/obj/structure/barricade/tires
	name = "pile of tires"
	desc = "A pile of old tires."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "tire3a"
	health = 200
	maxhealth = 200
	material_name = "wood"
	protection_chance = 30

/obj/structure/barricade/tires/New()
	..()
	icon_state = pick("tire2a","tire3","tire3a")
	name = "pile of tires"

/obj/structure/barricade/hescobastion
	name = "hesco bastion"
	desc = "A collapsible wire mesh container filled with sand. Very sturdy."
	icon = 'icons/obj/junk.dmi'
	icon_state = "hescobastion"
	health = 600
	maxhealth = 600
	material_name = "wood"
	protection_chance = 100
	opacity = TRUE
	density = TRUE

/obj/structure/barricade/hescobastion/New()
	..()
	icon_state = "hescobastion"
	name = "hesco bastion"

/obj/structure/barricade/construction
	name = "construction barrier"
	desc = "A barrier indicating an area of construction works."
	icon_state = "construction1"
	health = 50
	maxhealth = 50
	material_name = "steel"
	protection_chance = 10
	opacity = FALSE
	density = TRUE

/obj/structure/barricade/construction/New()
	name = "construction barrier"
	icon_state = "construction1"

/obj/structure/barricade/construction/corner
	icon_state = "construction_corner"
/obj/structure/barricade/construction/corner/New()
	icon_state = "construction_corner"

/obj/structure/barricade/construction/flashing
	icon_state = "construction2"
	light_range = 2
	light_power = 1
	light_color = "#9c2154"

/obj/structure/barricade/construction/flashing/New()
	..()
	name = "construction barrier"
	icon_state = "construction2"
	if (dir == NORTH)
		pixel_y = 6

/obj/structure/barricade/steel_crowd
	name = "steel crowd control barrier"
	desc = "A steel barrier used to control pedestrian traffic."
	icon_state = "crowd_barrier"
	health = 50
	maxhealth = 50
	material_name = "steel"
	protection_chance = 5
	opacity = FALSE
	density = TRUE
	anchored = FALSE

/obj/structure/barricade/steel_crowd/New()
	name = "steel crowd control barrier"
	icon_state = "crowd_barrier"

/obj/structure/shelf
	name = "shelf"
	desc = "A store shelf."
	icon = 'icons/obj/junk.dmi'
	icon_state = "shelf0"

/obj/structure/shelf/attackby(obj/item/W as obj, mob/living/human/user as mob)
	if (user.a_intent == I_HELP)
		user.drop_from_inventory(W)
		W.forceMove(loc)
		user << "You put \the [W] on the [src]."
	else
		..()

/obj/structure/shelf/palette
	name = "wooden palette"
	desc = "A wooden palette which is used by forklifts"
	icon_state = "palette"
	anchored = FALSE
	density = TRUE

/obj/structure/barricade/car
	name = "car"
	desc = "An abandoned car."
	icon = 'icons/obj/obj64x42.dmi'
	icon_state = "car1"
	health = 450
	maxhealth = 450
	material_name = "iron"
	protection_chance = 80
	bound_width = 64
	layer = MOB_LAYER + 0.4

/obj/structure/barricade/car/New()
	..()
	icon_state = pick("car1","car2","car3")
	name = "car"


/obj/structure/barricade/jap
	name = "shingled stone wall"
	desc = "A wall of stone blocks with some red shingles."
	icon = 'icons/turf/walls.dmi'
	icon_state = "japwall0"
	var/base_icon_state = "japwall"
	material = "stone"
	health = 2709
	maxhealth = 2709
	material_name = "stone"
	protection_chance = 100
	var/adjusts = TRUE
	applies_material_colour = FALSE

/obj/structure/barricade/jap/check_relatives(var/update_self = FALSE, var/update_others = FALSE)
	if (!adjusts)
		return
	var/junction
	if (update_self)
		junction = FALSE
	for (var/checkdir in cardinal)
		var/turf/T = get_step(src, checkdir)
		for(var/atom/CV in T)
			if (!can_join_with(CV))
				continue
			if (update_self)
				if (can_join_with(CV))
					junction |= get_dir(src,CV)
			if (update_others)
				CV.check_relatives(1,0)
	if (!isnull(junction))
		icon_state = "[base_icon_state][junction]"
	return

/obj/structure/barricade/jap/can_join_with(var/atom/W)
	if (istype(W,src))
		return TRUE
	return FALSE

/obj/structure/barricade/jap/update_icon()
	..()
	check_relatives(1,1)
/obj/structure/barricade/jap/New()
	..()
	check_relatives(1,1)

/obj/structure/barricade/jap/Destroy()
	check_relatives(0,1)
	..()

/obj/structure/barricade/jap/ex_act(severity)
	if (map.ID != "WHITERUN")
		switch(severity)
			if (1.0)
				health -= 150
			if (2.0)
				health -= 100
			if (3.0)
				health -= 50
		if (health <= 0)
			visible_message("<span class='danger'>\The [src] is blown apart!</span>")
			qdel(src)
			return
	else
		return

/obj/structure/barricade/jap/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/siegeladder))
		visible_message(
			"<span class='danger'>\The [user] starts deploying \the [W.name].</span>",
			"<span class='danger'>You start deploying \the [W.name].</span>")
		if (do_after(user, 80, src))
			visible_message(
				"<span class='danger'>\The [user] has deployed \the [W.name]!</span>",
				"<span class='danger'>You have deployed \the [W.name]!</span>")
			qdel(W)
			var/obj/item/weapon/siegeladder/ANCH = new/obj/item/weapon/siegeladder(src.loc)
			ANCH.anchored = TRUE
			src.climbable = TRUE
			ANCH.deployed = TRUE
			ANCH.icon_state = ANCH.depicon
			ANCH.dir = src.dir
			return
	if (istype(W,/obj/item/weapon) || !istype(W,/obj/item/weapon/wrench) || !istype(W,/obj/item/weapon/hammer)) //No weapons can harm me! If not weapon and not a wrench.
		user << "You hit the wall uselessly!"//sucker
		return
	else
		..()

/obj/structure/barricade/jap/tall
	name = "tall shingled stone wall"
	desc = "A wall of stone blocks with some red shingles. This one is rather tall."
	icon = 'icons/turf/tallwalls.dmi'
	icon_state = "japwall0"
	base_icon_state = "japwall"
	material = "stone"
	health = 2709
	maxhealth = 2709
	material_name = "stone"
	protection_chance = 100
	adjusts = TRUE
	layer = MOB_LAYER + 0.1