/obj/item/clothing/mask/gas
	name = "gas mask"
	desc = "A face-covering mask that filters harmful gases from the air."
	icon_state = "gas_alt"
	item_flags = BLOCK_GAS_SMOKE_EFFECT | AIRTIGHT
	flags_inv = HIDEEARS|HIDEEYES|HIDEFACE|BLOCKHAIR
	body_parts_covered = FACE|EYES
	w_class = ITEM_SIZE_SMALL
	item_state = "gas_alt"
	gas_transfer_coefficient = 0.01
	permeability_coefficient = 0.01
	siemens_coefficient = 0.9
	var/gas_filter_strength = TRUE			//For gas mask filters
	var/list/filtered_gases = list("plasma", "sleeping_agent, xylyl_bromide", "mustard_gas", "white_phosphorus_gas", "chlorine_gas", "zyklon_b", "phosgene_gas")
	slot_flags = SLOT_BELT|SLOT_MASK
	blocks_scope = TRUE
	restricts_view = 2
	flags = CONDUCT
	armor = list(melee = 10, arrow = FALSE, gun = FALSE, energy = 35, bomb = 15, bio = 100, rad = 80)

/obj/item/clothing/mask/gas/filter_air(datum/gas_mixture/air)
	var/datum/gas_mixture/filtered = new

	for (var/g in filtered_gases)
		if (air.gas[g])
			filtered.gas[g] = air.gas[g] * gas_filter_strength
			air.gas[g] -= filtered.gas[g]

	air.update_values()
	filtered.update_values()

	return filtered

/obj/item/clothing/mask/gas/german
	icon_state = "german_gasmask"
	item_state = "german_gasmask"

/obj/item/clothing/mask/gas/british
	icon_state = "british_gasmask"
	item_state = "british_gasmask"

/obj/item/clothing/mask/gas/french
	icon_state = "french_gasmask"
	item_state = "french_gasmask"

/obj/item/clothing/mask/gas/modern
	icon_state = "modern_gasmask"
	item_state = "modern_gasmask"

/obj/item/clothing/mask/gas/military
	icon_state = "military_gasmask"
	item_state = "military_gasmask"

/obj/item/clothing/mask/gas/modern2
	icon_state = "moderngasmask"
	item_state = "moderngasmask"

/obj/item/clothing/mask/gas/halfmask
	blocks_scope = FALSE
	name = "Half mask"
	restricts_view = 1
	icon_state = "halfmask"
	item_state = "halfmask"
	flags_inv = FALSE
	armor = list(melee = 5, arrow = FALSE, gun = FALSE, energy = 15, bomb = 5, bio = 100, rad = 70)
	body_parts_covered = FACE

/obj/item/clothing/mask/gas/japanese
	icon_state = "t99"
	item_state = "t99"

/obj/item/clothing/mask/gas/russia
	icon_state = "russiamask"
	item_state = "russiamask"
	name = "GP-9 gas mask"
	desc = "A panoramic gas mask intented for civilian use and civil denfense."

/obj/item/clothing/mask/gas/soviet
	name = "ShM-1 gas mask"
	desc = "A Soviet helmet styled-rubber mask introduced right before WW2."
	icon_state = "shm1"
	item_state = "shm1"

/obj/item/clothing/mask/gas/soviet/gp5
	name = "GP-5 gas mask"
	desc = "A Soviet helmet styled-rubber mask."
	icon_state = "gp5"
	item_state = "gp5"

/obj/item/clothing/mask/gas/soviet/pmk1
	icon_state = "pmk1"
	item_state = "pmk1"
	name = "PMK-1 gas mask"
	desc = "Compact combined mask designed in the late 1970s, used by Soviet and Russian Armed Forces."

/obj/item/clothing/mask/gas/swat
	icon_state = "swatmask"
	item_state = "swatmask"

/obj/item/clothing/mask/gas/swat_new
	icon_state = "swat_new"
	item_state = "swat_new"