// Sealed advancement notes are attached to an ORDINARY book. No special type,
// name, art, examine text or public interaction identifies a magical item.
// No initiation, casting, cipher-attempt or progression grant is added here.

/mob/living/human/proc/can_read_divine_journal()
	// Fail closed until the durable initiation/covenant service is integrated.
	// Possession, mathematics, a password and an admin client are not initiation.
	return FALSE

/obj/item/weapon/book
	var/list/divine_advancement_entries = null

/obj/item/weapon/book/proc/divine_journal_reader_allowed(mob/living/human/H)
	return istype(H) && !QDELETED(H) && H.stat == CONSCIOUS && H.can_read_divine_journal()

// The unauthorized projection is deliberately independent of chapter count,
// titles, notes and progress. Do not send plaintext in hidden HTML or UI data.
/obj/item/weapon/book/proc/divine_journal_html(mob/living/human/H)
	if (!divine_journal_reader_allowed(H) || !islist(divine_advancement_entries) || !divine_advancement_entries.len)
		return ""
	var/html = "<h3>Record of advancement</h3>"
	var/count = 0
	if (islist(divine_advancement_entries))
		for (var/title in divine_advancement_entries)
			if (++count > 32)
				break
			var/note = divine_advancement_entries[title]
			if (!istext(title) || !istext(note))
				continue
			html += "<h4>[html_encode(copytext(title, 1, 81))]</h4><p>[html_encode(copytext(note, 1, 1025))]</p>"
	return html

// Server-owned advancement adapter only. Recording an entry does not teach,
// unlock or approve any spell. No Topic handler accepts these values.
/obj/item/weapon/book/proc/record_divine_advancement(mob/living/human/H, title, note)
	if (!divine_journal_reader_allowed(H) || !istext(title) || !length(title) || length(title) > 80 || !istext(note) || length(note) > 1024)
		return FALSE
	if (!islist(divine_advancement_entries))
		divine_advancement_entries = list()
	if (!(title in divine_advancement_entries) && divine_advancement_entries.len >= 32)
		return FALSE
	divine_advancement_entries[title] = note
	return TRUE
