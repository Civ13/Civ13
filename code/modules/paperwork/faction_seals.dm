// Faction seals (docs/faction-seals.md). A seal matrix is a carved stamp. A
// faction leader cuts a blank one for their faction and names the office it
// speaks for ("Leader", "Treasurer", ...). Every impression it leaves records
// the faction, the office, the seal's number and the date on the paper, so a
// reader can later check the seal against the faction's register.
//
// The register lives in map.faction_recruitment["seals"] (durable, keyed by
// faction name, renamed with it):
//   faction -> list(serial text -> list(office, cut time, revoked tick or 0,
//                                        revoked time or 0))
// Times are world.realtime, for display only: BYOND numbers are 32-bit, so a
// realtime is only good to about a minute. Order is kept by a seal clock (an
// exact counter in map.faction_recruitment["seal_clock"]) that ticks on every
// impression and revocation.
// A lost or stolen seal can be revoked by the leader. Papers it sealed before
// the revocation stay good; anything it seals afterwards checks as void. An
// impression with no record (a printed copy, or a look-alike stamp) checks as
// unproven. The game never enforces what a sealed paper says: players do.
//
// Check Seals also lists readable signature text recorded by pens. A signature
// is a visible mark, not proof of the writer's identity.
//
// Nothing here sleeps except the prompts in attack_self, which recheck after.

#define FACTION_SEAL_OFFICE_MAX 32
#define FACTION_SEALS_PER_FACTION 24
#define FACTION_SEAL_RECORDS_MAX 12

var/global/list/faction_seal_items = list() // every faction seal matrix

/obj/item/weapon/stamp/proc/impression_state()
	return icon_state

/obj/item/weapon/stamp/faction_seal
	name = "seal matrix"
	desc = "A carved seal matrix. A faction leader can cut it as their faction's seal."
	icon_state = "stamp-blank"
	var/seal_faction = ""
	var/seal_office = ""
	var/seal_serial = ""

/obj/item/weapon/stamp/faction_seal/New()
	..()
	faction_seal_items |= src

/obj/item/weapon/stamp/faction_seal/Destroy()
	faction_seal_items -= src
	return ..()

/obj/item/weapon/stamp/faction_seal/impression_state()
	return "seal-court"

/obj/item/weapon/stamp/faction_seal/proc/is_cut()
	return istext(seal_faction) && length(seal_faction) && istext(seal_serial) && length(seal_serial)

/obj/item/weapon/stamp/faction_seal/proc/update_seal_name()
	if (is_cut())
		name = "seal of [seal_faction] ([seal_office])"
		desc = "The seal of [seal_faction], cut for the office of [seal_office]. Seal no. [seal_serial]."
	else
		name = initial(name)
		desc = initial(desc)

/obj/item/weapon/stamp/faction_seal/after_load()
	..()
	update_seal_name()

/obj/item/weapon/stamp/faction_seal/examine(mob/user, distance = -1)
	..()
	if (is_cut() && map)
		var/list/row = map.faction_seal_row(seal_faction, seal_serial)
		if (!row)
			to_chat(user, SPAN_WARNING("[seal_faction] keeps no record of this seal."))
		else if (row[3])
			to_chat(user, SPAN_WARNING("[seal_faction] revoked this seal on [faction_seal_date(row[4])]."))

// --- The register ---------------------------------------------------------

/proc/faction_seal_date(when)
	if (!isnum(when) || when <= 0)
		return "an unknown date"
	return time2text(when, "DD Month YYYY")

/proc/faction_seal_office_clean(value)
	if (!istext(value))
		return ""
	var/clean = sanitize(value, FACTION_SEAL_OFFICE_MAX + 1, FALSE)
	if (!istext(clean))
		return ""
	clean = trim(replacetext(clean, "|", "/"))
	if (length(clean) > FACTION_SEAL_OFFICE_MAX)
		return ""
	return clean

