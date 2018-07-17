/obj/item/megaphone
	name = "megaphone"
	desc = "A device used to project your voice. Loudly."
	icon = 'icons/obj/device.dmi'
	icon_state = "megaphone"
	item_state = "radio"
	w_class = 2.0
	flags = CONDUCT

	var/spamcheck = FALSE
	var/emagged = FALSE
	var/insults = FALSE
	var/list/insultmsg = list("FUCK EVERYONE!", "I'M A TATER!", "ALL SECURITY TO SHOOT ME ON SIGHT!", "I HAVE A BOMB!", "CAPTAIN IS A COMDOM!", "FOR THE SYNDICATE!")

/obj/item/megaphone/attack_self(mob/living/user as mob)
	if (user.client)
		if (user.client.prefs.muted & MUTE_IC)
			src << "<span class='warning'>You cannot speak in IC (muted).</span>"
			return
	if (!ishuman(user))
		user << "<span class='warning'>You don't know how to use this!</span>"
		return
	if (user.silent)
		return
	if (spamcheck)
		user << "<span class='warning'>\The [src] needs to recharge!</span>"
		return

	var/message = sanitize(input(user, "Shout a message?", "Megaphone", null)  as text)
	if (!message)
		return
	message = capitalize(message)
	if ((loc == user && usr.stat == FALSE))
		if (emagged)
			if (insults)
				for (var/mob/O in (viewers(user)))
					O.show_message("<b>[user]</b> broadcasts, <FONT size=3>\"[pick(insultmsg)]\"</FONT>",2) // 2 stands for hearable message
				insults--
			else
				user << "<span class='warning'>*BZZZZzzzzzt*</span>"
		else
			for (var/mob/O in (viewers(user)))
				O.show_message("<b>[user]</b> broadcasts, <FONT size=3>\"[message]\"</FONT>",2) // 2 stands for hearable message

		spamcheck = TRUE
		spawn(20)
			spamcheck = FALSE
		return

