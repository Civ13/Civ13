/mob/living/simple_animal/hostile/human/voyage/pirate
	name = "Pirate"
	desc = "Does what he wants cause a pirate is free."
	icon_state = "piratemelee"
	icon_dead = "piratemelee_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("ARRR!","Landlubber!")
	speak_emote = list("grumbles", "screams")
	emote_hear = list("curses","grumbles","screams")
	emote_see = list("stares ferociously", "stomps")
	attack_verb = "slashes"

	maxHealth = 100
	health = 100
	faction = CIVILIAN
	harm_intent_damage = 15
	melee_damage_lower = 30
	melee_damage_upper = 40
	attacktext = "slashed"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	behaviour = "hostile"
	role = "soldier"

	corpse = /mob/living/human/corpse/pirate
	weapon = /obj/item/weapon/material/sword/cutlass

///mob/living/simple_animal/hostile/human/voyage/pirate/New()
//	..()
//	var/icon_pick = pick("piratemelee","piratemelee1","piratemelee2")
//	icon_living = icon_pick
//	icon_state = icon_pick

/mob/living/simple_animal/hostile/human/voyage/pirate/ranged
	name = "Pirate"
	desc = "Does what he wants cause a pirate is free."
	icon_state = "pirateranged"
	icon_dead = "pirateranged_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list()
	speak_emote = list()
	emote_hear = list()
	emote_see = list("stares", "cocks musket")

	speed = 6
	stop_automated_movement_when_pulled = 0
	maxHealth = 150
	health = 150
	move_to_delay = 4
	harm_intent_damage = 10
	melee_damage_lower = 35
	melee_damage_upper = 45
	attacktext = "bashed"
	attack_sound = 'sound/weapons/punch3.ogg'
	starves = FALSE
	behaviour = "hostile"
	ranged = TRUE
	rapid = FALSE
	firedelay = 100
	projectiletype = /obj/item/projectile/bullet/rifle/musketball_pistol
	corpse = /mob/living/human/corpse/pirate
	casingtype = null
	role = "soldier"

	New()
		..()
		messages["injured"] = list("!!I am injured!","!!I'm hit!!")
		messages["backup"] = list("!!Over here!", "!!Come here!!")
		messages["enemy_sighted"] = list("!!I see one!", "!!HEY YOU!!")
		messages["grenade"] = list("!!GRENADE!")
		if (prob(65))
			gun = new/obj/item/weapon/gun/projectile/flintlock/musketoon(src)
		else
			gun = new/obj/item/weapon/gun/projectile/flintlock/musket(src)

/mob/living/simple_animal/hostile/human/voyage/pirate/ranged/captain
	name = "Pirate Captain"
	desc = "Does what he wants cause a pirate is free. But isn't hostile at first. This one has a flaming beard, pretty cool."
	icon_state = "pirate_friendly_captain"
	icon_dead = "piratemelee_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("Sure could use a drink","Landlubber!","can't wait to go see the girls of ol' maui", "time for drinking lads!!", "took some damage in that last fight", "Ahoy! this be your captain! ME! Yahaaargh!")
	speak_emote = list("grumbles", "screams")
	emote_hear = list("curses","grumbles","screams")
	emote_see = list("stares ferociously", "stomps")
	maxHealth = 200
	role = "officer"
	health = 200
	harm_intent_damage = 10
	melee_damage_lower = 20
	melee_damage_upper = 40
	attacktext = "punched"
	attack_sound = 'sound/weapons/punch3.ogg'
	behaviour = "wander"
	firedelay = 60

	corpse = /mob/living/human/corpse/pirate
	New()
		..()
		faction2_npcs++
		messages["injured"] = list("!!I'm hit!","!!AAARGH!")
		messages["backup"] =list( "!!I need help!","!!To my side!")
		messages["enemy_sighted"] = list("!!Landlubber ahead!","!!Enemy in my sights!")
		messages["grenade"] = list("!!GRENADE!!!", "!!Grenade, run!!")

		gun = new/obj/item/weapon/gun/projectile/flintlock/pistoletmodelean1733(src)
		icon_state = "pirate_friendly_captain"

