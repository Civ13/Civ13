/obj/item/weapon/gun/launcher/rocket
	name = "rocket launcher"
	desc = ""
	icon_state = "rocket"
	item_state = "rocket"
	w_class = 4.0
	throw_speed = 2
	throw_range = 10
	force = 5.0
	flags =  CONDUCT
	slot_flags = FALSE
//	origin_tech = list(TECH_COMBAT = 8, TECH_MATERIAL = 5)
	fire_sound = 'sound/effects/bang.ogg'

	release_force = 3
	throw_distance = 10
	var/max_rockets = TRUE
	var/list/rockets = new/list()

/obj/item/weapon/gun/launcher/rocket/examine(mob/user)
	if (!..(user, 2))
		return
	user << "<span class = 'notice'>[rockets.len] / [max_rockets] rockets.</span>"

/obj/item/weapon/gun/launcher/rocket/attackby(obj/item/I as obj, mob/user as mob)
	if (..()) // handle attachments
		return TRUE

	if (istype(I, /obj/item/ammo_casing/rocket))
		if (rockets.len < max_rockets)
			user.drop_item()
			I.loc = src
			rockets += I
			user << "<span class = 'notice'>You put the rocket in [src].</span>"
			user << "<span class = 'notice'>[rockets.len] / [max_rockets] rockets.</span>"
		else
			usr << "<span class = 'red'>[src] cannot hold more rockets.</span>"

/obj/item/weapon/gun/launcher/rocket/consume_next_projectile()
	if (rockets.len)
		var/obj/item/ammo_casing/rocket/I = rockets[1]
		var/obj/item/projectile/bullet/rifle/missile/M = new I.projectile_type (src)
	//	M.primed = TRUE
		rockets -= I
		qdel(I)
		return M
	return null

/obj/item/weapon/gun/launcher/rocket/handle_post_fire(mob/user, atom/target)
	message_admins("[key_name_admin(user)] fired a rocket from a rocket launcher ([name]) at [target].")
	log_game("[key_name_admin(user)] used a rocket launcher ([name]) at [target].")
	..()
