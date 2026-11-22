// ============================================================
// Repository tiers (Val, 2026-11-19/21). Hidden mechanic: keep it out of
// changelog lines, the wiki and anything an ordinary player sees.
// ------------------------------------------------------------
// A repository grows one tier at a time: personal, shrine, settlement,
// provincial, national. Each step is a rite the god must Grant (Beseech,
// with the repository in hand or beside the keeper): the repository must have
// stayed three quarters full for some days, the keeper needs the skill, and
// enough magic users tied to it must stand with them. After the Grant its
// keepers channel into it (Channel) for hours, paid from stored charge.
//
// The object's form caps the tier: a trinket stays personal, home art can be
// a shrine, large furniture a settlement (a great desk or throne provincial)
// and only a statue national. To grow past its form, the keepers move it
// into something greater with another rite; the charge moves with it and the
// old thing is ordinary again. A keeper whose skill has grown can re-attune a
// repository to it at the cost of an upgrade at its tier.
//
// Neglect: below a tenth for a week drops a tier; a personal repository empty
// for a month is ordinary again. Settlement and greater repositories belong to
// the seat that held them: if the hall goes or the province changes hands, the
// repository goes still until a keeper of the captor's god consecrates it anew,
// keeping the charge.
//
// Every number lives in config/magic_law_balance.json (magic_balance()).
// Altars, offerings and registered helpers come with the magic materials plan;
// until then a rite counts the tied magic users standing with the keeper.
// ============================================================

#define MAGIC_TIER_DAY 864000          // deciseconds of real time in a day
#define MAGIC_TIER_SITTING 600         // deciseconds per channelling step
#define MAGIC_TIER_SEAT_RECHECK 600    // deciseconds between seat checks on one repository

/obj
	var/magic_repo_full_since = 0     // saved: realtime it last rose to the upgrade threshold, 0 below it
	var/magic_repo_low_since = 0      // saved: realtime it last fell below the neglect line, 0 above it
	var/magic_repo_empty_since = 0    // saved: realtime it last ran empty, 0 while it holds charge
	var/magic_repo_rite = null        // saved: "strengthen" or "attune" while a granted rite is channelled
	var/magic_repo_rite_skill = 0     // saved: the skill the rite settles at
	var/magic_repo_faction = null     // saved: the faction whose seat it belongs to (tier 3 and up)
	var/magic_repo_group = null       // saved: that faction's province group (tier 4 and up)
	var/magic_repo_captured = FALSE   // saved: its seat fell; still until consecrated anew
	var/tmp/magic_repo_seat_checked = 0

/mob/living/human
	var/tmp/magic_rite_repo = null    // id of the repository a rite is asked for
	var/tmp/obj/magic_rite_dest = null // what a move rite pours it into

// Rites the "repository" grant brings, never taught on their own. Their
// names are in divine_invocation_names (covenant.dm).
var/global/list/magic_repo_rites = list("repository_strengthen", "repository_attune", "repository_move", "repository_consecrate")

// ---------- balance ----------

var/global/list/magic_balance_cache = null

/proc/magic_balance(key)
	if (!islist(magic_balance_cache))
		magic_balance_cache = list()
		if (fexists("config/magic_law_balance.json"))
			try
				var/list/L = json_decode(file2text("config/magic_law_balance.json"))
				if (islist(L))
					magic_balance_cache = L
			catch(var/exception/e)
				log_debug("magic_law_balance.json ignored: [e]")
	return magic_balance_cache[key]

/proc/magic_balance_num(key, fallback)
	var/v = magic_balance(key)
	return isnum(v) ? v : fallback

/proc/magic_tier_value(tier, field, fallback = 0)
	var/list/tiers = magic_balance("tiers")
	if (!islist(tiers) || !isnum(tier) || tier < 1 || tier > tiers.len)
		return fallback
	var/list/row = tiers[tier]
	if (!islist(row) || isnull(row[field]))
		return fallback
	return row[field]

/proc/magic_tier_count()
	var/list/tiers = magic_balance("tiers")
	return islist(tiers) ? min(5, tiers.len) : 1

/proc/magic_neglect_value(field, fallback)
	var/list/N = magic_balance("neglect")
	return islist(N) && isnum(N[field]) ? N[field] : fallback

