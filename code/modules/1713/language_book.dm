/obj/item/weapon/language_book
	name = "language book"
	desc = "A book that allows translation between two languages. Nothing is written in it."
	icon = 'icons/obj/library.dmi'
	icon_state = "book" // temporary someone fix this aa
	throw_speed = TRUE
	throw_range = 5
	w_class = 3
	attack_verb = list("bashed", "whacked")
	flammable = TRUE
	var/written = FALSE // has this book been written in yet?
	var/datum/language/lang1 = null // 1st language of translation
	var/datum/language/lang2 = null // 2nd language of translation

/obj/item/weapon/language_book/attack_self(var/mob/user as mob)
	var/mob/living/carbon/human/H = user
	if(src.written)
		var/choice = WWinput(user, "Do you want to learn a language from [src]?", "Learn a Language", "Yes", list("Yes", "No"))
		if (choice == "No")
			return
		else
			if(!lang1 in H.languages && !lang2 in H.languages)
				user << "<span class = 'warning'>You can't read a language book without knowing one of the languages!</span>"
				return
			if(lang1 in H.languages && lang2 in H.languages)
				user << "<span class = 'warning'>You can't read a language book if you already know both languages!</span>"
				return
			var/datum/language/langtolearn = lang1
			if (lang1 in H.languages)
				langtolearn = lang2
			H.visible_message("<span class='notice'>[user] begins to read the [src].</span>", "<span class='notice'>You begin reading translations for [langtolearn.name] in the [src]. This will take around 2 minutes, and you need to stand or sit still.</span>")
			if(do_after(user, 1200, src))
				H.visible_message("<span class='notice'>[user] finishes reading the [src].</span>", "<span class='notice'>You finish reading translations in the [src]. You can now understand and speak [langtolearn.name]!</span>")
				H.add_language(langtolearn.name, FALSE)
				H.add_note("Known Languages", "[langtolearn.name]")
	else
		user << "<span class = 'warning'>You can't read a language book with nothing in it!</span>"

/obj/item/weapon/language_book/attackby(obj/item/weapon/W as obj, mob/living/carbon/human/user as mob)
	if(istype(W, /obj/item/weapon/pen))
		if(user.languages.len < 2)
			user << "<span class = 'warning'>You can't write a language book if you only know one language!</span>"
			return
		if(written)
			user << "<span class = 'warning'>You can't write a language book that has already been written in!</span>"
			return
		var/list/langcopy = user.languages.Copy() + "Cancel"
		var/datum/language/language1 = WWinput(user, "What will your 1st language to translate be?", "Writing Translations", "text", langcopy)
		langcopy.Remove(language1)
		var/datum/language/language2 = WWinput(user, "What will your 2nd language to translate be?", "Writing Translations", "text", langcopy)
		user.visible_message("<span class='notice'>[user] begins to write in the [src].</span>", "<span class='notice'>You begin writing translations in the [src]. This will take around 2 minutes, and you need to stand or sit still.</span>")
		if(do_after(user, 1200, src))
			user.visible_message("<span class='notice'>[user] finishes writing in the [src].</span>", "<span class='notice'>You finish writing translations in the [src].</span>")
			src.name = "[language1.name] to [language2.name] language book"
			src.desc = "A book that allows translation between two languages. It looks like it translates between [language1] and [language2]."
			src.written = TRUE
			src.lang1 = language1
			src.lang2 = language2
	else
		..()
