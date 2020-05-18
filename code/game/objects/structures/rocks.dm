
/obj/structure/wild/rock
	name = "rock"
	icon_state = "rock5"
	icon = 'icons/obj/flora/rocks.dmi'
	deadicon = 'icons/obj/flora/rocks.dmi'
	deadicon_state = "rock5"
	opacity = FALSE
	density = FALSE
	flammable = FALSE
	amount = 0
	health = 20
	maxhealth = 20
	var/flint_amount = 5
	var/rocktype = "rock"

/obj/structure/wild/rock/basalt
	icon_state = "basalt1"
	rocktype = "basalt"
	density = TRUE
	maxhealth = 60
	health = 60

/obj/structure/wild/rock/attack_hand(var/mob/living/human/H)
	if (H.a_intent == I_GRAB)
		H << "You start looking for some flint among the rocks..."
		if (do_after(H, 50, H.loc) && flint_amount > 0)
			H << "You find some flint."
			flint_amount--
			var/obj/item/weapon/flint/newflint = new/obj/item/weapon/flint(src.loc)
			H.put_in_hands(newflint)
			flint_regen()
		return
	else
		..()

/obj/structure/wild/rock/attackby(var/obj/item/weapon/W, var/mob/living/human/H)
	if (istype(W, /obj/item/weapon/flint))
		H.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		var/obj/item/weapon/flint/F = W
		if (!F.sharpened)
			H << "<span class='warning'>You hit the rock with \the [W].</span>"
			playsound(src,'sound/effects/Stamp.ogg',100,1)
			if (prob(20))
				H << "\The [W] chips away, exposing a sharp edge!"
				F.sharpen()
		return

	..()

/obj/structure/wild/rock/proc/flint_regen()
	spawn(18000)
		if (src && flint_amount < 5)
			flint_amount++
		return

/obj/structure/wild/rock/New()
	..()
	icon_state = "[rocktype][rand(1,5)]"
	deadicon = 'icons/obj/flora/rocks.dmi'
	deadicon_state = "[rocktype][rand(1,5)]"

/obj/item/weapon/flint
	name = "flint"
	desc = "A small piece of flint rock."
	icon_state = "flint"
	item_state = ""
	icon = 'icons/obj/old_weapons.dmi'
	force = 5
	sharp = FALSE
	edge = FALSE
	w_class = 1.0
	throw_speed = 7
	throw_range = 10
	allow_spin = TRUE
	attack_verb = list("hit","bashed")
	value = 1
	cooldownw = 5
	flammable = FALSE
	var/sharpened = FALSE

/obj/item/weapon/flint/sharpened
	name = "sharpened flint"
	desc = "A small piece of sharpened flint rock."
	icon_state = "sharpened_flint"
	edge = TRUE
	sharp = TRUE
	attack_verb = list("cut","stabbed")
	sharpened = TRUE
	force = 12

/obj/item/weapon/flint/proc/sharpen()
	if (!sharpened)
		name = "sharpened flint"
		desc = "A small piece of sharpened flint rock."
		icon_state = "sharpened_flint"
		edge = TRUE
		sharp = TRUE
		attack_verb = list("cut","stabbed")
		sharpened = TRUE
		force = 12
	return