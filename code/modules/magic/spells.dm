/datum/spell
	var/name = "Spell"
	var/description = ""
	var/proj_type = null
	var/skill_level = 0
	var/cast_time = 8
	var/learnable = FALSE
	var/juice_cost = 0
	var/screen_obj = null
	var/sound_effect = null

/// The Fundamentals (Beginner Magic) ///

/datum/spell/zappus
	name = "Zappus"
	description = "A weak but reliable spark of magic."
	proj_type = /obj/item/projectile/magic/zappus
	skill_level = 1
	cast_time = 5
	learnable = TRUE
	juice_cost = 5
	screen_obj = /obj/screen/spell/zappus
	sound_effect = 'sound/effects/spells/zappus.ogg'

/datum/spell/blockum
	name = "Blockum"
	description = "Creates a bubble of magic denial around the caster."
	proj_type = /obj/item/projectile/magic/blockum
	skill_level = 10
	cast_time = 0
	learnable = TRUE
	juice_cost = 15
	screen_obj = /obj/screen/spell/blockum
	sound_effect = 'sound/effects/spells/blockum.ogg'

/datum/spell/lightus
	name = "Lightus"
	description = "Emits a temporary magical light from the caster."
	skill_level = 5
	cast_time = 0
	learnable = TRUE
	juice_cost = 15
	screen_obj = /obj/screen/spell/lightus
	sound_effect = 'sound/effects/spells/lightus.ogg'

/datum/spell/dropus
	name = "Dropus"
	description = "Makes the target to drop whatever they are holding."
	proj_type = /obj/item/projectile/magic/dropus
	skill_level = 15
	cast_time = 5
	learnable = TRUE
	juice_cost = 15
	screen_obj = /obj/screen/spell/dropus
	sound_effect = 'sound/effects/spells/dropus.ogg'

/datum/spell/stinkaeum
	name = "Stinkaeum"
	description = "Makes the target urinate and defecate."
	proj_type = /obj/item/projectile/magic/stinkaeum
	skill_level = 20
	cast_time = 5
	learnable = TRUE
	juice_cost = 15
	screen_obj = /obj/screen/spell/stinkaeum
	sound_effect = 'sound/effects/spells/stinkaeum.ogg'

/// Force & Physics (Intermediate Magic) ///

/datum/spell/pushum
	name = "Pushum"
	description = "Pushes the target away."
	proj_type = /obj/item/projectile/magic/pushum
	skill_level = 30
	cast_time = 7
	learnable = TRUE
	juice_cost = 20
	screen_obj = /obj/screen/spell/pushum
	sound_effect = 'sound/effects/spells/pushum.ogg'

/datum/spell/pullus
	name = "Pullus"
	description = "Pulls the target towards the caster."
	proj_type = /obj/item/projectile/magic/pullus
	skill_level = 30
	cast_time = 7
	learnable = TRUE
	juice_cost = 20
	screen_obj = /obj/screen/spell/pullus
	sound_effect = 'sound/effects/spells/pullus.ogg'

/datum/spell/wallus
	name = "Wallus"
	description = "Summons a sturdy barricade at the target location."
	proj_type = null
	skill_level = 35
	cast_time = 15
	learnable = TRUE
	juice_cost = 30
	screen_obj = /obj/screen/spell/wallus
	sound_effect = 'sound/effects/spells/wallus.ogg'

/datum/spell/floatus
	name = "Floatus"
	description = "Makes the target float around for a short period."
	proj_type = /obj/item/projectile/magic/floatus
	skill_level = 40
	cast_time = 12
	learnable = TRUE
	juice_cost = 35
	screen_obj = /obj/screen/spell/floatus
	sound_effect = 'sound/effects/spells/floatus.ogg'

/// Control & Chaos (Advanced Magic) ///

/datum/spell/freezeum
	name = "Freezeum"
	description = "Freezes the target in a block of ice."
	skill_level = 50
	cast_time = 15
	learnable = TRUE
	proj_type = /obj/item/projectile/magic/freezum
	juice_cost = 35
	screen_obj = /obj/screen/spell/freezeum
	sound_effect = 'sound/effects/spells/freezeum.ogg'

/datum/spell/blinkae
	name = "Blinkae"
	description = "Teleports the caster to a nearby location."
	skill_level = 55
	cast_time = 15
	learnable = TRUE
	juice_cost = 30
	screen_obj = /obj/screen/spell/blinkae
	sound_effect = 'sound/effects/spells/blinkae.ogg'
/// Destruction (Expert Magic) ///

/datum/spell/burnus
	name = "Burnus"
	description = "Sets the target on fire."
	skill_level = 55
	cast_time = 15
	learnable = TRUE
	proj_type = /obj/item/projectile/magic/fire_bolt
	juice_cost = 40
	screen_obj = /obj/screen/spell/burnus
	sound_effect = 'sound/effects/spells/burnus.ogg'

/datum/spell/barrelus
	name = "Barrelus"
	description = "Creates a wooden barrel and shoves the target inside it."
	proj_type = /obj/item/projectile/magic/barrelus
	skill_level = 65
	cast_time = 15
	learnable = TRUE
	juice_cost = 25
	screen_obj = /obj/screen/spell/barrelus
	sound_effect = 'sound/effects/spells/barrelus.ogg'

/datum/spell/sliceum
	name = "Sliceum"
	description = "An invisible, incredibly sharp slashing strike."
	proj_type = /obj/item/projectile/magic/sliceum
	skill_level = 70
	cast_time = 20
	learnable = TRUE
	juice_cost = 50
	screen_obj = /obj/screen/spell/sliceum
	sound_effect = 'sound/effects/spells/sliceum.ogg'

/datum/spell/fixae
	name = "Fixae"
	description = "A powerful healing spell that rejuvenates the target."
	proj_type = /obj/item/projectile/magic/fixae
	skill_level = 75
	cast_time = 15
	learnable = TRUE
	juice_cost = 80
	screen_obj = /obj/screen/spell/fixae
	sound_effect = 'sound/effects/spells/fixae.ogg'

/datum/spell/explodus
	name = "Explodus"
	description = "Creates an explosion at the target location, damaging everything in the area."
	proj_type = /obj/item/projectile/magic/explodus
	skill_level = 80
	cast_time = 30
	learnable = TRUE
	juice_cost = 60
	screen_obj = /obj/screen/spell/explodus
	sound_effect = 'sound/effects/spells/explodus.ogg'

/// The \"Naughty\" Curses (Dark Arts) ///

/datum/spell/painum
	name = "Painum"
	description = "A forbidden curse that causes unimaginable agony."
	proj_type = /obj/item/projectile/magic/painum
	skill_level = 85
	cast_time = 30
	learnable = TRUE
	juice_cost = 85
	screen_obj = /obj/screen/spell/painum
	sound_effect = 'sound/effects/spells/painum.ogg'

/datum/spell/deadum
	name = "Deadum"
	description = "The ultimate forbidden spell. Gibs the target into a bloody mess."
	proj_type = /obj/item/projectile/magic/deadum
	skill_level = 100
	cast_time = 50
	learnable = TRUE
	juice_cost = 100
	screen_obj = /obj/screen/spell/deadum
	sound_effect = 'sound/effects/spells/deadum.ogg'

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
