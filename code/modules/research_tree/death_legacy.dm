// Gameplay balance. What a dead character knew is kept with the world for a
// day, per account. The account's next character gets it back, less a loss
// set by the cause of death, when it starts close to where the last one died:
// beside its faction's recruitment station, or at the account's own
// long-held bed. Anywhere else, or too late, it starts fresh as before.
// Every death also leaves the account's next character weakened in combat
// for a while (animals excepted, so it can still hunt).
// Saved in round.json "death_legacy" (valid_death_legacy_record, functions.dm).

// Tiles (x and y only) between the death and the station or bed.
#define DEATH_LEGACY_RANGE 150
// Real hours a record lasts, and a bed must have been held before the death.
#define DEATH_LEGACY_HOURS 24
#define DEATH_LEGACY_BED_HOURS 24
// A bed start costs like this many more returns: one doubles the loss.
#define DEATH_LEGACY_BED_EXTRA 1
// A weakness nobody came back to collect is dropped after a week.
#define DEATH_LEGACY_WEAK_HOURS 168
#define DEATH_LEGACY_LIMIT 500
// Seconds of play the next character is weakened, and its damage to people.
#define DEATH_WEAKNESS_SECONDS 1800
#define DEATH_WEAKNESS_SCALE 0.5

// account -> record. "at" and "used" are death_legacy_now() hours.
var/global/list/death_legacies = list()
// Tests move the clock; always 0 in play.
var/global/death_legacy_test_hours = 0

/mob/living/human
	// Seconds of play left of the weakness a death left behind; saved.
	var/death_weakness_left = 0
	var/tmp/death_weakness_checked = 0
	var/tmp/started_with_faction = FALSE // set by the member start (job_controller.dm)
	var/tmp/died_by_own_hand = FALSE

// When this account was assigned the bed (death_legacy_now() hours). Null on a
// bed assigned before this was recorded, which counts as long held.
/obj/structure/bed/var/persistence_bed_assigned_at

/proc/death_legacy_enabled()
	return map && map.recipe_knowledge_enabled()

// Whole real hours since 2000: small enough to survive every save format.
/proc/death_legacy_now()
	return round(world.realtime / 36000) + death_legacy_test_hours

/proc/death_legacy_account(mob/living/human/H)
	if (!istype(H))
		return null
	var/account = H.client ? H.client.ckey : (H.ckey || H.persistence_owner_ckey)
	return istext(account) && length(account) && copytext(account, 1, 6) != "guest" ? account : null

/proc/death_legacy_near(list/record, turf/T)
	return T && isnum(record["x"]) && max(abs(T.x - record["x"]), abs(T.y - record["y"])) <= DEATH_LEGACY_RANGE

// TRUE when the bed was this account's for long enough before hour `at`.
/obj/structure/bed/proc/legacy_established(account, at)
	if (persistence_bed_owner_ckey != account || !anchored || !isturf(loc))
		return FALSE
	return !isnum(persistence_bed_assigned_at) || persistence_bed_assigned_at <= at - DEATH_LEGACY_BED_HOURS

// What a cause of death costs on return: list(fraction of body skill gains,
// fraction of scholarship, fraction of crafting and dexterity gains, subjects).
// Each earlier return in the same day doubles it.
/proc/death_legacy_loss(cause, returns = 0)
	var/list/loss
	switch (cause)
		if ("starved", "thirst", "cold", "heat", "disease", "poison")
			loss = list(0.2, 0, 0, 0)
		if ("drowned", "suffocated")
			loss = list(0, 0.2, 0, 0)
		if ("burned")
			loss = list(0, 0, 0.2, 0)
		if ("player")
			loss = list(0, 0.2, 0, 3)
		else
			loss = list(0.1, 0, 0, 0)
	var/times = 2 ** clamp(returns, 0, 6)
	return list(min(1, loss[1] * times), min(1, loss[2] * times), min(1, loss[3] * times), loss[4] * times)

/proc/death_legacy_share_text(fraction)
	if (fraction >= 1)
		return "all"
	switch (round(fraction * 100))
		if (10)
			return "a tenth"
		if (20)
			return "a fifth"
		if (40)
			return "two fifths"
		if (80)
			return "four fifths"
	return "[round(fraction * 100)]%"

/proc/death_legacy_cause_text(cause)
	switch (cause)
		if ("starved")
			return "starved"
		if ("thirst")
			return "died of thirst"
		if ("cold")
			return "froze"
		if ("heat")
			return "died of heat"
		if ("disease")
			return "died of illness"
		if ("poison")
			return "was poisoned"
		if ("drowned")
			return "drowned"
		if ("suffocated")
			return "suffocated"
		if ("burned")
			return "burned"
		if ("player")
			return "was killed by another person"
	return "died of wounds"