/mob/living/simple_animal/hostile/human/voyage/pirate/friendly
	name = "Pirate"
	desc = "Does what he wants cause a pirate is free. But isn't hostile at first."
	icon_state = "pirate_friendly1"
	icon_dead = "piratemelee_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("Sure could use a drink","Landlubber!","can't wait to go see the girls of ol' maui", "time for drinking lads!!", "took some damage in that last fight")
	speak_emote = list("grumbles", "screams")
	emote_hear = list("curses","grumbles","screams")
	emote_see = list("stares ferociously", "stomps")
	maxHealth = 100
	health = 100
	harm_intent_damage = 5
	melee_damage_lower = 5
	melee_damage_upper = 10
	attacktext = "punched"
	attack_sound = 'sound/weapons/punch3.ogg'
	behaviour = "wander"
	wander = TRUE
	stance = HOSTILE_STANCE_IDLE
	corpse = /mob/living/human/corpse/pirate
	faction = PIRATES
	fire_cannons = FALSE
	attack_verb = "hits"
	role = "soldier"
	New()
		..()
		if(prob(33))
			ranged = TRUE
			firedelay = 100
			projectiletype = /obj/item/projectile/bullet/rifle/musketball_pistol
			gun = new/obj/item/weapon/gun/projectile/flintlock/pistol(src)
		else
			weapon = /obj/item/weapon/material/sword/cutlass
		messages["injured"] = list("!!I'm hit!","!!AAARGH!")
		messages["backup"] =list( "!!I need help!","!!Help me!")
		messages["enemy_sighted"] = list("!!Landlubber ahead!","!!Enemy in my sights!")
		messages["grenade"] = list("!!GRENADE!!!", "!!Grenade, run!!")

		icon_state = "pirate_friendly[rand(1,3)]"


/mob/living/simple_animal/hostile/human/voyage/pirate/friendly/captain
	name = "Pirate Captain"
	desc = "Does what he wants cause a pirate is free. But isn't hostile at first. This one has a flaming beard, pretty cool."
	icon_state = "pirate_friendly_captain"
	icon_dead = "piratemelee_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("Sure could use a drink","Landlubber!","can't wait to go see the girls of ol' maui", "time for drinking lads!!", "took some damage in that last fight", "Ahoy! this be your captain! ME! Yahaaargh!")
	speak_emote = list("grumbles", "screams")
	emote_hear = list("curses","grumbles","screams")
	emote_see = list("stares ferociously", "stomps")

	maxHealth = 200
	role = "officer"
	health = 200
	harm_intent_damage = 10
	melee_damage_lower = 20
	melee_damage_upper = 40
	attacktext = "punched"
	attack_sound = 'sound/weapons/punch3.ogg'
	behaviour = "wander"

	corpse = /mob/living/human/corpse/pirate
	New()
		..()
		faction2_npcs++
		messages["injured"] = list("!!I'm hit!","!!AAARGH!")
		messages["backup"] =list( "!!I need help!","!!To my side!")
		messages["enemy_sighted"] = list("!!Landlubber ahead!","!!Enemy in my sights!")
		messages["grenade"] = list("!!GRENADE!!!", "!!Grenade, run!!")

		gun = new/obj/item/weapon/material/sword/cutlass(src)
		icon_state = "pirate_friendly_captain"

/mob/living/simple_animal/hostile/human/voyage/pirate/friendly/blindman
	name = "Old Blind Pirate"
	desc = "Does what he wants cause a pirate is free. But isn't hostile at first. This one has no vision, but is probably experienced enough to kick your ass, even with no eyes."
	icon_state = "pirate_friendly_blind"
	icon_dead = "piratemelee_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("Sure could use a drink","Landlubber!","can't wait to go see the girls of ol' maui", "time for drinking lads!!", "took some damage in that last fight", "Ahoy! this be your captain! ME! Yahaaargh!")
	speak_emote = list("grumbles", "screams")
	emote_hear = list("curses","grumbles","screams")
	emote_see = list("stares ferociously", "stomps")

	maxHealth = 200
	role = "medic"
	health = 500
	harm_intent_damage = 50
	melee_damage_lower = 50
	melee_damage_upper = 50
	attacktext = "punched"
	attack_sound = 'sound/weapons/punch3.ogg'
	behaviour = "wander"
	role = "soldier"
	corpse = /mob/living/human/corpse/pirate
	New()
		..()
		faction2_npcs++
		messages["injured"] = list("!!I'm hit!","!!Ye dare fight an old man?!")
		messages["backup"] =list( "!!I need help!","!!To my side!")
		messages["enemy_sighted"] = list("!!Cripple abuser!","!!Enemy in my sights! Even though I cant see!")
		messages["grenade"] = list("!!OOO, A SCARY GRENADE!!!", "!!AHARGH, I EAT GRENADES FOR BREAKFAST!!")
		icon_state = "pirate_friendly_blind"

