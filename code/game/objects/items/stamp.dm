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
	icon_state = "stamp_blank"
	desc = "A stamp for sealing important envelopes."


//INKSTAMPS FOLLOW -siro
/obj/item/weapon/stamp/captain
	name = "large blue ink stamp"
	icon_state = "stamp-cap"

/obj/item/weapon/stamp/hop
	name = "blue ink stamp"
	icon_state = "stamp-hop"

/obj/item/weapon/stamp/hos
	name = "red ink stamp"
	icon_state = "stamp-hos"

/obj/item/weapon/stamp/ce
	name = "yellow ink stamp"
	icon_state = "stamp-ce"

/obj/item/weapon/stamp/rd
	name = "research director's ink stamp"
	icon_state = "stamp-rd"

/obj/item/weapon/stamp/cmo
	name = "chief medical officer's ink stamp"
	icon_state = "stamp-cmo"

/obj/item/weapon/stamp/denied
	name = "DENIED ink stamp"
	icon_state = "stamp-deny"

/obj/item/weapon/stamp/clown
	name = "silly ink stamp"
	icon_state = "stamp-clown"

/obj/item/weapon/stamp/internalaffairs
	name = "dark red ink stamp"
	icon_state = "stamp-intaff"

/obj/item/weapon/stamp/centcomm
	name = "APPROVED ink stamp"
	icon_state = "stamp-cent"

/obj/item/weapon/stamp/qm
	name = "yellow ink stamp"
	icon_state = "stamp-qm"

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

	if (user && src in user.contents)

		var/obj/item/weapon/stamp/chosen_stamp = stamps[capitalize(input_stamp)]

		if (chosen_stamp)
			name = chosen_stamp.name
			icon_state = chosen_stamp.icon_state