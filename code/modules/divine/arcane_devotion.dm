// ============================================================
// Devotion (magic materials and enchanting plan, PR 8). Hidden mechanic: keep
// it out of changelog lines, the wiki and the public Crafting Atlas.
// ------------------------------------------------------------
// A magic user keeps a devotion at an altar of their god (Tend an Altar): no
// god's click. While they stay still and awake beside it, every 10 minutes
// one of their tied repositories of that god gains 1 charge, doubled for each
// favoured custom they keep (at most x4). The god chooses up to 3 customs in
// Divine Patron, each required (the devotion cannot start or ends without it)
// or favoured. Thirty minutes of devotion count as a day's worship at the
// altar. Caps are the repository's: 30 a day from each magic user and 150 a
// day in all ("devotion" in repository.dm), apart from offerings.
// ============================================================

#define ARCANE_DEVOTION_STEP 6000      // deciseconds of devotion per charge
#define ARCANE_DEVOTION_WORSHIP 18000  // deciseconds of devotion that count as worship
#define ARCANE_DEVOTION_TICK 100       // how often the devotion is checked
#define ARCANE_CUSTOMS_MAX 3
#define ARCANE_CUSTOMS_FILE "data/divine_customs.json"

// Custom id -> how the god and the magic user see it.
var/global/list/arcane_custom_names = list(
	"night" = "at night",
	"dawn" = "at dawn",
	"kneeling" = "kneeling or lying down",
	"barefoot" = "barefoot",
	"head_covered" = "with the head covered",
	"fasting" = "while fasting",
	"company" = "with another of the faithful",
)

// god key -> list(custom id -> "required" or "favoured"). Loaded on first use.
var/global/list/arcane_customs = null

/mob/living/human
	var/tmp/arcane_devoting = FALSE

/proc/arcane_customs_load()
	if (islist(arcane_customs))
		return arcane_customs
	arcane_customs = list()
	if (!fexists(ARCANE_CUSTOMS_FILE))
		return arcane_customs
	var/list/raw = null
	try
		raw = json_decode(file2text(ARCANE_CUSTOMS_FILE))
	catch
		raw = null
	if (!islist(raw))
		return arcane_customs
	for (var/god in raw)
		var/list/set_of = raw[god]
		if (!istext(god) || !islist(set_of))
			continue
		var/list/clean = list()
		for (var/custom in set_of)
			if (arcane_custom_names[custom] && (set_of[custom] == "required" || set_of[custom] == "favoured") && clean.len < ARCANE_CUSTOMS_MAX)
				clean[custom] = set_of[custom]
		if (clean.len)
			arcane_customs[god] = clean
	return arcane_customs

/proc/arcane_customs_save()
	var/list/L = arcane_customs_load()
	if (fexists(ARCANE_CUSTOMS_FILE))
		fdel(ARCANE_CUSTOMS_FILE)
	return text2file(json_encode(L), ARCANE_CUSTOMS_FILE)

/proc/arcane_customs_of(god)
	var/list/L = arcane_customs_load()
	var/list/C = L[god]
	return islist(C) ? C : list()

/mob/living/human/proc/arcane_keeps_custom(custom)
	switch (custom)
		if ("night")
			return time_of_day == "Night" || time_of_day == "Dark Night"
		if ("dawn")
			return time_of_day == "Early Morning"
		if ("kneeling")
			return lying || resting
		if ("barefoot")
			return !shoes
		if ("head_covered")
			return !!head
		if ("fasting")
			return nutrition < 220
		if ("company")
			for (var/mob/living/human/H in range(3, src))
				if (H != src && H.arcane_devoting && divine_book_key(H.divine_patron) == divine_book_key(divine_patron))
					return TRUE
	return FALSE

// The required custom this magic user is not keeping, or null.
/mob/living/human/proc/arcane_custom_missing(god)
	var/list/C = arcane_customs_of(god)
	for (var/custom in C)
		if (C[custom] == "required" && !arcane_keeps_custom(custom))
			return custom
	return null

/mob/living/human/proc/arcane_devotion_rate(god)
	var/rate = 1
	var/list/C = arcane_customs_of(god)
	for (var/custom in C)
		if (C[custom] == "favoured" && arcane_keeps_custom(custom))
			rate *= 2
	return min(rate, 4)

