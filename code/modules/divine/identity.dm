// ============================================================
// Divine stand-in names for staff (#5142). Hidden mechanic: keep it out of
// changelog lines, the wiki and the public Crafting Atlas.
// ------------------------------------------------------------
// Each admin sets the name and title they appear as when playing a god, such
// as "Valithor, The Weaver". Players pick their god from this list when they
// pray instead of typing a name, and staff speak as their own stand-in name.
// The list only offers ckeys that still hold admin rights, online or not, so
// it never shows who is on right now.
//
// Saved in its own small file next to the world's other data, so a name
// survives restarts and world wipes.
// ============================================================

#define DIVINE_IDENTITY_FILE "data/divine_identities.json"
#define DIVINE_NAME_MAX 40
#define DIVINE_TITLE_MAX 60

// ckey -> list("name" = text, "title" = text). Loaded on first use.
var/global/list/divine_identities = null

/proc/divine_identities_load()
	if (islist(divine_identities))
		return divine_identities
	divine_identities = list()
	if (!fexists(DIVINE_IDENTITY_FILE))
		return divine_identities
	var/list/raw = null
	try
		raw = json_decode(file2text(DIVINE_IDENTITY_FILE))
	catch
		raw = null
	if (!islist(raw))
		return divine_identities
	for (var/who in raw)
		var/list/entry = raw[who]
		if (!istext(who) || !islist(entry))
			continue
		var/name = divine_clean_name(entry["name"], DIVINE_NAME_MAX)
		if (!name)
			continue
		divine_identities[ckey(who)] = list("name" = name, "title" = divine_clean_name(entry["title"], DIVINE_TITLE_MAX))
	return divine_identities

/proc/divine_identities_save()
	var/list/L = divine_identities_load()
	if (fexists(DIVINE_IDENTITY_FILE))
		fdel(DIVINE_IDENTITY_FILE)
	return text2file(json_encode(L), DIVINE_IDENTITY_FILE)

/proc/divine_clean_name(text, max_length)
	if (!istext(text))
		return null
	text = trim(sanitize(text, max_length))
	return length(text) ? text : null

/proc/divine_identity_of(who)
	if (!istext(who))
		return null
	var/list/L = divine_identities_load()
	var/list/entry = L[ckey(who)]
	return islist(entry) ? entry : null

// "Name, Title", or just the name when no title is set.
/proc/divine_identity_label(list/entry)
	if (!islist(entry) || !entry["name"])
		return null
	return entry["title"] ? "[entry["name"]], [entry["title"]]" : entry["name"]

/proc/divine_set_identity(who, name, title)
	name = divine_clean_name(name, DIVINE_NAME_MAX)
	if (!istext(who) || !name)
		return FALSE
	var/list/L = divine_identities_load()
	L[ckey(who)] = list("name" = name, "title" = divine_clean_name(title, DIVINE_TITLE_MAX))
	return divine_identities_save()

/proc/divine_clear_identity(who)
	var/list/L = divine_identities_load()
	if (!istext(who) || !(ckey(who) in L))
		return FALSE
	L -= ckey(who)
	return divine_identities_save()

/proc/divine_identity_is_staff(who)
	var/datum/admins/D = admin_datums[who]
	return D && (D.rights & R_ADMIN)

// label -> deity name, one row per god, for players to pick from. Two admins
// sharing a name share one row (the first title found is shown).
/proc/divine_god_choices()
	. = list()
	var/list/seen = list()
	var/list/L = divine_identities_load()
	for (var/who in L)
		if (!divine_identity_is_staff(who))
			continue
		var/list/entry = L[who]
		var/key = divine_book_key(entry["name"])
		if (!key || (key in seen))
			continue
		seen += key
		.[divine_identity_label(entry)] = entry["name"]
	. = sortList(.)

// The full "Name, Title" shown for a deity name, or the name itself.
/proc/divine_label_for(deity)
	var/key = divine_book_key(deity)
	if (!key)
		return deity
	var/list/L = divine_identities_load()
	for (var/who in L)
		var/list/entry = L[who]
		if (divine_book_key(entry["name"]) == key && divine_identity_is_staff(who))
			return divine_identity_label(entry)
	return deity

// Online staff who play this god, whether or not they are speaking as it now.
/proc/divine_staff_for(deity)
	. = list()
	var/key = divine_book_key(deity)
	if (!key)
		return
	var/list/L = divine_identities_load()
	for (var/who in L)
		var/list/entry = L[who]
		if (divine_book_key(entry["name"]) != key)
			continue
		var/client/C = directory[who]
		if (C && C.holder && (C.holder.rights & R_ADMIN))
			. += C

// Asks an admin for their stand-in name and title. Returns the saved entry.
/client/proc/divine_edit_identity()
	var/list/current = divine_identity_of(ckey)
	var/name = player_input(src, "Your god's name, as players see it when they pray (for example Valithor).", "Divine Name", current ? current["name"] : null, "text", null, TRUE)
	name = divine_clean_name(name, DIVINE_NAME_MAX)
	if (!name || !check_rights(R_ADMIN))
		return null
	var/title = player_input(src, "Your god's title, shown after the name (for example The Weaver). Leave empty for none.", "Divine Name", current ? current["title"] : null, "text", null, TRUE)
	if (!check_rights(R_ADMIN))
		return null
	var/claim = divine_claim_of(src)
	if (claim && claim != divine_book_key(name))
		to_chat(src, SPAN_WARNING("Stop speaking as [claim] before you change your god's name."))
		return null
	var/old_name = current ? current["name"] : null
	if (!divine_set_identity(ckey, name, title))
		to_chat(src, SPAN_WARNING("Your divine name could not be saved."))
		return null
	var/list/entry = divine_identity_of(ckey)
	if (old_name && divine_book_key(old_name) != divine_book_key(name))
		divine_rename_deity(old_name, name)
	to_chat(src, SPAN_NOTICE("Players now see you as [divine_identity_label(entry)] when they pray."))
	log_admin("[key_name(src)] set their divine name to [divine_identity_label(entry)].")
	return entry

// A god's new name carries its followers and original book in this world with
// it, unless another admin still plays the old name.
/proc/divine_rename_deity(old_name, new_name)
	var/old_key = divine_book_key(old_name)
	var/list/L = divine_identities_load()
	for (var/who in L)
		var/list/entry = L[who]
		if (divine_book_key(entry["name"]) == old_key)
			return 0
	. = 0
	for (var/mob/living/human/H in human_mob_list)
		if (!QDELETED(H) && divine_book_key(H.divine_patron) == old_key)
			H.divine_patron = new_name
			.++
	for (var/obj/item/weapon/book/divine/B in divine_book_originals)
		if (!QDELETED(B) && divine_book_key(B.divine_deity) == old_key)
			B.divine_deity = new_name

#undef DIVINE_NAME_MAX
#undef DIVINE_TITLE_MAX
