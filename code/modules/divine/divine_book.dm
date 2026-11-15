// ============================================================
// A god's book (Val, 2026-11-14). Hidden mechanic: keep it out of
// changelog lines and the wiki.
// ------------------------------------------------------------
// A god (staff playing a deity) writes one original book and entrusts it to
// a player. Each god has at most one original in the world at a time.
// Players may copy it as they like (printing press, monks) and burn copies;
// a copy is an ordinary book. The god can write a new original only once the
// last one no longer exists: burned, destroyed or deleted.
//
// The original is an ordinary saved item (deity name and original flag are
// saved fields), so it outlives saves and restarts. Only originals that are
// still in this world count; the check waits for a load to finish restoring
// them, so a restart never frees the god to write a second one.
// ============================================================

// Every original god's book in this world, so the check never scans the map.
var/global/list/divine_book_originals = list()

/obj/item/weapon/book/divine
	name = "book"
	title = "book"
	var/divine_deity = null      // the god who wrote it
	var/divine_original = FALSE  // TRUE only for the god's own book; copies are plain books
	var/divine_text_sealed = FALSE
	var/divine_private_text = null
	var/divine_legacy_dat = null
	var/list/divine_legacy_pages = null

/obj/item/weapon/book/divine/New()
	..()
	divine_book_originals += src

/obj/item/weapon/book/divine/Destroy()
	divine_book_originals -= src
	if (divine_original && divine_deity && !persistence_active_operation)
		log_admin("The original book of [divine_deity] ([title]) is gone; [divine_deity] may write a new one.")
		message_admins("The original book of [divine_deity] ([title]) is gone; [divine_deity] may write a new one.")
	return ..()

// Ordinary writing, examination, page removal and ciphers remain inherited.
// Older originals placed the god's text in public pages. Preserve those bytes
// privately before clearing the old public projection. Subsequent player writing
// stays public. Copies already distributed by old code cannot be identified.
/obj/item/weapon/book/divine/after_load()
	. = ..()
	if (divine_original && !divine_text_sealed)
		divine_legacy_dat = dat
		divine_legacy_pages = islist(written_pages) ? written_pages.Copy() : null
		dat = null
		written_pages = null
		divine_text_sealed = TRUE
		if (author == divine_deity)
			author = initial(author)
		if (desc == "A book written by [divine_deity].")
			desc = initial(desc)

// The god's private text is for that god's own followers only.
/obj/item/weapon/book/divine/divine_journal_reader_allowed(mob/living/human/H)
	return ..() && divine_original && divine_book_key(H.divine_patron) == divine_book_key(divine_deity)

// Builds on the ordinary-book projection in #5154. No private bytes enter
// dat, page_list(), printing, copying, torn sheets or ordinary cipher metadata.
/obj/item/weapon/book/divine/divine_journal_html(mob/living/human/H)
	. = ..()
	if (!divine_journal_reader_allowed(H))
		return .
	if (istext(divine_private_text) && length(divine_private_text))
		. += "<p>[html_encode(copytext(divine_private_text, 1, MAX_BOOK_MESSAGE_LEN + 1))]</p>"
	// Old formatting is escaped rather than interpreted as active markup.
	if (istext(divine_legacy_dat) && length(divine_legacy_dat))
		. += "<p>[html_encode(copytext(divine_legacy_dat, 1, MAX_BOOK_MESSAGE_LEN + 1))]</p>"
	else if (islist(divine_legacy_pages))
		var/count = 0
		for (var/page in divine_legacy_pages)
			if (++count > 32)
				break
			if (istext(page))
				. += "<p>[html_encode(copytext(page, 1, MAX_BOOK_MESSAGE_LEN + 1))]</p>"

/proc/divine_book_key(deity)
	return istext(deity) ? lowertext(trim(deity)) : null

// The god's original book if it still exists in this world, otherwise null.
/proc/divine_book_original(deity)
	var/key = divine_book_key(deity)
	if (!key)
		return null
	for (var/obj/item/weapon/book/divine/B in divine_book_originals)
		if (QDELETED(B) || !B.divine_original)
			continue
		if (divine_book_key(B.divine_deity) == key)
			return B
	return null

// Why a god can't write a new original right now, or null when they can.
/proc/divine_book_problem(deity)
	if (!divine_book_key(deity))
		return "Name the god first."
	if (map && map.persistence && (!persistence_player_restore_ready || persistence_save_in_progress || persistence_active_operation))
		return "The world is saving or still loading. Try again once it has finished."
	var/obj/item/weapon/book/divine/B = divine_book_original(deity)
	if (B)
		var/mob/holder = B.loc
		var/where = istype(holder) ? "held by [holder.real_name ? holder.real_name : holder.name]" : "in [get_area(B)]"
		return "[deity] already has an original book ([B.title], [where]). A new one can be written only once it no longer exists."
	return null

// Writes the god's original book. Returns the book, or a text reason.
/proc/create_divine_book(deity, title, text, atom/destination, public_text = null)
	var/problem = divine_book_problem(deity)
	if (problem)
		return problem
	var/turf/T = get_turf(destination)
	if (!T)
		return "There is nowhere to put the book."
	var/obj/item/weapon/book/divine/B = new(T)
	B.divine_deity = trim(deity)
	B.divine_original = TRUE
	B.title = title
	B.name = title
	B.divine_text_sealed = TRUE
	B.divine_private_text = istext(text) ? copytext(text, 1, MAX_BOOK_MESSAGE_LEN + 1) : null
	if (istext(public_text) && length(public_text))
		B.add_written_page(public_text)
	return B
