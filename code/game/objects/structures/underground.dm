// diggable earth. For tunnels. Cloned and edited from barricades -Taislin

/obj/structure/underground
	name = "Soft Earth"
	desc = "This space is blocked off by soft earth and rocks. Can be digged."
	icon = 'icons/turf/walls.dmi'
	icon_state = "rock"
	anchored = TRUE

	density = TRUE
	var/health = 270
	var/maxhealth = 270
	var/attby = FALSE //TRUE if its being dug with a pickaxe - easier to find minerals

/obj/structure/underground/attackby(obj/item/W as obj, mob/user as mob)
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	switch(W.damtype)
		if ("fire")
			health -= W.force * 0.25
			attby = FALSE
		if ("brute")
			if (istype(W, /obj/item/weapon/shovel) || istype(W, /obj/item/weapon/shovel/pickaxe))
				health -= W.force * 2.5
				attby = TRUE
			else
				health -= W.force * 1
				attby = FALSE

	playsound(get_turf(src), 'sound/weapons/slash.ogg', 100)

	user.do_attack_animation(src)

	try_destroy()

	..()

/obj/structure/underground/proc/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>The hole gets bigger!</span>")
		if (attby == TRUE)
			if (prob(20))
				var/obj/item/stack/material/stone/mineral = new/obj/item/stack/material/stone(src)
				mineral.amount = rand(1,4)
				dismantle()
				qdel(src)
				return
			if (prob(20))
				new/obj/item/weapon/ore/iron(src)
				dismantle()
				qdel(src)
				return
			if (prob(5))
				new/obj/item/weapon/ore/silver(src)
				dismantle()
				qdel(src)
				return
			if (prob(2))
				new/obj/item/weapon/ore/gold(src)
				dismantle()
				qdel(src)
				return
			if (prob(1))
				new/obj/item/weapon/ore/diamond(src)
				dismantle()
				qdel(src)
				return
		dismantle()
		qdel(src)
		return

/obj/structure/underground/proc/dismantle()
	return

/obj/structure/underground/ex_act(severity)
	switch(severity)
		if (1.0)
			visible_message("<span class='danger'>\The tunnel wall is blown apart!</span>")
			qdel(src)
			return
		if (2.0)
			health -= (200 + round(maxhealth * 0.30))
			if (health <= 0)
				visible_message("<span class='danger'>\The tunnel wall is blown apart!</span>")
				dismantle()
			return
		if (3.0)
			health -= (100 + round(maxhealth * 0.10))
			if (health <= 0)
				visible_message("<span class='danger'>\The tunnel wall is blown apart!</span>")
				dismantle()
			return

/obj/structure/underground/bullet_act(var/obj/item/projectile/proj)
	health -= proj.damage
	visible_message("<span class='warning'>\The [proj.name] hits the tunnel wall!</span>")
	try_destroy()