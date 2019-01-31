// Basically they are for the firing range
/obj/structure/target_practice
	name = "target practice dummy"
	desc = "A wood platform, covered in straw. Used for training both melee and ranged weapons."
	icon = 'icons/obj/objects.dmi'
	icon_state = "target_dummy"
	density = TRUE
	w_class = 5
	var/health = 100
	not_movable = FALSE
	not_disassemblable = FALSE
/obj/structure/target_practice/attackby(obj/item/W as obj, mob/living/carbon/human/user as mob)

	if (istype(W, /obj/item/weapon/material))
		user.setClickCooldown(W.cooldownw)
		visible_message("<span class='notice'>[user] [pick(W.attack_verb)] the training dummy with the [W]!</span>","<span class='notice'>You have [W.attack_verb] the training dummy with the [W]!</span>")
		playsound(get_turf(src), W.hitsound, 100)
		user.do_attack_animation(src)
		health -= 5
		check_health()
		if (prob(20))
			if (prob(80))
				user.adaptStat("swords", 1)
			else
				user.adaptStat("strength", 1)
			return
		else
			return
	else
		..()
/obj/structure/target_practice/attack_hand(mob/living/carbon/human/user as mob)
	if (user.a_intent == I_HURT)
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
				user.adaptStat("strength", 1)
			else
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
					H.adaptStat("rifle", 1)
				if (GUN_TYPE_PISTOL)
					H.adaptStat("pistol", 1)
				if (GUN_TYPE_BOW)
					H.adaptStat("bows", 1)
		else
			return
		visible_message("<span class='notice'>[H] hits the target with the [proj]!</span>","<span class='notice'>You hit the target with the [proj]!</span>")

	return

/obj/structure/target_practice/proc/check_health()
	if (health <= 0)
		visible_message("<span class='notice'>The dummy is broken apart!</span>")
		qdel(src)
		return
	else
		return