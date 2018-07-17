// WIRES

/obj/item/weapon/wire
	desc = "This is just a simple piece of regular insulated wire."
	name = "wire"
	icon = 'icons/obj/power.dmi'
	icon_state = "item_wire"
	var/amount = 1.0
	var/laying = 0.0
	var/old_lay = null
	matter = list(DEFAULT_WALL_MATERIAL = 40)
	attack_verb = list("whipped", "lashed", "disciplined", "tickled")

/obj/item/weapon/wire/proc/update()
	if (amount > 1)
		icon_state = "spool_wire"
		desc = text("This is just spool of regular insulated wire. It consists of about [] unit\s of wire.", amount)
	else
		icon_state = "item_wire"
		desc = "This is just a simple piece of regular insulated wire."
	return

/obj/item/weapon/wire/attack_self(mob/user as mob)
	if (laying)
		laying = FALSE
		user << "<span class='notice'>You're done laying wire!</span>"
	else
		user << "<span class='warning'>You are not using this to lay wire...</span>"
	return
