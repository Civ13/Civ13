/obj/item/weapon/book/language_book
	name = "language book"
	desc = "A book that allows translation between two languages. Nothing is written in it."
	icon = 'icons/obj/library.dmi'
	icon_state = "book2" // temporary someone fix this aa
	throw_speed = TRUE
	throw_range = 5
	w_class = ITEM_SIZE_NORMAL
	attack_verb = list("bashed", "whacked")
	flammable = TRUE
	var/written = FALSE // has this book been written in yet?
	var/datum/language/lang1 = null // 1st language of translation
	var/datum/language/lang2 = null // 2nd language of translation
	unique = TRUE
/obj/item/weapon/book/language_book/attack_self(var/mob/user as mob)
	var/mob/living/human/H = user
	if(src.written && lang1 && lang2)
		var/choice = WWinput(user, "Do you want to learn a language from [src]?", "Learn a Language", "Yes", list("Yes", "No"))
		if (choice == "No")
			return
		else
			// Compare by language type: a book restored from a save holds language
			// copies, not the shared datums in the reader's languages list.
			var/known1 = H.knows_language(lang1)
			var/known2 = H.knows_language(lang2)
			if(!known1 && !known2)
				to_chat(user, "<span class = 'warning'>You can't read a language book without knowing one of the languages!</span>")
				return
			if(known1 && known2)
				to_chat(user, "<span class = 'warning'>You can't read a language book if you already know both languages!</span>")
				return
			var/datum/language/langtolearn = lang1
			if (known1)
				langtolearn = lang2
			if(H.too_dark_to_read())
				return
			// A primer: each sitting teaches a little, up to broken speech, and
			// only so much sinks in per day. The rest takes people.
			if (!H.language_day_left(langtolearn, "study"))
				to_chat(user, "<span class = 'warning'>You have taken in all the [langtolearn.name] you can from books today.</span>")
				return
			H.visible_message("<span class='notice'>[user] begins to read the [src].</span>", "<span class='notice'>You begin a sitting with the [langtolearn.name] translations in the [src]. This will take around 80 seconds, and you need to stand or sit still.</span>")
			if(do_reading(user, 800, src))
				if (H.gain_language(langtolearn, LANGUAGE_STUDY_GAIN, LANGUAGE_BROKEN, "study"))
					H.visible_message("<span class='notice'>[user] finishes reading the [src].</span>", "<span class='notice'>You finish a sitting with the [src]. You now understand about [round(H.language_score(langtolearn))]% of [langtolearn.name].</span>")
				else
					to_chat(user, "<span class='notice'>The [src] has taught you what a book can of [langtolearn.name]; the rest you must learn from people who speak it.</span>")
	else
		to_chat(user, "<span class = 'warning'>You can't read a language book with nothing in it!</span>")

/obj/item/weapon/book/language_book/attackby(obj/item/weapon/W as obj, mob/living/human/user as mob)
	if(istype(W, /obj/item/weapon/pen))
		if(user.languages.len < 2)
			to_chat(user, "<span class = 'warning'>You can't write a language book if you only know one language!</span>")
			return
		if(written)
			to_chat(user, "<span class = 'warning'>You can't write a language book that has already been written in!</span>")
			return
		if(user.too_dark_to_read())
			return
		// Only a language held well enough to converse in can be set down.
		var/list/langcopy = list()
		for (var/datum/language/held in user.languages)
			if (user.language_score(held) >= LANGUAGE_CONVERSATIONAL)
				langcopy += held
		if (langcopy.len < 2)
			to_chat(user, "<span class = 'warning'>You need to be at least conversational in two languages to write a language book!</span>")
			return
		langcopy += "Cancel"
		var/datum/language/language1 = WWinput(user, "What will your 1st language to translate be?", "Writing Translations", "Cancel", langcopy)
		if (!istype(language1))
			return
		langcopy.Remove(language1)
		var/datum/language/language2 = WWinput(user, "What will your 2nd language to translate be?", "Writing Translations", "Cancel", langcopy)
		if (!istype(language2))
			return
		user.visible_message("<span class='notice'>[user] begins to write in the [src].</span>", "<span class='notice'>You begin writing translations in the [src]. This will take around 2 minutes, and you need to stand or sit still.</span>")
		if(do_reading(user, 1200, src))
			if (written)
				return
			user.visible_message("<span class='notice'>[user] finishes writing in the [src].</span>", "<span class='notice'>You finish writing translations in the [src].</span>")
			src.name = "[language1.name] to [language2.name] language book"
			src.desc = "A book that allows translation between two languages. It looks like it translates between [language1] and [language2]."
			src.written = TRUE
			src.lang1 = canonical_language(language1)
			src.lang2 = canonical_language(language2)
	else
		..()
