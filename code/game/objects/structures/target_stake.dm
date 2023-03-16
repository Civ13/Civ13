// Practice target/dummy for training character skills.
/obj/structure/practice_dummy
	name = "practice dummy"
	desc = "A wood platform, covered in straw. Used for training both melee and ranged weapons."
	icon = 'icons/obj/objects.dmi'
	icon_state = "target_dummy"
	var/target_type = "dummy"
	density = TRUE
	w_class = ITEM_SIZE_HUGE
	var/health = 100
	not_movable = FALSE
	not_disassemblable = FALSE
	var/ranged = TRUE
	var/melee = TRUE
	var/humanoid = TRUE


/obj/structure/practice_dummy/New()
	..()
	name = "practice dummy"
	desc = "A wood platform, covered in straw. Used for training both melee and ranged weapons."
	icon = 'icons/obj/objects.dmi'
	icon_state = "target_dummy"


//As the name says, indestructible version of the dummy.
/obj/structure/practice_dummy/indestructible

/obj/structure/practice_dummy/indestructible/check_health()
	return

/obj/structure/practice_dummy/indestructible/ex_act()
	return

/obj/structure/practice_dummy/attackby(obj/item/W as obj, mob/living/human/user as mob)
	//If the user is holding dummy armor, equips the dummy(not target) with it and increases it's health.
	if (istype(W, /obj/item/weapon/dummy_armor))
		if(src.humanoid)
			visible_message("<span class='notice'>[user] put [W] on \the [src]!</span>","<span class='notice'>You put [W] on \the [src]!</span>")
			src.icon_state = icon_state + "_armor"
			src.health += 200
			qdel(W)
		else
			user << "<span class='notice'>That doesn't fit on [src]</span>"
	//Flavor text when hitting the dummy with weapons.
	if (istype(W, /obj/item/weapon/material))
		user.setClickCooldown(W.cooldownw)
		if (W.attack_verb.len)
			visible_message("<span class='notice'>[user] [pick(W.attack_verb)] \the [src] with \the [W]!</span>","<span class='notice'>You have [pick(W.attack_verb)] \the [src] with \the [W]!</span>")
		else
			visible_message("<span class='notice'>[user] hit \the [src] with \the [W]!</span>","<span class='notice'>You have hit \the [src] with \the [W]!</span>")

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

//Similar to the above, but with bare hands.
/obj/structure/practice_dummy/attack_hand(mob/living/human/user as mob)
	if (user.a_intent == I_HARM)
		user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
		if (prob(67))
			visible_message("<span class='notice'>[user] punches \the [src]!</span>","<span class='notice'>You punch \the [src]!</span>")
		else
			visible_message("<span class='notice'>[user] kicks \the [src]!</span>","<span class='notice'>You kick \the [src]!</span>")
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

//Training ranged skills
/obj/structure/practice_dummy/bullet_act(var/obj/item/projectile/proj)
	if (proj.firer && ishuman(proj.firer) && proj.firedfrom)
		var/mob/living/human/H = proj.firer
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
		visible_message("<span class='notice'>[H] hits \the [src] with \the [proj]!</span>","<span class='notice'>You hit \the [src] with \the [proj]!</span>")
		H << "<font size=4><b>You hit the target!</b></font>"
		//If the user shoots at a target, check if it's an arrow or a bolt and have a chance of dropping the arrow/bolt.
		if(istype(src, /obj/structure/practice_dummy/target))
			if (istype(proj, /obj/item/projectile/arrow/arrow))
				if(prob(75))
					if(istype(proj, /obj/item/projectile/arrow/arrow/stone))
						new/obj/item/ammo_casing/arrow/stone(src.loc)
					else if(istype(proj, /obj/item/projectile/arrow/arrow/flint))
						new/obj/item/ammo_casing/arrow/flint(src.loc)
					else if(istype(proj, /obj/item/projectile/arrow/arrow/sandstone))
						new/obj/item/ammo_casing/arrow/sandstone(src.loc)
					else if(istype(proj, /obj/item/projectile/arrow/arrow/copper))
						new/obj/item/ammo_casing/arrow/copper(src.loc)
					else if(istype(proj, /obj/item/projectile/arrow/arrow/iron))
						new/obj/item/ammo_casing/arrow/iron(src.loc)
					else if(istype(proj, /obj/item/projectile/arrow/arrow/bronze))
						new/obj/item/ammo_casing/arrow/bronze(src.loc)
					else if(istype(proj, /obj/item/projectile/arrow/arrow/steel))
						new/obj/item/ammo_casing/arrow/steel(src.loc)
					else if(istype(proj, /obj/item/projectile/arrow/arrow/modern))
						new/obj/item/ammo_casing/arrow/modern(src.loc)
					else
						new/obj/item/ammo_casing/arrow(src.loc)
					visible_message("<span class = 'warning'>The arrow falls to the ground!</span>")
				else
					visible_message("<span class = 'warning'>The arrow shatters!</span>")
			else if (istype(proj, /obj/item/projectile/arrow/bolt))
				if(prob(75))
					if(istype(proj, /obj/item/projectile/arrow/bolt/stone))
						new/obj/item/ammo_casing/bolt/stone(src.loc)
					else if(istype(proj, /obj/item/projectile/arrow/bolt/flint))
						new/obj/item/ammo_casing/bolt/flint(src.loc)
					else if(istype(proj, /obj/item/projectile/arrow/bolt/sandstone))
						new/obj/item/ammo_casing/bolt/sandstone(src.loc)
					else if(istype(proj, /obj/item/projectile/arrow/bolt/copper))
						new/obj/item/ammo_casing/bolt/copper(src.loc)
					else if(istype(proj, /obj/item/projectile/arrow/bolt/iron))
						new/obj/item/ammo_casing/bolt/iron(src.loc)
					else if(istype(proj, /obj/item/projectile/arrow/bolt/bronze))
						new/obj/item/ammo_casing/bolt/bronze(src.loc)
					else if(istype(proj, /obj/item/projectile/arrow/bolt/steel))
						new/obj/item/ammo_casing/bolt/steel(src.loc)
					else if(istype(proj, /obj/item/projectile/arrow/bolt/modern))
						new/obj/item/ammo_casing/bolt/modern(src.loc)
					else
						new/obj/item/ammo_casing/bolt(src.loc)
					visible_message("<span class = 'warning'>The bolt falls to the ground!</span>")
				else
					visible_message("<span class = 'warning'>The bolt shatters!</span>")
	else
		spawn (0.01)
		qdel(proj)
	return

