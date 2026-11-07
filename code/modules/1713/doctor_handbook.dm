// 2017-07-08: Created with essentials -- Irra

/obj/item/weapon/doctor_handbook
	name = "doctor's handbook"
	desc = "A book the size of your hand, containing a compact encyclopedia of the dark wonders of war - diseases, conditions, and documentation of all degrees of injury."
	icon = 'icons/obj/library.dmi'
	icon_state = "bookmed"
	item_state = "bible" // I couldn't find any better placeholder for now
	slot_flags = SLOT_BELT | SLOT_POCKET
	force = TRUE
	throwforce = TRUE
	w_class = ITEM_SIZE_SMALL
	throw_speed = 5
	throw_range = 10
	attack_verb = list("slapped", "whacked")
	flammable = TRUE
	var/list/severity_adj = list("minor", "moderate", "serious", "severe", "critical") // do not touch this
	var/sev_factor
	flags = FALSE

/obj/item/weapon/doctor_handbook/attack(mob/living/victim as mob, mob/living/user as mob)
	if (user.a_intent == I_HARM)
		return ..()

	var/datum/gender/G = gender_datums[victim.gender]
	user.visible_message("<span class='notice'>[user] glances through [src], inspecting [victim]'s [victim.stat == DEAD ? "corpse" : "body"].</span>")

	if (ishuman(victim))
		var/mob/living/human/H = victim

		var/severity_blood_loss = FALSE
		var/severity_poisoning = FALSE
		var/severity_malnourishment = FALSE

		// GENERAL BLOOD LOSS
		if (H.vessel) // look for any reference to "vessel"
			var/blood_percent = round((H.vessel.get_reagent_amount("blood") / H.species.blood_volume)*100)
			switch (blood_percent)
				if (91 to 100)	severity_blood_loss = FALSE
				if (81 to 90) 	severity_blood_loss = TRUE
				if (71 to 80)		severity_blood_loss = 2
				if (61 to 70) 	severity_blood_loss = 3
				if (51 to 60) 	severity_blood_loss = 4
				else						severity_blood_loss = 5

		// GENERAL TOXIN DAMAGE
		severity_poisoning = pick_severity(H.getToxLoss())

		// HUNGER
		switch (H.nutrition)
			if (41 to 50) severity_malnourishment = TRUE
			if (31 to 40) severity_malnourishment = 2
			if (21 to 30) severity_malnourishment = 3
			if (11 to 20) severity_malnourishment = 4
			if (0 to 10)  severity_malnourishment = 5
			else severity_malnourishment = FALSE

		// Begin displaying
		user.show_message("<b>----------</b>")
		user.show_message("Consulting [src], you've concluded that [victim] [victim.stat == DEAD ? SPAN_RED("<b>is dead.</b>") : SPAN_GREEN("<b>is alive.</b>")] [G.He] has:")

		user.show_message("<span class='notice'>* [H.b_type] blood type.</span>")
		var/is_bad = FALSE	// I hate myself
		if (severity_blood_loss)
			is_bad = TRUE
			user.show_message("<span class='warning'><b>* [capitalize(severity_adj[severity_blood_loss])] blood loss.</b></span>")
		if (severity_poisoning)
			is_bad = TRUE
			user.show_message("<span class='warning'><b>* [capitalize(severity_adj[severity_poisoning])] general poisoning.</b></span>")
		if (severity_malnourishment)
			is_bad = TRUE
			user.show_message("<span class='warning'><b>* [capitalize(severity_adj[severity_malnourishment])] malnourishment.</b></span>")
		if (!is_bad)
			user.show_message("<span class='notice'>* No general health issues.</span>")

		// DISEASES AND POISONS
		var/illness = diagnose_disease(H)
		if (illness)
			user.show_message("<span class='warning'><b>* [illness]</b></span>")
		else
			user.show_message("<span class='notice'>* No signs of disease.</span>")
		var/list/poisons = diagnose_poisons(H)
		for (var/line in poisons)
			user.show_message("<span class='warning'><b>* [line]</b></span>")
		if (!poisons.len)
			user.show_message("<span class='notice'>* No poison found in the blood or stomach.</span>")
		for (var/line in diagnose_immunity(H))
			user.show_message("<span class='notice'>* [line]</span>")

		var/ecount = 0 // external organs count
		var/icount = 0 // internal organs count

		var/list/unsplinted_limbs = list()
		user.show_message("[victim] has:")

		// check external organs first
		for (var/obj/item/organ/external/e in H.organs)

			var/wounds = FALSE
			var/infected = FALSE
			var/broken = FALSE
			var/internal = FALSE
			var/open = FALSE
			var/bleeding = FALSE
			var/foreign = FALSE // shrapnel, implants, and etcera

			if (!e)
				continue
			if (e.status & ORGAN_DESTROYED && !e.is_stump())
				user.show_message("<span class='warning'><b>* [capitalize(e.name)] is gored at [e.amputation_point] and needs to be amputated properly.</b></span>")
				ecount++
				continue
			if (e.status & ORGAN_BROKEN)
				broken = TRUE
				if ((e.limb_name in list("l_arm", "r_arm", "l_leg", "r_leg")) && !(e.status & ORGAN_SPLINTED))
					unsplinted_limbs.Add(e.name)
			if (e.has_infected_wound())
				infected = TRUE
			if (e.implants.len)
				foreign = TRUE
			for (var/datum/wound/W in e.wounds)
				if (W.damage > 2)					wounds++
				if (W.internal)						internal = TRUE
				if (W.bleeding())					bleeding = TRUE
				if (W.can_be_infected()) 	open = TRUE // returns TRUE when it can be infected, then cosnidered as an open wound

			if (wounds || infected || broken || internal || open || bleeding || internal || foreign)
				var/string = "<span class='warning'>* "
				var/inner = ""
				if (wounds || infected || broken || internal || open || bleeding)
					inner += "[wounds > 1 ? "multiple" : (open ? "an" : "a") ]"
					inner += "[open ? " open" : ""]"
					inner += "[bleeding ? " bleeding" : ""]"
					inner += "[infected && e.germ_level > 175 ? " infected" : ""]"
					inner += " wound[wounds > 1 ? "s" : ""]"
					inner += " [foreign || internal || broken || e.burn_dam > 2 || e.brute_dam > 2 ? "and " : "at"]"
				if (e.brute_dam > 2)
					var/sev = pick_severity(e.brute_dam)
					inner += "[sev ? severity_adj[sev] : "dismissable"] bruises"
					inner += " [foreign || internal || broken || e.burn_dam > 2 ? "and " : "at"]"
				if (e.burn_dam > 2)
					var/sev = pick_severity(e.burn_dam)
					inner += "[sev ? severity_adj[sev] : "dismissable"] burns"
					inner += " [foreign || internal || broken ? "and " : "at"]"
				if (broken)
					inner += "broken bones"
					inner += " [foreign || internal ? "and " : "in"]"
				if (internal)
					inner += "signs of internal bleeding"
					inner += " [foreign ? "and " : "in"]"
				if (foreign)
					inner += "likely shrapnel"
					inner += " in"
				string += "[capitalize(inner)] [G.his] [e.name].</span>"
				user.show_message("<b>[string]</b>")
				ecount++
		if (!ecount)
			user.show_message("<span class='notice'>* No local injuries.</span>")

		// check internal organs afterwards
		for (var/obj/item/organ/e in H.internal_organs)

			if (!e)
				continue
			else if (e.status & ORGAN_DESTROYED)
				user.show_message("<span class='warning'><b>* [capitalize(e.name)] has been destroyed.</b></span>")
				icount++
			else if (e.status & ORGAN_BROKEN || e.damage >= e.min_bruised_damage)
				var/string = "<span class='warning'>* "
				var/inner = ""
				inner += " and "
				inner += "injuries on"
				string += "[capitalize(inner)] [G.his] [e.name].</span>"
				user.show_message("<b>[string]</b>")
				icount++

		if (!icount)
			user.show_message("<span class='notice'>* No organ damage.</span>")

		if (unsplinted_limbs.len >= 1)
			var/string = "[G.His] "
			var/Count = TRUE
			for (var/limb_name in unsplinted_limbs)
				string += limb_name
				if (Count < unsplinted_limbs.len)
				 string += ", "
				 if (Count + 1 == unsplinted_limbs.len)
				 	string += "and "
				Count++
			string += " need[ecount == TRUE ? "s" : ""] splinting for safe transport."
			user.show_message("<b>[string]</b>")

		if (ishuman(victim))
			var/mob/living/human/C = victim
			var/hunger_coeff = C.nutrition/C.max_nutrition
			var/thirst_coeff = C.water/C.max_water
			var/oxyloss = victim.getOxyLoss()
			var/toxloss = victim.getToxLoss()

			if (oxyloss)
				user.show_message("<span class='[oxyloss <= 20 ? "warning" : "danger"]'><b>[G.He] has [oxyloss] units of oxygen loss.</b></span>")

			if (toxloss)
				user.show_message("<span class='[toxloss <= 20 ? "warning" : "danger"]'><b>[G.He] has [toxloss] units of toxin poisoning.</b></span>")

			user.show_message("<span class='[hunger_coeff > 0.66 ? "good" : hunger_coeff > 0.40 ? "notice" : "danger"]'>[G.He] is [round((1 - hunger_coeff)*100)]% hungry.</span>")
			user.show_message("<span class='[thirst_coeff > 0.66 ? "good" : thirst_coeff > 0.40 ? "notice" : "danger"]'>[G.He] is [round((1 - thirst_coeff)*100)]% thirsty.</span>")
			user.show_message("<b>----------</b>")


