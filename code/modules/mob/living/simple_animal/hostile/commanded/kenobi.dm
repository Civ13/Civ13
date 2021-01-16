/mob/living/simple_animal/hostile/human/kenobi
	name = "Kenobi"
	desc = "A monkey dawning a japanese uniform. fucking weeb."
	icon_state = "monkey_kenobi"
	icon_dead = "monkey_kenobi_dead"
	response_help = "pets"
	response_disarm = "shoo's"
	response_harm = "hits"
	speak = list("konichiwa","genkidesuka?","arigatougozaimasu")
	speak_emote = list("says","exclaims","whispers")
	emote_hear = list("whistles","whispers to himself","mumbles something")
	emote_see = list("walks around", "takes a stance", "bows", "adjusts their cap")
	speak_chance = TRUE
	move_to_delay = 3
	stance = HOSTILE_STANCE_IDLE
	stop_automated_movement_when_pulled = 0
	maxHealth = 150
	health = 150
	harm_intent_damage = 10
	melee_damage_lower = 10
	melee_damage_upper = 15
	attacktext = "pistol whipped"
	attack_sound = 'sound/weapons/slice.ogg'
	mob_size = MOB_MEDIUM
	starves = FALSE
	behaviour = "wander"
	faction = CIVILIAN
	ranged = 1
	projectiletype = /obj/item/projectile/bullet/pistol/c8mmnambu
	corpse = null
	casingtype = null
	grenade_type = /obj/item/weapon/grenade/ww2/type97
	language = new/datum/language/japanese

	New()
		..()
		grenades = rand(1,2)
		messages["injured"] = list("!!Tasukete!!","!!Tasukete Kurete!")
		messages["backup"] =list( "!!Engun ga hitsuyodesu!","!!Ore o kaba shite!")
		messages["enemy_sighted"] = list("!!AMERICA-JIN DESU!","!!KOROSHITE MIYO!")
		messages["grenade"] = list("!!TEKIDAN!!!", "!!Tekidan, Hayaku!!")
		behaviour = "wander"
		faction = CIVILIAN
		gun = new/obj/item/weapon/gun/projectile/pistol/ww2/nambu(src)
		if (!(behaviour = "defends") || !(behaviour = "hostile"))
			icon_state = "monkey_kenobi"
		else
			icon_state = "monkey_kenobi_hostile"
/mob/living/simple_animal/hostile/human/kenobi/attack_hand(mob/living/human/M as mob)
	..()
	if (behaviour == "hostile")
		stance = HOSTILE_STANCE_ATTACK
		stance_step = 6
		target_mob = M
		icon_state = "monkey_kenobi_hostile"
	else if (behaviour == "scared")
		do_behaviour("scared")
		icon_state = "monkey_kenobi"

	switch(M.a_intent)

		if (I_HELP)
			if (health > 0)
				if (istype(src, /mob/living/simple_animal/hostile/human/kenobi))
					if (prob(30))
						M.visible_message("<span class = 'notice'>[M] tells \the [src] that he is a good soldier!</span>")
					else
						M.visible_message("<span class = 'notice'>[M] pats \the [src]'s head!</span>")
				else
					M.visible_message("<span class = 'notice'>[M] [response_help] \the [src].</span>")

		if (I_DISARM)
			if (behaviour == "defends")
				stance = HOSTILE_STANCE_ATTACK
				stance_step = 6
				target_mob = M
				icon_state = "monkey_kenobi_hostile"
			M.visible_message("<span class = 'notice'>[M] [response_disarm] \the [src].</span>")
			M.do_attack_animation(src)
			playsound(get_turf(M), 'sound/weapons/punchmiss.ogg', 50, TRUE, -1)
			//TODO: Push the mob away or something

		if (I_GRAB)
			if (behaviour == "defends")
				stance = HOSTILE_STANCE_ATTACK
				stance_step = 6
				target_mob = M
				icon_state = "monkey_kenobi_hostile"
			if (M == src)
				return
			if (!(status_flags & CANPUSH))
				return

			var/obj/item/weapon/grab/G = new /obj/item/weapon/grab(M, src)

			M.put_in_active_hand(G)

			G.synch()
			G.affecting = src
			LAssailant = M

			M.visible_message("<span class = 'red'>[M] has grabbed [src] passively!</span>")
			M.do_attack_animation(src)

		if (I_HARM)
			if (behaviour == "wander")
				behaviour = "defends"
				stance = HOSTILE_STANCE_ATTACK
				stance_step = 6
				target_mob = M
				icon_state = "monkey_kenobi_hostile"
				update_icons()
			adjustBruteLoss(harm_intent_damage*M.getStatCoeff("strength"))
			M.visible_message("<span class = 'red'>[M] [response_harm] \the [src].</span>")
			M.do_attack_animation(src)
			playsound(get_turf(M), "punch", 50, TRUE, -1)

	return

