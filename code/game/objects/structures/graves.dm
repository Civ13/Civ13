/obj/structure/religious/gravestone
	name = "gravestone"
	desc = "A gravestone made with polished stone."
	icon = 'icons/obj/cross.dmi'
	icon_state = "gravestone"
	density = FALSE
	anchored = TRUE
	var/health = 100

/obj/structure/religious/totem
	name = "stone totem"
	desc = "A stone statue, representing the spirit animal of this tribe."
	icon = 'icons/obj/cross.dmi'
	icon_state = "goose"
	density = TRUE
	anchored = TRUE
	var/tribe = "goose"
	layer = 3.2
	var/health = 100

/obj/structure/religious/woodcross1
	name = "small wood cross"
	desc = "A small engraved wood cross."
	icon = 'icons/obj/cross.dmi'
	icon_state = "cross1"
	density = FALSE
	anchored = TRUE
	var/health = 50

/obj/structure/religious/woodcross2
	name = "wood cross"
	desc = "An engraved wood cross."
	icon = 'icons/obj/cross.dmi'
	icon_state = "cross2"
	density = FALSE
	anchored = TRUE
	var/health = 50

/obj/structure/religious/grave
	name = "open_grave"
	desc = "An opened grave."
	icon = 'icons/obj/cross.dmi'
	icon_state = "grave_overlay"
	density = FALSE
	anchored = TRUE


/obj/structure/religious/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/wrench) && not_movable == TRUE)
		return
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	switch(W.damtype)
		if ("fire")
			health -= W.force * 0.3
		if ("brute")
			health -= W.force * 0.3

	playsound(get_turf(src), 'sound/weapons/smash.ogg', 100)
	user.do_attack_animation(src)
	try_destroy()
	..()

/obj/structure/religious/proc/try_destroy()
	if (health <= 0)
		visible_message("<span class='danger'>The [src] is broken into pieces!</span>")
		qdel(src)
		return