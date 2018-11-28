//cow
/mob/living/simple_animal/cow
	name = "cow"
	desc = "Known for their milk, just don't tip them over."
	icon_state = "cow"
	icon_living = "cow"
	icon_dead = "cow_dead"
	icon_gib = "cow_gib"
	speak = list("moo?","moo","MOOOOOO")
	speak_emote = list("moos","moos hauntingly")
	emote_hear = list("brays")
	emote_see = list("shakes its head")
	speak_chance = TRUE
	turns_per_move = 5
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 6
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 50
	var/calf = FALSE
	var/datum/reagents/udder = null
	var/pregnant = FALSE
	var/birthCountdown = 0
	var/overpopulationCountdown = 0
	mob_size = MOB_LARGE

/mob/living/simple_animal/bull
	name = "bull"
	desc = "Good for meat."
	icon_state = "bull"
	icon_living = "bull"
	icon_dead = "bull_dead"
	icon_gib = "cow_gib"
	speak = list("moo?","moo","MOOOOOO")
	speak_emote = list("moos","moos hauntingly")
	emote_hear = list("brays")
	emote_see = list("shakes its head")
	speak_chance = TRUE
	turns_per_move = 5
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 6
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	var/calf = FALSE
	health = 65
	mob_size = MOB_LARGE

/mob/living/simple_animal/bull/New()
	..()
	spawn(1)
		if (calf)
			icon_state = "calf"
			icon_living = "calf"
			icon_dead = "calf_dead"
			meat_amount = 2
			mob_size = MOB_SMALL
			spawn(3000)
				calf = FALSE
				icon_state = "bull"
				icon_living = "bull"
				icon_dead = "bull_dead"
				mob_size = MOB_LARGE

/mob/living/simple_animal/cow/New()
	udder = new(50)
	udder.my_atom = src
	..()
	spawn(1)
		if (calf)
			icon_state = "calf"
			icon_living = "calf"
			icon_dead = "calf_dead"
			meat_amount = 2
			udder.remove_reagent("milk")
			mob_size = MOB_SMALL
			spawn(3000)
				calf = FALSE
				icon_state = "cow"
				icon_living = "cow"
				icon_dead = "cow_dead"
				mob_size = MOB_LARGE
/mob/living/simple_animal/cow/attackby(var/obj/item/O as obj, var/mob/user as mob)
	var/obj/item/weapon/reagent_containers/glass/G = O
	if (stat == CONSCIOUS && istype(G) && G.is_open_container())
		user.visible_message("<span class='notice'>[user] milks [src] using \the [O].</span>")
		var/transfered = udder.trans_id_to(G, "milk", rand(5,10))
		if (G.reagents.total_volume >= G.volume)
			user << "<span class = 'red'>The [O] is full.</span>"
		if (!transfered)
			user << "<span class = 'red'>The udder is dry. Wait a bit.</span>"
	else
		..()

/mob/living/simple_animal/cow/Life()
	. = ..()
	if (stat == CONSCIOUS)
		if (udder && prob(5) && !calf)
			udder.add_reagent("milk", rand(5, 10))
	else
		return

	if (overpopulationCountdown > 0) //don't do any checks while overpopulation is in effect
		overpopulationCountdown--
		return

	if (!pregnant)
		var/nearbyObjects = range(2,src) //5x5 area around cow
		var/cowCount = 0
		for(var/mob/living/simple_animal/bull/M in nearbyObjects)
			if (M.stat == CONSCIOUS)
				pregnant = TRUE
				birthCountdown = 300 // life ticks once per 2 seconds, 300 == 10 minutes
			cowCount++

		for(var/mob/living/simple_animal/cow/M in nearbyObjects)
			cowCount++

		if (cowCount > 5) // max 5 cows/bulls in a 5x5 area around cow
			overpopulationCountdown = 30 // 1 minute
			pregnant = FALSE
	else
		birthCountdown--
		if (birthCountdown <= 0)
			pregnant = FALSE
			if (prob(50))
				var/mob/living/simple_animal/cow/C = new/mob/living/simple_animal/cow(loc)
				C.calf = TRUE
			else
				var/mob/living/simple_animal/bull/B = new/mob/living/simple_animal/bull(loc)
				B.calf = TRUE
			visible_message("A calf has been born!")

/mob/living/simple_animal/cow/attack_hand(mob/living/carbon/M as mob)
	if (!stat && M.a_intent == I_DISARM && icon_state != icon_dead)
		M.visible_message("<span class='warning'>[M] tips over [src].</span>","<span class='notice'>You tip over [src].</span>")
		Weaken(30)
		icon_state = icon_dead
		spawn(rand(20,50))
			if (!stat && M)
				icon_state = icon_living
				var/list/responses = list(	"[src] looks at you imploringly.",
											"[src] looks at you pleadingly",
											"[src] looks at you with a resigned expression.",
											"[src] seems resigned to its fate.")
				M << pick(responses)
	else
		..()

/mob/living/simple_animal/chick
	name = "\improper chick"
	desc = "Adorable! They make such a racket though."
	icon_state = "chick"
	icon_living = "chick"
	icon_dead = "chick_dead"
	icon_gib = "chick_gib"
	speak = list("Cherp.","Cherp?","Chirrup.","Cheep!")
	speak_emote = list("cheeps")
	emote_hear = list("cheeps")
	emote_see = list("pecks at the ground","flaps its tiny wings")
	speak_chance = 2
	turns_per_move = 2
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = TRUE
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = TRUE
	var/amount_grown = FALSE
	pass_flags = PASSTABLE
	mob_size = MOB_MINISCULE

