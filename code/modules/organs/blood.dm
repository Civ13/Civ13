/****************************************************
				BLOOD SYSTEM
****************************************************/
//Blood levels. These are percentages based on the species blood_volume far.
var/const/BLOOD_VOLUME_SAFE =    85
var/const/BLOOD_VOLUME_OKAY =    75
var/const/BLOOD_VOLUME_BAD =     60
var/const/BLOOD_VOLUME_SURVIVE = 20

/mob/living/carbon/human/var/datum/reagents/vessel // Container for blood and BLOOD ONLY. Do not transfer other chems here.
/mob/living/carbon/human/var/var/pale = FALSE          // Should affect how mob sprite is drawn, but currently doesn't.

//Initializes blood vessels
/mob/living/carbon/human/proc/make_blood()

	if (vessel)
		return

	vessel = new/datum/reagents(species.blood_volume)
	vessel.my_atom = src

	if (species && species.flags & NO_BLOOD) //We want the var for safety but we can do without the actual blood.
		return

	vessel.add_reagent("blood",species.blood_volume)
	spawn(1)
		fixblood()

//Resets blood data
/mob/living/carbon/human/proc/fixblood()
	for (var/datum/reagent/blood/B in vessel.reagent_list)
		if (B.id == "blood")
			B.data = list(	"donor"=src,"viruses"=null,"species"=species.name,"blood_DNA"=dna.unique_enzymes,"blood_colour"= species.blood_color,"blood_type"=dna.b_type,	\
							"resistances"=null,"trace_chem"=null, "virus2" = null, "antibodies" = list())
			B.color = B.data["blood_colour"]

/* takes care of blood loss and regeneration
 * it now takes ~10 minutes to bleed out with 100 brute damage and 10 minutes to recover all blood
 * bloodloss is capped to 4 per tick (2.5 minutes to bleed out) - Kachnov */

/mob/living/carbon/human/handle_blood()

	make_blood()

	if (in_stasis)
		return

	if (!species.has_organ["heart"])
		return

	var/obj/item/organ/heart/H = internal_organs_by_name["heart"]

	if (!H)	// not having a heart is bad for health
		setOxyLoss(max(getOxyLoss(),60))
		adjustOxyLoss(10)

	var/obj/item/organ/lungs/L = internal_organs_by_name["lungs"]

	if (!L) // ditto for lungs
		adjustOxyLoss(10)
		if (prob(20))
			src << "<span class = 'danger'>You're suffocating!</span>"
		if (prob(40))
			emote("gasp")


	//Bleeding out
	var/bloodloss = 0
	for (var/obj/item/organ/external/temp in organs)
		if (!(temp.status & ORGAN_BLEEDING))
			continue
		for (var/datum/wound/W in temp.wounds)
			if (W.bleeding())
				if (W.damage_type == PIERCE)
					bloodloss += W.damage / 200
				else if (W.damage_type == CUT)
					bloodloss += W.damage / 70
				else
					bloodloss += W.damage / 1000
		if (temp.open)
			++bloodloss  //Yer stomach is cut open
	bloodloss = min(bloodloss, 4)

	if (bloodloss) // we're bleeding
		drip(bloodloss)
	else // we're not bleeding, regenerate some blood (experimental) - Kachnov
		for (var/datum/reagent/r in vessel.reagent_list)
			if (istype(r, /datum/reagent/blood))
				if (r.volume >= species.blood_volume)
					return // we're full on blood.
		vessel.add_reagent("blood", 1.00)

//Makes a blood drop, leaking amt units of blood from the mob
/mob/living/carbon/human/proc/drip(var/amt as num)

	if (species && species.flags & NO_BLOOD) //TODO: Make drips come from the reagents instead.
		return

	if (!amt)
		return

	vessel.remove_reagent("blood",amt)

	// don't splatter blood all the time
	if (prob(amt * 100))
		blood_splatter(src,src)


#define BLOOD_SPRAY_DISTANCE 2
/mob/living/carbon/human/proc/blood_squirt(var/amt, var/turf/sprayloc)
	if(amt <= 0 || !istype(sprayloc))
		return
	var/spraydir = pick(alldirs)
	amt = ceil(amt/BLOOD_SPRAY_DISTANCE)
	var/bled = 0
	spawn(0)
		for(var/i = 1 to BLOOD_SPRAY_DISTANCE)
			sprayloc = get_step(sprayloc, spraydir)
			if(!istype(sprayloc) || sprayloc.density)
				break
			var/hit_mob
			for(var/thing in sprayloc)
				var/atom/A = thing
				if(!A.simulated)
					continue

				if(ishuman(A))
					var/mob/living/carbon/human/H = A
					if(!H.lying)
						H.bloody_body(src)
						H.bloody_hands(src)
						var/blinding = FALSE
						if(ran_zone() == "head")
							blinding = TRUE
							for(var/obj/item/I in list(H.head, H.wear_mask))
								if(I && (I.body_parts_covered & EYES))
									blinding = FALSE
									break
						if(blinding)
							H.eye_blurry = max(H.eye_blurry, 10)
							H.eye_blind = max(H.eye_blind, 5)
							H << "<span class='danger'>You are blinded by a spray of blood!</span>"
						else
							H << "<span class='danger'>You are hit by a spray of blood!</span>"
						hit_mob = TRUE

				if(hit_mob || !A.CanPass(src, sprayloc))
					break

			drip(amt, sprayloc, spraydir)
			bled += amt
			if(hit_mob) break
			sleep(1)
	return bled
