/datum/spell
	var/name = "Spell"
	var/description = ""
	var/proj_type = null
	var/skill_level = 0
	var/cast_time = 8
	var/learnable = FALSE

/// The Fundamentals (Beginner Magic) ///

/datum/spell/zappus
	name = "Zappus"
	description = "A weak but reliable spark of magic. Good for annoying Nuggles and breaking pots."
	proj_type = /obj/item/projectile/magic/zappus
	skill_level = 0
	cast_time = 5
	learnable = TRUE

/datum/spell/blockum
	name = "Blockum"
	description = "Creates a shimmering bubble of denial around the caster. Simply say 'Nuh-Uh!' to danger."
	proj_type = /obj/item/projectile/magic/blockum
	skill_level = 10
	cast_time = 2
	learnable = TRUE

/datum/spell/dropus
	name = "Dropus"
	description = "The signature spell of Barry Hatter. Politely asks the target to drop whatever they are holding."
	proj_type = /obj/item/projectile/magic/dropus
	skill_level = 15
	cast_time = 10
	learnable = TRUE

/// Force & Physics (Intermediate Magic) ///

/datum/spell/pushum
	name = "Pushum"
	description = "A rude, invisible shove. Excellent for tavern brawls and pushing prefects down the stairs."
	proj_type = /obj/item/projectile/magic/pushum
	skill_level = 25
	cast_time = 12
	learnable = TRUE

/datum/spell/pullus
	name = "Pullus"
	description = "Lazily drags a person, or that sandwich across the room, right to your feet."
	proj_type = /obj/item/projectile/magic/pullus
	skill_level = 30
	cast_time = 15
	learnable = TRUE

/// Control & Chaos (Advanced Magic) ///

/datum/spell/freezeum
	name = "Freezeum"
	description = "Encases the target in a block of suspiciously unmelting ice."
	skill_level = 50
	cast_time = 25
	learnable = TRUE
	proj_type = /obj/item/projectile/magic/freezum

/// Destruction (Expert Magic) ///

/datum/spell/burnus
	name = "Burnus"
	description = "A reckless burst of flame. Do not use near the Shrieking Shrub or in the library."
	skill_level = 55
	cast_time = 20
	learnable = TRUE
	proj_type = /obj/item/projectile/magic/fire_bolt

/datum/spell/sliceum
	name = "Sliceum"
	description = "An invisible, incredibly sharp slashing strike."
	proj_type = /obj/item/projectile/magic/sliceum
	skill_level = 70
	cast_time = 30
	learnable = TRUE

/datum/spell/explodus
	name = "Explodus"
	description = "A highly illegal compression of explosive magical force. The janitors hate this one."
	proj_type = /obj/item/projectile/magic/explodus
	skill_level = 80
	cast_time = 45
	learnable = TRUE

/// The \"Naughty\" Curses (Dark Arts) ///

/datum/spell/painum
	name = "Painum"
	description = "A forbidden curse that causes unimaginable agony. Usually results in expulsion and/or jail time."
	proj_type = /obj/item/projectile/magic/painum
	skill_level = 85
	cast_time = 50
	learnable = TRUE

/datum/spell/deadum
	name = "Deadum"
	description = "The ultimate forbidden spell. A blinding green light that simply deletes life."
	proj_type = /obj/item/projectile/magic/deadum
	skill_level = 100
	cast_time = 80
	learnable = TRUE

/// Previously Existing Spells ///

/datum/spell/spark
	name = "Spark"
	description = "A minor electrical discharge used for basic magic practice."
	proj_type = /obj/item/projectile/magic/spark
	skill_level = 0
	cast_time = 5

/datum/spell/flare
	name = "Flare"
	description = "A bright magical flame that burns the target."
	proj_type = /obj/item/projectile/magic/flare
	skill_level = 0
	cast_time = 8

/datum/spell/root
	name = "Root"
	description = "Summons basic vines to hold a target in place."
	proj_type = /obj/item/projectile/magic/root
	skill_level = 0
	cast_time = 8

/datum/spell/ice_shard
	name = "Ice Shard"
	description = "A jagged piece of ice thrown with magical force."
	proj_type = /obj/item/projectile/magic/ice_shard
	skill_level = 0
	cast_time = 8

/datum/spell/shock_bolt
	name = "Shock Bolt"
	description = "A concentrated bolt of lightning that shocks and stuns."
	proj_type = /obj/item/projectile/magic/shock_bolt
	skill_level = 50
	cast_time = 8

/datum/spell/fire_bolt
	name = "Fire Bolt"
	description = "A bolt of fire designed to set the target ablaze."
	proj_type = /obj/item/projectile/magic/fire_bolt
	skill_level = 50
	cast_time = 8

/datum/spell/vine_shot
	name = "Vine Shot"
	description = "Shoots a cluster of vines to entangle the enemy."
	proj_type = /obj/item/projectile/magic/vine_shot
	skill_level = 50
	cast_time = 8

/datum/spell/ice_blast
	name = "Ice Blast"
	description = "A powerful blast of freezing energy."
	proj_type = /obj/item/projectile/magic/ice_blast
	skill_level = 50
	cast_time = 8

/datum/spell/lightning_strike
	name = "Lightning Strike"
	description = "A devastating strike of high-voltage magic."
	proj_type = /obj/item/projectile/magic/lightning_strike
	skill_level = 75
	cast_time = 8

/datum/spell/fire_ball
	name = "Fire Ball"
	description = "A massive sphere of fire that creates an explosion."
	proj_type = /obj/item/projectile/magic/fire_ball
	skill_level = 75
	cast_time = 8

/datum/spell/ensnare
	name = "Ensnare"
	description = "Advanced plant magic that completely incapacitates the target."
	proj_type = /obj/item/projectile/magic/ensnare
	skill_level = 75
	cast_time = 8

/datum/spell/frozen_rain
	name = "Frozen Rain"
	description = "Calls down a chilling deluge to freeze enemies solid."
	proj_type = /obj/item/projectile/magic/frozen_rain
	skill_level = 75
	cast_time = 8


/mob/proc/add_spell(var/datum/spell/S)
	if(!S)
		return FALSE
	if(!spell_list)
		spell_list = list()
	spell_list |= S
	return TRUE

/mob/proc/remove_spell(var/datum/spell/S)
	if(!S)
		return FALSE
	if(spell_list)
		spell_list -= S
	return TRUE
