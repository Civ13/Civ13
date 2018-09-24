/obj/structure/religious
	name = "gravestone"
	desc = "A gravestone made with polished stone."
	icon = 'icons/obj/cross.dmi'
	icon_state = "gravestone"
	var/health = 100
/obj/structure/religious/gravestone
	name = "gravestone"
	desc = "A gravestone made with polished stone."
	icon = 'icons/obj/cross.dmi'
	icon_state = "gravestone"
	density = FALSE
	anchored = TRUE

/obj/structure/religious/totem
	name = "stone totem"
	desc = "A stone statue, representing the spirit animal of this tribe."
	icon = 'icons/obj/cross.dmi'
	icon_state = "goose"
	density = TRUE
	anchored = TRUE
	var/tribe = "goose"
	layer = 3.2

/obj/structure/religious/woodcross1
	name = "small wood cross"
	desc = "A small engraved wood cross."
	icon = 'icons/obj/cross.dmi'
	icon_state = "cross1"
	density = FALSE
	anchored = TRUE
	health = 50

/obj/structure/religious/woodcross2
	name = "wood cross"
	desc = "An engraved wood cross."
	icon = 'icons/obj/cross.dmi'
	icon_state = "cross2"
	density = FALSE
	anchored = TRUE
	health = 50

/obj/structure/religious/grave
	name = "open_grave"
	desc = "An opened grave."
	icon = 'icons/obj/cross.dmi'
	icon_state = "grave_overlay"
	density = FALSE
	anchored = TRUE

/obj/structure/religious/impaledskull
	name = "impaled skull"
	desc = "A skull on a spike."
	icon = 'icons/obj/structures.dmi'
	icon_state = "impaledskull"

/obj/structure/religious/tribalmask
	name = "native wood mask"
	desc = "A decorative wood mask."
	icon = 'icons/misc/tribal.dmi'
	icon_state = "tribalmask1"

/obj/structure/religious/remains
	name = "human remains"
	desc = "A bunch of human bones. Spooky."
	icon = 'icons/misc/tribal.dmi'
	icon_state = "remains1"

/obj/structure/religious/remains/New()
	..()
	icon_state = "remains[rand(1,6)]"

/obj/structure/religious/tribalmask/New()
	..()
	icon_state = "tribalmask[rand(1,2)]"

/obj/structure/religious/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/wrench))
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