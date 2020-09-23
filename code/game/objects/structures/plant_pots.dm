/obj/structure/plant_pot
	name = "plant pot"
	icon = 'icons/obj/flora/plantpots.dmi'
	icon_state = null
	desc = "If you can see this, ping a @cotributor on the discord or a @sergeant"
	anchored = FALSE
	var/health = 20
	density = TRUE
	opacity = FALSE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = TRUE
	var/planttype = null //saves immense amounts of time from copy-pasting
	var/plantverb = null //also saves time from the task of making sure its consistent across objects.
	var/mob/living/human/stored_unit = null
	var/protection_chance = 35 //odds of something hitting the src
	var/filled_type = null
	var/filled = FALSE

/* Clay Plant-Pots*/

/obj/structure/plant_pot/clay/light
	name = "light clay plant pot"
	desc = "light clay plant pot."
	icon_state = "plant_pot-06"
	planttype = "plant-05"
	plantverb = "potting"

/obj/structure/plant_pot/clay/light/filled
	icon = 'icons/obj/flora/filled_plantpots.dmi'

/obj/structure/plant_pot/clay/light/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/material/trowel))
		if (filled_type)
			user << "You start removing the plant from the pot."
			if (do_after(user, 15, src))
				new filled_type(loc)
				new /obj/structure/plant_pot/clay/light(loc)
				qdel(src)
				return

		else
			user << "You start refilling the pot using the trowel..."
			if (do_after(user, 15, src))
				user << "You finish refilling the pot."
				var/obj/structure/plant_pot/clay/light/filled/S = new /obj/structure/plant_pot/clay/light/filled(loc)
				qdel(src)

				var/choice = WWinput(user, "What type of potted plant?","Choose a plant type","Normal",list("Cancel & Empty Pot", "Trees", "Shrubs", "Flowers"))
				if (choice == "Cancel & Empty Pot")
					return

				if (choice == "Trees")
					var/choice1 = WWinput(user, "Which kind of Tree?","Trees","Types",list("Cherry Blossom Tree","Small Fruit Tree", "Bonsai Tree", "Small Cypress Tree", "Small Conifer Tree", "Cancel & Empty Pot"))
					if (choice1 == "Cancel & Empty Pot")
						return

					if (choice1 == "Cherry Blossom Tree")
						S.icon_state = "[planttype]c"
						S.desc = "A pot with a cherry blossom tree."

					if (choice1 == "Small Fruit Tree")
						S.icon_state = "[planttype]a"
						S.desc = "A pot with a ornamental fruit tree."

					if (choice1 == "Bonsai Tree")
						S.icon_state = "[planttype]h"
						S.desc = "A pot with a bonsai minature tree."

					if (choice1 == "Small Cypress Tree")
						S.icon_state = "[planttype]f"
						S.desc = "A pot with a small cypress tree."

					if (choice1 == "Small Conifer Tree")
						S.icon_state = "[planttype]m"
						S.desc = "A pot with a small conifer tree."
					S.filled = TRUE
					return

				if (choice == "Shrubs")
					var/choice2 = WWinput(user, "Which kind of Shrub?","Shrubbery","Types",list("Leafy Plant","Small Succulent", "Rubber Plant", "Thin Stemmmed House Plant", "Thick Stemmed House Plant", "Leafy Creeper", "Large Leafy Bush", "Cancel & Empty Pot"))
					if (choice2 == "Cancel & Empty Pot")
						return

					if (choice2 == "Leafy Plant")
						S.icon_state = "[planttype]"
						S.desc = "A pot with a leafy plant."

					if (choice2 == "Small Succulent")
						S.icon_state = "[planttype]d"
						S.desc = "A pot with a small, spiky succulent cacti."

					if (choice2 == "Rubber Plant")
						S.icon_state = "[planttype]g"
						S.desc = "A pot with a plant with wide rubbery leaves."

					if (choice2 == "Thin Stemmmed House Plant")
						S.icon_state = "[planttype]n"
						S.desc = "A pot with a ordinary thin stemmed house plant."

					if (choice2 == "Thick Stemmed House Plant")
						S.icon_state = "[planttype]o"
						S.desc = "A pot with a ordinary thick stemmed house plant."

					if (choice2 == "Leafy Creeper")
						S.icon_state = "[planttype]i"
						S.desc = "A pot with a leafy creeper supported a wood stick-pole."

					if (choice2 == "Large Leafy Bush")
						S.icon_state = "[planttype]l"
						S.desc = "A pot with a large leafy bush."
					S.filled = TRUE
					return

				if (choice == "Flowers")
					var/choice3 = WWinput(user, "Which kind of Flower?","Flowers","Types",list("Small Flower Bouquet", "Sunflower", "Purple Angel Trumpet", "Exotic Jungle Plant Flower Bouquet", "Titan-Anum Corpse Flower", "Corpse Flower", "Purple Hicynth", "Carnivorous Pitcher Plant", "Cancel & Empty Pot"))
					if (choice3 == "Cancel & Empty Pot")
						return

					if (choice3 == "Small Flower Bouquet")
						S.icon_state = "[planttype]b"
						S.desc = "A pot with a pretty bouquet of small flowers."

					if (choice3 == "Sunflower")
						S.icon_state = "[planttype]s"
						S.desc = "A pot with a sunflower."

					if (choice3 == "Purple Angel Trumpet")
						S.icon_state = "[planttype]v"
						S.desc = "A pot with a purple angel trumpet."

					if (choice3 == "Exotic Jungle Plant Flower Bouquet")
						S.icon_state = "[planttype]b"
						S.desc = "A pot with a exotic bouquet of jungle flowers."

					if (choice3 == "Titan-Anum Corpse Flower")
						S.icon_state = "[planttype]j"
						S.desc = "A pot filled with very large and brightly colored titan anum flower spilling over the sides, flies come and go to its attractive aroma."

					if (choice3 == "Corpse Flower")
						S.icon_state = "[planttype]u"
						S.desc = "A pot filled with a corpse flower, flies come and go to its attractive aroma."

					if (choice3 == "Purple Hicynth")
						S.icon_state = "[planttype]e"
						S.desc = "A pot with a tall and aromatic purple hicynth stooped under the weight of its own bulbs."

					if (choice3 == "Carnivorous Pitcher Plant")
						S.icon_state = "[planttype]k"
						S.desc = "A pot with a hungry pitcher plant, inert; it will prefer to wait for its prey to arrive."
					S.filled = TRUE
					return

	if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/chinchona))
		if (filled_type || filled)
			user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
			return
		else
			user << "You start [plantverb] the chinchona..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the chinchona."
				icon = 'icons/obj/flora/filled_plantpots.dmi'
				icon_state = "[planttype]chinchona"
				desc = "A pot with a chinchona plant."
				filled_type = /obj/item/weapon/reagent_containers/food/snacks/grown/chinchona
				qdel(W)
				return

	if (istype(W, /obj/item/stack/farming/seeds))
		var/obj/item/stack/farming/seeds/WS = W
		if (WS.plant in list("peyote", "poppy", "bamboo", "coffee", "grapes", "apple", "orange", "lime", "lemon", "cherry", "apricot"))
			if (filled_type || filled)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return

			user << "You start [plantverb] the [WS.name]..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the [WS.name]..."
				var/obj/structure/plant_pot/clay/light/filled/S = new /obj/structure/plant_pot/clay/light/filled(loc)
				S.icon_state = "[planttype][WS.plant]"
				S.desc = "A pot with a purely decorative [WS.plant] plant."
				S.filled_type = WS.type
				WS.amount -= 1
				if (WS.amount <= 0)
					qdel(WS)
				qdel(src)
				return

	if (istype(W, /obj/item/stack/material/plastic))
		if (filled_type || filled)
			user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
			return

		user << "You start to mould the plastic into a plant shape..."
		if (do_after(user, 15, src))
			user << "You finish moulding the plastic."
			var/obj/structure/plant_pot/clay/light/filled/S = new /obj/structure/plant_pot/clay/light/filled(loc)
			var/choice = WWinput(user, "What type of plastic plant?","Choose a plant type","Normal",list("Plastic Tree", "Plastic Pine Tree", "Plastic Palm Tree", "Plastic Leaf Plant"))
			if (choice == "Plastic Tree")
				S.icon_state = "[planttype]plastic1"
				S.desc = "A pot with a plastic, it won't fool anybody but it looks nice."

			if (choice == "Plastic Pine Tree")
				S.icon_state = "[planttype]plastic2"
				S.desc = "A pot with a plastic pine tree, it won't fool anybody but it looks nice."

			if (choice == "Plastic Palm Tree")
				S.icon_state = "[planttype]plastic3"
				S.desc = "A pot with a plastic palm tree, it won't fool anybody but it looks nice."

			if (choice == "Plastic Leaf Plant")
				S.icon_state = "[planttype]plastic4"
				S.desc = "A pot with a plastic leaf plant, it won't fool anybody but it looks nice."

			S.filled_type = /obj/item/stack/material/plastic
			W.amount -= 1
			if (W.amount <= 0)
				qdel(W)
			qdel(src)
			return
	..()

