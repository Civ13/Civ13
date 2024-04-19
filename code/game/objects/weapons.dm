/obj/item/weapon
	name = "weapon"
	icon = 'icons/obj/weapons.dmi'
	hitsound = "swing_hit"
	flags = CONDUCT
	item_icons = list(
		slot_l_hand_str = 'icons/mob/items/lefthand_weapons.dmi',
		slot_r_hand_str = 'icons/mob/items/righthand_weapons.dmi',
		)
	var/drawsound = null
	var/warning_played = null
	var/training = FALSE
	New()
		maxhealth = health
		..()
		maxhealth = health

/obj/item/weapon/New()
	..()
	force*=global_damage_modifier

/obj/item/weapon/Bump(mob/M as mob)
	spawn(0)
		..()
	return

/obj/item/weapon/pickup(mob/user)
	drawsound(user)

/obj/item/weapon/proc/drawsound(mob/user)
	if (drawsound && !warning_played)
		user.visible_message(SPAN_WARNING("<b>[user] draws a weapon!</b></span>"), SPAN_WARNING("<b>You draw a weapon!</b>"))
		warning_played = TRUE
		playsound(user, drawsound, 50, 1)
	spawn(10)
		warning_played = FALSE
/obj/item/weapon/gun
	var/gtype = "rifle"
