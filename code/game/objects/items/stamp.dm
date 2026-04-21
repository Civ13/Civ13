/obj/item/weapon/stamp
	name = "wax seal stamp"
	desc = "A stamp for marking important documents."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "stamp-rn"
	item_state = "stamp"
	throwforce = FALSE
	w_class = ITEM_SIZE_TINY
	throw_speed = 7
	throw_range = 15
	attack_verb = list("stamped")
	var/mob/living/human/owner = null

/obj/item/weapon/stamp/rn
	name = "British Governor's seal"
	icon_state = "stamp-rn"

/obj/item/weapon/stamp/fr
	name = "French Governor's seal"
	icon_state = "stamp-fr"

/obj/item/weapon/stamp/pt
	name = "Portuguese Governor's seal"
	icon_state = "stamp-pt"

/obj/item/weapon/stamp/es
	name = "Spanish Governor's seal"
	icon_state = "stamp-es"

/obj/item/weapon/stamp/nl
	name = "Dutch Governor's seal"
	icon_state = "stamp-nl"

/obj/item/weapon/stamp/baily
	name = "Baily approval"
	icon_state = "stamp-fr"

/obj/item/weapon/stamp/mail
	name = "envelope seal"
	icon_state = "stamp-blank"
	desc = "A stamp for sealing important envelopes."


//INKSTAMPS FOLLOW -siro
//NEW STAMPS - goldenfreddycl
/obj/item/weapon/stamp/fna
	name = "fna ink stamp"
	icon_state = "stamp-fna"

/obj/item/weapon/stamp/mail/fna
	name = "fna seal stamp"
	icon_state = "seal-fna"

/obj/item/weapon/stamp/cccp
	name = "red cccp stamp"
	icon_state = "stamp-cccp"

/obj/item/weapon/stamp/mail/cccp
	name = "red cccp seal stamp"
	icon_state = "seal-cccp"

/obj/item/weapon/stamp/nkvdseal
	name = "nkvd seal stamp"
	icon_state = "stamp-nkvd"

/obj/item/weapon/stamp/denied
	name = "DENIED ink stamp"
	icon_state = "stamp-deny"

/obj/item/weapon/stamp/approved
	name = "APPROVED ink stamp"
	icon_state = "stamp-approved"

/obj/item/weapon/stamp/stamplatin
	name = "latin ink stamp"
	icon_state = "stamp-latin"

/obj/item/weapon/stamp/stampgerman
	name = "german ink stamp"
	icon_state = "stamp-german"

/obj/item/weapon/stamp/stampgaul
	name = "gaelic ink stamp"
	icon_state = "stamp-gaul"

/obj/item/weapon/stamp/mail/latin
	name = "latin seal stamp"
	icon_state = "seal-latin"

/obj/item/weapon/stamp/mail/german
	name = "german seal stamp"
	icon_state = "seal-german"

/obj/item/weapon/stamp/mail/gaul
	name = "gaelic seal stamp"
	icon_state = "seal-gaul"

/obj/item/weapon/stamp/mail/berlin
	name = "berlin seal stamp"
	icon_state = "steal-berlin"

/obj/item/weapon/stamp/mail/berlin/censored
	icon_state = "seal-berlin-cens"

/obj/item/weapon/stamp/mail/admin
	name = "civ13 admin seal"
	icon_state = "seal-admin"

/obj/item/weapon/stamp/mail/court
	name = "court seal stamp"
	icon_state = "seal-court"

// "Syndicate stamp to forge documents." Was the orrigional comments for the orrigional item. Its a fancy adujustable stamp now, nothing sinister yet. - siro
/obj/item/weapon/stamp/chameleon/attack_self(mob/user as mob)

	var/list/stamp_types = typesof((/obj/item/weapon/stamp) && !(/obj/item/weapon/stamp/mail)) - type // Get all stamp types except our own
	var/list/stamps = list()

	// Generate them into a list
	for (var/stamp_type in stamp_types)
		var/obj/item/weapon/stamp/S = new stamp_type
		stamps[capitalize(S.name)] = S

	var/list/show_stamps = list("EXIT" = null) + sortList(stamps) // the list that will be shown to the user to pick from

	var/input_stamp = WWinput(user, "Choose a stamp to change to.", "Choose a stamp.", show_stamps[1], show_stamps)

	if (user && (src in user.contents))

		var/obj/item/weapon/stamp/chosen_stamp = stamps[capitalize(input_stamp)]

		if (chosen_stamp)
			name = chosen_stamp.name
			icon_state = chosen_stamp.icon_state