#undef BLOOD_SPRAY_DISTANCE

/mob/living/carbon/human/proc/remove_blood(var/amt)
	if(!amt)
		return 0
	return vessel.remove_reagent("blood", amt * (src.mob_size/MOB_MEDIUM))

/****************************************************
				BLOOD TRANSFERS
****************************************************/

//Gets blood from mob to the container, preserving all data in it.
/mob/living/carbon/proc/take_blood(obj/item/weapon/reagent_containers/container, var/amount)

	var/datum/reagent/B = get_blood(container.reagents)
	if (!B) B = new /datum/reagent/blood
	B.holder = container
	B.volume += amount

	//set reagent data
	B.data["donor"] = src
	/*
	if (!B.data["virus2"])
		B.data["virus2"] = list()
	B.data["virus2"] |= virus_copylist(virus2)
	*/
	B.data["antibodies"] = antibodies
	B.data["blood_DNA"] = copytext(dna.unique_enzymes,1,0)
	B.data["blood_type"] = copytext(dna.b_type,1,0)

	// Putting this here due to return shenanigans.
	if (istype(src,/mob/living/carbon/human))
		var/mob/living/carbon/human/H = src
		B.data["blood_colour"] = H.species.blood_color
		B.color = B.data["blood_colour"]

	var/list/temp_chem = list()
	for (var/datum/reagent/R in reagents.reagent_list)
		temp_chem += R.id
		temp_chem[R.id] = R.volume
	B.data["trace_chem"] = list2params(temp_chem)
	return B

//For humans, blood does not appear from blue, it comes from vessels.
/mob/living/carbon/human/take_blood(obj/item/weapon/reagent_containers/container, var/amount)

	if (species && species.flags & NO_BLOOD)
		return null

	if (vessel.get_reagent_amount("blood") < amount)
		return null

	. = ..()
	vessel.remove_reagent("blood",amount) // Removes blood if human

//Transfers blood from container ot vessels
/mob/living/carbon/proc/inject_blood(var/datum/reagent/blood/injected, var/amount)
	if (!injected || !istype(injected))
		return

/*	var/list/sniffles = virus_copylist(injected.data["virus2"])
	for (var/ID in sniffles)
		var/datum/disease2/disease/sniffle = sniffles[ID]
		infect_virus2(src,sniffle,1)
	if (injected.data["antibodies"] && prob(5))
		antibodies |= injected.data["antibodies"]*/
	var/list/chems = list()
	chems = params2list(injected.data["trace_chem"])
	for (var/C in chems)
		reagents.add_reagent(C, (text2num(chems[C]) / species.blood_volume) * amount)//adds trace chemicals to owner's blood
	reagents.update_total()

//Transfers blood from reagents to vessel, respecting blood types compatability.
/mob/living/carbon/human/inject_blood(var/datum/reagent/blood/injected, var/amount)

	if (species.flags & NO_BLOOD)
		reagents.add_reagent("blood", amount, injected.data)
		reagents.update_total()
		return

	var/datum/reagent/blood/our = get_blood(vessel)

	if (!injected || !our)
		return
	if (blood_incompatible(injected.data["blood_type"],our.data["blood_type"],injected.data["species"],our.data["species"]) )
		reagents.add_reagent("toxin",amount * 0.5)
		reagents.update_total()
	else
		vessel.add_reagent("blood", amount, injected.data)
		vessel.update_total()
	..()

//Gets human's own blood.
/mob/living/carbon/proc/get_blood(datum/reagents/container)
	var/datum/reagent/blood/res = locate() in container.reagent_list //Grab some blood
	if (res) // Make sure there's some blood at all
		if (res.data["donor"] != src) //If it's not theirs, then we look for theirs
			for (var/datum/reagent/blood/D in container.reagent_list)
				if (D.data["donor"] == src)
					return D
	return res

proc/blood_incompatible(donor,receiver,donor_species,receiver_species)
	if (!donor || !receiver) return FALSE

	if (donor_species && receiver_species)
		if (donor_species != receiver_species)
			return TRUE

	var/donor_antigen = copytext(donor,1,lentext(donor))
	var/receiver_antigen = copytext(receiver,1,lentext(receiver))
	var/donor_rh = (findtext(donor,"+")>0)
	var/receiver_rh = (findtext(receiver,"+")>0)

	if (donor_rh && !receiver_rh) return TRUE
	switch(receiver_antigen)
		if ("A")
			if (donor_antigen != "A" && donor_antigen != "O") return TRUE
		if ("B")
			if (donor_antigen != "B" && donor_antigen != "O") return TRUE
		if ("O")
			if (donor_antigen != "O") return TRUE
		//AB is a universal receiver.
	return FALSE

