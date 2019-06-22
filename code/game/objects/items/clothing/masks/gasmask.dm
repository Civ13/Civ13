/obj/item/clothing/mask/gas
	name = "gas mask"
	desc = "A face-covering mask that filters harmful gases from the air."
	icon_state = "gas_alt"
	item_flags = BLOCK_GAS_SMOKE_EFFECT | AIRTIGHT
	flags_inv = HIDEEARS|HIDEEYES|HIDEFACE
	body_parts_covered = FACE|EYES
	w_class = 2.0
	item_state = "gas_alt"
	gas_transfer_coefficient = 0.01
	permeability_coefficient = 0.01
	var/efficiency = 95 // 0 to 100
	siemens_coefficient = 0.9
	var/gas_filter_strength = TRUE			//For gas mask filters
	var/list/filtered_gases = list("plasma", "sleeping_agent")
	slot_flags = SLOT_BELT|SLOT_MASK
	blocks_scope = TRUE
	restricts_view = 2
	armor = list(melee = 10, arrow = FALSE, gun = FALSE, energy = 35, bomb = 15, bio = 100, rad = 80)

/obj/item/clothing/mask/gas/proc/check_can_block(var/datum/reagent/r)
	if (prob(efficiency))
		return TRUE
	else
		return FALSE

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
	filtered_gases = list("xylyl_bromide", "mustard_gas", "white_phosphorus_gas", "chlorine_gas", "zyklon_b", "phosgene_gas")

/obj/item/clothing/mask/gas/british
	icon_state = "british_gasmask"
	item_state = "british_gasmask"
	filtered_gases = list("xylyl_bromide", "mustard_gas", "white_phosphorus_gas", "chlorine_gas", "zyklon_b", "phosgene_gas")

/obj/item/clothing/mask/gas/french
	icon_state = "french_gasmask"
	item_state = "french_gasmask"
	filtered_gases = list("xylyl_bromide", "mustard_gas", "white_phosphorus_gas", "chlorine_gas", "zyklon_b", "phosgene_gas")

/obj/item/clothing/mask/gas/modern
	icon_state = "modern_gasmask"
	item_state = "modern_gasmask"
	filtered_gases = list("xylyl_bromide", "mustard_gas", "white_phosphorus_gas", "chlorine_gas", "zyklon_b", "phosgene_gas")
