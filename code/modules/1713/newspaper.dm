/obj/item/weapon/newspaper
	name = "newspaper"
	desc = "An issue of a local Newspaper."
	icon = 'icons/obj/bureaucracy.dmi'
	icon_state = "newspaper"
	w_class = 2	//Let's make it fit in trashbags!
	attack_verb = list("bapped")
	var/screen = FALSE
	var/pages = FALSE
	var/curr_page = FALSE
	var/list/datum/feed_channel/news_content = list()
	var/datum/feed_message/important_message = null
	var/scribble=""
	var/scribble_page = null
	flammable = TRUE
/obj/item/weapon/newspaper/attack_self(mob/user as mob)
	return ..(user)

/obj/item/weapon/newspaper/Topic(href, href_list)
	var/mob/living/U = usr
	..()
	if ((src in U.contents) || ( istype(loc, /turf) && in_range(src, U) ))
		U.set_using_object(src)
		if (href_list["next_page"])
			if (curr_page==pages+1)
				return //Don't need that at all, but anyway.
			if (curr_page == pages) //We're at the middle, get to the end
				screen = 2
			else
				if (curr_page == FALSE) //We're at the start, get to the middle
					screen=1
			curr_page++
			playsound(loc, "pageturn", 50, TRUE)

		else if (href_list["prev_page"])
			if (curr_page == FALSE)
				return
			if (curr_page == TRUE)
				screen = FALSE

			else
				if (curr_page == pages+1) //we're at the end, let's go back to the middle.
					screen = TRUE
			curr_page--
			playsound(loc, "pageturn", 50, TRUE)

		if (istype(loc, /mob))
			attack_self(loc)


obj/item/weapon/newspaper/attackby(obj/item/weapon/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/pen))
		if (scribble_page == curr_page)
			user << "<span class = 'notice'>There's already a scribble in this page... You wouldn't want to make things too cluttered, would you?</span>"
		else
			var/s = cp1251_to_utf8(sanitize(input(user, "Write something", "Newspaper", "")))
			s = sanitize(s)
			if (!s)
				return
			if (!in_range(src, usr) && loc != usr)
				return
			scribble_page = curr_page
			scribble = s
			attack_self(user)
		return
