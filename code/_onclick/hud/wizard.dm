/obj/screen/spell
	icon = 'icons/mob/screen/wizard.dmi'
	layer = 20
	var/spell_path = null

/obj/screen/spell/Click()
	if(!parentmob || !ishuman(parentmob))
		return
	var/mob/living/human/H = parentmob

	// Only allow interaction if holding a wand
	var/obj/item/W = H.get_active_hand()
	if (!W || !istype(W, /obj/item/weapon/wand))
		return

	if(spell_path)
		// This assumes a cast_spell proc is handled by the human mob
		H.cast_spell(spell_path)

/// Top Left Spells (Row 15) ///
/obj/screen/spell/zappus
	name = "Zappus"
	icon_state = "zappus"
	screen_loc = "1,15"
	spell_path = /datum/spell/zappus

/obj/screen/spell/blockum
	name = "Blockum"
	icon_state = "blockum"
	screen_loc = "2,15"
	spell_path = /datum/spell/blockum

/obj/screen/spell/lightus
	name = "Lightus"
	icon_state = "lightus"
	screen_loc = "3,15"
	spell_path = /datum/spell/lightus

/obj/screen/spell/dropus
	name = "Dropus"
	icon_state = "dropus"
	screen_loc = "4,15"
	spell_path = /datum/spell/dropus

/obj/screen/spell/stinkaeum
	name = "Stinkaeum"
	icon_state = "stinkaeum"
	screen_loc = "5,15"
	spell_path = /datum/spell/stinkaeum

/// Below Top Left (Row 14) ///
/obj/screen/spell/pushum
	name = "Pushum"
	icon_state = "pushum"
	screen_loc = "1,14"
	spell_path = /datum/spell/pushum

/obj/screen/spell/pullus
	name = "Pullus"
	icon_state = "pullus"
	screen_loc = "2,14"
	spell_path = /datum/spell/pullus

/obj/screen/spell/wallus
	name = "Wallus"
	icon_state = "wallus"
	screen_loc = "3,14"
	spell_path = /datum/spell/wallus

/obj/screen/spell/floatus
	name = "Floatus"
	icon_state = "floatus"
	screen_loc = "4,14"
	spell_path = /datum/spell/floatus

/// Top Right Spells (Row 15) ///
/obj/screen/spell/freezeum
	name = "Freezeum"
	icon_state = "freezeum"
	screen_loc = "15,15"
	spell_path = /datum/spell/freezeum

/obj/screen/spell/blinkae
	name = "Blinkae"
	icon_state = "blinkae"
	screen_loc = "14,15"
	spell_path = /datum/spell/blinkae

/obj/screen/spell/burnus
	name = "Burnus"
	icon_state = "burnus"
	screen_loc = "13,15"
	spell_path = /datum/spell/burnus

/obj/screen/spell/barrelus
	name = "Barrelus"
	icon_state = "barrelus"
	screen_loc = "12,15"
	spell_path = /datum/spell/barrelus

/obj/screen/spell/sliceum
	name = "Sliceum"
	icon_state = "sliceum"
	screen_loc = "11,15"
	spell_path = /datum/spell/sliceum

/// Below Top Right (Row 14) ///
/obj/screen/spell/fixae
	name = "Fixae"
	icon_state = "fixae"
	screen_loc = "15,14"
	spell_path = /datum/spell/fixae

/obj/screen/spell/explodus
	name = "Explodus"
	icon_state = "explodus"
	screen_loc = "14,14"
	spell_path = /datum/spell/explodus

/obj/screen/spell/painum
	name = "Painum"
	icon_state = "painum"
	screen_loc = "13,14"
	spell_path = /datum/spell/painum

/obj/screen/spell/deadum
	name = "Deadum"
	icon_state = "deadum"
	screen_loc = "12,14"
	spell_path = /datum/spell/deadum

/datum/hud
	var/list/wizard_hud = list()

/datum/hud/proc/add_wizard_hud(mob/living/human/H)
	if (wizard_hud.len)
		return

	var/static/list/spell_hud_types = list(
		/obj/screen/spell/zappus, /obj/screen/spell/blockum, /obj/screen/spell/lightus, /obj/screen/spell/dropus, /obj/screen/spell/stinkaeum,
		/obj/screen/spell/pushum, /obj/screen/spell/pullus, /obj/screen/spell/wallus, /obj/screen/spell/floatus,
		/obj/screen/spell/freezeum, /obj/screen/spell/blinkae, /obj/screen/spell/burnus, /obj/screen/spell/barrelus, /obj/screen/spell/sliceum,
		/obj/screen/spell/fixae, /obj/screen/spell/explodus, /obj/screen/spell/painum, /obj/screen/spell/deadum
	)

	for(var/typepath in spell_hud_types)
		var/datum/spell/sp_path = initial(typepath.spell_path)
		if(!sp_path)
			continue

		// Only show spells the user has learned and meets the skill requirement for
		if(H.magic_skill < initial(sp_path.skill_level))
			continue

		var/learned = FALSE
		if(H.spell_list)
			for(var/datum/spell/learned_spell in H.spell_list)
				if(learned_spell.type == sp_path)
					learned = TRUE
					break
		
		if(!learned)
			continue

		var/obj/screen/spell/S = new typepath()
		S.parentmob = H
		wizard_hud += S

	if (mymob && mymob.client)
		mymob.client.screen |= wizard_hud

/datum/hud/proc/remove_wizard_hud(mob/living/human/H)
	if (!wizard_hud.len)
		return
	if (H && H.client)
		H.client.screen -= wizard_hud
	for (var/obj/screen/spell/S in wizard_hud)
		qdel(S)
	wizard_hud.Cut()

/obj/item/weapon/wand/equipped(mob/living/human/H, slot)
	..()
	if(istype(H) && H.hud_used)
		if(slot == slot_l_hand || slot == slot_r_hand)
			H.hud_used.add_wizard_hud(H)
		else
			H.hud_used.remove_wizard_hud(H)

/obj/item/weapon/wand/dropped(mob/living/human/H)
	..()
	if(istype(H) && H.hud_used)
		H.hud_used.remove_wizard_hud(H)