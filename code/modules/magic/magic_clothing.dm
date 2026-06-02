
/obj/item/clothing/under/civ2/wizard
	name = "wizard clothing"
	desc = "An old-school white shirt and black trousers, commonly used by wizards."
	icon_state = "civuni2"
	item_state = "civuni2"
	
/obj/item/clothing/suit/storage/jacket/wizard
	name = "wizard robe"
	desc = "A black robe worn by wizards."
	icon_state = "magic_boy_robe"
	item_state = "magic_boy_robe"
	var/house_colors = "#000000"
	var/uncolored = TRUE

	New()
		..()
		spawn(1)
			if (src)
				var/image/lines = image("icon" = 'icons/obj/clothing/suits.dmi', "icon_state" = "magic_boy_robe_decoration")
				lines.color = house_colors
				overlays += lines
				update_icon()

/obj/item/clothing/suit/storage/jacket/wizard/red
	name = "Rubywyrm wizard robe"
	house_colors = "#7F0000"

/obj/item/clothing/suit/storage/jacket/wizard/green
	name = "Mintysnek wizard robe"
	house_colors = "#007F00"

/obj/item/clothing/suit/storage/jacket/wizard/blue
	name = "Slatepie wizard robe"
	house_colors = "#0000c8"

/obj/item/clothing/suit/storage/jacket/wizard/yellow
	name = "Mustardweasel wizard robe"
	house_colors = "#cbb600"

/obj/item/clothing/suit/storage/jacket/wizard/pinkrobe
	name = "L.O.S.E.R. wizard robe"
	desc = "A pink wizard's robe used by those who have received the 'LLanboarwart Outcast and Substandard Educational Reject' status."
	house_colors = "#000000"

/obj/item/clothing/suit/storage/jacket/wizard/greyrobe
	name = "I.D.I.O.T. wizard robe"
	desc = "A grey wizard's robe used by those who have received the 'Inept & Deficient Individual's Ordinary Test' certificate. Not to be left unnatended near crayons."
	house_colors = "#000000"

/obj/item/clothing/suit/storage/jacket/wizard/greyrobe/red
	name = "Rubywyrm I.D.I.O.T. wizard robe"
	house_colors = "#7F0000"

/obj/item/clothing/suit/storage/jacket/wizard/greyrobe/green
	name = "Mintysnek I.D.I.O.T. wizard robe"
	house_colors = "#007F00"

/obj/item/clothing/suit/storage/jacket/wizard/greyrobe/blue
	name = "Slatepie I.D.I.O.T. wizard robe"
	house_colors = "#0000c8"

/obj/item/clothing/suit/storage/jacket/wizard/greyrobe/yellow
	name = "Mustardweasel I.D.I.O.T. wizard robe"
	house_colors = "#cbb600"

/obj/item/clothing/head/wizard
	name = "wizard's hat"
	desc = "A wide brim black wizard's hat."
	icon_state = "blackwizard"
	item_state = "blackwizard"

/obj/item/clothing/head/custodian_helmet
	name = "custodian helmet"
	desc = "A traditional British police custodian helmet, complete with a silver badge."
	icon = 'icons/obj/clothing/hats.dmi'
	icon_state = "constable"
	item_state = "constable"

/obj/item/clothing/suit/storage/jacket/wizard/neon_yellow
	name = "police wizard robe"
	desc = "A high-visibility wizard robe worn by the C.A.P., the Constabulary for Arcane Practices."
	house_colors = "#E5FF00"
	icon_state = "magic_boy_robe_police"

// the school tier pins/certificates
/obj/item/weapon/magic_id
	name = "L.A.M.E. professor badge"
	desc = "A badge worn by professors at the Llanboarwart Academy of Magical Education. It grants the wearer a small amount of magical power, but mostly just serves as a fashion statement."
	icon = 'icons/obj/clothing/badges.dmi'
	item_icons = 'icons/mob/badge.dmi'
	icon_state = "Order of the Patriotic War, 1st Class"
	worn_state = "OPW I, on body"
	item_state = "OPW I, on body"
	throwforce = FALSE
	w_class = ITEM_SIZE_TINY
	slot_flags = SLOT_ID
	throw_range = TRUE
	throw_speed = TRUE
	attack_verb = list("bapped")
	flammable = FALSE
	icon_override = 'icons/mob/badge.dmi'

	attack_hand(mob/M)
		if (istype(M, /mob/living/human))
			var/mob/living/human/H = M
			if (H.wear_id == src)
				return //cannot remove the badge once equipped, so no attack_hand proc
		..()
// Tier 0: I.D.I.O.T. certificate
/obj/item/weapon/magic_id/idiot
	name = "I.D.I.O.T. certificate"
	desc = "The 'Inept & Deficient Individual's Ordinary Test' certificate. Not to be left unnatended near crayons."
	icon_state = "wizard_idiot"
	worn_state = "christian_party_pin"
	item_state = "christian_party_pin"

// Tier 1: U.N.G.A. certificate
/obj/item/weapon/magic_id/unga
	name = "U.N.G.A. certificate"
	desc = "The 'Underperforming Numpty General Assessment' certificate. The most basic magic aptitude level."
	icon_state = "wizard_unga"
	worn_state = "nationalist_party_pin"
	item_state = "nationalist_party_pin"

// Tier 2: C.O.A.L. licence
/obj/item/weapon/magic_id/coal
	name = "C.O.A.L. license"
	desc = "The 'Community Ordinary Amateur License'. The bare minimum required to carry a wand in the valley without being arrested."
	icon_state = "wizard_coal"
	worn_state = "pirate_flag_pin"
	item_state = "pirate_flag_pin"

// Tier 3: G.E.M. licence
/obj/item/weapon/magic_id/slate
	name = "G.E.M. licence"
	desc = "The 'Gravity & Elemental Manipulation'. Granted to those proven unlikely to accidentally collapse the school's slate roofs."
	icon_state = "wizard_gem"
	worn_state = "nationalist_party_pin"
	item_state = "nationalist_party_pin"

// Tier 4: B.A.S.E.D. licence
/obj/item/weapon/magic_id/based
	name = "B.A.S.E.D. licence"
	desc = "The 'Boarwart Advanced Sorcery & Experimental Deeds' licence. Reserved for students whose deeds are considered extremely based, yet highly unstable."
	icon_state = "wizard_based"
	worn_state = "AS, on body"
	item_state = "AS, on body"

// Tier 5: C.H.A.D. degree
/obj/item/weapon/magic_id/chad
	name = "C.H.A.D. degree"
	desc = "The 'Classified High-level Arcane Destruction' degree. The absolute peak of magical education. Absolute gigachad energy required."
	icon_state = "wizard_chad"
	worn_state = "Verwund Geld, on body"
	item_state = "Verwund Geld, on body"

// Tier R: L.O.S.E.R. status
/obj/item/weapon/magic_id/loser
	name = "L.O.S.E.R. status pin"
	desc = "The 'Llanboarwart Outcast & Sub-standard Educational Reject' status. A mark of disciplinary shame for those who have violated school laws."
	icon_state = "wizard_loser"
	worn_state = "globalist_pin"
	item_state = "globalist_pin"
