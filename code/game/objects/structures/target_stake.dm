// Basically they are for the firing range
/obj/structure/target_practice
	name = "target practice dummy"
	desc = "A wood platform, covered in straw. Used for training both melee and ranged weapons."
	icon = 'icons/obj/objects.dmi'
	icon_state = "target_dummy"
	var/wreckage_icon = "target_dummy_wreckage"
	density = TRUE
	w_class = 5
	var/health = 100
	not_movable = FALSE
	not_disassemblable = FALSE
	var/ranged = TRUE
	var/melee = TRUE
	var/humanoid = TRUE

/obj/structure/target_practice/indestructible

/obj/structure/target_practice/indestructible/check_health()
	return

/obj/structure/target_practice/indestructible/ex_act()
	return
/obj/structure/target_practice/attackby(obj/item/W as obj, mob/living/carbon/human/user as mob)
	if (istype(W, /obj/item/weapon/dummy_armor))
		if(src.humanoid)
			visible_message("<span class='notice'>[user] put [W] on the [src]!</span>","<span class='notice'>You put [W] on the [src]!</span>")
			src.icon_state = icon_state + "_armor"
			src.health += 200
			qdel(W)
		else
			user << "<span class='notice'>That doesn't fit on [src]</span>"
	if (istype(W, /obj/item/weapon/material))
		user.setClickCooldown(W.cooldownw)
		if (W.attack_verb.len)
			visible_message("<span class='notice'>[user] [pick(W.attack_verb)] the training dummy with the [W]!</span>","<span class='notice'>You have [pick(W.attack_verb)] the training dummy with the [W]!</span>")
		else
			visible_message("<span class='notice'>[user] hit the training dummy with the [W]!</span>","<span class='notice'>You have hit the training dummy with the [W]!</span>")

		playsound(get_turf(src), W.hitsound, 100)
		user.do_attack_animation(src)
		health -= 5
		check_health()
		if (prob(20))
			if (prob(80))
				if(melee)
					user.adaptStat("swords", 1)
			else
				if(melee)
					user.adaptStat("strength", 1)
			return
		else
			return
	else
		..()
/obj/structure/target_practice/attack_hand(mob/living/carbon/human/user as mob)
	if (user.a_intent == I_HARM)
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		if (prob(67))
			visible_message("<span class='notice'>[user] punches the training dummy!</span>","<span class='notice'>You punch the training dummy!</span>")
		else
			visible_message("<span class='notice'>[user] kicks the training dummy!</span>","<span class='notice'>You kick the training dummy!</span>")
		playsound(get_turf(src), pick('sound/weapons/punch1.ogg','sound/weapons/punch2.ogg','sound/weapons/punch3.ogg'), 100)
		user.do_attack_animation(src)
		health -= 2
		check_health()
		if (prob(20))
			if (prob(60))
				if(melee)
					user.adaptStat("strength", 1)
			else
				if(melee)
					user.adaptStat("dexterity", 1)
			return
		else
			return
	else
		..()

/obj/structure/target_practice/bullet_act(var/obj/item/projectile/proj)
	if (proj.firer && ishuman(proj.firer) && proj.firedfrom)
		var/mob/living/carbon/human/H = proj.firer
		health -= 8
		check_health()
		if (prob(40))
			switch (proj.firedfrom.gun_type)
				if (GUN_TYPE_RIFLE)
					if(ranged)
						H.adaptStat("rifle", 1)
				if (GUN_TYPE_PISTOL)
					if(ranged)
						H.adaptStat("pistol", 1)
				if (GUN_TYPE_BOW)
					if(ranged)
						H.adaptStat("bows", 1)
		else
			return
		visible_message("<span class='notice'>[H] hits the target with the [proj]!</span>","<span class='notice'>You hit the target with the [proj]!</span>")

	return

/obj/structure/target_practice/proc/check_health()
	if (health <= 0)
		visible_message("<span class='notice'>The dummy is broken apart!</span>")
		var/obj/structure/target_practice_wreckage/JUNK = new /obj/structure/target_practice_wreckage(src.loc)
		JUNK.target_type = src
		JUNK.icon = src.wreckage_icon
		qdel(src)
		return
	else
		return

/obj/structure/target_practice/ex_act()
	visible_message("\The [src] blows up!")
	qdel(src)
	return

/obj/item/weapon/dummy_armor
	name = "dummy armor"
	desc = "A set of preadjusted cheap armor, to extend the life of a training dummy."
	icon = 'icons/obj/objects.dmi'
	icon_state = "dummy_armor"
	w_class = 3.0
	throwforce = FALSE
	throw_speed = 1
	throw_range = 3

/obj/structure/target_practice_wreckage/
	name = "dummy wreckage"
	desc = "The wreckage of a training dummy. Can be fixed with wood."
	icon = 'icons/obj/objects.dmi'
	icon_state = "target_dummy_wreckage"
	var/target_type = /obj/structure/target_practice
	density = TRUE
	w_class = 5
	var/health = 10
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/target_practice_wreckage/attackby(obj/item/W as obj, mob/living/carbon/human/user as mob)
	var/mob/living/carbon/human/H = user
	if(istype(W, /obj/item/stack/material/wood))
		if(W.amount >= 3)
			visible_message("<span class='danger'>[user] starts repairing the dummy..</span>")
			if(do_after(H, (60 / H.getStatCoeff("crafting")), H.loc))
				visible_message("<span class='danger'>[user] finishes repairing the dummy.</span>")
				W.amount -= 3
				if(W.amount <= 0)
					qdel(W)
				new target_type(src.loc)
				qdel(src)
				if (ishuman(user))
					H.adaptStat("crafting", 1)

/obj/structure/target_practice/target
	name = "target practice target"
	desc = "A wood target, covered in straw. Used for training ranged weapons."
	icon = 'icons/obj/objects.dmi'
	icon_state = "target_dummy_target"
	density = TRUE
	w_class = 5
	health = 100
	not_movable = FALSE
	not_disassemblable = FALSE
	ranged = TRUE
	melee = FALSE
	humanoid = FALSE