// Internal code for doctor_handbook
/obj/item/weapon/doctor_handbook/proc/pick_severity(var/damage, var/max_damage = 200)
	if (damage > max_damage)
		damage = max_damage
	return pick_severity_by_percent(round((damage / max_damage)*100))

/obj/item/weapon/doctor_handbook/proc/pick_severity_by_percent(var/percent)
	return round(percent - (percent % get_factor()))/(get_factor())

/obj/item/weapon/doctor_handbook/proc/get_factor()
	if (!sev_factor)
		sev_factor = 100/severity_adj.len
	return sev_factor

// Names the illness the patient carries and how far along it is, or null.
/obj/item/weapon/doctor_handbook/proc/diagnose_disease(mob/living/human/H)
	if (!H.disease || !H.disease_type || H.disease_type == "none")
		return null
	var/list/names = list("flu" = "Influenza", "zombie" = "Zombie infection", "plague" = "Plague", "typhus" = "Typhus", "malaria" = "Malaria", "cholera" = "Cholera")
	var/illness = names[H.disease_type] || capitalize(H.disease_type)
	var/fighting = H.builds_disease_immunity(H.disease_type) ? " The body has built [round(H.disease_resistance_to(H.disease_type))]% of the resistance it needs to clear it." : ""
	if (H.is_severe_disease())
		var/stage = "early stage"
		if (H.disease_progression >= 900)
			stage = "critical stage, fatal without treatment"
		else if (H.disease_progression >= 180)
			stage = "worsening stage"
		illness += " ([stage]). It will not clear on its own; it needs a full medicine course"
		if (H.disease_course > 0)
			illness += ", currently [round(min(100, H.disease_course / 1.8))]% done"
		return illness + "." + fighting
	if (H.disease_type == "flu")
		var/stage = "early stage"
		if (H.disease_progression >= 180)
			stage = "recovering"
		else if (H.disease_progression >= 60)
			stage = "high fever"
		return "[illness] ([stage]).[fighting]"
	return "[illness]."