/* Clay Planters*/

/obj/structure/plant_pot/medium_planter/clay/yellow
	name = "medium sized yellow clay planter"
	desc = "medium sized, yellow clay planter."
	icon_state = "plant_pot-03"
	planttype = "plant-03"
	plantverb = "planting"

/obj/structure/plant_pot/medium_planter/clay/yellow/filled
	icon = 'icons/obj/flora/filled_plantpots.dmi'

/obj/structure/plant_pot/medium_planter/clay/yellow/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/material/trowel))
		if (filled_type)
			user << "You start removing the plant from the planter."
			if (do_after(user, 15, src))
				new filled_type(loc)
				new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
				qdel(src)
				return

		else
			user << "You start refilling the planter using the trowel..."
			if (do_after(user, 15, src))
				user << "You finish refilling the planter."
				var/obj/structure/plant_pot/medium_planter/clay/yellow/filled/S = new /obj/structure/plant_pot/medium_planter/clay/yellow/filled(loc)
				qdel(src)

				var/choice = WWinput(user, "What type of potted plant?","Choose a plant type","Normal",list("Cancel & Empty Pot", "Trees", "Shrubs", "Flowers", "Rocks"))
				if (choice == "Cancel & Empty Pot")
					return

				if (choice == "Trees")
					var/choice1 = WWinput(user, "Which kind of Tree?","Trees","Types",list("Cherry Blossom Tree","Small Fruit Tree", "Bonsai Tree", "Small Cypress Tree", "Large Cypress Tree", "Cancel & Empty Pot"))
					if (choice1 == "Cancel & Empty Pot")
						return

					if (choice1 == "Cherry Blossom Tree")
						S.icon_state = "[planttype]c"
						S.desc = "A pot with a cherry blossom tree."

					if (choice1 == "Small Fruit Tree")
						S.icon_state = "[planttype]a"
						S.desc = "A pot with a ornamental fruit tree."

					if (choice1 == "Bonsai Tree")
						S.icon_state = "[planttype]h"
						S.desc = "A pot with a bonsai minature tree."

					if (choice1 == "Small Cypress Tree")
						S.icon_state = "[planttype]f"
						S.desc = "A pot with a small cypress tree."

					if (choice1 == "Large Cypress Tree")
						S.icon_state = "[planttype]r"
						S.desc = "A pot with a large cypress tree."
					S.filled = TRUE
					return

				if (choice == "Shrubs")
					var/choice2 = WWinput(user, "Which kind of Shrub?","Shrubbery","Types",list("Small Succulent", "Apple Topiary Bush", "Rubber Plant", "Thin Stemmmed House Plant", "Leafy Creeper", "Large Leafy Bush", "Large Jungle Bush", "Cancel & Empty Pot"))
					if (choice2 == "Cancel & Empty Pot")
						return

					if (choice2 == "Small Succulent")
						S.icon_state = "[planttype]d"
						S.desc = "A pot with a small, spiky succulent cacti."

					if (choice2 == "Apple Topiary Bush")
						S.icon_state = "[planttype]applebush"
						S.desc = "A pot with a topiary bush in the shape of a apple."

					if (choice2 == "Rubber Plant")
						S.icon_state = "[planttype]g"
						S.desc = "A pot with a plant with wide rubbery leaves."

					if (choice2 == "Thin Stemmmed House Plant")
						S.icon_state = "[planttype]n"
						S.desc = "A pot with a ordinary thin stemmed house plant."

					if (choice2 == "Leafy Creeper")
						S.icon_state = "[planttype]i"
						S.desc = "A pot with a leafy creeper supported a wood stick-pole."

					if (choice2 == "Large Leafy Bush")
						S.icon_state = "[planttype]l"
						S.desc = "A pot with a large leafy bush."

					if (choice2 == "Large Jungle Bush")
						S.icon_state = "[planttype]q"
						S.desc = "A pot with a large jungle bush."
					S.filled = TRUE
					return

				if (choice == "Flowers")
					var/choice3 = WWinput(user, "Which kind of Flower?","Flowers","Types",list("Small Flower Bouquet", "Sunflower", "Purple Angel Trumpet", "Exotic Jungle Plant Flower Bouquet", "Flower Bush", "Titan-Anum Corpse Flower", "Corpse Flower", "Purple Hicynth", "Carnivorous Pitcher Plant", "Cancel & Empty Pot"))
					if (choice3 == "Cancel & Empty Pot")
						return

					if (choice3 == "Small Flower Bouquet")
						S.icon_state = "[planttype]b"
						S.desc = "A pot with a pretty bouquet of small flowers."

					if (choice3 == "Sunflower")
						S.icon_state = "[planttype]s"
						S.desc = "A pot with a sunflower."

					if (choice3 == "Purple Angel Trumpet")
						S.icon_state = "[planttype]v"
						S.desc = "A pot with a purple angel trumpet."

					if (choice3 == "Exotic Jungle Plant Flower Bouquet")
						S.icon_state = "[planttype]p"
						S.desc = "A pot with a exotic bouquet of jungle flowers."

					if (choice3 == "Flower Bush")
						S.icon_state = "[planttype]t"
						S.desc = "A pot with a flower bush."

					if (choice3 == "Titan-Anum Corpse Flower")
						S.icon_state = "[planttype]j"
						S.desc = "A pot filled with very large and brightly colored titan anum flower spilling over the sides, flies come and go to its attractive aroma."

					if (choice3 == "Corpse Flower")
						S.icon_state = "[planttype]u"
						S.desc = "A pot filled with a corpse flower, flies come and go to its attractive aroma."

					if (choice3 == "Purple Hicynth")
						S.icon_state = "[planttype]e"
						S.desc = "A pot with a tall and aromatic purple hicynth stooped under the weight of its own bulbs."

					if (choice3 == "Carnivorous Pitcher Plant")
						S.icon_state = "[planttype]k"
						S.desc = "A pot with a hungry pitcher plant, inert; it will prefer to wait for its prey to arrive."
					S.filled = TRUE
					return

				if (choice == "Rocks")
					var/choice4 = WWinput(user, "Which kind of Rock?","Rocks","Types",list("Solitary Rock", "Cancel & Empty Pot"))
					if (choice4 == "Cancel & Empty Pot")
						return

					if (choice4 == "Solitary Rock")
						S.icon_state = "[planttype]rock"
						S.desc = "A pot with a solitary grey rock."
					S.filled = TRUE
					return

	if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/chinchona))
		if (filled_type || filled)
			user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
			return
		else
			user << "You start [plantverb] the chinchona..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the chinchona."
				icon = 'icons/obj/flora/filled_plantpots.dmi'
				icon_state = "[planttype]chinchona"
				desc = "A pot with a chinchona plant."
				filled_type = /obj/item/weapon/reagent_containers/food/snacks/grown/chinchona
				qdel(W)
				return

	if (istype(W, /obj/item/stack/farming/seeds))
		var/obj/item/stack/farming/seeds/WS = W
		if (WS.plant in list("peyote", "poppy", "bamboo", "coffee", "grapes", "apple", "orange", "lime", "lemon", "cherry", "apricot", "olives", "coconut", "pumpkin", "banana"))
			if (filled_type || filled)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return

			user << "You start [plantverb] the [WS.name]..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the [WS.name]..."
				var/obj/structure/plant_pot/medium_planter/clay/yellow/filled/S = new /obj/structure/plant_pot/medium_planter/clay/yellow/filled(loc)
				if (WS.plant == "coconut")
					var/choice = WWinput(user, "What type of plant?","Choose a plant type","Normal",list("Decorative Coconut Tree", "Wavy Coconut Tree"))						
					if (choice == "Decorative Coconut Tree")
						S.icon_state = "[planttype]coconut"
					if (choice == "Wavy Coconut Tree")
						S.icon_state = "[planttype]coconut2"
				else
					S.icon_state = "[planttype][WS.plant]"
				S.desc = "A planter with a purely decorative [WS.plant] plant."
				S.filled_type = WS.type
				WS.amount -= 1
				if (WS.amount <= 0)
					qdel(WS)
				qdel(src)
				return

	if (istype(W, /obj/item/stack/material/plastic))
		if (filled_type || filled)
			user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
			return

		user << "You start to mould the plastic into a plant shape..."
		if (do_after(user, 15, src))
			user << "You finish moulding the plastic."
			var/obj/structure/plant_pot/medium_planter/clay/yellow/filled/S = new /obj/structure/plant_pot/medium_planter/clay/yellow/filled(loc)
			var/choice = WWinput(user, "What type of plastic plant?","Choose a plant type","Normal",list("Plastic Tree", "Plastic Pine Tree", "Plastic Palm Tree", "Plastic Leaf Plant"))
			if (choice == "Plastic Tree")
				S.icon_state = "[planttype]plastic1"
				S.desc = "A pot with a plastic, it won't fool anybody but it looks nice."

			else if (choice == "Plastic Pine Tree")
				S.icon_state = "[planttype]plastic2"
				S.desc = "A pot with a plastic pine tree, it won't fool anybody but it looks nice."

			else if (choice == "Plastic Palm Tree")
				S.icon_state = "[planttype]plastic3"
				S.desc = "A pot with a plastic palm tree, it won't fool anybody but it looks nice."

			else if (choice == "Plastic Leaf Plant")
				S.icon_state = "[planttype]plastic4"
				S.desc = "A pot with a plastic leaf plant, it won't fool anybody but it looks nice."

			S.filled_type = /obj/item/stack/material/plastic
			W.amount -= 1
			if (W.amount <= 0)
				qdel(W)
			qdel(src)
			return
	..()

