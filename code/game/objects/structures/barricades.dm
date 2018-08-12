/obj/structure/barricade
	name = "barricade"
	desc = "This space is blocked off by a barricade."
	icon = 'icons/obj/structures.dmi'
	icon_state = "barricade"
	anchored = TRUE

	density = TRUE
	var/health = 100
	var/maxhealth = 100
	var/material/material

/obj/structure/barricade/New(var/newloc, var/material_name)
	..(newloc)
	if (!material_name)
		material_name = "wood"
	material = get_material_by_name("[material_name]")
	if (!material)
		qdel(src)
		return
	name = "[material.display_name] barricade"
	desc = "This space is blocked off by a barricade made of [material.display_name]."
	if (istype(material, /material/wood))
		icon_state = "wood_barricade"
	else
		color = material.icon_colour
	maxhealth = (material.integrity*2.5) + 100
	health = maxhealth

/obj/structure/barricade/get_material()
	return material

/obj/structure/barricade/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack))
		var/obj/item/stack/D = W
		if (D.get_material_name() != material.name)
			return //hitting things with the wrong type of stack usually doesn't produce messages, and probably doesn't need to.
		if (health < maxhealth)
			if (D.get_amount() < 1)
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
	material.place_dismantled_product(get_turf(src))
	qdel(src)
	return

/obj/structure/barricade/ex_act(severity)
	switch(severity)
		if (1.0)
			visible_message("<span class='danger'>\The [src] is blown apart!</span>")
			qdel(src)
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
		return prob(15)
	else
		return FALSE

/obj/structure/barricade/bullet_act(var/obj/item/projectile/proj)
	health -= proj.damage
	visible_message("<span class='warning'>\The [src] is hit by the [proj.name]!</span>")
	try_destroy()

/obj/structure/barricade/horizontal
	name = "wood barrier"
	desc = "A wood wall made of vines and logs roped together."
	icon_state = "woodbarricade_horizontal"

/obj/structure/barricade/vertical
	name = "wood barrier"
	desc = "A wood wall made of vines and logs roped together."
	icon_state = "woodbarricade_vertical"

/obj/structure/barricade/vertical/New()
	..()
	icon_state = "woodbarricade_vertical"
/obj/structure/barricade/horizontal/New()
	..()
	icon_state = "woodbarricade_horizontal"
// steel barricades

/obj/structure/barricade/steel

/obj/structure/barricade/steel/New(_loc)
	..(_loc, DEFAULT_WALL_MATERIAL)