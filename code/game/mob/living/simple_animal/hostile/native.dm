/mob/living/simple_animal/hostile/native
	name = "native"
	desc = "Seems ferocious."
	icon_state = "native_melee1"
	icon_dead = "native_melee1_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("kakare peri!!","totomo asale", "nakaka muniri!")
	speak_emote = list("grumbles", "screams")
	emote_hear = list("grumbles","screams")
	emote_see = list("stares ferociously", "stomps")
	speak_chance = TRUE
	speed = 5
	maxHealth = 120
	health = 120
	move_to_delay = 5
	stop_automated_movement_when_pulled = FALSE
	harm_intent_damage = 15
	melee_damage_lower = 30
	melee_damage_upper = 40
	attacktext = "slashed"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	mob_size = MOB_MEDIUM
	starves = FALSE
	faction = INDIANS
	attack_verb = "slashes"
	behaviour = "hostile"

/mob/living/simple_animal/hostile/native/New()
	..()
	var/icon_pick = pick("native_melee1","native_melee2","native_melee3")
	icon_living = icon_pick
	icon_state = icon_pick
	icon_dead = "[icon_pick]_dead"

/mob/living/simple_animal/hostile/native/bigboi
	name = "giant native"
	desc = "A massive native, better avoided."
	maxHealth = 300
	health = 300
	move_to_delay = 7
	speed = 7
	harm_intent_damage = 30
	melee_damage_lower = 50
	melee_damage_upper = 70
	attacktext = "bludgeoned"
	attack_verb = "hits"
	icon_state = "native_bigboi"
/mob/living/simple_animal/hostile/native/bigboi/New()
	..()
	icon_living = "native_bigboi"
	icon_state = "native_bigboi"
	icon_dead = "native_bigboi_dead"

/mob/living/simple_animal/hostile/human/native/ranged
	name = "native"
	desc = "Seems ferocious."
	icon_state = "native_ranged1"
	icon_dead = "native_ranged1_dead"
	emote_see = list("stares", "prepares an arrow")
	harm_intent_damage = 10
	attack_sound = 'sound/weapons/punch3.ogg'
	behaviour = "hostile"
	starves = FALSE
	ranged = TRUE
	rapid = FALSE
	firedelay = 40
	projectiletype = /obj/item/projectile/arrow/arrow/copper
	casingtype = null
	attack_verb = "slashes"

	New()
		..()
		var/icon_pick = pick("native_ranged1","native_ranged2")
		icon_living = icon_pick
		icon_state = icon_pick
		icon_dead = "[icon_pick]_dead"
		messages["injured"] = list("!!Namale suni!","!!Kako!!")
		messages["backup"] = list("!!Malé!!", "!!Sale!")
		messages["enemy_sighted"] = list("!!Unga Dunga!", "!!Muko!!")
		messages["grenade"] = list("!!BANGAAA!")