/datum/job/pillarman
	faction = "Station"

/datum/job/pillarman/give_random_name(var/mob/living/carbon/human/H)
	H.name = H.species.get_random_ukrainian_name(H.gender)
	H.real_name = H.name

/datum/job/pillarman/pillarman
	title = "Pillar Man"
	en_meaning = ""
	total_positions = 3
	selection_color = "#4c4ca5"
	spawn_location = "JoinLatePillarMan"

/datum/job/pillarman/pillarman/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)
	H.equip_to_slot_or_del(new /obj/item/clothing/mask/stone(H), slot_l_hand)
	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/shotgun/pump/combat/winchester1897(H), slot_r_hand)
	equip_random_civilian_clothing(H)

	// give them webbing with shotgun shells
	var/obj/item/clothing/accessory/storage/webbing/webbing = new/obj/item/clothing/accessory/storage/webbing(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(webbing, H)

	for (var/v in 1 to 5)
		uniform.attackby(new /obj/item/ammo_casing/shotgun(null), H)

	H.add_note("Role", "You are a <b>fucking PILLAR MAN</b>. You have a stone mask. Hit humans with it to turn them into vampires. <span class = 'danger'>Fear the sun's light.</span>")
	H.add_note("Abilities", "SPACEBAR - shoot boiling blood")
	H.add_note("Abilities", "Emote *pose - AOE knockdown")
	H.add_note("Abilities", "Attack (harm intent) - Absorption")
	H.add_note("Abilities", "Stone Mask - put it on people to make them into Vampires. Has no effect on Pillar Men or Vampires.")
	return TRUE

/datum/job/pillarman/vampire
	title = "Vampire"
	en_meaning = ""
	total_positions = 15
	selection_color = "#4c4ca5"
	spawn_location = "JoinLateVampire"

/datum/job/pillarman/vampire/equip(var/mob/living/carbon/human/H)
	if (!H)	return FALSE
	H.equip_to_slot_or_del(new /obj/item/clothing/shoes/swat/wrappedboots(H), slot_shoes)

	// melee weapons for Vampires. Pillar Men don't need them since they're so robust already.
	if (prob(50))
		H.equip_to_slot_or_del(new /obj/item/weapon/material/scythe(H), slot_l_hand)
	else
		H.equip_to_slot_or_del(new /obj/item/weapon/material/knife/ritual(H), slot_l_hand)

	H.equip_to_slot_or_del(new /obj/item/weapon/gun/projectile/shotgun/pump/combat/ithaca37(H), slot_r_hand)


	equip_random_civilian_clothing(H)

	// give them shotgun shells
	var/obj/item/clothing/accessory/storage/webbing/webbing = new/obj/item/clothing/accessory/storage/webbing(null)
	var/obj/item/clothing/under/uniform = H.w_uniform
	uniform.attackby(webbing, H)

	for (var/v in 1 to 5)
		uniform.attackby(new /obj/item/ammo_casing/shotgun(null), H)

	H.add_note("Role", "You are a <b>[title]</b>, a fucking VAMPIRE.<span class = 'danger'>Fear the sun's light.</span>")
	H.add_note("Abilities", "Attack (harm intent) - Blood Drain")

	return TRUE