// The value of the most specific path in a [[path, value], ...] table that O is.
/proc/magic_balance_path_value(table, obj/O)
	var/list/rows = magic_balance(table)
	if (!islist(rows) || !O)
		return null
	var/best = null
	var/best_len = 0
	for (var/list/row in rows)
		if (row.len < 2 || !istext(row[1]))
			continue
		var/path = text2path(row[1])
		if (path && istype(O, path) && length(row[1]) > best_len)
			best = row[2]
			best_len = length(row[1])
	return best

// ---------- forms and capacity ----------

// The highest tier this object's form can hold.
/proc/magic_repo_form_ceiling(obj/O)
	if (!istype(O))
		return 0
	var/tier = magic_balance_path_value("forms", O)
	if (isnum(tier))
		return clamp(tier, 1, 5)
	var/obj/item/I = O
	if (istype(I) && I.w_class <= ITEM_SIZE_SMALL)
		return 1
	return 0

/proc/magic_repo_capacity_for(obj/O, tier, skill)
	var/ceiling = magic_tier_value(tier, "ceiling", tier == 1 ? 100 : 0)
	return max(1, round(ceiling * magic_repo_size_factor(O) * max(0.05, skill / 100)))

/proc/magic_repo_tier_name(tier)
	var/name = magic_tier_value(tier, "name", null)
	return istext(name) ? name : "personal"

/obj/proc/magic_repo_set_tier(tier)
	magic_repo_tier = clamp(tier, 1, 5)
	magic_repo_capacity = magic_repo_capacity_for(src, magic_repo_tier, magic_repo_skill)
	magic_repo_charge = min(magic_repo_charge, magic_repo_capacity)
	if (magic_repo_tier < 3)
		magic_repo_faction = null
		magic_repo_group = null
		magic_repo_captured = FALSE

// Back to an ordinary object. Its keepers' lists forget it once the world has loaded.
/obj/proc/magic_repo_unmake(reason)
	if (!magic_repo_id)
		return
	log_game("Repository [magic_repo_id] ([type]) became ordinary again: [reason].")
	magic_repo_index -= magic_repo_id
	for (var/v in vars)
		if (findtext(v, "magic_repo_") == 1 && v != "magic_repo_seat_checked")
			vars[v] = initial(vars[v])

// ---------- neglect and seats ----------

// Lazy upkeep: called whenever a repository is used or looked at.
/obj/proc/magic_repo_tick()
	if (!magic_repo_finished())
		return
	if (map && map.persistence && !persistence_player_restore_ready)
		return
	magic_repo_check_seat()
	magic_repo_check_keepers() // repository_upkeep.dm
	magic_repo_check_home()
	if (magic_repo_dormant())
		// Still repositories neither grow nor wither; the clocks start again on waking.
		magic_repo_full_since = 0
		magic_repo_low_since = 0
		magic_repo_empty_since = 0
		return
	var/now = world.realtime
	var/full = magic_repo_charge >= magic_repo_capacity * magic_balance_num("full_fraction", 0.75)
	if (!full)
		magic_repo_full_since = 0
	else if (!magic_repo_full_since)
		magic_repo_full_since = now
	var/low_period = magic_neglect_value("low_days", 7) * MAGIC_TIER_DAY
	var/low_line = magic_neglect_value("low_fraction", 0.1)
	if (magic_repo_charge >= magic_repo_capacity * low_line)
		magic_repo_low_since = 0
	else if (!magic_repo_low_since)
		magic_repo_low_since = now
	else
		while (magic_repo_tier > 1 && low_period > 0 && now - magic_repo_low_since >= low_period)
			magic_repo_set_tier(magic_repo_tier - 1)
			magic_repo_full_since = 0
			log_game("Repository [magic_repo_id] shrank to tier [magic_repo_tier] from neglect.")
			if (magic_repo_charge >= magic_repo_capacity * low_line)
				magic_repo_low_since = 0
				break
			magic_repo_low_since += low_period
	if (magic_repo_charge > 0)
		magic_repo_empty_since = 0
	else if (!magic_repo_empty_since)
		magic_repo_empty_since = now
	else if (magic_repo_tier == 1 && now - magic_repo_empty_since >= magic_neglect_value("empty_days", 30) * MAGIC_TIER_DAY)
		magic_repo_unmake("empty for too long")

