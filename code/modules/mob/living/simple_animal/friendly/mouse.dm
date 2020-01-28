/mob/living/simple_animal/mouse
	name = "mouse"
	real_name = "mouse"
	desc = "It's a small rodent."
	icon_state = "mouse_gray"
	item_state = "mouse_gray"
	icon_living = "mouse_gray"
	icon_dead = "mouse_gray_dead"
	speak = list("Squeek!","SQUEEK!","Squeek?")
	speak_emote = list("squeeks","squeeks","squiks")
	emote_hear = list("squeeks","squeaks","squiks")
	emote_see = list("runs in a circle", "shakes", "scritches at something")
	pass_flags = PASSTABLE
	speak_chance = TRUE
	turns_per_move = 5
	see_in_dark = 6
	maxHealth = 5
	health = 5
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "stamps on"
	density = FALSE
	var/body_color //brown, gray, black and white, leave blank for random
	layer = MOB_LAYER
	minbodytemp = 223		//Below -50 Degrees Celcius
	maxbodytemp = 323	//Above 50 Degrees Celcius
	universal_speak = FALSE
	universal_understand = TRUE
//	holder_type = /obj/item/weapon/holder/mouse
	mob_size = MOB_MINISCULE
	possession_candidate = TRUE
	var/plaguemouse = FALSE

	can_pull_size = TRUE
	can_pull_mobs = MOB_PULL_NONE
	granivore = 1
	scavenger = 1
	behaviour = "defends"
	melee_damage_lower = 2
	melee_damage_upper = 5

/mob/living/simple_animal/mouse/New()
	..()

	if (!body_color)
		body_color = pick( list("brown","gray","white", "black") )
	icon_state = "mouse_[body_color]"
	item_state = "mouse_[body_color]"
	icon_living = "mouse_[body_color]"
	icon_dead = "mouse_[body_color]_dead"
	desc = "It's a small [body_color] rodent, often seen hiding in the ship's hull and making a nuisance of itself."

	if(body_color == "black")
		if(map.ordinal_age == 2 || map.ordinal_age == 3) //Approx epochs where black plague was a thing.
			if(prob(50))
				plaguemouse = TRUE
		else
			if(prob(25))
				plaguemouse = TRUE
	else
		if(map.ordinal_age == 2 || map.ordinal_age == 3) //Approx epochs where black plague was a thing.
			if(prob(10))
				plaguemouse = TRUE
		else
			if(prob(5))
				plaguemouse = TRUE

/mob/living/simple_animal/mouse/proc/splat()
	health = FALSE
	death()
	icon_dead = "mouse_[body_color]_splat"
	icon_state = "mouse_[body_color]_splat"
/*
/mob/living/simple_animal/mouse/MouseDrop(atom/over_object)

	var/mob/living/carbon/H = over_object
	if (!istype(H) || !Adjacent(H)) return ..()

	if (H.a_intent == I_HELP)
		get_scooped(H)
		return
	else
		return ..()
*/
/mob/living/simple_animal/mouse/Crossed(AM as mob|obj)
	if ( ishuman(AM) )
		if (!stat)
			var/mob/living/carbon/human/M = AM
			M << "<span class = 'notice'>\icon[src] Squeek!</span>"
			M << 'sound/effects/mousesqueek.ogg'
			target_mob = M
			stance = HOSTILE_STANCE_ATTACK
			stance_step = 6
			if(plaguemouse && prob(2))
				M.disease = TRUE
				M.disease_type = "plague"
			else if((plaguemouse && prob(0.03)) && (map.ordinal_age == 2 || map.ordinal_age == 3)) //2 percent chance because of if-else logic,
				M.disease = TRUE
				M.disease_type = "plague"
			else if(plaguemouse && body_color == "black" && prob(4)) //prob is 3 percent.
				M.disease = TRUE
				M.disease_type = "plague"
			else if((plaguemouse && body_color == "black" && prob(5)) && (map.ordinal_age == 2 || map.ordinal_age == 3)) //four percent chance kinda
				M.disease = TRUE
				M.disease_type = "plague"
	..()