/mob/living/simple_animal/hostile/human/voyage/pirate/friendly/female
	name = "Pirate Woman"
	desc = "Does what she wants cause a pirate is free. But isn't hostile at first.."
	icon_state = "pirate_friendly_female"
	icon_dead = "piratemelee_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("Sure could use a drink","Landlubber!", "time for drinking lads!!", "took some damage in that last fight")
	speak_emote = list("grumbles", "screams")
	emote_hear = list("curses","grumbles","screams")
	emote_see = list("stares ferociously", "stomps")

	maxHealth = 200
	role = "officer"
	health = 200
	harm_intent_damage = 10
	melee_damage_lower = 20
	melee_damage_upper = 40
	attacktext = "punched"
	attack_sound = 'sound/weapons/punch3.ogg'
	behaviour = "wander"
	role = "soldier"
	corpse = /mob/living/human/corpse/pirate
	New()
		..()
		faction2_npcs++
		messages["injured"] = list("!!I'm hit!","!!Ye dare hit a woman?!")
		messages["backup"] =list( "!!I need help!","!!To my side!")
		messages["enemy_sighted"] = list("!!Landlubber ahead!","!!Enemy in my sights!")
		messages["grenade"] = list("!!GRENADE!!!", "!!Grenade, run!!")

		weapon = /obj/item/weapon/material/sword/cutlass
		icon_state = "pirate_friendly_female"

/mob/living/simple_animal/hostile/human/voyage/slaver
	name = "slaver"
	desc = "A slave owner and conductor."
	icon_state = "slaver1"
	icon_dead = "slaver1_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("C'mon, work!")
	speak_emote = list("grumbles", "screams")
	emote_hear = list("curses","grumbles","screams")
	emote_see = list("stares ferociously", "stomps")
	maxHealth = 100
	health = 100
	harm_intent_damage = 15
	melee_damage_lower = 20
	melee_damage_upper = 30
	attacktext = "whipped"
	attack_sound = 'sound/weapons/punch3.ogg'
	behaviour = "wander"
	wander = TRUE
	stance = HOSTILE_STANCE_IDLE
	faction = PIRATES
	fire_cannons = FALSE
	attack_verb = "whips"
	role = "soldier"
	New()
		..()
		weapon = /obj/item/weapon/melee/classic_baton/whip
		messages["injured"] = list("!!I'm hit!","!!AAARGH!")
		messages["backup"] =list( "!!I need help!","!!Help me!")
		messages["enemy_sighted"] = list("!!Landlubber ahead!","!!Enemy in my sights!")
		messages["grenade"] = list("!!GRENADE!!!", "!!Grenade, run!!")

/mob/living/simple_animal/hostile/human/voyage/slaver/club
	name = "slaver"
	desc = "A slave owner and conductor."
	icon_state = "slaver2"
	icon_dead = "slaver2_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("C'mon, work!")
	speak_emote = list("grumbles", "screams")
	emote_hear = list("curses","grumbles","screams")
	emote_see = list("stares ferociously", "stomps")
	maxHealth = 100
	health = 100
	harm_intent_damage = 18
	melee_damage_lower = 22
	melee_damage_upper = 32
	attacktext = "clubbed"
	attack_sound = 'sound/weapons/punch3.ogg'
	behaviour = "wander"
	wander = TRUE
	stance = HOSTILE_STANCE_IDLE
	faction = PIRATES
	fire_cannons = FALSE
	attack_verb = "clubs"
	role = "soldier"
	New()
		..()
		weapon = /obj/item/weapon/melee/classic_baton/club
		messages["injured"] = list("!!I'm hit!","!!AAARGH!")
		messages["backup"] =list( "!!I need help!","!!Help me!")
		messages["enemy_sighted"] = list("!!Landlubber ahead!","!!Enemy in my sights!")
		messages["grenade"] = list("!!GRENADE!!!", "!!Grenade, run!!")