// Why a repository of this tier can't belong to this faction's seat at T, or null.
/proc/magic_repo_seat_problem(turf/T, tier, faction, group)
	if (tier < 3)
		return null
	if (!T || !map)
		return "It must stand fixed in place."
	if (!istext(faction) || faction == "none")
		return "You must belong to a faction."
	if (tier == 3)
		return province_near_faction_seat(faction, T) ? null : "It must stand by a hall of [faction], or on its land."
	var/datum/province_map/P = map ? map.province_map() : null
	var/c = P ? P.char_at(T.x, T.y) : null
	if (!c)
		return "It must stand in a province."
	if (!group || province_holder_of(c) != group)
		return "[province_group_name(group)] does not hold this province."
	if (tier == 5 && findtext(group, "nation:") != 1)
		return "Only a nation can keep one so great."
	var/obj/structure/faction_hall/seat = province_seat(c, group)
	if (!seat || get_dist(seat, T) > magic_balance_num("seat_range", 40))
		return "It must stand near the seat of this province."
	return null

// A settlement or greater repository goes still once its seat is lost.
/obj/proc/magic_repo_check_seat()
	if (magic_repo_tier < 3 || magic_repo_captured || !magic_repo_faction)
		return
	if (world.time < magic_repo_seat_checked + MAGIC_TIER_SEAT_RECHECK && magic_repo_seat_checked)
		return
	magic_repo_seat_checked = world.time
	var/turf/T = isturf(loc) ? loc : null
	var/lost = !T
	if (T)
		if (magic_repo_tier == 3)
			lost = !province_near_faction_seat(magic_repo_faction, T)
		else
			var/datum/province_map/P = map ? map.province_map() : null
			var/c = P ? P.char_at(T.x, T.y) : null
			lost = !c || province_holder_of(c) != magic_repo_group
	if (lost)
		magic_repo_captured = TRUE
		magic_repo_rite = null
		magic_repo_progress = 0
		log_game("Repository [magic_repo_id] (tier [magic_repo_tier]) lost its seat and went still.")

// ---------- rites ----------

/proc/magic_repo_rite_spell(spell)
	return istext(spell) && (spell in magic_repo_rites)

// Prayers this character may ask for: those taught, plus the rites the grant brings.
/mob/living/human/proc/divine_spells_allowed()
	. = islist(divine_known) ? divine_known.Copy() : list()
	if ("repository" in .)
		for (var/rite in magic_repo_rites)
			. |= rite

/mob/living/human/proc/magic_repo_reachable(obj/O)
	if (!O || QDELETED(O))
		return FALSE
	return (O in GetAllContents(4)) || O.Adjacent(src)

// Magic users of the repository's god standing with this one: conscious,
// played, tied to it (unless tied is FALSE) and verified when asked.
/mob/living/human/proc/magic_repo_vigil(obj/O, verified = FALSE, tied = TRUE)
	. = list()
	var/turf/T = get_turf(src)
	if (!T || !O)
		return
	for (var/mob/living/human/H in range(magic_balance_num("rite_range", 3), T))
		if (H.stat != CONSCIOUS || !H.client || !H.magic_is_magic_user())
			continue
		if (divine_book_key(H.divine_patron) != divine_book_key(divine_patron))
			continue
		if (tied && !(islist(O.magic_repo_registrants) && (H.magic_key() in O.magic_repo_registrants)))
			continue
		if (verified && !account_verified(H.magic_key()))
			continue
		. += H

// Somebody standing in the rite who may speak for the seat's faction or nation.
/proc/magic_repo_consent(list/vigil, tier, faction, group)
	if (tier < 4)
		return TRUE
	if (tier == 4)
		for (var/mob/living/human/H in vigil)
			if (map && map.is_faction_leader(H, faction))
				return TRUE
		return FALSE
	var/nid = findtext(group, "nation:") == 1 ? copytext(group, 8) : null
	if (!nid)
		return FALSE
	var/list/G = nation_government_of(nid)
	for (var/mob/living/human/H in vigil)
		if (H.nation_rules(nid))
			return TRUE
		if (!G["personal"] && map && map.is_faction_leader(H, H.civilization) && nation_of_id(nation_faction_id(H.civilization)) == nid)
			return TRUE
	return FALSE

