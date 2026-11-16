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
	move_to_delay = 5
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
	minbodytemp = 223		//Below -50 Degrees Celsius
	maxbodytemp = 323	//Above 50 Degrees Celsius
	universal_speak = FALSE
	universal_understand = TRUE
//	holder_type = /obj/item/weapon/holder/mouse
	mob_size = MOB_MINISCULE
	possession_candidate = TRUE
	var/plaguemouse = FALSE

	can_pull_size = TRUE
	can_pull_mobs = MOB_PULL_NONE
	// Mice eat through their nest (code/modules/ecology/mouse_nests.dm), not by roaming.
	granivore = 0
	scavenger = 0
	behaviour = "scared" // mice bolt from people; they never attack
	melee_damage_lower = 0
	melee_damage_upper = 0

/mob/living/simple_animal/mouse/New()
	..()

	if (!body_color)
		body_color = pick( list("brown","gray","white", "black") )
	icon_state = "mouse_[body_color]"
	item_state = "mouse_[body_color]"
	icon_living = "mouse_[body_color]"
	icon_dead = "mouse_[body_color]_dead"
	desc = "It's a small [body_color] rodent."
	// Plague no longer comes from a coin flip at birth; only the admin plague subtype carries it.

/mob/living/simple_animal/mouse/proc/splat()
	health = FALSE
	death()
	icon_dead = "mouse_[body_color]_splat"
	icon_state = "mouse_[body_color]_splat"
/*
/mob/living/simple_animal/mouse/MouseDrop(atom/over_object)

	var/mob/living/human/H = over_object
	if (!istype(H) || !Adjacent(H)) return ..()

	if (H.a_intent == I_HELP)
		get_scooped(H)
		return
	else
		return ..()
*/
// Stepping near a mouse startles it; it squeaks and runs rather than biting.
/mob/living/simple_animal/mouse/Crossed(AM as mob|obj)
	if (ishuman(AM) && !stat)
		var/mob/living/human/M = AM
		to_chat(M, "<span class = 'notice'>\icon[getFlatIcon(src)] Squeek!</span>")
		to_chat(M, 'sound/effects/mousesqueek.ogg')
		do_behaviour("scared")
	..()

/mob/living/simple_animal/mouse/death()
	layer = MOB_LAYER
	..()

/mob/living/simple_animal/mouse/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (stat == DEAD && W && W.sharp)
		return harvest_animal(user, W, user.a_intent == I_GRAB)
	return ..()

/mob/living/simple_animal/mouse/harvest_products(turf/site, skin)
	var/obj/item/weapon/reagent_containers/food/snacks/meat/M = harvest_food(/obj/item/weapon/reagent_containers/food/snacks/meat, site)
	if (plaguemouse && M.reagents)
		M.reagents.add_reagent("plague", 3)

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