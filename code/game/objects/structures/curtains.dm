// 2017-07-06: Defeated the curtain man meme (they were unanchored) -- Irra

/obj/structure/curtain
	name = "curtain"
	icon = 'icons/obj/curtain.dmi'
	icon_state = "closed"
	layer = MOB_LAYER + 0.03 // above new windows
	anchored = TRUE
	opacity = TRUE
	density = FALSE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = TRUE

/obj/structure/curtain/open
	icon_state = "open"
	opacity = FALSE

/obj/structure/curtain/bullet_act(obj/item/projectile/P, def_zone)
	if (!P.nodamage)
		visible_message("<span class='warning'>[P] tears [src] down!</span>")
		qdel(src)
	else
		..(P, def_zone)

/obj/structure/curtain/attack_hand(mob/user)
	playsound(get_turf(loc), "rustle", 50, TRUE, -5)
	toggle()
	..()

/obj/structure/curtain/proc/toggle()
	opacity = !opacity
	if (opacity)
		icon_state = "closed"
	else
		icon_state = "open"
	for (var/atom/movable/lighting_overlay/L in view(7*3, src))
		L.update_overlay()

/obj/structure/curtain/Destroy()
	for (var/atom/movable/lighting_overlay/L in view(7*3, src))
		L.update_overlay()
	..()

/obj/structure/curtain/black
	name = "black curtain"
	color = "#222222"

/obj/structure/curtain/medical
	name = "plastic curtain"
	color = "#B8F5E3"
	alpha = 200

/obj/structure/curtain/open/bed
	name = "bed curtain"
	color = "#854636"

/obj/structure/curtain/open/privacy
	name = "privacy curtain"
	color = "#B8F5E3"

/obj/structure/curtain/open/shower
	name = "shower curtain"
	color = "#ACD1E9"
	alpha = 200

/obj/structure/curtain/leather
	name = "leather curtain"
	color = "#624a2e"

/obj/structure/curtain/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (user.a_intent == I_HELP)
		if ((istype(W, /obj/item/weapon/material/kitchen/utensil/knife)))
			visible_message("<span class='warning'>[user] starts to cut down \the [src].</span>")
			playsound(src, 'sound/items/poster_ripped.ogg', 100, TRUE)
			if (do_after(user,50,src))
				visible_message("<span class='warning'>[user] cuts down \the [src].</span>")
				qdel(src)
				return

/obj/structure/curtain/leather/open
	icon_state = "open"
	opacity = FALSE

/obj/structure/curtain/open/shower/engineering
	color = "#FFA500"

/obj/structure/curtain/open/shower/security
	color = "#AA0000"

#undef SHOWER_OPEN_LAYER
#undef SHOWER_CLOSED_LAYER