// One sentence naming what a return costs.
/proc/death_legacy_loss_text(cause, returns = 0)
	var/list/loss = death_legacy_loss(cause, returns)
	var/list/parts = list()
	if (loss[1] > 0)
		parts += "[death_legacy_share_text(loss[1])] of what their body skills had gained"
	if (loss[3] > 0)
		parts += "[death_legacy_share_text(loss[3])] of what their crafting and dexterity had gained"
	if (loss[4] > 0)
		parts += "the [loss[4]] subjects they learned last"
	if (loss[2] > 0)
		parts += "[death_legacy_share_text(loss[2])] of their scholarship"
	return english_list(parts)

// The account's record if it still holds knowledge, else null.
/proc/death_legacy_record(account)
	var/list/record = account ? death_legacies[account] : null
	if (!islist(record) || !record["kept"] || death_legacy_now() - record["at"] >= DEATH_LEGACY_HOURS)
		return null
	return record

// Called by death() before the dead forget what they knew.
/proc/death_legacy_note(mob/living/human/H, gibbed)
	if (!death_legacy_enabled() || !istype(H) || istype(H, /mob/living/human/corpse))
		return
	var/account = death_legacy_account(H)
	var/turf/T = get_turf(H)
	if (!account || !T)
		return
	var/now = death_legacy_now()
	var/list/before = death_legacies[account]
	var/returns = islist(before) && isnum(before["used"]) && now - before["used"] < DEATH_LEGACY_HOURS ? before["returns"] : 0
	var/list/record = list("at" = now, "weak" = 1, "kept" = 0, "returns" = returns)
	if (islist(before) && isnum(before["used"]))
		record["used"] = before["used"]
	death_legacies[account] = record
	if (gibbed || H.died_by_own_hand)
		to_chat(H, SPAN_WARNING("Nothing of what you knew can be recovered from this death."))
		return
	var/list/cause = player_activity_death_cause(H)
	record["kept"] = 1
	record["x"] = T.x
	record["y"] = T.y
	record["z"] = T.z
	record["cause"] = cause[1]
	record["name"] = "[H.real_name]"
	record["nodes"] = clean_recipe_node_ids(H.known_recipe_nodes)
	record["scholarship"] = clean_scholarship(H.scholarship)
	record["reading"] = clean_study_progress(H.study_progress)
	record["lessons"] = clean_scholar_lessons(H.scholar_lessons)
	record["mastery"] = clean_skill_mastery(H.skill_mastery)
	var/list/skills = list()
	for (var/stat in H.stats)
		var/list/pair = H.stats[stat]
		if (stat != "magic" && islist(pair) && pair.len == 2 && isnum(pair[1]) && isnum(pair[2]))
			skills[stat] = list(pair[1], pair[2])
	record["skills"] = skills
	var/obj/structure/bed/B = region_home_bed(account)
	record["bed"] = B && B.legacy_established(account, now) && death_legacy_near(record, get_turf(B)) ? 1 : 0
	to_chat(H, SPAN_NOTICE("What you knew is not lost yet. For one day, a new character who starts within [DEATH_LEGACY_RANGE] tiles of here, beside your faction's recruitment station[record["bed"] ? " or at your own bed" : " or at a bed you had held for a day"], keeps it, less [death_legacy_loss_text(cause[1], returns)]."))

// TRUE when a character starting on T this way would get the record back.
/proc/death_legacy_reachable(account, turf/T, by_station)
	var/list/record = death_legacy_record(account)
	if (!record || !T || !death_legacy_near(record, T))
		return FALSE
	if (by_station)
		return TRUE
	if (!record["bed"])
		return FALSE
	var/obj/structure/bed/B = region_home_bed(account)
	return B && B.legacy_established(account, record["at"]) && get_dist(T, get_turf(B)) <= 1 && T.z == B.z