/obj/map_metadata/proc/faction_seal_state()
	var/list/S = recruitment_state()
	if (!islist(S["seals"]))
		S["seals"] = list()
	return S["seals"]

// The faction's seal rows, or an empty list.
/obj/map_metadata/proc/faction_seals(faction)
	var/list/seals = faction_seal_state()
	var/list/rows = seals[faction]
	return islist(rows) ? rows : list()

/obj/map_metadata/proc/faction_seal_row(faction, serial)
	var/list/rows = faction_seals(faction)
	var/list/row = rows[serial]
	if (!islist(row) || row.len != 4 || !istext(row[1]) || !isnum(row[2]) || !isnum(row[3]) || !isnum(row[4]))
		return null
	return row

// Drops malformed rows (a damaged save is never trusted).
/obj/map_metadata/proc/faction_seal_normalize()
	var/list/seals = faction_seal_state()
	for (var/faction in seals.Copy())
		var/list/rows = seals[faction]
		if (!istext(faction) || !islist(rows))
			seals -= faction
			continue
		for (var/serial in rows.Copy())
			if (!istext(serial) || !faction_seal_row(faction, serial))
				rows -= serial

// Records a new seal and returns its serial, or null when the faction is full.
/obj/map_metadata/proc/faction_seal_register(faction, office)
	if (!istext(faction) || !length(faction) || faction == "none" || !length(office))
		return null
	var/list/seals = faction_seal_state()
	var/list/rows = seals[faction]
	if (!islist(rows))
		rows = list()
		seals[faction] = rows
	var/live = 0
	var/highest = 0
	for (var/serial in rows)
		var/list/row = rows[serial]
		if (islist(row) && row.len == 4 && !row[3])
			live++
		highest = max(highest, text2num(serial) || 0)
	if (live >= FACTION_SEALS_PER_FACTION)
		return null
	var/serial = "[highest + 1]"
	rows[serial] = list(office, recruitment_now(), 0, 0)
	return serial

/obj/map_metadata/proc/faction_seal_revoke(faction, serial)
	var/list/row = faction_seal_row(faction, serial)
	if (!row || row[3])
		return FALSE
	row[3] = faction_seal_tick()
	row[4] = recruitment_now()
	return TRUE

// Advances and returns the seal clock.
/obj/map_metadata/proc/faction_seal_tick()
	var/list/S = recruitment_state()
	var/clock = S["seal_clock"]
	if (!isnum(clock) || clock < 0 || clock != round(clock))
		clock = 0
	clock++
	S["seal_clock"] = clock
	return clock

/obj/map_metadata/proc/faction_seal_rename(old_name, new_name)
	faction_rename_assoc_key(faction_seal_state(), old_name, new_name)
	for (var/obj/item/weapon/stamp/faction_seal/S in faction_seal_items)
		if (S.seal_faction == old_name)
			S.seal_faction = new_name
			S.update_seal_name()

// Who may cut and revoke seals for a faction: the leader, or an officer with
// the seals power (faction_offices.dm).
/obj/map_metadata/proc/can_manage_faction_seals(mob/living/human/H, faction)
	return istype(H) && H.stat != DEAD && faction_power(H, faction, "seals")

// --- Cutting and revoking -------------------------------------------------

/obj/item/weapon/stamp/faction_seal/attack_self(mob/living/human/user)
	if (!istype(user) || !map)
		return
	var/faction = user.civilization
	if (!faction || faction == "none" || !map.can_manage_faction_seals(user, faction))
		if (is_cut())
			to_chat(user, SPAN_NOTICE("This is the seal of [seal_faction] ([seal_office]). Press it onto a paper to seal it."))
		else
			to_chat(user, SPAN_NOTICE("Only a faction's leader can cut this matrix as a seal."))
		return
	var/list/choices = list()
	if (!is_cut())
		choices += "Cut as a seal of [faction]"
	choices += list("List [faction]'s seals", "Revoke a seal", "Cancel")
	var/choice = WWinput(user, "Seals of [faction]", "Faction seals", "Cancel", choices)
	if (!choice || choice == "Cancel" || user.get_active_hand() != src || !map.can_manage_faction_seals(user, faction))
		return
	if (choice == "List [faction]'s seals")
		to_chat(user, faction_seal_list_text(faction))
	else if (choice == "Revoke a seal")
		faction_seal_revoke_prompt(user, faction)
	else if (!is_cut())
		faction_seal_cut_prompt(user, faction)

