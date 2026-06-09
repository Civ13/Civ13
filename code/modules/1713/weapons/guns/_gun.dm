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
	var/KD_chance = 5
	var/load_delay = 0

	equiptimer = 10

	stat = "rifle"


	// does not need to include all organs

	var/mob/living/human/firer = null
	var/blackpowder = FALSE
	secondary_action = TRUE

/obj/item/weapon/gun/projectile/secondary_attack_self(mob/living/human/user)
	if (gun_safety)
		if (safetyon)
			safetyon = FALSE
			to_chat(user, "<span class='notice'>You toggle \the [src]'s safety <b>OFF</b>.</span>")
			return
		else
			safetyon = TRUE
			to_chat(user, "<span class='notice'>You toggle \the [src]'s safety <b>ON</b>.</span>")
			return

/obj/item/weapon/gun/projectile/special_check(var/mob/user)
	if (gun_safety && safetyon)
		to_chat(user, "<span class='warning'>You can't fire \the [src] while the safety is on!</span>")
		return FALSE
	return ..()