// Poisons in the blood and stomach, one line each, by reagent name.
/obj/item/weapon/doctor_handbook/proc/diagnose_poisons(mob/living/human/H)
	. = list()
	var/list/blood = list()
	var/list/stomach = list()
	var/list/order = list()
	var/list/holders = list(H.reagents, H.ingested)
	for (var/i in 1 to holders.len)
		var/datum/reagents/R = holders[i]
		if (!R)
			continue
		for (var/datum/reagent/A in R.reagent_list)
			if (A.volume <= 0 || !is_handbook_poison(A))
				continue
			var/list/into = i == 1 ? blood : stomach
			into[A.name] = (into[A.name] || 0) + A.volume
			order |= A.name
	for (var/poison in order)
		var/list/where = list()
		if (blood[poison])
			where += "[round(blood[poison], 0.1)]u in the blood"
		if (stomach[poison])
			where += "[round(stomach[poison], 0.1)]u in the stomach"
		. += "Poisoned with [poison] ([jointext(where, ", ")])."

// Resistance left over from past illnesses and tolerance built up to poisons.
/obj/item/weapon/doctor_handbook/proc/diagnose_immunity(mob/living/human/H)
	. = list()
	var/list/names = list("flu" = "influenza", "plague" = "plague", "typhus" = "typhus", "malaria" = "malaria", "cholera" = "cholera")
	for (var/kind in H.disease_resistance)
		if (H.disease && kind == H.disease_type)
			continue
		var/percent = round(H.disease_resistance_to(kind))
		if (percent < 1)
			continue
		var/illness = names[kind] || kind
		if (H.resists_disease(kind))
			. += "Recently fought off [illness] and is still immune to it ([percent]% resistance)."
		else
			. += "Some lingering resistance to [illness] ([percent]%), too little to stop a new infection."
	for (var/id in H.poison_exposure)
		var/less = round((1 - H.poison_tolerance(id, 0)) * 100)
		if (less < 1)
			continue
		var/datum/reagent/R = chemical_reagents_list[id]
		. += "Has built a tolerance to [R ? R.name : id] and takes [less]% less harm from it."

/obj/item/weapon/doctor_handbook/proc/is_handbook_poison(datum/reagent/A)
	return istype(A, /datum/reagent/toxin) || (A.id in list("lexorin", "stoxin", "chloralhydrate", "pacid"))
