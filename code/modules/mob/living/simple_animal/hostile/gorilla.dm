/mob/living/simple_animal/hostile/gorilla
	name = "gorilla"
	desc =  "The largest member of the great-apes, their fierce reputation misrepresents their gentle nature unless provoked."
	icon = 'icons/mob/animals_32x64.dmi'
	icon_state = "gorilla_crawling"
	icon_living = "gorilla_crawling"
	icon_dead = "gorilla_dead"
	speak = list("Uh uh ah","HOOOOH OOOH!","Ah uh uh!")
	speak_emote = list("growls","screams","howls")
	emote_hear = list("growls","screams","howls")
	emote_see = list("paces around", "beats its chest")
	health = 450
	maxHealth = 450
	move_to_delay = 5
	attacktext = "beats with fists"
	melee_damage_lower = 35
	melee_damage_upper = 50
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "punches"
	mob_size = MOB_LARGE
	granivore = 1
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	hostilesounds = list('sound/animals/gorilla/gorilla_roar.ogg')
	behaviour = "defends"

/mob/living/simple_animal/hostile/gorilla/gigantopithecus
	name = "giganthopithecus"
	desc =  "The largest ape to have ever lived, powerfully stocked with muscle and inhuman intelligence."
	icon_state = "gigantopithecus"
	icon_living = "gigantopithecus"
	icon_dead = "gigantopithecus_dead"
	speak = list("Uh uh ah","HOOOOH OOOH!","Ah uh uh!")
	speak_emote = list("growls","screams","howls")
	emote_hear = list("growls","screams","howls")
	emote_see = list("paces around", "beats its chest")
	health = 750
	maxHealth = 750
	move_to_delay = 4
	attacktext = "beats with fists"
	melee_damage_lower = 45
	melee_damage_upper = 50
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "punches"
	mob_size = MOB_HUGE
	granivore = 1
	meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat
	behaviour = "defends"

/mob/living/simple_animal/hostile/gorilla/gigantopithecus/bigfoot
	name = "bigfoot"
	desc =  "A elusive creatures of myth, long believed to be surviving members of a dying race."
	behaviour = "scared"

/mob/living/simple_animal/hostile/gorilla/gigantopithecus/yeti
	name = "yeti"
	desc =  "A elusive creatures of myth, you would be lucky to have never encountered its predatory appetite."
	icon_state = "yeti"
	icon_living = "yeti"
	icon_dead = "yeti_dead"
	predatory_carnivore = 1
	carnivore = 1
	scavenger = 1
	granivore = 0
	behaviour = "hunt"