/obj/item/weapon
	name = "weapon"
	icon = 'icons/obj/weapons.dmi'
	hitsound = "swing_hit"
	var/drawsound = null

/obj/item/weapon/Bump(mob/M as mob)
	spawn(0)
		..()
	return

/obj/item/weapon/pickup(mob/user)
	drawsound(user)

/obj/item/weapon/proc/drawsound(mob/user)
	if (drawsound)
		user.visible_message("<span class = 'warning'><b>[user] draws a weapon!</b></span>")
		playsound(user, drawsound, 50, 1)