/mob/living/simple_animal/chick/New()
	..()
	pixel_x = rand(-6, 6)
	pixel_y = rand(0, 10)

/mob/living/simple_animal/chick/Life()
	. =..()
	if (!.)
		return
	if (!stat)
		amount_grown += rand(1,2)
		if (amount_grown >= 250)
			new /mob/living/simple_animal/chicken(loc)
			qdel(src)

var/const/MAX_CHICKENS = 50
var/global/chicken_count = FALSE

/mob/living/simple_animal/chicken
	name = "\improper chicken"
	desc = "Hopefully the eggs are good this season."
	icon_state = "chicken_brown"
	icon_living = "chicken_brown"
	icon_dead = "chicken_dead"
	speak = list("Cluck!","BWAAAAARK BWAK BWAK BWAK!","Bwaak bwak.")
	speak_emote = list("clucks","croons")
	emote_hear = list("clucks")
	emote_see = list("pecks at the ground","flaps its wings viciously")
	speak_chance = 2
	turns_per_move = 3
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 2
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	attacktext = "kicked"
	health = 10
	var/eggsleft = 5
	var/body_color
	var/egg_timer = FALSE
	pass_flags = PASSTABLE
	mob_size = MOB_SMALL

/mob/living/simple_animal/chicken/New()
	..()
	if (!body_color)
		body_color = pick( list("brown","black","white") )
	icon_state = "chicken_[body_color]"
	icon_living = "chicken_[body_color]"
	icon_dead = "chicken_[body_color]_dead"
	pixel_x = rand(-6, 6)
	pixel_y = rand(0, 10)
	chicken_count += 1

/mob/living/simple_animal/chicken/death()
	..()
	chicken_count -= 1

/mob/living/simple_animal/chicken/attackby(var/obj/item/O as obj, var/mob/user as mob)
	if (stat == CONSCIOUS && istype(O, /obj/item/stack/farming/seeds))
		var/obj/item/stack/S = O
		if (eggsleft < 5)
			user.visible_message("<span class='notice'>[user] feeds [src] \the [O].</span>")
			eggsleft++
			S.use(1)
		else
			user << "<span class = 'red'>The [src] is not hungry.</span>"

/mob/living/simple_animal/chicken/Life()
	. =..()
	if (!.)
		return
	if (!stat)
		egg_timer += 1
		if (egg_timer >= 120)
			if (!stat && eggsleft > 0)
				visible_message("[src] [pick("lays an egg.","squats down and croons.","begins making a huge racket.","begins clucking raucously.")]")
				eggsleft--
				egg_timer = 0
				var/obj/item/weapon/reagent_containers/food/snacks/egg/E = new(get_turf(src))
				E.pixel_x = rand(-6,6)
				E.pixel_y = rand(-6,6)
				if (prob(10))
					var/nearbyObjects = range(2,src) //5x5 area
					var/chickenCount = 0
					for(var/mob/living/simple_animal/chicken/M in nearbyObjects)
						chickenCount++

					for(var/mob/living/simple_animal/chick/M in nearbyObjects)
						chickenCount++

					if (chickenCount <= 5) // max 5 chickens/chicks in a 5x5 area for eggs to start hatching
						processing_objects.Add(E)

/obj/item/weapon/reagent_containers/food/snacks/egg/var/amount_grown = FALSE
/obj/item/weapon/reagent_containers/food/snacks/egg/process()
	if (isturf(loc))
		amount_grown += rand(1,2)
		if (amount_grown >= 150)
			visible_message("[src] hatches with a quiet cracking sound.")
			new /mob/living/simple_animal/chick(get_turf(src))
			processing_objects.Remove(src)
			qdel(src)
	else
		processing_objects.Remove(src)

//goat
/mob/living/simple_animal/goat
	name = "goat"
	desc = "Not known for their pleasant disposition."
	icon_state = "goat"
	icon_living = "goat"
	icon_dead = "goat_dead"
	speak = list("EHEHEHEHEH","eh?")
	speak_emote = list("brays")
	emote_hear = list("brays.")
	emote_see = list("shakes its head", "stamps a foot", "glares around")
	speak_chance = 1
	turns_per_move = 5
	see_in_dark = 6
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	meat_amount = 3
	response_help  = "pets"
	response_disarm = "gently pushes aside"
	response_harm   = "kicks"
	faction = list("neutral")
	attacktext = "kicks"
	attack_sound = 'sound/weapons/punch1.ogg'
	health = 40
	maxHealth = 40
	melee_damage_lower = 2
	melee_damage_upper = 6
	stop_automated_movement_when_pulled = 1
	var/datum/reagents/udder = null
	mob_size = MOB_MEDIUM
/mob/living/simple_animal/goat/New()
	udder = new(50)
	udder.my_atom = src
	..()

/mob/living/simple_animal/goat/attackby(var/obj/item/O as obj, var/mob/user as mob)
	var/obj/item/weapon/reagent_containers/glass/G = O
	if (stat == CONSCIOUS && istype(G) && G.is_open_container())
		user.visible_message("<span class='notice'>[user] milks [src] using \the [O].</span>")
		var/transfered = udder.trans_id_to(G, "milk", rand(5,10))
		if (G.reagents.total_volume >= G.volume)
			user << "<span class = 'red'>The [O] is full.</span>"
		if (!transfered)
			user << "<span class = 'red'>The udder is dry. Wait a bit.</span>"
	else
		..()

/mob/living/simple_animal/goat/Life()
	. = ..()
	if (stat == CONSCIOUS)
		if (udder && prob(5))
			udder.add_reagent("milk", rand(3, 5))