// For the lobby's starting place question: what each choice keeps.
/mob/new_player/proc/death_legacy_preview(list/factions, wilds)
	if (!client || !death_legacy_enabled())
		return ""
	var/account = client.ckey
	var/list/record = death_legacy_record(account)
	if (!record)
		return ""
	var/list/keeps = list()
	for (var/faction in factions)
		if (death_legacy_reachable(account, map.faction_start_turf(faction), TRUE))
			keeps += "with [faction]"
	var/obj/structure/bed/B = region_home_bed(account)
	var/bed = region_home_enabled() && B && B.valid_character_bed(null) && death_legacy_reachable(account, get_turf(B), FALSE)
	var/who = "[record["name"]] [death_legacy_cause_text(record["cause"])]"
	var/cost = death_legacy_loss_text(record["cause"], record["returns"])
	var/bed_cost = death_legacy_loss_text(record["cause"], record["returns"] + DEATH_LEGACY_BED_EXTRA)
	var/others = english_list(keeps, "", " or ")
	if (bed && keeps.len)
		return "\n\n[who]. Starting [others] keeps what they knew, less [cost]. Starting at your bed (the choice '[wilds]') keeps it less [bed_cost]."
	if (bed)
		return "\n\n[who]. Starting at your bed (the choice '[wilds]') keeps what they knew, less [bed_cost]."
	if (keeps.len)
		return "\n\n[who]. Starting [others] keeps what they knew, less [cost]. Any other start begins with nothing."
	return "\n\n[who] too far from your faction's station or a bed you had held for a day, so this character starts with nothing they knew."

// Called once a new character stands at its start. Returns TRUE when it took
// the record back.
/proc/death_legacy_return(mob/living/human/H)
	if (!istype(H) || !H.client || IsGuestKey(H.client.key))
		return FALSE
	return death_legacy_apply(H, H.client.ckey)