/mob/living/human/proc/magic_repo_vigil_problem(obj/O, tier, tied = TRUE)
	var/need = magic_tier_value(tier, "vigil", 1)
	var/verified = magic_tier_value(tier, "verified", FALSE)
	var/list/vigil = magic_repo_vigil(O, verified, tied)
	if (vigil.len < need)
		return "It takes [need] of you[tied ? " tied to it" : ""] standing together[verified ? ", each with a verified Discord account" : ""]. You have [vigil.len]."
	return null

// Why this keeper can't strengthen O now, or null.
/mob/living/human/proc/magic_repo_upgrade_problem(obj/O)
	var/tier = O.magic_repo_tier + 1
	if (O.magic_repo_rite)
		return "Something is already being poured into it."
	if (tier > magic_tier_count())
		return "It cannot grow any further."
	if (magic_repo_form_ceiling(O) < tier)
		return "It is too small a thing to hold more. Move it into something greater first."
	if (magic_skill() < magic_tier_value(tier, "skill", 100))
		return "You are not yet skilled enough to strengthen it."
	var/days = magic_tier_value(tier, "full_days", 0)
	if (days > 0 && (!O.magic_repo_full_since || world.realtime - O.magic_repo_full_since < days * MAGIC_TIER_DAY))
		return "It must stay at least [round(100 * magic_balance_num("full_fraction", 0.75))]% full for [days] days first."
	if (tier >= 3 && !(O.anchored && isturf(O.loc)))
		return "It must stand fixed in place."
	. = magic_repo_vigil_problem(O, tier)
	if (.)
		return
	var/group = province_group_of(civilization)
	. = magic_repo_seat_problem(get_turf(O), tier, civilization, group)
	if (.)
		return
	if (!magic_repo_consent(magic_repo_vigil(O), tier, civilization, group))
		return tier == 4 ? "The leader of [civilization] must stand with you." : "One who speaks for your nation must stand with you."
	return null

/mob/living/human/proc/magic_repo_attune_problem(obj/O)
	if (O.magic_repo_rite)
		return "Something is already being poured into it."
	if (magic_skill() <= O.magic_repo_skill)
		return "It already holds all the skill you have."
	return magic_repo_vigil_problem(O, O.magic_repo_tier)

/mob/living/human/proc/magic_repo_move_problem(obj/O, obj/D)
	if (O.magic_repo_rite)
		return "Something is already being poured into it."
	if (!D || QDELETED(D) || D.magic_repo_id || !magic_repo_reachable(D))
		return "The greater thing must be in your hand or beside you."
	if (magic_repo_form_ceiling(D) <= magic_repo_form_ceiling(O))
		return "That can hold no more than it does now."
	if (O.magic_repo_tier >= 3 && !(D.anchored && isturf(D.loc)))
		return "The greater thing must stand fixed in place."
	. = magic_repo_vigil_problem(O, min(magic_tier_count(), O.magic_repo_tier + 1))
	if (.)
		return
	return magic_repo_seat_problem(get_turf(D), O.magic_repo_tier, O.magic_repo_faction, O.magic_repo_group)

/mob/living/human/proc/magic_repo_consecrate_problem(obj/O)
	if (!O.magic_repo_captured)
		return "It is not fallen."
	if (magic_repos_kept().len >= magic_repo_allowance())
		return "You can't keep another one yet."
	if (magic_skill() < magic_tier_value(O.magic_repo_tier, "skill", 100))
		return "You are not yet skilled enough to take it up."
	var/group = province_group_of(civilization)
	. = magic_repo_seat_problem(get_turf(O), O.magic_repo_tier, civilization, group)
	if (.)
		return
	. = magic_repo_vigil_problem(O, O.magic_repo_tier, FALSE)
	if (.)
		return
	if (!magic_repo_consent(magic_repo_vigil(O, FALSE, FALSE), O.magic_repo_tier, civilization, group))
		return O.magic_repo_tier == 4 ? "The leader of [civilization] must stand with you." : "One who speaks for your nation must stand with you."
	return null