/obj/item/weapon/stamp/faction_seal/proc/faction_seal_cut_prompt(mob/living/human/user, faction)
	var/office = faction_seal_office_clean(player_input(user, "Which office does this seal speak for? (e.g. Leader, Treasurer, Registrar)", "Cut a seal", "Leader", "text", null, FALSE))
	if (!length(office))
		to_chat(user, SPAN_WARNING("The office needs a short name, up to [FACTION_SEAL_OFFICE_MAX] letters."))
		return FALSE
	if (is_cut() || user.get_active_hand() != src || user.civilization != faction || !map.can_manage_faction_seals(user, faction))
		return FALSE
	var/serial = map.faction_seal_register(faction, office)
	if (!serial)
		to_chat(user, SPAN_WARNING("[faction] already keeps [FACTION_SEALS_PER_FACTION] seals. Revoke one first."))
		return FALSE
	seal_faction = faction
	seal_office = office
	seal_serial = serial
	update_seal_name()
	to_chat(user, SPAN_NOTICE("You cut the matrix as seal no. [serial] of [faction], for the office of [office]."))
	log_game("[key_name(user)] cut seal no. [serial] of [faction] ([office]).")
	return TRUE

/obj/item/weapon/stamp/faction_seal/proc/faction_seal_list_text(faction)
	var/list/rows = map.faction_seals(faction)
	if (!rows.len)
		return SPAN_NOTICE("[faction] has cut no seals yet.")
	var/list/lines = list("<b>Seals of [html_encode(faction)]</b>")
	for (var/serial in rows)
		var/list/row = map.faction_seal_row(faction, serial)
		if (!row)
			continue
		lines += "No. [serial]: [html_encode(row[1])], cut [faction_seal_date(row[2])][row[3] ? ", REVOKED [faction_seal_date(row[4])]" : ""]"
	return jointext(lines, "<br>")

/obj/item/weapon/stamp/faction_seal/proc/faction_seal_revoke_prompt(mob/living/human/user, faction)
	var/list/options = list()
	var/list/rows = map.faction_seals(faction)
	for (var/serial in rows)
		var/list/row = map.faction_seal_row(faction, serial)
		if (row && !row[3])
			options["No. [serial] ([row[1]])"] = serial
	if (!options.len)
		to_chat(user, SPAN_NOTICE("[faction] has no seals in force."))
		return FALSE
	var/pick = WWinput(user, "Revoke which seal? Papers it sealed before today stay good.", "Revoke a seal", "Cancel", options + "Cancel")
	if (!pick || pick == "Cancel" || !(pick in options) || user.civilization != faction || !map.can_manage_faction_seals(user, faction))
		return FALSE
	var/serial = options[pick]
	if (!map.faction_seal_revoke(faction, serial))
		return FALSE
	to_chat(user, SPAN_NOTICE("Seal no. [serial] of [faction] is revoked."))
	log_game("[key_name(user)] revoked seal no. [serial] of [faction].")
	return TRUE

// --- Records on the paper ---------------------------------------------------

/obj/item/weapon/paper
	// One "faction|office|serial|time|seal clock" entry per genuine seal impression,
	// in the order they were pressed. Saved as plain text.
	var/list/seal_records = null

/proc/faction_seal_record_text(obj/item/weapon/stamp/faction_seal/S)
	return "[replacetext(S.seal_faction, "|", "/")]|[replacetext(S.seal_office, "|", "/")]|[S.seal_serial]|[num2text(recruitment_now(), 12)]|[map ? map.faction_seal_tick() : 0]"

