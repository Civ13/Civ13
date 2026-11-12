// ============================================================
// Research Tree - ciphers and code-breaking (Val, 2026-11-12)
// ------------------------------------------------------------
// On book-research worlds, someone who knows the Printing Press can write a
// book's research in cipher under a key word. Whoever is told the word reads
// the book as usual. Anyone else has to break the cipher with Basic
// Mathematics before they can study, copy or tear chapters from it, which
// takes longer the better the writer's mathematics was. A stolen book is a
// project, not an instant win. Enciphered books still count as records of
// their era.
// ============================================================

#define CIPHER_NODE "printing_currency"
#define CIPHER_KEY_MIN 3
#define CIPHER_KEY_MAX 24
#define CIPHER_MAX_STRENGTH 6
// Enciphering or writing out plainly: time per chapter (deciseconds).
#define CIPHER_WRITE_TIME 300
// Code-breaking: mathematics needed to try, work per sitting, and the base
// time per point of strength for a breaker as able as the writer.
#define CIPHER_BREAK_SKILL 12
#define CIPHER_BREAK_SITTING 300
#define CIPHER_BREAK_TIME 1200

/obj/item/weapon/book
	var/cipher_key = ""      // the key word; empty means plain writing
	var/cipher_strength = 0  // 1-6, from the writer's Basic Mathematics
	var/cipher_readers = ""  // "identity|identity": characters who can read it
	var/cipher_progress = "" // "identity=fraction|...": code-breaking so far

/proc/clean_cipher_key(word)
	if (!istext(word))
		return null
	word = lowertext(trim(sanitizeSafe(word, CIPHER_KEY_MAX + 1)))
	if (length(word) < CIPHER_KEY_MIN || length(word) > CIPHER_KEY_MAX || findtext(word, "|") || findtext(word, "="))
		return null
	return word

/obj/item/weapon/book/proc/is_enciphered()
	return istext(cipher_key) && length(cipher_key) > 0

/obj/item/weapon/book/proc/cipher_reader_list()
	return (istext(cipher_readers) && length(cipher_readers)) ? splittext(cipher_readers, "|") : list()

/obj/item/weapon/book/proc/can_read_cipher(mob/living/human/H)
	return !is_enciphered() || (istype(H) && (H.scholar_identity() in cipher_reader_list()))

// Whether the cipher keeps this reader out of the research in the book.
/obj/item/weapon/book/proc/cipher_blocks(mob/living/human/H)
	return is_enciphered() && map && map.book_research_enabled() && !can_read_cipher(H)

/obj/item/weapon/book/proc/add_cipher_reader(mob/living/human/H)
	var/list/readers = cipher_reader_list()
	readers |= H.scholar_identity()
	cipher_readers = jointext(readers, "|")

// Tells a blocked reader why. Returns TRUE when the cipher is in the way.
/obj/item/weapon/book/proc/cipher_refuses(mob/living/human/H)
	if (!cipher_blocks(H))
		return FALSE
	to_chat(H, SPAN_WARNING("[src] is written in cipher. Write in it with a pen and choose Cipher to enter its key word or to break it."))
	return TRUE

/proc/cipher_strength_for(mob/living/human/H)
	return clamp(1 + round(H.scholar_level("mathematics") / 20), 1, CIPHER_MAX_STRENGTH)

// Why H cannot encipher this book right now, or null.
/obj/item/weapon/book/proc/encipher_problem(mob/living/human/H)
	if (!map || !map.book_research_enabled() || !can_hold_research())
		return "This book cannot be written in cipher."
	if (is_enciphered())
		return "[src] is already in cipher."
	if (!length(research_chapter_list()))
		return "There is no research in [src] to hide."
	if (!H.knows_recipe_node(CIPHER_NODE))
		var/datum/research_node/N = get_research_node(CIPHER_NODE)
		return "You need to know [N ? N.name : "printing"] to write in cipher."
	if (!H.held_writing_pen())
		return "Hold a pencil or pen to write with."
	return null

/obj/item/weapon/book/proc/encipher_commit(mob/living/human/H, key)
	key = clean_cipher_key(key)
	if (!key || encipher_problem(H))
		return FALSE
	cipher_key = key
	cipher_strength = cipher_strength_for(H)
	cipher_readers = ""
	cipher_progress = ""
	add_cipher_reader(H)
	return TRUE

// A correct key word makes the character a reader at once.
/obj/item/weapon/book/proc/try_cipher_key(mob/living/human/H, word)
	if (!is_enciphered() || can_read_cipher(H))
		return FALSE
	if (clean_cipher_key(word) != cipher_key)
		return FALSE
	add_cipher_reader(H)
	return TRUE

// A reader writes the book out in plain words again.
/obj/item/weapon/book/proc/decipher_commit(mob/living/human/H)
	if (!is_enciphered() || !can_read_cipher(H))
		return FALSE
	cipher_key = ""
	cipher_strength = 0
	cipher_readers = ""
	cipher_progress = ""
	return TRUE

// ---- Code-breaking ----

/obj/item/weapon/book/proc/cipher_progress_map()
	var/list/result = list()
	if (istext(cipher_progress) && length(cipher_progress))
		for (var/entry in splittext(cipher_progress, "|"))
			var/split = findtext(entry, "=")
			if (!split)
				continue
			var/fraction = text2num(copytext(entry, split + 1))
			if (isnum(fraction) && fraction > 0)
				result[copytext(entry, 1, split)] = min(1, fraction)
	return result

/obj/item/weapon/book/proc/cipher_break_fraction(mob/living/human/H)
	return cipher_progress_map()[H.scholar_identity()] || 0

