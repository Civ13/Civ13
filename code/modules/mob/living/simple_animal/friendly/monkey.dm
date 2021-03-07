/mob/living/simple_animal/monkey
	name = "monkey"
	desc = "A monkey. The meat makes a delicious soup."
	icon = 'icons/mob/animal.dmi'
	icon_state = "monkey"
	icon_living = "monkey"
	icon_dead = "monkey_dead"
	speak = list("Uh uh uh","AAAAH AAAAH!","Uh uh uh!")
	speak_emote = list("growls","screams","howls")
	emote_hear = list("growls","screams","howls")
	emote_see = list("walks around", "waves his hands", "scratches its head")
	health = 55
	maxHealth = 55
	meat_amount = 2
	attacktext = "bitten"
	melee_damage_lower = 6
	melee_damage_upper = 9
	response_help  = "pets"
	response_disarm = "shoos"
	response_harm   = "hits"
	mob_size = MOB_MEDIUM
	possession_candidate = TRUE
	granivore = 1
	behaviour = "scared"

/mob/living/simple_animal/monkey/kostas
	name = "Kostas the Monkey"
	desc = "A species of greek monkey."