/mob/living/simple_animal/hostile/human/kenobi/attackby(var/obj/item/O, var/mob/user)
	if (istype(O, /obj/item/weapon/leash) && behaviour != "defends" && behaviour != "hunt")
		var/obj/item/weapon/leash/L = O
		if (L.onedefined == FALSE)
			L.S1 = src
			user << "You tie \the [src] with the leash."
			L.onedefined = TRUE
			return
		else if (L.onedefined == TRUE && (src in range(3,L.S1)))
			L.S2 = src
			L.S2.following_mob = L.S1
			user << "You tie \the [src] to \the [L.S1] with the leash. It will now follow \the [L.S1]."
			qdel(L)
			return
	else if (istype(O, /obj/item/stack/medical))
		if (stat != DEAD)
			var/obj/item/stack/medical/MED = O
			if (health < maxHealth)
				if (MED.amount >= 1)
					adjustBruteLoss(-MED.heal_brute)
					MED.amount -= 1
					if (MED.amount <= 0)
						qdel(MED)
					for (var/mob/M in viewers(src, null))
						if ((M.client && !( M.blinded )))
							M.show_message("<span class='notice'>[user] applies the [MED] on [src].</span>")
					return TRUE
		else
			user << "<span class='notice'>\The [src] is dead, medical items won't bring \him back to life.</span>"
			return TRUE
	else if (!O.sharp || istype(O, /obj/item/weapon/macuahuitl))
		if (!O.force && !istype(O, /obj/item/stack/medical/bruise_pack))
			visible_message("<span class='notice'>[user] gently taps [src] with \the [O].</span>")
		else
			var/tgt = user.targeted_organ
			if (user.targeted_organ == "random")
				tgt = pick("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","eyes","mouth","head")
			O.attack(src, user, tgt)
	else if (O.sharp && !istype(src, /mob/living/simple_animal/hostage))
		if (!istype(O, /obj/item/weapon/reagent_containers) && user.a_intent == I_HARM && stat == DEAD)
			user.visible_message("<span class = 'notice'>[user] starts to butcher [src].</span>")
			if (do_after(user, 30, src))
				user.visible_message("<span class = 'notice'>[user] butchers [src].</span>")
				var/amt = 0
				if (mob_size == MOB_MINISCULE)
					amt = 1
				if (mob_size == MOB_TINY)
					amt = 2
				if (mob_size == MOB_SMALL)
					amt = 3
				if (mob_size == MOB_MEDIUM)
					amt = 4
				if (mob_size == MOB_LARGE)
					amt = 5
				if (mob_size == MOB_HUGE)
					amt = 8
				var/namt = amt-2
				if (namt <= 0)
					namt = 1
				if (!istype(src, /mob/living/simple_animal/crab))
					if (istype(src, /mob/living/simple_animal/hostile/zombie))
						for (var/i=0, i<=namt, i++)
							var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat(get_turf(src))
							meat.name = "rotten zombie meat"
							meat.radiation = radiation/2
							meat.icon_state = "rottenmeat"
							if (meat.reagents)
								meat.reagents.remove_reagent("protein", 2)
								meat.reagents.add_reagent("food_poisoning", 1)
							meat.rotten = TRUE
							meat.satisfaction = -30
					else if (istype(src, /mob/living/simple_animal/pig_gilt) || istype(src, /mob/living/simple_animal/pig_boar))
						new/obj/item/weapon/reagent_containers/food/snacks/pig/stomach(get_turf(src))
						new/obj/item/weapon/pigleg(get_turf(src))
					else if (istype(src, /mob/living/simple_animal/boar_gilt))
						new/obj/item/weapon/reagent_containers/food/snacks/pig/stomach(get_turf(src))
						new/obj/item/weapon/pigleg(get_turf(src))
					else if (istype(src, /mob/living/simple_animal/boar_boar))
						new/obj/item/weapon/reagent_containers/food/snacks/pig/stomach(get_turf(src))
						new/obj/item/weapon/pigleg(get_turf(src))
					else if (istype(src, /mob/living/simple_animal/chicken) || istype(src, /mob/living/simple_animal/rooster))
						new/obj/item/weapon/chicken_carcass(get_turf(src))
					else if (istype(src, /mob/living/simple_animal/cattle/cow) || istype(src, /mob/living/simple_animal/cattle/bull))
						new/obj/item/weapon/reagent_containers/food/snacks/cow/stomach(get_turf(src))
						for (var/i=0, i<=namt, i++)
							var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat(get_turf(src))
							meat.name = "[name] meat"
							meat.radiation = radiation/2
					else if (istype(src, /mob/living/simple_animal/goat))
						new/obj/item/weapon/reagent_containers/food/snacks/pig/stomach/goat(get_turf(src))
						for (var/i=0, i<=namt, i++)
							var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat(get_turf(src))
							meat.name = "[name] meat"
							meat.radiation = radiation/2
					else if (istype(src, /mob/living/simple_animal/sheep))
						new/obj/item/weapon/reagent_containers/food/snacks/pig/stomach/sheep(get_turf(src))
						for (var/i=0, i<=namt, i++)
							var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat(get_turf(src))
							meat.name = "[name] meat"
							meat.radiation = radiation/2
					else
						for (var/i=0, i<=namt, i++)
							var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat(get_turf(src))
							meat.name = "[name] meat"
							meat.radiation = radiation/2
				else
					for (var/i=0, i<=namt, i++)
						var/obj/item/weapon/reagent_containers/food/snacks/rawcrab/meat = new/obj/item/weapon/reagent_containers/food/snacks/rawcrab(get_turf(src))
						meat.radiation = radiation/2

				if ((amt-2) >= 1)
					var/obj/item/stack/material/leather/leather = new/obj/item/stack/material/leather(get_turf(src))
					leather.name = "[name] leather"
					leather.amount = (amt-2)
				if ((amt-2) >= 1)
					var/obj/item/stack/material/bone/bone = new/obj/item/stack/material/bone(get_turf(src))
					bone.name = "[name] bone"
					bone.amount = (amt-2)
				if (istype(user, /mob/living/human))
					var/mob/living/human/HM = user
					HM.adaptStat("medical", amt/3)
				crush()
				qdel(src)
		if (!istype(O, /obj/item/weapon/reagent_containers) && user.a_intent == I_GRAB && stat == DEAD)
			user.visible_message("<span class = 'notice'>[user] starts to skin and butcher [src].</span>")
			if (do_after(user, 100, src))
				user.visible_message("<span class = 'notice'>[user] skins and butchers [src].</span>")
				var/amt = 0
				if (mob_size == MOB_MINISCULE)
					amt = 1
				if (mob_size == MOB_TINY)
					amt = 2
				if (mob_size == MOB_SMALL)
					amt = 3
				if (mob_size == MOB_MEDIUM)
					amt = 4
				if (mob_size == MOB_LARGE)
					amt = 5
				if (mob_size == MOB_HUGE)
					amt = 8
				var/namt = amt-2
				if (namt <= 0)
					namt = 1
				if (!istype(src, /mob/living/simple_animal/crab))
					var/obj/item/weapon/reagent_containers/food/snacks/meat/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat(get_turf(src))
					meat.name = "[name] meatsteak"
					meat.amount = namt
					meat.radiation = radiation/2
				else
					var/obj/item/weapon/reagent_containers/food/snacks/rawcrab/meat = new/obj/item/weapon/reagent_containers/food/snacks/rawcrab(get_turf(src))
					meat.amount = namt
					meat.radiation = radiation/2

				if ((amt-2) >= 1)
					var/obj/item/stack/material/bone/bone = new/obj/item/stack/material/bone(get_turf(src))
					bone.name = "[name] bone"
					bone.amount = amt
				else
					var/obj/item/stack/material/leather/leather = new/obj/item/stack/material/leather(get_turf(src))
					leather.name = "[name] leather"
					leather.amount = amt
				crush()
				qdel(src)
		else
			var/tgt = user.targeted_organ
			if (user.targeted_organ == "random")
				tgt = pick("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","eyes","mouth","head")
			O.attack(src, user, tgt)
	if (behaviour == "defends")
		stance = HOSTILE_STANCE_ATTACK
		stance_step = 6
		target_mob = user
		..()
	else if (behaviour == "hunt")
		stance = HOSTILE_STANCE_ATTACK
		stance_step = 6
		target_mob = user
		..()
	else
		if (behaviour == "scared" && mob_size < user.mob_size)
			do_behaviour("defends")
		else if (behaviour == "hostile")
			do_behaviour("wander")
		..()

/mob/living/simple_animal/hostile/human/kenobi/hit_with_weapon(obj/item/O, mob/living/user, var/effective_force, var/hit_zone)

	visible_message("<span class='danger'>\The [src] has been attacked with \the [O] by [user].</span>")

	if (O.force <= resistance)
		user << "<span class='danger'>This weapon is ineffective, it does no damage.</span>"
		return 2

	var/damage = O.force
	if (O.damtype == HALLOSS)
		damage = FALSE

	adjustBruteLoss(damage)

	return FALSE