/*
- to-do wishlist: 1.get some code to replace corpse flower & pitcher plant with realised potted plants that do the real thing against flies, mosquitos, mice and insects
- 2.exotic realised plants might need some exclusive resource from jungle biomes or where appropriate
- 3.potted plant climatization on continents, generalised on general maps
- potted plant climatization cont: allowed under a glass roof or something detrimental will happen to it to encourage greenhouses/exhibitions.
- 4. potted plant harvests for chinchona, greenhousing (see point 3)
- 5. A soil variant the previous points will rely upon closer to ye olde farming
- 6.bees
- bees cont: can react to potted plants if more realisation is brought in as a substitute to natural wild.dm structures
*/


/obj/structure/plant_pot/attackby(obj/O as obj, mob/living/human/user as mob)
	if (istype(O,/obj/item/weapon/wrench))
		playsound(loc, 'sound/items/Ratchet.ogg', 100, TRUE)
		user << (anchored ? "<span class='notice'r>You unfasten \the [src] from the floor.</span>" : "<span class='notice'>You secure \the [src] to the floor.</span>")
		anchored = !anchored
	else if (istype(O,/obj/item/weapon/hammer) || istype(O,/obj/item/weapon/hammer/modern))
		playsound(loc, 'sound/weapons/smash.ogg', 75, 1)
		user << "<span class='notice'>You begin smashing apart \the [src].</span>"
		if (do_after(user,25,src))
			user << "<span class='notice'>You smash apart \the [src].</span>"
			new /obj/item/weapon/clayshards(loc)
			qdel(src)