/mob/living/simple_animal/mouse/death()
	layer = MOB_LAYER
	..()

/mob/living/simple_animal/mouse/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (stat != DEAD)
		return ..()
	if (!istype(W) || !W.sharp)
		return ..()
	else if (W.sharp)
		user.visible_message("<span class = 'notice'>[user] starts to butcher [src].</span>")
		if (do_after(user, 30, src))
			user.visible_message("<span class = 'notice'>[user] butchers [src] into a sole meat slab.</span>")
			var/obj/item/weapon/reagent_containers/food/snacks/meat/human/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat/human(get_turf(src))
			meat.name = "[name] meatsteak"
			meat.radiation = radiation/2
			if(plaguemouse)
				meat.reagents.add_reagent("plague", 3)
			if (istype(user, /mob/living/carbon/human))
				var/mob/living/carbon/human/HM = user
				HM.adaptStat("medical", 0.3)
			qdel(src)

/mob/living/simple_animal/mouse/AttackingTarget()
	if (!Adjacent(target_mob))
		return
	playsound(src.loc, 'sound/weapons/bite.ogg', 100, TRUE, 2)
	custom_emote(1, "bites [target_mob]!")

	var/damage = pick(melee_damage_lower,melee_damage_upper)

	if (ishuman(target_mob))
		var/mob/living/carbon/human/H = target_mob
		var/dam_zone = pick("chest", "l_hand", "r_hand", "l_leg", "r_leg")
		var/obj/item/organ/external/affecting = H.get_organ(ran_zone(dam_zone))
		H.apply_damage(damage, BRUTE, affecting, H.run_armor_check(affecting, "melee"), sharp=1, edge=1)
		if (prob(3))
			H.disease = TRUE
			H.disease_type = "plague"
	else if (isliving(target_mob))
		var/mob/living/L = target_mob
		L.adjustBruteLoss(damage)
		if (istype(target_mob, /mob/living/simple_animal))
			var/mob/living/simple_animal/SA = target_mob
			if (SA.behaviour == "defends" || SA.behaviour == "hunt")
				if (SA.stance != HOSTILE_STANCE_ATTACK && SA.stance != HOSTILE_STANCE_ATTACKING)
					SA.stance = HOSTILE_STANCE_ATTACK
					SA.stance_step = 7
					SA.target_mob = src
		return L
/*
 * Mouse types
 */

/mob/living/simple_animal/mouse/white
	body_color = "white"
	icon_state = "mouse_white"

/mob/living/simple_animal/mouse/gray
	body_color = "gray"
	icon_state = "mouse_gray"

/mob/living/simple_animal/mouse/brown
	body_color = "brown"
	icon_state = "mouse_brown"

/mob/living/simple_animal/mouse/black
	body_color = "black"
	icon_state = "mouse_black"

/mob/living/simple_animal/mouse/black/plague
	plaguemouse = TRUE

//TOM IS ALIVE! SQUEEEEEEEE~K :)
/mob/living/simple_animal/mouse/brown/Tom
	name = "Tom"
	desc = "Jerry the cat is not amused."

/mob/living/simple_animal/mouse/brown/Tom/New()
	..()
	// Change my name back, don't want to be named Tom (666)
	name = initial(name)

/mob/living/simple_animal/mouse/cannot_use_vents()
	return

//Here temporarally until animals act as reagent containers.
/obj/item/weapon/reagent_containers/food/snacks/attack_generic(var/mob/living/user)
	/*
	..()
	if(istype(user, /mob/living/simple_animal/mouse))
		var/mob/living/simple_animal/mouse/PM = src
		if(istype(src, /obj/item/weapon/reagent_containers/food/snacks))
			var/obj/item/weapon/reagent_containers/food/snacks/S = src
			if(PM.plaguemouse)
				S.reagents.add_reagent("plague", 0.05)
		else if(istype(src, /mob/living/carbon/human))
			var/mob/living/carbon/human/M = src
			if(PM.plaguemouse)
				M.reagents.add_reagent("plague", 0.05)*/