//Checks the dummy health, if it drops to 0 or below, turns it into a wreckage.
/obj/structure/practice_dummy/proc/check_health()
	if (health <= 0)
		visible_message("<span class='notice'>The training [target_type] is broken apart!</span>")
		var/obj/structure/practice_dummy/wreckage/JUNK = new /obj/structure/practice_dummy/wreckage(src.loc)
		JUNK.target_type = src.target_type //Determines what it was before turning into wreckage and stores it in the variable.
		JUNK.name = "[target_type] wreckage"
		JUNK.desc = "The wreckage of a training [target_type]. Can be fixed with wood."
		qdel(src)
		return
	else
		return

//Explosion result!
/obj/structure/practice_dummy/ex_act()
	visible_message("\The [src] blows up!")
	qdel(src)
	return

//Dummy armor that can be equipped on the training dummy to increase health.
/obj/item/weapon/dummy_armor
	name = "dummy armor"
	desc = "A set of preadjusted cheap armor, to extend the life of a training dummy."
	icon = 'icons/obj/objects.dmi'
	icon_state = "dummy_armor"
	w_class = ITEM_SIZE_NORMAL
	throwforce = FALSE
	throw_speed = 1
	throw_range = 3

//Wreckage object created when a dummy/target is destroyed.
/obj/structure/practice_dummy/wreckage/
	name = "dummy wreckage"
	desc = "The wreckage of a training dummy. Can be fixed with wood."
	icon = 'icons/obj/objects.dmi'
	icon_state = "target_dummy_wreckage"
	target_type = "dummy"
	density = TRUE
	w_class = ITEM_SIZE_HUGE
	health = 10
	not_movable = FALSE
	not_disassemblable = FALSE

/obj/structure/practice_dummy/wreckage/New()
	..()
	name = "dummy wreckage"
	desc = "The wreckage of a training dummy. Can be fixed with wood."
	icon = 'icons/obj/objects.dmi'
	icon_state = "target_dummy_wreckage"

//Check if the object being used on it is wood, if it is and there is enough of it, repair the wreckage back into dummy/target.
/obj/structure/practice_dummy/wreckage/attackby(obj/item/W as obj, mob/living/human/user as mob)
	var/mob/living/human/H = user
	if(istype(W, /obj/item/stack/material/wood))
		if(W.amount >= 3)
			visible_message("<span class='danger'>[user] starts repairing the dummy..</span>")
			if(do_after(H, (60 / H.getStatCoeff("crafting")), H.loc))
				visible_message("<span class='danger'>[user] finishes repairing the dummy.</span>")
				W.amount -= 3
				if(W.amount <= 0)
					qdel(W)
				if(src.target_type == "dummy")
					new /obj/structure/practice_dummy(src.loc)
				else if (src.target_type == "target")
					new /obj/structure/practice_dummy/target(src.loc)
				qdel(src)
				if (ishuman(user))
					H.adaptStat("crafting", 1)

//Works like a practice dummy, but only for ranged training, cannot improve health.
/obj/structure/practice_dummy/target
	name = "practice target"
	desc = "A wood target, covered in straw. Used for training ranged weapons."
	icon = 'icons/obj/objects.dmi'
	icon_state = "target_dummy_target"
	target_type = "target"
	density = TRUE
	w_class = ITEM_SIZE_HUGE
	health = 100
	not_movable = FALSE
	not_disassemblable = FALSE
	ranged = TRUE
	melee = FALSE
	humanoid = FALSE

/obj/structure/practice_dummy/target/New()
	..()
	name = "practice target"
	desc = "A wood target, covered in straw. Used for training ranged weapons."
	icon = 'icons/obj/objects.dmi'
	icon_state = "target_dummy_target"

/obj/structure/practice_dummy/target/human
	name = "practice target"
	desc = "A cardboard target. Used for training ranged weapons."
	icon = 'icons/obj/objects.dmi'
	icon_state = "target_h"
/obj/structure/practice_dummy/target/human/New()
	..()
	name = "practice target"
	desc = "A cardboard target. Used for training ranged weapons."
	icon_state = "target_h"

/obj/structure/practice_dummy/target/human/indestructible

/obj/structure/practice_dummy/target/human/indestructible/check_health()
	return
/obj/structure/practice_dummy/target/human/indestructible/ex_act()
	return