/obj/structure/plant_pot/attackby(obj/item/W as obj, mob/user as mob)
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	switch(W.damtype)
		if ("fire")
			health -= W.force * TRUE
		if ("brute")
			health -= W.force * 0.20
	playsound(get_turf(src), 'sound/weapons/smash.ogg', 100)
	user.do_attack_animation(src)
	try_destroy()
	..()

/* imported*/

/obj/structure/plant_pot/fire_act(temperature)
	if (prob(35 * (temperature/500)))
		visible_message("<span class = 'warning'>[src] is damaged by the fire and breaks apart!.</span>")
		qdel(src)

/obj/structure/plant_pot/CanPass(atom/movable/mover, turf/target, height=0, air_group=0)
	if (istype(mover, /obj/item/projectile))
		return prob(100-protection_chance)
	else
		return FALSE

/obj/structure/plant_pot/bullet_act(var/obj/item/projectile/proj)
	health -= proj.damage/3
	visible_message("<span class='warning'>\The [src] is hit by the [proj.name]!</span>")
	try_destroy()

/obj/structure/plant_pot/proc/try_destroy()
	if (health <= 0)
		if (stored_unit)
			release_stored()
		visible_message("<span class='danger'>[src] is broken into pieces!</span>")
		qdel(src)
		return

/obj/structure/plant_pot/attack_hand(mob/user as mob)
	if (stored_unit)
		if (user == stored_unit)
			release_stored()
	else
		..()

/obj/structure/plant_pot/proc/release_stored()
	if (stored_unit)
		if (stored_unit.client)
			stored_unit.client.eye = stored_unit.client.mob
			stored_unit.client.perspective = MOB_PERSPECTIVE
			stored_unit.forceMove(get_turf(src))
			stored_unit = null
			return