/proc/death_legacy_apply(mob/living/human/H, account)
	if (!death_legacy_enabled() || !istype(H) || !account)
		return FALSE
	var/list/record = death_legacies[account]
	if (!islist(record))
		return FALSE
	if (record["weak"])
		record["weak"] = 0
		H.death_weakness_left = DEATH_WEAKNESS_SECONDS
		to_chat(H, SPAN_WARNING("You are still shaken by your last death. For [round(DEATH_WEAKNESS_SECONDS / 60)] minutes of play you deal half damage to people. Animals are not affected."))
	var/by_station = H.started_with_faction
	H.started_with_faction = FALSE
	if (!death_legacy_reachable(account, get_turf(H), by_station))
		return FALSE
	// A bed only partly protects: it costs as much as one more return (Val, 2026-11-18),
	// less inside a Town or City of the account's own side (province_ranks.dm).
	var/bed_extra = by_station ? 0 : DEATH_LEGACY_BED_EXTRA * province_rank_bed_extra(account, get_turf(H))
	var/charged = record["returns"] + bed_extra
	var/list/loss = death_legacy_loss(record["cause"], charged)
	var/list/nodes = clean_recipe_node_ids(record["nodes"])
	if (loss[4] > 0)
		nodes.Cut(max(1, nodes.len - loss[4] + 1))
	H.known_recipe_nodes = nodes
	H.recipe_knowledge_initialized = TRUE
	var/list/scholarship = clean_scholarship(record["scholarship"])
	for (var/discipline in scholarship)
		scholarship[discipline] = round(scholarship[discipline] * (1 - loss[2]), 0.01)
	H.scholarship = clean_scholarship(scholarship)
	H.study_progress = clean_study_progress(record["reading"])
	H.scholar_lessons = clean_scholar_lessons(record["lessons"])
	H.skill_mastery = clean_skill_mastery(record["mastery"])
	var/list/skills = record["skills"]
	if (islist(skills))
		for (var/stat in skills)
			var/list/pair = skills[stat]
			if (!(stat in H.stats) || !islist(pair) || pair.len != 2 || !isnum(pair[1]) || !isnum(pair[2]))
				continue
			var/fraction = max(loss[1], (stat in list("crafting", "dexterity")) ? loss[3] : 0)
			var/list/kept = list()
			for (var/value in pair)
				kept += value > STAT_NORMAL ? round(value - (value - STAT_NORMAL) * fraction, 0.01) : value
			H.stats[stat] = kept
	H.refresh_recipe_knowledge_menus()
	to_chat(H, "<big><font color='#3d9e3d'><b>You remember what [record["name"]] knew.</b></font></big>")
	to_chat(H, SPAN_NOTICE("Lost with that death: [death_legacy_loss_text(record["cause"], charged)][by_station ? "" : ", [round(2 ** bed_extra, 0.01)] times for starting at a bed instead of your faction's station"]. Another return within a day costs double."))
	death_legacies[account] = list("at" = record["at"], "weak" = 0, "kept" = 0, "returns" = record["returns"] + 1, "used" = death_legacy_now())
	return TRUE

// ---------- Weakness after a death ----------

// Counts down only while the player is at the keys and awake.
/mob/living/human/proc/handle_death_weakness()
	if (death_weakness_left <= 0)
		return
	var/last = death_weakness_checked
	death_weakness_checked = world.time
	if (!client || inducedSSD || stat == DEAD || !last)
		return
	var/played = min(5, (death_weakness_checked - last) / 10) // seconds; a stalled tick counts five at most
	death_weakness_left = max(0, death_weakness_left - played)
	if (death_weakness_left <= 0)
		to_chat(src, SPAN_NOTICE("You have found your strength again. You deal full damage to people."))

// Multiplier on combat damage this attacker deals to target.
/proc/death_weakness_scale(mob/living/attacker, mob/living/target)
	var/mob/living/human/H = attacker
	if (!istype(H) || H.death_weakness_left <= 0 || !istype(target, /mob/living/human) || target == attacker)
		return 1
	return DEATH_WEAKNESS_SCALE

// ---------- Saved with the world ----------

/proc/death_legacy_clean(list/one)
	if (!islist(one) || !isnum(one["at"]) || one["at"] <= 0)
		return null
	var/list/record = list("at" = round(one["at"]), "weak" = one["weak"] ? 1 : 0, "kept" = one["kept"] ? 1 : 0, "returns" = clamp(round(isnum(one["returns"]) ? one["returns"] : 0), 0, 6))
	if (isnum(one["used"]))
		record["used"] = round(one["used"])
	if (!record["kept"])
		return record
	if (!isnum(one["x"]) || !isnum(one["y"]) || !isnum(one["z"]) || !istext(one["cause"]) || length(one["cause"]) > 20)
		record["kept"] = 0
		return record
	record["x"] = round(one["x"])
	record["y"] = round(one["y"])
	record["z"] = round(one["z"])
	record["cause"] = one["cause"]
	record["name"] = istext(one["name"]) ? sanitize(copytext(one["name"], 1, 65)) : "Your last character"
	record["bed"] = one["bed"] ? 1 : 0
	record["nodes"] = clean_recipe_node_ids(one["nodes"])
	record["scholarship"] = clean_scholarship(one["scholarship"])
	record["reading"] = clean_study_progress(one["reading"])
	record["lessons"] = clean_scholar_lessons(one["lessons"])
	record["mastery"] = clean_skill_mastery(one["mastery"])
	var/list/skills = list()
	if (islist(one["skills"]))
		for (var/stat in one["skills"])
			var/list/pair = one["skills"][stat]
			if (istext(stat) && length(stat) <= 20 && skills.len < 40 && islist(pair) && pair.len == 2 && isnum(pair[1]) && isnum(pair[2]))
				skills[stat] = list(clamp(pair[1], 0, 1000), clamp(pair[2], 0, 1000))
	record["skills"] = skills
	return record

// Drops what is spent: a record past its day keeps only a weakness still
// owed (for a week) and the count of returns (for its own day).
/proc/death_legacy_prune()
	var/now = death_legacy_now()
	for (var/account in death_legacies.Copy())
		var/list/record = death_legacies[account]
		if (!islist(record) || !isnum(record["at"]))
			death_legacies -= account
			continue
		var/age = now - record["at"]
		if (age >= DEATH_LEGACY_HOURS && record["kept"])
			record["kept"] = 0
			record -= list("x", "y", "z", "cause", "name", "bed", "nodes", "scholarship", "reading", "lessons", "mastery", "skills")
		var/used_lately = isnum(record["used"]) && now - record["used"] < DEATH_LEGACY_HOURS
		if (age >= DEATH_LEGACY_HOURS && !used_lately && !(record["weak"] && age < DEATH_LEGACY_WEAK_HOURS))
			death_legacies -= account
	while (death_legacies.len > DEATH_LEGACY_LIMIT)
		death_legacies.Cut(1, 2)

/map_storage/death_legacy_capture()
	death_legacy_prune()
	if (!death_legacies.len)
		return null
	return list("version" = 1, "accounts" = death_legacies.Copy())

// The loaded save's records replace nothing newer: a death since this world
// started (none before the load in practice) wins.
/map_storage/death_legacy_loaded(list/round_state)
	var/list/saved = islist(round_state) ? round_state["death_legacy"] : null
	if (!valid_death_legacy_record(saved))
		return
	var/list/accounts = saved["accounts"]
	for (var/account in accounts)
		if (account in death_legacies)
			continue
		var/list/record = death_legacy_clean(accounts[account])
		if (record)
			death_legacies[account] = record
	death_legacy_prune()

#undef DEATH_LEGACY_RANGE
#undef DEATH_LEGACY_HOURS
#undef DEATH_LEGACY_BED_HOURS
#undef DEATH_LEGACY_BED_EXTRA
#undef DEATH_LEGACY_WEAK_HOURS
#undef DEATH_LEGACY_LIMIT
#undef DEATH_WEAKNESS_SECONDS
#undef DEATH_WEAKNESS_SCALE

/obj/item/projectile/var/tmp/death_weakened = FALSE