// divine_problem(): why this rite can't be asked for now, or null.
/mob/living/human/proc/magic_repo_rite_problem(spell)
	if (!magic_has_grant())
		return "You don't know that prayer."
	var/obj/O = magic_repo_find(magic_rite_repo)
	if (!O || !magic_repo_reachable(O) || !O.magic_repo_finished())
		return "Hold it, or stand beside it."
	O.magic_repo_tick()
	if (QDELETED(O) || !O.magic_repo_id)
		return "It is ordinary now."
	if (spell == "repository_consecrate")
		return magic_repo_consecrate_problem(O)
	if (!O.magic_repo_is_keeper(src))
		return "You do not keep it."
	if (O.magic_repo_dormant())
		return "It is cold and still."
	switch (spell)
		if ("repository_strengthen")
			return magic_repo_upgrade_problem(O)
		if ("repository_attune")
			return magic_repo_attune_problem(O)
		if ("repository_move")
			return magic_repo_move_problem(O, magic_rite_dest)
	return "You don't know that prayer."

// Beseech: picks the repository (and for a move, the greater thing) the rite is for.
/mob/living/human/proc/magic_repo_rite_choose(spell)
	magic_rite_repo = null
	magic_rite_dest = null
	var/list/candidates = list()
	var/list/near = GetAllContents(4) | orange(1, src)
	for (var/obj/O in near)
		if (!O.magic_repo_finished())
			continue
		if (spell == "repository_consecrate" ? O.magic_repo_captured : O.magic_repo_is_keeper(src))
			candidates["[O.name] ([O.magic_repo_id])"] = O.magic_repo_id
	if (!candidates.len)
		to_chat(src, SPAN_WARNING(spell == "repository_consecrate" ? "There is nothing fallen here to take up." : "Hold one you keep, or stand beside it."))
		return FALSE
	var/id = candidates.len == 1 ? candidates[candidates[1]] : candidates[player_input(src, "Which one?", "Beseech", null, "anything", candidates, TRUE)]
	if (!id)
		return FALSE
	magic_rite_repo = id
	if (spell != "repository_move")
		return TRUE
	var/obj/from = magic_repo_find(id)
	var/list/dests = list()
	for (var/obj/D in near)
		if (D != from && !D.magic_repo_id && magic_repo_form_ceiling(D) > magic_repo_form_ceiling(from))
			dests["[D.name]"] = D
	if (!dests.len)
		to_chat(src, SPAN_WARNING("Hold or stand beside something greater to move it into."))
		return FALSE
	magic_rite_dest = dests.len == 1 ? dests[dests[1]] : dests[player_input(src, "Move it into?", "Beseech", null, "anything", dests, TRUE)]
	return !!magic_rite_dest

// divine_dispatch(): the god granted the rite.
/mob/living/human/proc/magic_repo_rite_granted(spell)
	var/obj/O = magic_repo_find(magic_rite_repo)
	if (!O)
		return FALSE
	switch (spell)
		if ("repository_strengthen")
			O.magic_repo_rite = "strengthen"
			O.magic_repo_rite_skill = magic_skill()
			O.magic_repo_progress = 0
			if (O.magic_repo_tier + 1 >= 3)
				O.magic_repo_faction = civilization
				O.magic_repo_group = province_group_of(civilization)
			to_chat(src, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("Your god is willing. Now you and its keepers must pour yourselves into \the [O].")))
		if ("repository_attune")
			O.magic_repo_rite = "attune"
			O.magic_repo_rite_skill = magic_skill()
			O.magic_repo_progress = 0
			to_chat(src, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("Your god is willing. Pour yourself into \the [O] to make it answer to you as you are now.")))
		if ("repository_move")
			var/obj/D = magic_rite_dest
			if (!D || QDELETED(D) || D.magic_repo_id)
				return FALSE
			for (var/v in O.vars)
				if (findtext(v, "magic_repo_") == 1 && v != "magic_repo_seat_checked")
					D.vars[v] = O.vars[v]
					O.vars[v] = initial(O.vars[v])
			magic_repo_index[D.magic_repo_id] = D
			D.magic_repo_capacity = magic_repo_capacity_for(D, D.magic_repo_tier, D.magic_repo_skill)
			D.magic_repo_charge = min(D.magic_repo_charge, D.magic_repo_capacity)
			D.magic_repo_full_since = 0
			D.magic_repo_home = null // a shrine belongs where it now stands (repository_upkeep.dm)
			D.magic_repo_astray = FALSE
			to_chat(src, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("What \the [O] held pours into \the [D]. \The [O] is only \a [O] again.")))
			log_game("[key_name(src)] moved repository [D.magic_repo_id] from [O.type] into [D.type].")
		if ("repository_consecrate")
			var/old_deity = O.magic_repo_deity
			O.magic_repo_deity = divine_book_key(divine_patron)
			O.magic_repo_maker = magic_key()
			O.magic_repo_keepers = list(magic_key())
			O.magic_repo_registrants = list(magic_key())
			O.magic_repo_barred = null
			O.magic_repo_withdrawn = FALSE
			if (old_deity != O.magic_repo_deity)
				O.magic_repo_targets = null
			O.magic_repo_faction = civilization
			O.magic_repo_group = province_group_of(civilization)
			O.magic_repo_captured = FALSE
			O.magic_repo_seat_checked = 0
			O.magic_repo_full_since = 0
			if (!islist(magic_kept_repos))
				magic_kept_repos = list()
			magic_kept_repos |= O.magic_repo_id
			if (!islist(magic_registered_repos))
				magic_registered_repos = list()
			magic_registered_repos |= O.magic_repo_id
			to_chat(src, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("\The [O] wakes under your hands. It is yours to keep now.")))
			log_game("[key_name(src)] consecrated fallen repository [O.magic_repo_id] (tier [O.magic_repo_tier]) from [old_deity] to [O.magic_repo_deity].")
	magic_rite_repo = null
	magic_rite_dest = null
	return TRUE

