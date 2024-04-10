/obj/item/weapon/gun
	var/gun_safety = FALSE
	var/safetyon = FALSE
	var/obj/item/weapon/attachment/scope/scope = null
	var/obj/item/weapon/attachment/under/under = null
	var/pocket = FALSE

/obj/item/weapon/gun/Destroy()
	attachments = null
	contents = null
	..()

/obj/item/weapon/gun/attackby(obj/item/I, mob/user)
	if (istype(I, /obj/item/weapon/attachment))
		var/obj/item/weapon/attachment/A = I
		if (A.attachable)
			try_attach(A, user)
	if (istype(I, /obj/item/weapon/gun/launcher/grenade/underslung))
		var/obj/item/weapon/gun/launcher/grenade/underslung/G = I
		try_attach(G, user)
	..()

/obj/item/weapon/gun/projectile
	var/accuracy_increase_mod = 1.00
	var/accuracy_decrease_mod = 1.00
	var/KD_chance = 5
	var/load_delay = 0

	equiptimer = 10

	stat = "rifle"

	var/headshot_kill_chance = 40 // if we have enough damage. See projectile.dm if you want to know why this needs to be set to 40 for all guns - Kachnov
	var/KO_chance = 33 // even if we fail to kill with a headshot, chance to make the target go unconscious

	// does not need to include all organs

	var/aim_miss_chance_divider = 1.50
	var/mob/living/human/firer = null
	var/blackpowder = FALSE
	secondary_action = TRUE

/obj/item/weapon/gun/projectile/secondary_attack_self(mob/living/human/user)
	if (gun_safety)
		if (safetyon)
			safetyon = FALSE
			user << "<span class='notice'>You toggle \the [src]'s safety <b>OFF</b>.</span>"
			return
		else
			safetyon = TRUE
			user << "<span class='notice'>You toggle \the [src]'s safety <b>ON</b>.</span>"
			return

/obj/item/weapon/gun/projectile/special_check(var/mob/user)
	if (gun_safety && safetyon)
		user << "<span class='warning'>You can't fire \the [src] while the safety is on!</span>"
		return FALSE
	return ..()
