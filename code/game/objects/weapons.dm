/obj/item/weapon
	name = "weapon"
	icon = 'icons/obj/weapons.dmi'
	hitsound = "swing_hit"
	var/drawsound = null
	var/warning_played = null
	var/image/bayonet_ico
	var/image/optics_ico
	var/image/under_ico

/obj/item/weapon/Bump(mob/M as mob)
	spawn(0)
		..()
	return

/obj/item/weapon/pickup(mob/user)
	drawsound(user)

/obj/item/weapon/proc/drawsound(mob/user)
	if (drawsound && !warning_played)
		user.visible_message("<span class = 'warning'><b>[user] draws a weapon!</b></span>")
		warning_played = TRUE
		playsound(user, drawsound, 50, 1)
	spawn(10)
		warning_played = FALSE

/obj/item/weapon/gun/projectile/New()
	..()
	bayonet_ico = image("icon" = 'icons/obj/gun.dmi', "icon_state" = "bayonet")
	optics_ico = image("icon" = 'icons/obj/gun_att.dmi', "icon_state" = "")
	under_ico = image("icon" = 'icons/obj/gun_att.dmi', "icon_state" = "")