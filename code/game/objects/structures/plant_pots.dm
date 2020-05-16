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
	var/mob/living/carbon/human/stored_unit = null
	var/protection_chance = 35 //odds of something hitting the src
	var/filled_type = null

/* Clay Plant-Pots*/

/obj/structure/plant_pot/clay/light
	name = "light clay plant pot"
	desc = "light clay plant pot."
	icon_state = "plant_pot-06"
	planttype = "plant-05"
	plantverb = "potting"

/obj/structure/plant_pot/clay/light/proc/empty_and_return()
		new filled_type(loc)
		filled_type = null
		new /obj/structure/plant_pot/clay/light(loc)
		qdel(src)

/obj/structure/plant_pot/clay/light/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/material/trowel))
		if (filled_type)
			user << "You start removing the plant from the [src]."
			if (do_after(user, 15, src))
				empty_and_return()
				return
		else
			user << "You start refilling the [src] using the trowel..."
			if (do_after(user, 15, src))
				user << "You finish refilling the [src]."
				var/obj/structure/plant_pot/clay/light/S = new /obj/structure/plant_pot/clay/light(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of potted plant?","Choose a plant type","Normal",list("Empty", "Trees", "Shrubs", "Flowers"))
				if (choice == "Empty")
					return
				else if (choice == "Trees")
					var/choice1 = WWinput(user, "Which kind of Tree?","Trees","Types",list("Cherry Blossom Tree","Small Fruit Tree", "Bonsai Tree", "Small Cypress Tree", "Small Conifer Tree", "Cancel"))
					if (choice1 == "Cherry Blossom Tree")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]c"
						S.name = "A [src] with a cherry blossom tree."
					else if (choice1 == "Small Fruit Tree")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]a"
						S.name = "A [src] with a ornamental fruit tree."
					else if (choice1 == "Bonsai Tree")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]h"
						S.name = "A [src] with a bonsai minature tree."
					else if (choice1 == "Small Cypress Tree")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]f"
						S.name = "A [src] with a small cypress tree."
					else if (choice1 == "Small Conifer Tree")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]m"
						S.name = "A [src] with a small conifer tree."
					else if (choice1 == "Cancel")
						return
				if (choice == "Shrubs")
					var/choice2 = WWinput(user, "Which kind of Shrub?","Shrubbery","Types",list("Leafy Plant","Small Succulent", "Rubber Plant", "Thin Stemmmed House Plant", "Thick Stemmed House Plant", "Leafy Creeper", "Large Leafy Bush", "Cancel"))
					if (choice2 == "Leafy Plant")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]"
						S.name = "A [src] with a leafy plant."
					else if (choice2 == "Small Succulent")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]d"
						S.name = "A [src] with a small, spiky succulent cacti."
					else if (choice2 == "Rubber Plant")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]g"
						S.name = "A [src] with a plant with wide rubbery leaves."
					else if (choice2 == "Thin Stemmmed House Plant")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]n"
						S.name = "A [src] with a ordinary thin stemmed house plant."
					else if (choice2 == "Thick Stemmed House Plant")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]o"
						S.name = "A [src] with a ordinary thick stemmed house plant."
					else if (choice2 == "Leafy Creeper")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]i"
						S.name = "A [src] with a leafy creeper supported a wood stick-pole."
					else if (choice2 == "Large Leafy Bush")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]l"
						S.name = "A [src] with a large leafy bush."
					else if (choice2 == "Cancel")
						return
				if (choice == "Flowers")
					var/choice3 = WWinput(user, "Which kind of Flower?","Flowers","Types",list("Small Flower Bouquet", "Sunflower", "Purple Angel Trumpet", "Exotic Jungle Plant Flower Bouquet", "Titan-Anum Corpse Flower", "Corpse Flower", "Purple Hicynth", "Carnivorous Pitcher Plant", "Cancel"))
					if (choice3 == "Small Flower Bouquet")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]b"
						S.name = "A [src] with a pretty bouquet of small flowers."
					else if (choice3 == "Sunflower")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]s"
						S.name = "A [src] with a sunflower."
					else if (choice3 == "Purple Angel Trumpet")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]v"
						S.name = "A [src] with a purple angel trumpet."
					else if (choice3 == "Exotic Jungle Plant Flower Bouquet")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]b"
						S.name = "A [src] with a exotic bouquet of jungle flowers."
					else if (choice3 == "Titan-Anum Corpse Flower")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]j"
						S.name = "A [src] filled with very large and brightly colored titan anum flower spilling over the sides, flies come and go to its attractive aroma."
					else if (choice3 == "Corpse Flower")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]u"
						S.name = "A [src] filled with a corpse flower, flies come and go to its attractive aroma."
					else if (choice3 == "Purple Hicynth")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]e"
						S.name = "A [src] with a tall and aromatic purple hicynth stooped under the weight of its own bulbs."
					else if (choice3 == "Carnivorous Pitcher Plant")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]k"
						S.name = "A [src] with a hungry pitcher plant, inert; it will prefer to wait for its prey to arrive."
					else if (choice3 == "Cancel")
						return
		if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/chinchona))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the chinchona..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the chinchona."
				qdel(W)
				var/obj/structure/plant_pot/clay/light/S = new /obj/structure/plant_pot/clay/light(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of potted plant?","Choose a plant type","Normal",list("Empty & Return Plant", "Decorative Chinchona"))
				if (choice == "Empty & Return Plant")
					new /obj/item/weapon/reagent_containers/food/snacks/grown/chinchona(loc)
					return
				else if (choice == "Decorative Chinchona")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]chinchona"
					S.name = "A [src] with a chinchona plant."
					S.filled_type = /obj/item/weapon/reagent_containers/food/snacks/grown/chinchona
					return
		if (istype(W, /obj/item/stack/farming/seeds/peyote))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the peyote seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the peyote seeds."
				qdel(W)
				var/obj/structure/plant_pot/clay/light/S = new /obj/structure/plant_pot/clay/light(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of potted plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Peyote"))
				if (choice == "Empty & Return Seeds")
					new /obj/item/stack/farming/seeds/peyote(loc)
					return
				else if (choice == "Decorative Peyote")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]peyote"
					S.name = "A [src] with a peyote plant."
					S.filled_type = /obj/item/stack/farming/seeds/peyote
					return
		if (istype(W, /obj/item/stack/farming/seeds/poppy))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the poppy seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the poppy seeds."
				qdel(W)
				var/obj/structure/plant_pot/clay/light/S = new /obj/structure/plant_pot/clay/light(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of potted plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Poppy"))
				if (choice == "Empty & Return Seeds")
					new /obj/item/stack/farming/seeds/poppy(loc)
					return
				else if (choice == "Decorative Poppy")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]poppy"
					S.name = "A [src] with a poppy plant."
					S.filled_type = /obj/item/stack/farming/seeds/poppy
					return
		if (istype(W, /obj/item/stack/farming/seeds/bamboo))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the bamboo seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the bamboo seeds."
				qdel(W)
				var/obj/structure/plant_pot/clay/light/S = new /obj/structure/plant_pot/clay/light(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of potted plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Bamboo"))
				if (choice == "Empty & Return Seeds")
					new /obj/item/stack/farming/seeds/bamboo(loc)
					return
				else if (choice == "Decorative Bamboo")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]bamboo"
					S.name = "A [src] with bamboo shoots."
					S.filled_type = /obj/item/stack/farming/seeds/bamboo
					return
		if (istype(W, /obj/item/stack/farming/seeds/coffee))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the coffee seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the coffee seeds."
				qdel(W)
				var/obj/structure/plant_pot/clay/light/S = new /obj/structure/plant_pot/clay/light(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of potted plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Coffee"))
				if (choice == "Empty & Return Seeds")
					new /obj/item/stack/farming/seeds/coffee(loc)
					return
				else if (choice == "Decorative Coffee")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]coffee"
					S.name = "A [src] with a coffee plant."
					S.filled_type = /obj/item/stack/farming/seeds/coffee
					return
		if (istype(W, /obj/item/stack/farming/seeds/grapes))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the grape seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the grape seeds."
				qdel(W)
				var/obj/structure/plant_pot/clay/light/S = new /obj/structure/plant_pot/clay/light(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of potted plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Grape Vine"))
				if (choice == "Empty & Return Seeds")
					new /obj/item/stack/farming/seeds/grapes(loc)
					return
				else if (choice == "Decorative Grape Vine")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]grapes"
					S.name = "A [src] with a grape vine."
					S.filled_type = /obj/item/stack/farming/seeds/grapes
					return
		if (istype(W, /obj/item/stack/farming/seeds/apple))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the apple seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the apple seeds."
				qdel(W)
				var/obj/structure/plant_pot/clay/light/S = new /obj/structure/plant_pot/clay/light(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of potted plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Apple Tree"))
				if (choice == "Empty & Return Plant")
					new /obj/item/stack/farming/seeds/apple(loc)
					return
				else if (choice == "Decorative Apple Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]apple"
					S.name = "A [src] with a apple tree, its fruits do not look suitable for eating."
					S.filled_type = /obj/item/stack/farming/seeds/apple
					return
		if (istype(W, /obj/item/stack/farming/seeds/orange))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the orange seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the orange seeds."
				qdel(W)
				var/obj/structure/plant_pot/clay/light/S = new /obj/structure/plant_pot/clay/light(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of potted plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Orange Tree"))
				if (choice == "Empty & Return Plant")
					new /obj/item/stack/farming/seeds/orange(loc)
					return
				else if (choice == "Decorative Orange Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]orange"
					S.name = "A [src] with a orange tree, its fruits do not look suitable for eating."
					S.filled_type = /obj/item/stack/farming/seeds/orange
					return
		if (istype(W, /obj/item/stack/farming/seeds/lime))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the lime seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the lime seeds."
				qdel(W)
				var/obj/structure/plant_pot/clay/light/S = new /obj/structure/plant_pot/clay/light(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of potted plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Lime Tree"))
				if (choice == "Empty & Return Plant")
					new /obj/item/stack/farming/seeds/lime(loc)
					return
				else if (choice == "Decorative Lime Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]lime"
					S.name = "A [src] with a lime tree, its fruits do not look suitable for eating."
					S.filled_type = /obj/item/stack/farming/seeds/lime
					return
		if (istype(W, /obj/item/stack/farming/seeds/lemon))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the lemon seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the lemon seeds."
				qdel(W)
				var/obj/structure/plant_pot/clay/light/S = new /obj/structure/plant_pot/clay/light(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of potted plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Lemon Tree"))
				if (choice == "Empty & Return Plant")
					new /obj/item/stack/farming/seeds/lemon(loc)
					return
				else if (choice == "Decorative Lemon Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]lemon"
					S.name = "A [src] with a lemon tree, its fruits do not look suitable for eating."
					S.filled_type = /obj/item/stack/farming/seeds/lemon
					return
		if (istype(W, /obj/item/stack/farming/seeds/cherry))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the cherry seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the cherry seeds."
				qdel(W)
				var/obj/structure/plant_pot/clay/light/S = new /obj/structure/plant_pot/clay/light(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of potted plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Cherry Tree"))
				if (choice == "Empty & Return Plant")
					new /obj/item/stack/farming/seeds/cherry(loc)
					return
				else if (choice == "Decorative Cherry Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]cherry"
					S.name = "A [src] with a cherry tree, its fruits do not look suitable for eating."
					S.filled_type = /obj/item/stack/farming/seeds/cherry
					return
		if (istype(W, /obj/item/stack/farming/seeds/apricot))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the apricot seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the apricot seeds."
				qdel(W)
				var/obj/structure/plant_pot/clay/light/S = new /obj/structure/plant_pot/clay/light(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of potted plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Apricot Tree"))
				if (choice == "Empty & Return Plant")
					new /obj/item/stack/farming/seeds/apricot(loc)
					return
				else if (choice == "Decorative Apricot Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]apricot"
					S.name = "A [src] with a apricot tree, its fruits do not look suitable for eating."
					S.filled_type = /obj/item/stack/farming/seeds/apricot
					return
		if (istype(W, /obj/item/stack/material/plastic))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start to mould the plastic into a plant shape..."
			if (do_after(user, 15, src))
				user << "You finish moulding the plastic."
				qdel(W)
				var/obj/structure/plant_pot/medium_planter/clay/yellow/S = new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of plastic plant?","Choose a plant type","Normal",list("Empty & Return Plastic Sheet", "Plastic Tree", "Plastic Pine Tree", "Plastic Palm Tree", "Plastic Leaf Plant"))
				if (choice == "Empty & Return Plastic Sheet")
					new /obj/item/stack/material/plastic(loc)
					return
				else if (choice == "Plastic Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]plastic1"
					S.name = "A [src] with a plastic, it won't fool anybody but it looks nice."
					S.filled_type = /obj/item/stack/material/plastic
					return
				else if (choice == "Plastic Pine Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]plastic2"
					S.name = "A [src] with a plastic pine tree, it won't fool anybody but it looks nice."
					S.filled_type = /obj/item/stack/material/plastic
					return
				else if (choice == "Plastic Palm Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]plastic3"
					S.name = "A [src] with a plastic palm tree, it won't fool anybody but it looks nice."
					S.filled_type = /obj/item/stack/material/plastic
					return
				else if (choice == "Plastic Leaf Plant")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]plastic4"
					S.name = "A [src] with a plastic leaf plant, it won't fool anybody but it looks nice."
					S.filled_type = /obj/item/stack/material/plastic
					return
			return
	..()

/* Clay Planters*/

/obj/structure/plant_pot/medium_planter/clay/yellow
	name = "medium sized yellow clay planter"
	desc = "medium sized, yellow clay planter."
	icon_state = "plant_pot-03"
	planttype = "plant-03"
	plantverb = "planting"

/obj/structure/plant_pot/medium_planter/clay/yellow/proc/empty_and_return()
		new filled_type(loc)
		filled_type = null
		new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
		qdel(src)

/obj/structure/plant_pot/medium_planter/clay/yellow/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/material/trowel))
		if (filled_type)
			user << "You start removing the plant from the [src]."
			if (do_after(user, 15, src))
				empty_and_return()
				return
		else
			user << "You start refilling the [src] using the trowel..."
			if (do_after(user, 15, src))
				user << "You finish refilling the [src]."
				var/obj/structure/plant_pot/medium_planter/clay/yellow/S = new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of potted plant?","Choose a plant type","Normal",list("Empty", "Trees", "Shrubs", "Flowers"))
				if (choice == "Empty")
					return
				else if (choice == "Trees")
					var/choice1 = WWinput(user, "Which kind of Tree?","Trees","Types",list("Cherry Blossom Tree","Small Fruit Tree", "Bonsai Tree", "Small Cypress Tree", "Large Cypress Tree", "Cancel"))
					if (choice1 == "Cherry Blossom Tree")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]c"
						S.name = "A [src] with a cherry blossom tree."
					else if (choice1 == "Small Fruit Tree")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]a"
						S.name = "A [src] with a ornamental fruit tree."
					else if (choice1 == "Bonsai Tree")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]h"
						S.name = "A [src] with a bonsai minature tree."
					else if (choice1 == "Small Cypress Tree")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]f"
						S.name = "A [src] with a small cypress tree."
					else if (choice1 == "Large Cypress Tree")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]r"
						S.name = "A [src] with a large cypress tree."
						return
				if (choice == "Shrubs")
					var/choice2 = WWinput(user, "Which kind of Shrub?","Shrubbery","Types",list("Small Succulent", "Apple Topiary Bush", "Rubber Plant", "Thin Stemmmed House Plant", "Leafy Creeper", "Large Leafy Bush", "Large Jungle Bush", "Cancel"))
					if (choice2 == "Small Succulent")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]d"
						S.name = "A [src] with a small, spiky succulent cacti."
					else if (choice2 == "Apple Topiary Bush")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]applebush"
						S.name = "A [src] with a topiary bush in the shape of a apple."
					else if (choice2 == "Rubber Plant")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]g"
						S.name = "A [src] with a plant with wide rubbery leaves."
					else if (choice2 == "Thin Stemmmed House Plant")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]n"
						S.name = "A [src] with a ordinary thin stemmed house plant."
					else if (choice2 == "Leafy Creeper")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]i"
						S.name = "A [src] with a leafy creeper supported a wood stick-pole."
					else if (choice2 == "Large Leafy Bush")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]l"
						S.name = "A [src] with a large leafy bush."
					else if (choice2 == "Large Jungle Bush")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]q"
						S.name = "A [src] with a large jungle bush."
					else if (choice2 == "Cancel")
						return
				if (choice == "Flowers")
					var/choice3 = WWinput(user, "Which kind of Flower?","Flowers","Types",list("Small Flower Bouquet", "Sunflower", "Purple Angel Trumpet", "Exotic Jungle Plant Flower Bouquet", "Flower Bush", "Titan-Anum Corpse Flower", "Corpse Flower", "Purple Hicynth", "Carnivorous Pitcher Plant", "Cancel"))
					if (choice3 == "Small Flower Bouquet")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]b"
						S.name = "A [src] with a pretty bouquet of small flowers."
					else if (choice3 == "Sunflower")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]s"
						S.name = "A [src] with a sunflower."
					else if (choice3 == "Purple Angel Trumpet")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]v"
						S.name = "A [src] with a purple angel trumpet."
					else if (choice3 == "Exotic Jungle Plant Flower Bouquet")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]p"
						S.name = "A [src] with a exotic bouquet of jungle flowers."
					else if (choice3 == "Flower Bush")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]t"
						S.name = "A [src] with a flower bush."
					else if (choice3 == "Titan-Anum Corpse Flower")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]j"
						S.name = "A [src] filled with very large and brightly colored titan anum flower spilling over the sides, flies come and go to its attractive aroma."
					else if (choice3 == "Corpse Flower")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]u"
						S.name = "A [src] filled with a corpse flower, flies come and go to its attractive aroma."
					else if (choice3 == "Purple Hicynth")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]e"
						S.name = "A [src] with a tall and aromatic purple hicynth stooped under the weight of its own bulbs."
					else if (choice3 == "Carnivorous Pitcher Plant")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]k"
						S.name = "A [src] with a hungry pitcher plant, inert; it will prefer to wait for its prey to arrive."
					else if (choice3 == "Cancel")
						return
				if (choice == "Rocks")
					var/choice4 = WWinput(user, "Which kind of Rock?","Rocks","Types",list("Solitary Rock", "Cancel"))
					if (choice4 == "Solitary Rock")
						S.icon = 'icons/obj/flora/filled_plantpots.dmi'
						S.icon_state = "[planttype]rock"
						S.name = "A [src] with a solitary grey rock."
						return
		if (istype(W, /obj/item/weapon/reagent_containers/food/snacks/grown/chinchona))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the chinchona..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the chinchona."
				qdel(W)
				var/obj/structure/plant_pot/medium_planter/clay/yellow/S = new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of plant?","Choose a plant type","Normal",list("Empty & Return Plant", "Decorative Chinchona"))
				if (choice == "Empty & Return Plant")
					new /obj/item/weapon/reagent_containers/food/snacks/grown/chinchona(loc)
					return
				else if (choice == "Decorative Chinchona")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]chinchona"
					S.name = "A [src] with a chinchona plant."
					S.filled_type = /obj/item/weapon/reagent_containers/food/snacks/grown/chinchona
					return
		if (istype(W, /obj/item/stack/farming/seeds/peyote))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the peyote seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the peyote seeds."
				qdel(W)
				var/obj/structure/plant_pot/medium_planter/clay/yellow/S = new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Peyote"))
				if (choice == "Empty & Return Seeds")
					new /obj/item/stack/farming/seeds/peyote(loc)
					return
				else if (choice == "Decorative Peyote")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]peyote"
					S.name = "A [src] with a peyote plant."
					S.filled_type = /obj/item/stack/farming/seeds/peyote
					return
		if (istype(W, /obj/item/stack/farming/seeds/poppy))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the poppy seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the poppy seeds."
				qdel(W)
				var/obj/structure/plant_pot/medium_planter/clay/yellow/S = new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Poppy"))
				if (choice == "Empty & Return Seeds")
					new /obj/item/stack/farming/seeds/poppy(loc)
					return
				else if (choice == "Decorative Poppy")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]poppy"
					S.name = "A [src] with a poppy plant."
					S.filled_type = /obj/item/stack/farming/seeds/poppy
					return
		if (istype(W, /obj/item/stack/farming/seeds/bamboo))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the bamboo seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the bamboo seeds."
				qdel(W)
				var/obj/structure/plant_pot/medium_planter/clay/yellow/S = new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Bamboo"))
				if (choice == "Empty & Return Seeds")
					new /obj/item/stack/farming/seeds/bamboo(loc)
					return
				else if (choice == "Decorative Bamboo")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]bamboo"
					S.name = "A [src] with bamboo shoots."
					S.filled_type = /obj/item/stack/farming/seeds/bamboo
					return
		if (istype(W, /obj/item/stack/farming/seeds/coffee))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the coffee seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the coffee seeds."
				qdel(W)
				var/obj/structure/plant_pot/medium_planter/clay/yellow/S = new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Coffee"))
				if (choice == "Empty & Return Seeds")
					new /obj/item/stack/farming/seeds/coffee(loc)
					return
				else if (choice == "Decorative Coffee")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]coffee"
					S.name = "A [src] with a coffee plant."
					S.filled_type = /obj/item/stack/farming/seeds/coffee
					return
		if (istype(W, /obj/item/stack/farming/seeds/grapes))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the grape seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the grape seeds."
				qdel(W)
				var/obj/structure/plant_pot/medium_planter/clay/yellow/S = new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Grape Vine"))
				if (choice == "Empty & Return Seeds")
					new /obj/item/stack/farming/seeds/grapes(loc)
					return
				else if (choice == "Decorative Grape Vine")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]grapes"
					S.name = "A [src] with a grape vine."
					S.filled_type = /obj/item/stack/farming/seeds/grapes
					return
		if (istype(W, /obj/item/stack/farming/seeds/apple))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the apple seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the apple seeds."
				qdel(W)
				var/obj/structure/plant_pot/medium_planter/clay/yellow/S = new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Apple Tree"))
				if (choice == "Empty & Return Seeds")
					new /obj/item/stack/farming/seeds/apple(loc)
					return
				else if (choice == "Decorative Apple Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]apple"
					S.name = "A [src] with a apple tree, its fruits do not look suitable for eating."
					S.filled_type = /obj/item/stack/farming/seeds/apple
					return
		if (istype(W, /obj/item/stack/farming/seeds/orange))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the orange seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the orange seeds."
				qdel(W)
				var/obj/structure/plant_pot/medium_planter/clay/yellow/S = new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Orange Tree"))
				if (choice == "Empty & Return Seeds")
					new /obj/item/stack/farming/seeds/orange(loc)
					return
				else if (choice == "Decorative Orange Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]orange"
					S.name = "A [src] with a orange tree, its fruits do not look suitable for eating."
					S.filled_type = /obj/item/stack/farming/seeds/orange
					return
		if (istype(W, /obj/item/stack/farming/seeds/lime))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the lime seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the lime seeds."
				qdel(W)
				var/obj/structure/plant_pot/medium_planter/clay/yellow/S = new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Lime Tree"))
				if (choice == "Empty & Return Seeds")
					new /obj/item/stack/farming/seeds/lime(loc)
					return
				else if (choice == "Decorative Lime Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]lime"
					S.name = "A [src] with a lime tree, its fruits do not look suitable for eating."
					S.filled_type = /obj/item/stack/farming/seeds/lime
					return
		if (istype(W, /obj/item/stack/farming/seeds/lemon))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the lemon seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the lemon seeds."
				qdel(W)
				var/obj/structure/plant_pot/medium_planter/clay/yellow/S = new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Lemon Tree"))
				if (choice == "Empty & Return Seeds")
					new /obj/item/stack/farming/seeds/lemon(loc)
					return
				else if (choice == "Decorative Lemon Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]lemon"
					S.name = "A [src] with a lemon tree, its fruits do not look suitable for eating."
					S.filled_type = /obj/item/stack/farming/seeds/lemon
					return
		if (istype(W, /obj/item/stack/farming/seeds/cherry))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the cherry seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the cherry seeds."
				qdel(W)
				var/obj/structure/plant_pot/medium_planter/clay/yellow/S = new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Cherry Tree"))
				if (choice == "Empty & Return Seeds")
					new /obj/item/stack/farming/seeds/cherry(loc)
					return
				else if (choice == "Decorative Cherry Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]cherry"
					S.name = "A [src] with a cherry tree, its fruits do not look suitable for eating."
					S.filled_type = /obj/item/stack/farming/seeds/cherry
					return
		if (istype(W, /obj/item/stack/farming/seeds/apricot))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the apricot seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the apricot seeds."
				qdel(W)
				var/obj/structure/plant_pot/medium_planter/clay/yellow/S = new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Apricot Tree"))
				if (choice == "Empty & Return Seeds")
					new /obj/item/stack/farming/seeds/apricot(loc)
					return
				else if (choice == "Decorative Apricot Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]apricot"
					S.name = "A [src] with a apricot tree, its fruits do not look suitable for eating."
					S.filled_type = /obj/item/stack/farming/seeds/apricot
					return
		if (istype(W, /obj/item/stack/farming/seeds/olives))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the olive seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the olive seeds."
				qdel(W)
				var/obj/structure/plant_pot/medium_planter/clay/yellow/S = new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Olive Tree"))
				if (choice == "Empty & Return Seeds")
					new /obj/item/stack/farming/seeds/olives(loc)
					return
				else if (choice == "Decorative Olive Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]olives"
					S.name = "A [src] with a olive tree, its fruits do not look suitable for harvesting."
					S.filled_type = /obj/item/stack/farming/seeds/olives
					return
		if (istype(W, /obj/item/stack/farming/seeds/coconut))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the coconut seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the coconut seeds."
				qdel(W)
				var/obj/structure/plant_pot/medium_planter/clay/yellow/S = new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Coconut Tree", "Wavy Coconut Tree"))
				if (choice == "Empty & Return Seeds")
					new /obj/item/stack/farming/seeds/coconut(loc)
					return
				else if (choice == "Decorative Coconut Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]coconut2"
					S.name = "A [src] with a coconut tree, its fruits do not look suitable for harvesting."
					S.filled_type = /obj/item/stack/farming/seeds/coconut
					return
				else if (choice == "Wavy Coconut Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]coconut"
					S.name = "A [src] with a coconut tree, its fruits do not look suitable for harvesting."
					S.filled_type = /obj/item/stack/farming/seeds/coconut
					return
		if (istype(W, /obj/item/stack/farming/seeds/pumpkin))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the pumpkin seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the pumpkin seeds."
				qdel(W)
				var/obj/structure/plant_pot/medium_planter/clay/yellow/S = new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Pumpkin Vine"))
				if (choice == "Empty & Return Seeds")
					new /obj/item/stack/farming/seeds/pumpkin(loc)
					return
				else if (choice == "Decorative Pumpkin Vine")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]pumpkin"
					S.name = "A [src] with a pumpkin vine, it does not look suitable for harvesting."
					S.filled_type = /obj/item/stack/farming/seeds/pumpkin
					return
		if (istype(W, /obj/item/stack/farming/seeds/banana))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start [plantverb] the banana seeds..."
			if (do_after(user, 15, src))
				user << "You finish [plantverb] the banana seeds."
				qdel(W)
				var/obj/structure/plant_pot/medium_planter/clay/yellow/S = new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of plant?","Choose a plant type","Normal",list("Empty & Return Seeds", "Decorative Banana Tree"))
				if (choice == "Empty & Return Seeds")
					new /obj/item/stack/farming/seeds/banana(loc)
					return
				else if (choice == "Decorative Banana Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]banana"
					S.name = "A [src] with a banana tree, its fruits do not look suitable for eating."
					S.filled_type = /obj/item/stack/farming/seeds/banana
					return
		if (istype(W, /obj/item/stack/material/plastic))
			if (filled_type)
				user << "<span class = 'warning'>You need to remove the current plant first with the trowel before you [plantverb] this.</span>"
				return
		else
			user << "You start to mould the plastic into a plant shape..."
			if (do_after(user, 15, src))
				user << "You finish moulding the plastic."
				qdel(W)
				var/obj/structure/plant_pot/medium_planter/clay/yellow/S = new /obj/structure/plant_pot/medium_planter/clay/yellow(loc)
				qdel(src)
				var/choice = WWinput(user, "What type of plastic plant?","Choose a plant type","Normal",list("Empty & Return Plastic Sheet", "Plastic Tree", "Plastic Pine Tree", "Plastic Palm Tree", "Plastic Leaf Plant"))
				if (choice == "Empty & Return Plastic Sheet")
					new /obj/item/stack/material/plastic(loc)
					return
				else if (choice == "Plastic Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]plastic1"
					S.name = "A [src] with a plastic tree, it won't fool anybody but it looks nice."
					S.filled_type = /obj/item/stack/material/plastic
					return
				else if (choice == "Plastic Pine Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]plastic2"
					S.name = "A [src] with a plastic pine tree, it won't fool anybody but it looks nice."
					S.filled_type = /obj/item/stack/material/plastic
					return
				else if (choice == "Plastic Palm Tree")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]plastic3"
					S.name = "A [src] with a plastic palm tree, it won't fool anybody but it looks nice."
					S.filled_type = /obj/item/stack/material/plastic
					return
				else if (choice == "Plastic Leaf Plant")
					S.icon = 'icons/obj/flora/filled_plantpots.dmi'
					S.icon_state = "[planttype]plastic4"
					S.name = "A [src] with a plastic leaf plant, it won't fool anybody but it looks nice."
					S.filled_type = /obj/item/stack/material/plastic
					return
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


/obj/structure/plant_pot/attackby(obj/O as obj, mob/living/carbon/human/user as mob)
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