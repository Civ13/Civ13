/obj/structure/girder
	icon_state = "girder"
	anchored = TRUE
	density = TRUE
	layer = 2.04 // above snow
	w_class = 5
	var/state = FALSE
	var/health = 200
	var/cover = 50 //how much cover the girder provides against projectiles.
	var/material/reinf_material
	var/reinforcing = FALSE

/obj/structure/girder/displaced
	icon_state = "displaced"
	anchored = FALSE
	health = 50
	cover = 25

/obj/structure/girder/attack_generic(var/mob/user, var/damage, var/attack_message = "smashes apart", var/wallbreaker)
	if (!damage || !wallbreaker)
		return FALSE
	attack_animation(user)
	visible_message("<span class='danger'>[user] [attack_message] the [src]!</span>")
	spawn(1) dismantle()
	return TRUE

/obj/structure/girder/bullet_act(var/obj/item/projectile/Proj)
	//Girders only provide partial cover. There's a chance that the projectiles will just pass through. (unless you are trying to shoot the girder)
	if (Proj.original != src && !prob(cover))
		return PROJECTILE_CONTINUE //pass through

	var/damage = Proj.get_structure_damage()
	if (!damage)
		return

/*	if (!istype(Proj, /obj/item/projectile/beam))*/
	damage *= 0.4 //non beams do reduced damage

	health -= damage
	..()
	if (health <= 0)
		dismantle()

	return

/obj/structure/girder/proc/reset_girder()
	anchored = TRUE
	cover = initial(cover)
	health = min(health,initial(health))
	state = FALSE
	icon_state = initial(icon_state)
	reinforcing = FALSE
	if (reinf_material)
		reinforce_girder()

/obj/structure/girder/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/wrench) && state == FALSE)
		if (anchored && !reinf_material)
			playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
			user << "<span class='notice'>Now disassembling the girder...</span>"
			if (do_after(user, 40,src))
				if (!src) return
				user << "<span class='notice'>You dissasembled the girder!</span>"
				dismantle()
		else if (!anchored)
			playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
			user << "<span class='notice'>Now securing the girder...</span>"
			if (get_turf(user, 40))
				user << "<span class='notice'>You secured the girder!</span>"
				reset_girder()

	else if (istype(W, /obj/item/weapon/screwdriver))
		if (state == 2)
			playsound(loc, 'sound/items/Screwdriver.ogg', 100, TRUE)
			user << "<span class='notice'>Now unsecuring support struts...</span>"
			if (do_after(user, 40,src))
				if (!src) return
				user << "<span class='notice'>You unsecured the support struts!</span>"
				state = TRUE
		else if (anchored && !reinf_material)
			playsound(loc, 'sound/items/Screwdriver.ogg', 100, TRUE)
			reinforcing = !reinforcing
			user << "<span class='notice'>\The [src] can now be [reinforcing? "reinforced" : "constructed"]!</span>"

	else if (istype(W, /obj/item/weapon/wirecutters) && state == TRUE)
		playsound(loc, 'sound/items/Wirecutter.ogg', 100, TRUE)
		user << "<span class='notice'>Now removing support struts...</span>"
		if (do_after(user, 40,src))
			if (!src) return
			user << "<span class='notice'>You removed the support struts!</span>"
			reinf_material.place_dismantled_product(get_turf(src))
			reinf_material = null
			reset_girder()

	else if (istype(W, /obj/item/weapon/crowbar) && state == FALSE && anchored)
		playsound(loc, 'sound/items/Crowbar.ogg', 100, TRUE)
		user << "<span class='notice'>Now dislodging the girder...</span>"
		if (do_after(user, 40,src))
			if (!src) return
			user << "<span class='notice'>You dislodged the girder!</span>"
			icon_state = "displaced"
			anchored = FALSE
			health = 50
			cover = 25

	else if (istype(W, /obj/item/stack/material))
		if (reinforcing && !reinf_material)
			if (!reinforce_with_material(W, user))
				return ..()
		else
			if (!construct_wall(W, user))
				return ..()

	else
		return ..()

/obj/structure/girder/proc/construct_wall(obj/item/stack/material/S, mob/user)
	if (S.get_amount() < 2)
		user << "<span class='notice'>There isn't enough material here to construct a wall.</span>"
		return FALSE

	var/material/M = name_to_material[S.default_type]
	if (!istype(M))
		return FALSE

	var/wall_fake
	add_hiddenprint(usr)

	if (M.integrity < 50)
		user << "<span class='notice'>This material is too soft for use in wall construction.</span>"
		return FALSE

	user << "<span class='notice'>You begin adding the plating...</span>"

	if (!do_after(user,40,src) || !S.use(2))
		return TRUE //once we've gotten this far don't call parent attackby()

	if (anchored)
		user << "<span class='notice'>You added the plating!</span>"
	else
		user << "<span class='notice'>You create a false wall! Push on it to open or close the passage.</span>"
		wall_fake = TRUE

	var/turf/Tsrc = get_turf(src)
	Tsrc.ChangeTurf(/turf/wall)
	var/turf/wall/T = get_turf(src)
	T.set_material(M, reinf_material)
	if (wall_fake)
		T.can_open = TRUE
	T.add_hiddenprint(usr)
	qdel(src)
	return TRUE

/obj/structure/girder/proc/reinforce_with_material(obj/item/stack/material/S, mob/user) //if the verb is removed this can be renamed.
	if (reinf_material)
		user << "<span class='notice'>\The [src] is already reinforced.</span>"
		return FALSE

	if (S.get_amount() < 2)
		user << "<span class='notice'>There isn't enough material here to reinforce the girder.</span>"
		return FALSE

	var/material/M = name_to_material[S.default_type]
	if (!istype(M) || M.integrity < 50)
		user << "You cannot reinforce \the [src] with that; it is too soft."
		return FALSE

	user << "<span class='notice'>Now reinforcing...</span>"
	if (!do_after(user, 40,src) || !S.use(2))
		return TRUE //don't call parent attackby() past this point
	user << "<span class='notice'>You added reinforcement!</span>"

	reinf_material = M
	reinforce_girder()
	return TRUE

/obj/structure/girder/proc/reinforce_girder()
	cover = reinf_material.hardness
	health = 500
	state = 2
	icon_state = "reinforced"
	reinforcing = FALSE

/obj/structure/girder/proc/dismantle()
	new /obj/item/stack/material/steel(get_turf(src))
	qdel(src)

/obj/structure/girder/attack_hand(mob/user as mob)
	if (HULK in user.mutations)
		visible_message("<span class='danger'>[user] smashes [src] apart!</span>")
		dismantle()
		return
	return ..()


/obj/structure/girder/ex_act(severity)
	switch(severity)
		if (1.0)
			qdel(src)
			return
		if (2.0)
			if (prob(30))
				dismantle()
			return
		if (3.0)
			if (prob(5))
				dismantle()
			return
		else
	return


/obj/structure/girder/cult/dismantle()
	new /obj/item/remains/human(get_turf(src))
	qdel(src)

/obj/structure/girder/cult/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		user << "<span class='notice'>Now disassembling the girder...</span>"
		if (do_after(user,40,src))
			user << "<span class='notice'>You dissasembled the girder!</span>"
			dismantle()