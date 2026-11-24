// Clinic gameplay only: a paid abstract supply batch grants a limited set of
// optional preventive doses. No game illness or live agent is a batch input.
#define CLINIC_IMMUNIZATION_EPOCH 5
#define CLINIC_BATCH_DOSES 3
#define CLINIC_DOSE_CAPACITY 12
#define CLINIC_CHOLERA_ONSET_MINUTES 10
#define CLINIC_CHOLERA_PROTECTION_MINUTES 360

// Changed-field world saves retain this on the body, not the client's prefs.
/mob/living/human/var/list/immunization_record = null

/proc/immunization_now()
	return round(world.realtime / (1 MINUTES))

/proc/immunization_entry_valid(kind, list/entry)
	return kind == "cholera" && islist(entry) && entry.len == 2 && isnum(entry[1]) && isnum(entry[2]) && entry[1] > 0 && entry[2] > entry[1] && entry[2] - entry[1] == CLINIC_CHOLERA_PROTECTION_MINUTES

/mob/living/human/proc/immunization_protects(kind, now = null)
	if (kind != "cholera" || !islist(immunization_record))
		return FALSE
	var/list/entry = immunization_record[kind]
	if (!immunization_entry_valid(kind, entry))
		return FALSE
	if (isnull(now))
		now = immunization_now()
	return now >= entry[1] && now < entry[2]

// Accepting a dose never edits active illness, treatment, or ordinary immunity.
// An unexpired scheduled dose also prevents repeatedly spending stock.
/mob/living/human/proc/receive_clinic_immunization(kind, now)
	if (kind != "cholera" || !isnum(now) || now <= 0 || (disease && disease_type == kind))
		return FALSE
	var/list/entry = islist(immunization_record) ? immunization_record[kind] : null
	if (immunization_entry_valid(kind, entry) && now < entry[2])
		return FALSE
	if (!islist(immunization_record))
		immunization_record = list()
	var/starts = now + CLINIC_CHOLERA_ONSET_MINUTES
	immunization_record[kind] = list(starts, starts + CLINIC_CHOLERA_PROTECTION_MINUTES)
	return TRUE

/mob/living/human/verb/check_immunizations()
	set name = "Check Immunizations"
	set category = "IC"
	if (stat == DEAD || !islist(immunization_record))
		to_chat(src, SPAN_NOTICE("You have no recorded immunizations."))
		return
	var/list/entry = immunization_record["cholera"]
	if (!immunization_entry_valid("cholera", entry))
		to_chat(src, SPAN_NOTICE("You have no recorded immunizations."))
		return
	var/now = immunization_now()
	if (now < entry[1])
		to_chat(src, SPAN_NOTICE("Your cholera protection begins in about [entry[1] - now] minute(s)."))
	else if (now < entry[2])
		to_chat(src, SPAN_NOTICE("Your cholera protection has about [entry[2] - now] minute(s) remaining."))
	else
		to_chat(src, SPAN_NOTICE("Your cholera protection has expired."))

/obj/structure/workshop_machine/immunization_clinic
	name = "immunization clinic"
	desc = "A small medicine station. Use a glass sheet to stock three abstract cholera vaccine doses, then use an empty hand to offer a dose to yourself or a nearby patient."
	icon = 'icons/obj/chemical.dmi'
	icon_state = "mixer0b"
	var/clinic_doses = 0

// Single-world release only until every receiving world can preserve the
// optional record. Never produce a record that an old peer would silently lose.
/obj/structure/workshop_machine/immunization_clinic/proc/clinic_active()
	return map && map.ordinal_age >= CLINIC_IMMUNIZATION_EPOCH && (!shard_group || !shard_group.enabled)

/obj/structure/workshop_machine/immunization_clinic/proc/clinic_present(mob/living/human/H)
	return !QDELETED(src) && anchored && isturf(loc) && !QDELETED(H) && istype(H) && H.client && H.client.mob == H && !H.incapacitated() && !H.inducedSSD && !H.droid && !H.orc && !H.crab && isturf(H.loc) && H.z == z && get_dist(src, H) <= 1 && Adjacent(H) && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required