// A repository this keeper is channelling a granted rite into.
/mob/living/human/proc/magic_repo_rite_at_hand()
	for (var/id in magic_registered_repos)
		var/obj/O = magic_repo_find(id)
		if (O && O.magic_repo_rite && O.magic_repo_is_keeper(src) && magic_repo_reachable(O))
			return O
	return null

/proc/magic_repo_rite_time(obj/O)
	var/tier = O.magic_repo_rite == "strengthen" ? O.magic_repo_tier + 1 : O.magic_repo_tier
	return max(MAGIC_TIER_SITTING, magic_tier_value(tier, "channel_minutes", 30) * MAGIC_TIER_SITTING)

/proc/magic_repo_rite_seed(obj/O)
	var/tier = O.magic_repo_rite == "strengthen" ? O.magic_repo_tier + 1 : O.magic_repo_tier
	return magic_tier_value(tier, "seed", 10)

// Channel (repository.dm) for a granted rite: any keeper may take a turn, the
// progress stays on the repository, and every sitting draws its share of the
// seed from the repository itself or another one the keeper holds.
/mob/living/human/proc/magic_channel_rite(obj/O)
	magic_channelling = TRUE
	to_chat(src, SPAN_NOTICE("You close your eyes and pour yourself into \the [O]."))
	var/total = magic_repo_rite_time(O)
	var/per_sitting = magic_repo_rite_seed(O) * MAGIC_TIER_SITTING / total
	while (O && !QDELETED(O) && O.magic_repo_rite && O.magic_repo_is_keeper(src))
		if (!magic_has_grant() || !magic_repo_reachable(O) || O.magic_repo_dormant())
			break
		if (!do_after(src, MAGIC_TIER_SITTING, O, needhand = TRUE))
			break
		if (QDELETED(O) || !O.magic_repo_rite || !magic_repo_reachable(O))
			break
		var/obj/source = O.magic_repo_charge >= per_sitting ? O : magic_repo_seed_source(O, per_sitting)
		if (!source)
			to_chat(src, SPAN_WARNING("There is not enough stored to draw on."))
			break
		source.magic_repo_charge = max(0, source.magic_repo_charge - per_sitting)
		divine_drain(src, 0.02)
		O.magic_repo_progress += MAGIC_TIER_SITTING
		adaptStat("magic", 1, "repository_rite")
		if (O.magic_repo_progress >= total)
			magic_repo_rite_finish(O)
			break
	magic_channelling = FALSE