// Called from Tend an Altar (arcane_altars.dm).
/mob/living/human/proc/arcane_devote_at(obj/O)
	var/god = O.arcane_altar_live()
	if (arcane_devoting)
		to_chat(src, SPAN_WARNING("You are already keeping a devotion."))
		return FALSE
	var/list/repos = list()
	for (var/obj/R in magic_registered_repositories())
		if (R.magic_repo_deity == god)
			repos["[R.name] ([R.magic_repo_id])"] = R
	if (!repos.len)
		to_chat(src, SPAN_WARNING("You are tied to nothing it could reach."))
		return FALSE
	var/obj/target = repos.len == 1 ? repos[repos[1]] : repos[player_input(src, "Keep it for which?", "Devotion", null, "anything", repos, TRUE)]
	if (!target || QDELETED(O) || !O.Adjacent(src) || O.arcane_altar_live() != god || arcane_devoting)
		return FALSE
	var/missing = arcane_custom_missing(god)
	if (missing)
		to_chat(src, SPAN_WARNING("Your god asks for devotion [arcane_custom_names[missing]]."))
		return FALSE
	arcane_devoting = TRUE
	to_chat(src, SPAN_NOTICE("You settle beside [O] and keep a quiet devotion. Stay still."))
	log_game("[key_name(src)] began a devotion at an altar of [god] for [target.magic_repo_id].")
	arcane_devotion_loop(O, target, god)
	return TRUE

/mob/living/human/proc/arcane_devotion_loop(obj/O, obj/target, god)
	set waitfor = FALSE
	var/turf/start = get_turf(src)
	var/start_damage = getBruteLoss() + getBurnLoss()
	var/kept = 0
	var/since_charge = 0
	var/worshipped = FALSE
	var/total = 0
	var/why = null
	while (TRUE)
		sleep(ARCANE_DEVOTION_TICK)
		if (QDELETED(src))
			return
		if (!client || stat != CONSCIOUS || sleeping || get_turf(src) != start)
			why = "You break off your devotion."
		else if (getBruteLoss() + getBurnLoss() > start_damage)
			why = "Your devotion is broken."
		else if (QDELETED(O) || !O.Adjacent(src) || O.arcane_altar_live() != god || divine_book_key(divine_patron) != god || !magic_allowed())
			why = "Your devotion falls quiet."
		else if (QDELETED(target) || target.magic_repo_dormant())
			why = "What you kept it for is gone."
		else if (arcane_custom_missing(god))
			why = "You no longer keep your god's custom."
		if (why)
			break
		kept += ARCANE_DEVOTION_TICK
		since_charge += ARCANE_DEVOTION_TICK
		if (since_charge >= ARCANE_DEVOTION_STEP)
			since_charge = 0
			total += ward_refill(target, arcane_devotion_rate(god), "devotion", src)
		if (!worshipped && kept >= ARCANE_DEVOTION_WORSHIP)
			worshipped = TRUE
			O.arcane_altar_worship(src)
	arcane_devoting = FALSE
	to_chat(src, SPAN_NOTICE(why))
	log_game("[key_name(src)] ended a devotion at an altar of [god] after [round(kept / 600)] minutes: [total] charge to [target ? target.magic_repo_id : "nothing"].")

// Divine Patron > Set customs.
/client/proc/arcane_edit_customs(claim)
	var/list/current = arcane_customs_of(claim).Copy()
	while (TRUE)
		var/list/lines = list()
		for (var/custom in current)
			lines += "[arcane_custom_names[custom]] ([current[custom]])"
		var/list/menu = list()
		for (var/custom in arcane_custom_names)
			menu["[arcane_custom_names[custom]][current[custom] ? " - [current[custom]]" : ""]"] = custom
		menu["Done"] = "done"
		var/pick = player_input(src, "Customs for devotion to [divine_label_for(claim)]: [lines.len ? english_list(lines) : "none"]. Pick one to change (up to [ARCANE_CUSTOMS_MAX]).", "Customs", null, "anything", menu, TRUE)
		var/custom = menu[pick]
		if (!custom || custom == "done")
			break
		var/how = player_input(src, "Devotion [arcane_custom_names[custom]] is...", "Customs", null, "anything", list("Required", "Favoured", "Not asked"), TRUE)
		if (!how)
			continue
		if (how == "Not asked")
			current -= custom
		else if (current[custom] || current.len < ARCANE_CUSTOMS_MAX)
			current[custom] = lowertext(how)
		else
			to_chat(src, SPAN_WARNING("A god can ask for at most [ARCANE_CUSTOMS_MAX] customs."))
	if (!check_rights(R_ADMIN) || divine_claim_of(src) != claim)
		return
	var/list/L = arcane_customs_load()
	if (current.len)
		L[claim] = current
	else
		L -= claim
	arcane_customs_save()
	to_chat(src, SPAN_NOTICE("Customs saved."))
	log_admin("[key_name(src)] as [claim] set devotion customs: [json_encode(current)].")

#undef ARCANE_DEVOTION_STEP
#undef ARCANE_DEVOTION_WORSHIP
#undef ARCANE_DEVOTION_TICK
#undef ARCANE_CUSTOMS_MAX
#undef ARCANE_CUSTOMS_FILE