/obj/structure/workshop_machine/immunization_clinic/examine(mob/user, distance)
	..()
	to_chat(user, SPAN_NOTICE("It has [clinic_doses] of [CLINIC_DOSE_CAPACITY] doses stocked."))
	if (!clinic_active())
		to_chat(user, SPAN_WARNING("Immunization is not available in this world yet."))

/obj/structure/workshop_machine/immunization_clinic/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (handle_machine_tool(I, H))
		return
	if (I.type != /obj/item/stack/material/glass)
		return ..()
	if (!clinic_active() || !clinic_present(H))
		return
	if (!crafting_node_allowed_or_warn(H, "immunization"))
		return
	if (clinic_doses > CLINIC_DOSE_CAPACITY - CLINIC_BATCH_DOSES)
		to_chat(H, SPAN_WARNING("There is no room for another complete supply batch."))
		return
	var/obj/item/stack/material/glass/S = I
	if (QDELETED(S) || S.loc != H || H.get_active_hand() != S || !S.use(1))
		return
	clinic_doses += CLINIC_BATCH_DOSES
	to_chat(H, SPAN_NOTICE("You stock [CLINIC_BATCH_DOSES] cholera vaccine doses."))

// Called only after actor, consent, stock and world admission have been
// rechecked. No yield between checking the record and consuming one dose.
/obj/structure/workshop_machine/immunization_clinic/proc/apply_clinic_dose(mob/living/human/patient, now)
	if (clinic_doses <= 0 || !patient.receive_clinic_immunization("cholera", now))
		return FALSE
	clinic_doses--
	return TRUE

/obj/structure/workshop_machine/immunization_clinic/attack_hand(mob/living/human/H)
	if (!istype(H) || !clinic_present(H))
		return
	if (!clinic_active())
		to_chat(H, SPAN_WARNING("Immunization is not available in this world yet."))
		return
	if (!crafting_node_allowed_or_warn(H, "immunization"))
		return
	if (clinic_doses <= 0)
		to_chat(H, SPAN_WARNING("The clinic has no doses. Stock it with a glass sheet."))
		return
	var/client/operator = H.client
	var/list/candidates = list(H)
	for (var/mob/living/human/P in range(1, src))
		if (P != H && clinic_present(P) && P.client != operator && P.Adjacent(H))
			candidates += P
	var/mob/living/human/patient = WWinput(H, "Who should receive a cholera vaccine dose?", "Immunization Clinic", "Cancel", candidates + "Cancel")
	if (!istype(patient) || !(patient in candidates) || !clinic_present(H) || H.client != operator || !clinic_present(patient) || (patient != H && !patient.Adjacent(H)))
		return
	var/client/recipient = patient.client
	if (patient != H)
		var/answer = WWinput(patient, "[H.real_name] offers you a preventive cholera vaccine dose. Accept?", "Immunization Clinic", "Decline", list("Accept", "Decline"))
		if (answer != "Accept")
			return
	if (!clinic_active() || !clinic_present(H) || H.client != operator || !clinic_present(patient) || patient.client != recipient || (patient != H && !patient.Adjacent(H)) || !crafting_node_allowed(H, "immunization") || clinic_doses <= 0)
		return
	if (!apply_clinic_dose(patient, immunization_now()))
		to_chat(H, SPAN_WARNING("No dose used: the patient already has a current record or has active cholera."))
		return
	to_chat(patient, SPAN_NOTICE("You received a cholera vaccine dose. Protection takes about [CLINIC_CHOLERA_ONSET_MINUTES] minutes and lasts about [CLINIC_CHOLERA_PROTECTION_MINUTES / 60] hours. It does not treat illness."))
	if (H != patient)
		to_chat(H, SPAN_NOTICE("You administer one cholera vaccine dose."))

#undef CLINIC_IMMUNIZATION_EPOCH
#undef CLINIC_BATCH_DOSES
#undef CLINIC_DOSE_CAPACITY
#undef CLINIC_CHOLERA_ONSET_MINUTES
#undef CLINIC_CHOLERA_PROTECTION_MINUTES