/mob/living/human/proc/magic_repo_rite_finish(obj/O)
	O.magic_repo_skill = max(O.magic_repo_skill, O.magic_repo_rite_skill)
	if (O.magic_repo_rite == "strengthen")
		O.magic_repo_set_tier(O.magic_repo_tier + 1)
		to_chat(src, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("\The [O] swells and settles. It could hold far more now.")))
	else
		O.magic_repo_set_tier(O.magic_repo_tier)
		to_chat(src, CHAT_TYPED(CHAT_PRAYER, SPAN_NOTICE("\The [O] settles, answering to all you have learned.")))
	log_game("[key_name(src)] finished a [O.magic_repo_rite] rite on repository [O.magic_repo_id]: tier [O.magic_repo_tier], capacity [O.magic_repo_capacity].")
	adaptStat("magic", 5, "repository_rite_done")
	O.magic_repo_rite = null
	O.magic_repo_rite_skill = 0
	O.magic_repo_progress = 0
	O.magic_repo_full_since = 0

// ---------- keepers ----------

// Ready a tie > "Tend the keepers here": its maker names or turns away keepers
// among those standing by; any keeper can turn a tied follower away for good.
/mob/living/human/proc/magic_repo_keeper_menu(obj/O)
	if (!O || !O.magic_repo_is_keeper(src))
		return
	var/maker = O.magic_repo_maker == magic_key()
	var/list/options = list()
	var/list/present = list()
	for (var/mob/living/human/H in range(magic_balance_num("rite_range", 3), get_turf(src)))
		if (H != src && H.client && islist(O.magic_repo_registrants) && (H.magic_key() in O.magic_repo_registrants))
			present[H.name] = H
	if (maker && present.len)
		options += "Name a keeper"
		options += "Turn a keeper away"
	if (present.len)
		options += "Turn someone away from it for good"
	if (!maker)
		options += "Stop keeping it"
	var/nation = magic_repo_nation_option(O) // repository_nations.dm
	if (nation)
		options += nation
	if (!options.len)
		to_chat(src, SPAN_NOTICE("No one tied to it stands with you."))
		return
	var/pick = player_input(src, "What do you do?", "Keepers", null, "anything", options, TRUE)
	if (!pick || !O.magic_repo_is_keeper(src) || !magic_repo_reachable(O))
		return
	if (pick == nation)
		magic_repo_nation_toggle(O)
		return
	if (pick == "Stop keeping it")
		O.magic_repo_keepers -= magic_key()
		to_chat(src, SPAN_NOTICE("You set it down in your heart. It is no longer yours to keep."))
		return
	var/mob/living/human/H = present[player_input(src, "Who?", "Keepers", null, "anything", present, TRUE)]
	if (!H || QDELETED(H) || get_dist(H, src) > magic_balance_num("rite_range", 3))
		return
	var/key = H.magic_key()
	switch (pick)
		if ("Name a keeper")
			O.magic_repo_keepers |= key
			to_chat(src, SPAN_NOTICE("You open \the [O] to [H.name]."))
			to_chat(H, SPAN_NOTICE("You feel \the [O] open to you, as if it were your own."))
		if ("Turn a keeper away")
			if (key == O.magic_repo_maker)
				return
			O.magic_repo_keepers -= key
			to_chat(src, SPAN_NOTICE("You close \the [O] to [H.name]."))
		if ("Turn someone away from it for good")
			if (key == O.magic_repo_maker || (!maker && (key in O.magic_repo_keepers)))
				return
			O.magic_repo_keepers -= key
			O.magic_repo_registrants -= key
			if (!islist(O.magic_repo_barred))
				O.magic_repo_barred = list()
			O.magic_repo_barred |= key
			H.magic_registered_repos -= O.magic_repo_id
			to_chat(src, SPAN_NOTICE("You cut [H.name]'s thread to \the [O]."))
	log_game("[key_name(src)] at repository [O.magic_repo_id]: [pick] [key_name(H)].")

// What a keeper learns of its tier and any rite under way (magic_repo_examine()).
/obj/proc/magic_repo_tier_examine(mob/living/human/user)
	var/text = "It is a [magic_repo_tier_name(magic_repo_tier)] repository."
	if (magic_repo_form_ceiling(src) <= magic_repo_tier && magic_repo_tier < magic_tier_count())
		text += " It cannot grow any further in this shape."
	if (magic_repo_rite)
		text += " About [round(100 * magic_repo_progress / magic_repo_rite_time(src))]% of the rite is poured in."
	to_chat(user, SPAN_NOTICE(text))

#undef MAGIC_TIER_DAY
#undef MAGIC_TIER_SITTING
#undef MAGIC_TIER_SEAT_RECHECK
