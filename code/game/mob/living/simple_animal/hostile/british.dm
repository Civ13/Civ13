/mob/living/simple_animal/hostile/human/voyage/british
	name = "Redcoat Soldier"
	desc = "A british soldier."
	icon_state = "britishmelee1"
	icon_dead = "britishmelee1_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("FOR THE KING!","Fucking pirates!")
	speak_emote = list("grumbles", "screams")
	emote_hear = list("curses","grumbles","screams")
	emote_see = list("stares ferociously", "stomps")
	speak_chance = TRUE
	stop_automated_movement_when_pulled = 0
	maxHealth = 100
	health = 100
	harm_intent_damage = 5
	melee_damage_lower = 30
	melee_damage_upper = 40
	attacktext = "slashed"
	attack_sound = 'sound/weapons/bladeslice.ogg'
	mob_size = MOB_MEDIUM
	behaviour = "hostile"
	base_icon = "britishmelee1"

	corpse = /mob/living/human/corpse/british

	faction = BRITISH
	New()
		..()
		base_icon = "britishmelee[rand(1,6)]"
		icon_state = "[base_icon]"

/mob/living/simple_animal/hostile/human/voyage/british/ranged
	name = "Redcoat Soldier"
	desc = "A british soldier."
	icon_state = "britishranged1"
	icon_dead = "britishranged1_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list()
	speak_emote = list()
	emote_hear = list()
	emote_see = list("stares", "cocks musket")
	speak_chance = TRUE
	stop_automated_movement_when_pulled = 0
	maxHealth = 150
	health = 150
	harm_intent_damage = 10
	melee_damage_lower = 35
	melee_damage_upper = 45
	attacktext = "bashed"
	attack_sound = 'sound/weapons/punch3.ogg'
	mob_size = MOB_MEDIUM
	starves = FALSE
	behaviour = "hostile"
	faction = BRITISH
	ranged = TRUE
	rapid = FALSE
	firedelay = 80
	projectiletype = /obj/item/projectile/bullet/rifle/musketball_pistol
	corpse = /mob/living/human/corpse/british
	casingtype = null
	attack_verb = "slashes"
	base_icon = "britishmelee1"

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
		base_icon = "britishranged[rand(1,6)]"
		icon_state = "[base_icon]"
		if (behaviour == "defend")
			icon_state = "[base_icon]_docile"
			fire_cannons = FALSE

/mob/living/simple_animal/hostile/human/townmilitia
	name = "Town Militia"
	desc = "A british town militia."
	icon_state = "britishmelee1"
	icon_dead = "britishmelee1_dead"
	response_help = "pushes"
	response_disarm = "shoves"
	response_harm = "hits"
	speak = list("FOR THE KING!","Fucking pirates!")
	speak_emote = list("grumbles", "screams")
	emote_hear = list("curses","grumbles","screams")
	emote_see = list("stares ferociously", "stomps")
	speak_chance = TRUE
	speed = 4
	stop_automated_movement_when_pulled = 0
	maxHealth = 100
	health = 100
	harm_intent_damage = 5
	melee_damage_lower = 30
	melee_damage_upper = 40
	attacktext = "slashed"
	attack_sound = 'sound/weapons/bladeslice.ogg'


	corpse = /mob/living/human/corpse/british
	faction = CIVILIAN
