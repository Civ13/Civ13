// Test-only world. Production startup is disabled by run.py.
/world/New()
	try
		text2file("commit=[world.params["tested_commit"]] BYOND=[world.byond_version].[world.byond_build]", "metadata.txt")
#ifdef SURVIVAL_BASELINE
		for(var/sample in 1 to 20)
			var/mob/living/human/H = new(locate(10,10,1))
			H.disease = TRUE
			H.disease_type = "plague"
			var/first_critical = 0
			for(var/tick in 1 to 180)
				H.survival_baseline_step()
				if(!first_critical && H.getToxLoss() >= 100)
					first_critical = tick
			text2file("sample=[sample] first_100_toxin_seconds=[first_critical] toxin_180s=[H.getToxLoss()] progression=[H.disease_progression]", "baseline.txt")
			del(H)
		text2file("PASS: baseline samples recorded in baseline.txt", "survival-result.txt")
#else
		survival_regressions()
		text2file("PASS: severe terminal windows, oral medicines, interrupted courses, herbal stock, renewable recipe, exemptions and transmission", "survival-result.txt")
#endif
	catch(var/exception/error)
		text2file("FAIL: [error]", "survival-result.txt")
	del(world)

/proc/survival_assert(condition, message)
	if(!condition)
		throw EXCEPTION(message)

#ifndef SURVIVAL_BASELINE
/proc/survival_patient(kind)
	var/mob/living/human/H = new(locate(10,10,1))
	H.disease = TRUE
	H.disease_type = kind
	H.inducedSSD = FALSE
	return H

/proc/survival_tick(mob/living/human/H)
	// Preserve Life ordering: disease consumes the preceding tick's treatment,
	// then the existing metabolism holder supplies the following tick's dose.
	H.life_tick++
	H.handle_disease()
	H.ingested.metabolize()

/proc/survival_regressions()
	for(var/kind in list("plague", "typhus", "malaria", "cholera"))
		text2file("[kind]: untreated", "progress.txt")
		var/mob/living/human/H = survival_patient(kind)
		for(var/tick in 1 to 1199)
			survival_tick(H)
			if(tick == 180)
				survival_assert(H.drowsyness > 0, "[kind]: debilitating phase")
			if(tick == 900)
				survival_assert(H.weakened > 0, "[kind]: critical phase")
			survival_assert(H.stat != DEAD && H.getToxLoss() == 0 && H.getBrainLoss() == 0, "[kind]: premature lethal damage")
		survival_tick(H)
		survival_assert(H.stat == DEAD && H.disease_progression == 1200, "[kind]: untreated terminal deadline")
		del(H)
		H = survival_patient(kind)
		text2file("[kind]: medicine", "progress.txt")
		var/medicine = kind == "malaria" ? "quinine" : "penicillin"
		H.ingested.add_reagent(medicine, kind == "malaria" ? 10 : 2)
		for(var/tick in 1 to 181)
			survival_tick(H)
		survival_assert(!H.disease && H.disease_course == 0 && H.stat != DEAD, "[kind]: practical oral course")
		del(H)
		H = survival_patient(kind)
		text2file("[kind]: herbs", "progress.txt")
		var/obj/item/stack/medical/advanced/herbs/herbs = new(H.loc, 4)
		for(var/tick in 1 to 601)
			if(tick == 1 || tick == 181 || tick == 361)
				herbs.attack_self(H)
			survival_tick(H)
		survival_assert(!H.disease && herbs.amount == 1, "[kind]: three oral herbs complete course and reserve planting stock")
		del(herbs)
		del(H)
	var/mob/living/human/H = survival_patient("plague")
	H.ingested.add_reagent("penicillin", 0.5)
	for(var/tick in 1 to 80)
		survival_tick(H)
	survival_assert(H.disease && H.disease_course == 0 && H.disease_progression > 1, "short dose cannot permanently treat")
	H.ingested.add_reagent("penicillin", 2)
	for(var/tick in 1 to 181)
		survival_tick(H)
	survival_assert(!H.disease, "interrupted course remains recoverable")
	del(H)
	H = survival_patient("malaria")
	H.ingested.add_reagent("penicillin", 2)
	for(var/tick in 1 to 181)
		survival_tick(H)
	survival_assert(H.disease && H.disease_course == 0, "wrong medicine does not treat malaria")
	del(H)
	H = survival_patient("plague")
	H.inducedSSD = TRUE
	for(var/tick in 1 to 1300)
		survival_tick(H)
	survival_assert(H.stat != DEAD && H.disease_progression == 0, "disconnect pauses illness")
	H.inducedSSD = FALSE
	H.status_flags |= GODMODE
	survival_tick(H)
	survival_assert(H.disease_progression == 0, "godmode exemption")
	H.status_flags &= ~GODMODE
	H.disease_immunity += "plague"
	survival_tick(H)
	survival_assert(!H.disease, "existing immunity exemption")
	del(H)
	var/datum/reagents/holder = new(100)
	holder.add_reagent("charcoal", 1, safety = TRUE)
	holder.add_reagent("ethanol", 2, safety = TRUE)
	var/datum/chemical_reaction/acetone_charcoal/acetone = new
	survival_assert(acetone.can_happen(holder), "renewable acetone inputs registered")
	acetone.process(holder)
	survival_assert(holder.get_reagent_amount("acetone") == 1, "renewable acetone yield")
	holder.add_reagent("enzyme", 10, safety = TRUE)
	var/datum/chemical_reaction/penicillin/antibiotic = new
	survival_assert(antibiotic.can_happen(holder), "penicillin after renewable acetone")
	antibiotic.process(holder)
	survival_assert(holder.get_reagent_amount("penicillin") == 5, "renewable antibiotic output")
	del(holder)
	del(acetone)
	del(antibiotic)
	// A real cultivated herb harvest must exceed one unit reserved to replant.
	var/obj/structure/farming/plant/herbs/plant = new(locate(12,10,1))
	plant.plant_nutrition = 0
	plant.spawn_produce()
	var/obj/item/stack/medical/advanced/herbs/harvest = locate() in plant.loc
	survival_assert(harvest && harvest.amount == 3, "herbs renewable minimum yield")
	del(harvest)
	del(plant)
	var/mob/living/human/source = survival_patient("plague")
	H = new(locate(11,10,1))
	H.hygiene = 100
	for(var/tick in 1 to 3000)
		H.acquire_nearby_disease()
		if(H.disease)
			break
	survival_assert(H.disease && H.disease_type == "plague", "susceptible healthy target can catch illness")
	H.disease_progression = 500
	H.acquire_nearby_disease()
	survival_assert(H.disease_progression == 500, "nearby illness never resets infected target")
	H.clear_disease()
	source.disease_type = "malaria"
	for(var/mob/living/human/nearby in range(2, H))
		text2file("nearby=[nearby] disease=[nearby.disease] type=[nearby.disease_type]", "progress.txt")
	for(var/tick in 1 to 1000)
		H.acquire_nearby_disease()
	survival_assert(!H.disease, "malaria does not transmit person to person")
	del(H)
	del(source)
#endif