proc/blood_splatter(var/target,var/datum/reagent/blood/source,var/large)

	var/obj/effect/decal/cleanable/blood/B
	var/decal_type = /obj/effect/decal/cleanable/blood/splatter
	var/turf/T = get_turf(target)

	if (istype(source,/mob/living/carbon/human))
		var/mob/living/carbon/human/M = source
		source = M.get_blood(M.vessel)

	// Are we dripping or splattering?
	var/list/drips = list()
	// Only a certain number of drips (or one large splatter) can be on a given turf.
	for (var/obj/effect/decal/cleanable/blood/drip/drop in T)
		drips |= drop.drips
		qdel(drop)
	if (!large && drips.len < 3)
		decal_type = /obj/effect/decal/cleanable/blood/drip

	// Find a blood decal or create a new one.
	B = locate(decal_type) in T
	if (!B)
		B = new decal_type(T)

	var/obj/effect/decal/cleanable/blood/drip/drop = B
	if (istype(drop) && drips && drips.len && !large)
		drop.overlays |= drips
		drop.drips |= drips

	// If there's no data to copy, call it quits here.
	if (!source)
		return B

	// Update appearance.
	if (source.data["blood_colour"])
		B.basecolor = source.data["blood_colour"]
		B.update_icon()

	// Update blood information.
	if (source.data["blood_DNA"])
		B.blood_DNA = list()
		if (source.data["blood_type"])
			B.blood_DNA[source.data["blood_DNA"]] = source.data["blood_type"]
		else
			B.blood_DNA[source.data["blood_DNA"]] = "O+"

/*	// Update virus information.
	if (source.data["virus2"])
		B.virus2 = virus_copylist(source.data["virus2"])*/

//	B.fluorescent  = FALSE
	B.invisibility = FALSE
	return B


//Percentage of maximum blood volume.
/mob/living/carbon/human/proc/get_blood_volume()
	return round((vessel.get_reagent_amount(/datum/reagent/blood)/species.blood_volume)*100)

//Percentage of maximum blood volume, affected by the condition of circulation organs
/mob/living/carbon/human/proc/get_blood_circulation()
	var/obj/item/organ/heart/heart = internal_organs_by_name["heart"]
	var/blood_volume = get_blood_volume()
	if(!heart)
		return 0.25 * blood_volume

	var/recent_pump = LAZYACCESS(heart.external_pump, 1) > world.time - (20 SECONDS)
	var/pulse_mod = 1
	if(status_flags & FAKEDEATH)
		pulse_mod = 1
	else
		switch(heart.pulse)
			if(PULSE_NONE)
				if(recent_pump)
					pulse_mod = LAZYACCESS(heart.external_pump, 2)
				else
					pulse_mod *= 0.25
			if(PULSE_SLOW)
				pulse_mod *= 0.9
			if(PULSE_FAST)
				pulse_mod *= 1.1
			if(PULSE_2FAST, PULSE_THREADY)
				pulse_mod *= 1.25
	blood_volume *= pulse_mod

	var/min_efficiency = recent_pump ? 0.5 : 0.3
	blood_volume *= max(min_efficiency, (1-(heart.damage / heart.max_damage)))

	if(!heart.open && chem_effects["blockage"])
		blood_volume *= max(0, 1-chem_effects["blockage"])

	return min(blood_volume, 100)


//Percentage of maximum blood volume, affected by the condition of circulation organs, affected by the oxygen loss. What ultimately matters for brain
/mob/living/carbon/human/proc/get_blood_oxygenation()
	var/blood_volume = get_blood_circulation()
	if(is_asystole()) // Heart is missing or isn't beating and we're not breathing (hardcrit)
		return min(blood_volume, BLOOD_VOLUME_SURVIVE)

	else
		blood_volume = 100

	var/blood_volume_mod = max(0, 1 - getOxyLoss()/(species.total_health/2))
	var/oxygenated_mult = 0
	if(chem_effects["oxygen"] == 1) // Dexalin.
		oxygenated_mult = 0.5
	else if(chem_effects["oxygen"] >= 2) // Dexplus.
		oxygenated_mult = 0.8
	blood_volume_mod = blood_volume_mod + oxygenated_mult - (blood_volume_mod * oxygenated_mult)
	blood_volume = blood_volume * blood_volume_mod
	return min(blood_volume, 100)


/mob/living/carbon/human/proc/get_effective_blood_volume()
	var/obj/item/organ/heart/heart = internal_organs_by_name["heart"]
	var/blood_volume = round((vessel.get_reagent_amount("blood")/species.blood_volume)*100)
	if(!heart || (heart.pulse == PULSE_NONE && !(status_flags & FAKEDEATH)))
		blood_volume *= 0.25
	else
		blood_volume *= max(0.3, (1-(heart.damage / heart.max_damage)))
	return blood_volume