// Called after a stamp left its impression on P.
/proc/faction_seal_note_impression(obj/item/weapon/paper/P, obj/item/weapon/stamp/S)
	if (!P || !istype(S, /obj/item/weapon/stamp/faction_seal))
		return
	var/obj/item/weapon/stamp/faction_seal/F = S
	if (!F.is_cut())
		return
	if (!islist(P.seal_records))
		P.seal_records = list()
	if (P.seal_records.len >= FACTION_SEAL_RECORDS_MAX)
		return
	P.seal_records += faction_seal_record_text(F)

// One line per seal record: genuine, void (pressed after its revocation) or
// unknown to the faction.
/proc/faction_seal_verdict(entry)
	if (!istext(entry))
		return null
	var/list/parts = splittext(entry, "|")
	if (parts.len != 5)
		return null
	var/faction = parts[1]
	var/office = parts[2]
	var/serial = parts[3]
	var/when = text2num(parts[4])
	var/tick = text2num(parts[5])
	var/head = "Seal of [html_encode(faction)] ([html_encode(office)]), no. [html_encode(serial)], pressed [faction_seal_date(when)]"
	var/list/row = map ? map.faction_seal_row(faction, serial) : null
	if (!row)
		return "[head]: <b>unknown</b>, [html_encode(faction)] keeps no record of it."
	if (row[1] != office)
		return "[head]: <b>does not match</b> the register, which lists that seal for [html_encode(row[1])]."
	if (row[3] && (!isnum(tick) || tick > row[3]))
		return "[head]: <b>void</b>, the seal was revoked on [faction_seal_date(row[4])]."
	return "[head]: <b>impression matches the current register</b>; does not authenticate the current contents."

/proc/faction_seal_can_inspect(obj/item/weapon/paper/P, mob/reader)
	// Inspect a held sheet or one exposed on the ground, not the contents of
	// a nearby inventory or a closed container.
	return P && !P.gc_destroyed && reader && !reader.stat && reader.client && reader.client.mob == reader && (P.loc == reader || (isturf(P.loc) && P.Adjacent(reader)))

/proc/faction_seal_signature_lines(obj/item/weapon/paper/P, mob/reader)
	var/list/lines = list()
	if (!faction_seal_can_inspect(P, reader))
		return lines
	var/datum/paper_document_reader/request = new(P, reader, "paper", null)
	var/list/projection = request.project(reader)
	if (!projection || projection["error"])
		return lines
	for (var/list/section in projection["sections"])
		if (section["kind"] == "signature" && length(section["text"]))
			lines += "Signature text (identity not verified): [html_encode(section["text"])]"
	return lines

/proc/faction_seal_check_text(obj/item/weapon/paper/P, mob/reader = null)
	var/list/lines = list("<b>[html_encode(P.name)]</b>")
	lines += faction_seal_signature_lines(P, reader)
	var/recorded = 0
	if (islist(P.seal_records))
		for (var/entry in P.seal_records)
			var/verdict = faction_seal_verdict(entry)
			if (verdict)
				lines += verdict
				recorded++
	var/impressions = islist(P.stamped) ? P.stamped.len : 0
	if (impressions > recorded)
		lines += "[impressions - recorded] other stamp[impressions - recorded == 1 ? "" : "s"] carr[impressions - recorded == 1 ? "ies" : "y"] no seal record: an ordinary stamp, a copy or a forgery."
	if (lines.len == 1)
		lines += "There are no signatures or seals on it."
	return jointext(lines, "<br>")

/obj/item/weapon/paper/verb/check_seals()
	set name = "Check Seals"
	set category = "Object"
	set src in view(1)
	if (!faction_seal_can_inspect(src, usr))
		return
	to_chat(usr, faction_seal_check_text(src, usr))

#undef FACTION_SEAL_OFFICE_MAX
#undef FACTION_SEALS_PER_FACTION
#undef FACTION_SEAL_RECORDS_MAX
