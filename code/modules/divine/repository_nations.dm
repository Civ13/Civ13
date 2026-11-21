// ============================================================
// Nations, staff tools and gods' own characters (Val, 2026-11-19/21).
// Hidden mechanic: keep it out of changelog lines, the wiki and anything an
// ordinary player sees.
// ------------------------------------------------------------
// Nations: ward_draw_nation(group, amount) draws national magic from the
// nation's national repositories first, then from settlement or provincial
// repositories of its members whose makers have lent them to the nation
// (Tend the keepers here > Lend it to the nation).
//
// Staff: Divine Patron > Tend repositories (admin/verbs/divine_repositories.dm) lists every repository in this
// world and sets its charge or tier, wakes a fallen or withdrawn one, makes
// one ordinary or jumps to it. Every change is logged and shown to staff.
//
// Gods playing Nomads worship themselves: staff with a divine name who play a
// character on a Nomads world follow their own god, count as magic users and
// answer their own prayers. Each self-approval is logged and shown to the
// other staff online.
// ============================================================

/obj
	var/magic_repo_nation_share = FALSE // saved: its maker lent it to the nation's magic

// ---------- nations ----------

// Draws up to amount for the nation group ("nation:<id>"). Returns what it got.
/proc/ward_draw_nation(group, amount)
	if (!istext(group) || findtext(group, "nation:") != 1 || !isnum(amount) || amount <= 0)
		return 0
	var/drawn = 0
	for (var/pass in 1 to 2)
		for (var/id in magic_repo_index)
			var/obj/O = magic_repo_find(id)
			if (!O || O.magic_repo_group != group || O.magic_repo_dormant())
				continue
			if (pass == 1 ? O.magic_repo_tier != 5 : (O.magic_repo_tier == 5 || !O.magic_repo_nation_share))
				continue
			var/take = min(amount - drawn, O.magic_repo_charge)
			if (take <= 0)
				continue
			ward_drain(O, take)
			drawn += take
			if (drawn >= amount)
				return drawn
	return drawn

// Tend the keepers here: the maker lends a settlement or provincial repository
// of a nation's member to the nation, or takes it back.
/mob/living/human/proc/magic_repo_nation_option(obj/O)
	if (!O || O.magic_repo_maker != magic_key() || O.magic_repo_tier < 3 || O.magic_repo_tier > 4)
		return null
	if (!istext(O.magic_repo_group) || findtext(O.magic_repo_group, "nation:") != 1)
		return null
	return O.magic_repo_nation_share ? "Stop lending it to the nation" : "Lend it to the nation"

/mob/living/human/proc/magic_repo_nation_toggle(obj/O)
	if (!magic_repo_nation_option(O))
		return
	O.magic_repo_nation_share = !O.magic_repo_nation_share
	to_chat(src, SPAN_NOTICE(O.magic_repo_nation_share ? "You open \the [O] to [province_group_name(O.magic_repo_group)]." : "You close \the [O] to [province_group_name(O.magic_repo_group)]."))
	log_game("[key_name(src)] [O.magic_repo_nation_share ? "lent" : "took back"] repository [O.magic_repo_id] [O.magic_repo_nation_share ? "to" : "from"] [O.magic_repo_group].")

// ---------- gods' own characters ----------

// TRUE for staff with a divine name playing their own follower on a Nomads world.
/mob/living/human/proc/divine_is_own_god()
	if (!map || !map.nomads)
		return FALSE
	var/key = magic_key()
	var/list/entry = divine_identity_of(key)
	return entry && divine_identity_is_staff(key) && divine_book_key(divine_patron) == divine_book_key(entry["name"])

// Login: a god playing a Nomad follows themself and hears their own prayers.
/mob/living/human/proc/divine_self_worship()
	if (!client || !map || !map.nomads)
		return
	var/list/entry = divine_identity_of(client.ckey)
	if (!entry || !divine_identity_is_staff(client.ckey))
		return
	var/key = divine_book_key(entry["name"])
	if (!key)
		return
	if (divine_book_key(divine_patron) != key)
		if (divine_patron)
			divine_known = list()
		divine_patron = entry["name"]
		log_admin("[key_name(src)] now worships their own god, [entry["name"]].")
	if (!islist(divine_known))
		divine_known = list()
	if (!divine_claim_of(client))
		if (!islist(divine_patron_claims[key]))
			divine_patron_claims[key] = list()
		divine_patron_claims[key] |= client.ckey

// divine_grant(): a god answering their own character's prayer.
/proc/divine_note_self_approval(datum/divine_use_request/R, client/C)
	var/mob/living/human/caster = R && R.covenant ? R.covenant.caster : null
	if (!istype(caster) || !C || caster.magic_key() != C.ckey)
		return
	log_admin("[key_name(C)] approved their own character's prayer as [R.covenant.deity_id]: [R.spell_id], [R.scope_key].")
	message_admins("[key_name_admin(C)] approved their own character's prayer as [R.covenant.deity_id]: [divine_invocation_names[R.spell_id]].")
