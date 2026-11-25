/datum/reagents/metabolism
	var/metabolism_class //CHEM_TOUCH, CHEM_INGEST, or CHEM_BLOOD
	var/mob/living/human/parent
	// Null outside this ingest tick so direct effect calls can still use their mixture.
	var/tmp/ingest_brine = null

/datum/reagents/metabolism/New(var/max = 100, mob/living/human/parent_mob, var/met_class)
	..(max, parent_mob)

	metabolism_class = met_class
	if (istype(parent_mob))
		parent = parent_mob

/datum/reagents/metabolism/proc/metabolize()

	var/metabolism_type = FALSE //non-human mobs
	if (ishuman(parent))
		var/mob/living/human/H = parent
		metabolism_type = H.species.reagent_tag

	if (islist(reagent_list) && !reagent_list.len)
		total_volume = 0
		return

	var/datum/reagent/water/brine_water = null
	var/datum/reagent/sodiumchloride/brine_salt = null
	var/water_removed = null
	var/salt_removed = null
	if (metabolism_class == CHEM_INGEST)
		// Classify once before either entry changes; seasoning stays on its normal path.
		var/water_volume = get_reagent_amount("water")
		ingest_brine = reagents_are_brine(src, water_volume, 0.00001)
		if (ingest_brine)
			for (var/datum/reagent/current in reagent_list)
				if (current.id == "water")
					brine_water = current
				else if (current.id == "sodiumchloride")
					brine_salt = current
			if (brine_water && brine_salt)
				var/water_rate = brine_water.metabolism
				if (brine_water.ingest_met)
					water_rate = brine_water.ingest_met
				water_removed = min(water_rate, water_volume)
				var/salt_remaining = brine_salt.volume * (water_volume - water_removed) / water_volume
				if (salt_remaining < MINIMUM_CHEMICAL_VOLUME)
					// Finish the pair before the holder silently prunes the last trace of salt.
					water_removed = water_volume
					salt_remaining = 0
				salt_removed = brine_salt.volume - salt_remaining

	// Digesting one component can remove it from the live list before the other runs.
	var/list/processing = reagent_list
	if (brine_water && brine_salt)
		processing = reagent_list.Copy()
	for (var/datum/reagent/current in processing)
		if (brine_water && brine_salt && current.holder != src)
			continue
		if (brine_water && current == brine_water)
			current.on_mob_life(parent, metabolism_type, metabolism_class, water_removed)
		else if (brine_salt && current == brine_salt)
			current.on_mob_life(parent, metabolism_type, metabolism_class, salt_removed)
		else
			current.on_mob_life(parent, metabolism_type, metabolism_class)
	ingest_brine = null
	update_total()