// Total working time for H to break this cipher: longer for stronger ciphers
// and for breakers whose mathematics trails the writer's.
/obj/item/weapon/book/proc/cipher_break_time(mob/living/human/H)
	var/writer = (cipher_strength - 1) * 20 + 10
	var/breaker = max(5, H.scholar_level("mathematics"))
	return round(CIPHER_BREAK_TIME * max(1, cipher_strength) * clamp(writer / breaker, 0.5, 3))

/obj/item/weapon/book/proc/break_problem(mob/living/human/H)
	if (!cipher_blocks(H))
		return "There is no cipher here to break."
	if (H.scholar_level("mathematics") < CIPHER_BREAK_SKILL)
		return "Breaking a cipher takes Basic Mathematics [CIPHER_BREAK_SKILL]."
	if (!H.held_writing_pen())
		return "Hold a pencil or pen to work the cipher with."
	return null

// One sitting of code-breaking has passed. Returns TRUE once the cipher is broken.
/obj/item/weapon/book/proc/break_commit(mob/living/human/H, worked = CIPHER_BREAK_SITTING)
	if (break_problem(H))
		return FALSE
	var/list/progress = cipher_progress_map()
	var/id = H.scholar_identity()
	var/fraction = (progress[id] || 0) + worked / cipher_break_time(H)
	if (fraction >= 1)
		progress -= id
		add_cipher_reader(H)
	else
		progress[id] = round(fraction, 0.001)
	var/list/parts = list()
	for (var/who in progress)
		parts += "[who]=[progress[who]]"
	cipher_progress = jointext(parts, "|")
	return can_read_cipher(H)

// ---- The pen menu ----

/obj/item/weapon/book/proc/cipher_menu(mob/living/human/H)
	if (!istype(H) || !map || !map.book_research_enabled() || !can_hold_research() || page_busy)
		return
	if (!is_enciphered())
		var/problem = encipher_problem(H)
		if (problem)
			to_chat(H, SPAN_WARNING(problem))
			return
		var/key = clean_cipher_key(player_input(H, "Choose a key word ([CIPHER_KEY_MIN] to [CIPHER_KEY_MAX] characters). Anyone you tell it to can read the book; everyone else must break the cipher.", "Cipher", null, "text", null, FALSE))
		if (!key)
			to_chat(H, SPAN_WARNING("That key word won't do."))
			return
		to_chat(H, SPAN_NOTICE("You begin writing [src] out in cipher."))
		page_busy = TRUE
		var/done = do_reading(H, CIPHER_WRITE_TIME * length(research_chapter_list()), src)
		page_busy = FALSE
		if (!done || QDELETED(src) || !H.Adjacent(src))
			return
		if (encipher_commit(H, key))
			to_chat(H, SPAN_NOTICE("[src] is now in cipher (strength [cipher_strength] of [CIPHER_MAX_STRENGTH]). Its key word is \"[cipher_key]\"."))
		return
	if (can_read_cipher(H))
		if (player_input(H, "[src] is in cipher and you can read it. Write it out in plain words again?", "Cipher", null, "anything", list("Write it out plainly", "Leave it"), TRUE) != "Write it out plainly")
			return
		if (!H.held_writing_pen())
			to_chat(H, SPAN_WARNING("Hold a pencil or pen to write with."))
			return
		page_busy = TRUE
		var/done = do_reading(H, CIPHER_WRITE_TIME * length(research_chapter_list()), src)
		page_busy = FALSE
		if (done && !QDELETED(src) && H.Adjacent(src) && decipher_commit(H))
			to_chat(H, SPAN_NOTICE("[src] is in plain words again."))
		return
	var/pick = player_input(H, "[src] is written in cipher (strength [cipher_strength] of [CIPHER_MAX_STRENGTH]).", "Cipher", null, "anything", list("Enter the key word", "Break the cipher", "Leave it"), TRUE)
	if (pick == "Enter the key word")
		if (try_cipher_key(H, player_input(H, "What is the key word?", "Cipher", null, "text", null, FALSE)))
			to_chat(H, SPAN_NOTICE("The key word fits. You can read [src] now."))
		else
			to_chat(H, SPAN_WARNING("That is not the key word."))
		return
	if (pick != "Break the cipher")
		return
	var/problem = break_problem(H)
	if (problem)
		to_chat(H, SPAN_WARNING(problem))
		return
	to_chat(H, SPAN_NOTICE("You set to work on the cipher. You are [round(cipher_break_fraction(H) * 100)]% of the way through; all of it takes about [round(cipher_break_time(H) / 600, 0.5)] minutes."))
	while (!QDELETED(src) && H.Adjacent(src) && !break_problem(H))
		if (!do_reading(H, CIPHER_BREAK_SITTING, src))
			break
		if (break_commit(H))
			to_chat(H, SPAN_NOTICE("The cipher gives way. You can read [src] now."))
			return
	if (!QDELETED(src) && cipher_blocks(H))
		to_chat(H, SPAN_NOTICE("You stop for now, [round(cipher_break_fraction(H) * 100)]% of the way through the cipher. Your working stays with the book."))

// A printed or copied book carries the cipher of its original.
/obj/item/weapon/book/proc/copy_cipher_from(obj/item/weapon/book/original)
	if (!istype(original))
		return
	cipher_key = original.cipher_key
	cipher_strength = original.cipher_strength
	cipher_readers = original.cipher_readers
	cipher_progress = ""

#undef CIPHER_NODE
#undef CIPHER_KEY_MIN
#undef CIPHER_KEY_MAX
#undef CIPHER_MAX_STRENGTH
#undef CIPHER_WRITE_TIME
#undef CIPHER_BREAK_SKILL
#undef CIPHER_BREAK_SITTING
#undef CIPHER_BREAK_TIME
