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
	var/body_color //brown, gray and white, leave blank for random
	layer = MOB_LAYER
	min_oxy = 16 //Require atleast 16kPA oxygen
	minbodytemp = 223		//Below -50 Degrees Celcius
	maxbodytemp = 323	//Above 50 Degrees Celcius
	universal_speak = FALSE
	universal_understand = TRUE
//	holder_type = /obj/item/weapon/holder/mouse
	mob_size = MOB_MINISCULE
	possession_candidate = TRUE

	can_pull_size = TRUE
	can_pull_mobs = MOB_PULL_NONE

/mob/living/simple_animal/mouse/Life()
	..()

	if (!stat && prob(speak_chance))
		for (var/mob/M in view())
			M << 'sound/effects/mousesqueek.ogg'

	if (!ckey && stat == CONSCIOUS && prob(1))
		stat = UNCONSCIOUS
		icon_state = "mouse_[body_color]_sleep"
		wander = FALSE
		speak_chance = FALSE
		//snuffles
	else if (stat == UNCONSCIOUS)
		if (ckey || prob(5))
			stat = CONSCIOUS
			icon_state = "mouse_[body_color]"
			wander = TRUE
		else if (prob(5))
			audible_emote("snuffles.")

/mob/living/simple_animal/mouse/lay_down()
	..()
	icon_state = resting ? "mouse_[body_color]_sleep" : "mouse_[body_color]"

/mob/living/simple_animal/mouse/New()
	..()

//	verbs += /mob/living/proc/ventcrawl
//	verbs += /mob/living/proc/hide

	if (name == initial(name))
		name = "[name] ([rand(1, 1000)])"

	real_name = name

	if (!body_color)
		body_color = pick( list("brown","gray","white") )
	icon_state = "mouse_[body_color]"
	item_state = "mouse_[body_color]"
	icon_living = "mouse_[body_color]"
	icon_dead = "mouse_[body_color]_dead"
	desc = "It's a small [body_color] rodent, often seen hiding in maintenance areas and making a nuisance of itself."

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
			var/mob/M = AM
			M << "<span class = 'notice'>\icon[src] Squeek!</span>"
			M << 'sound/effects/mousesqueek.ogg'
	..()

/mob/living/simple_animal/mouse/death()
	layer = MOB_LAYER
	..()

/mob/living/simple_animal/mouse/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (stat != DEAD)
		return ..()
	if (!istype(W) || !W.sharp)
		return ..()
	else if (W.sharp && !istype(W, /obj/item/weapon/reagent_containers/syringe))
		user.visible_message("<span class = 'notice'>[user] starts to butcher [src].</span>")
		if (do_after(user, 30, src))
			user.visible_message("<span class = 'notice'>[user] butchers [src] into a sole meat slab.</span>")
			var/obj/item/weapon/reagent_containers/food/snacks/meat/human/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat/human(get_turf(src))
			meat.name = "[name] meatsteak"
			qdel(src)

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
