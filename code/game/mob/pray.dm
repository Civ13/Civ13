/mob/verb/pray()
	set category = "IC"
	set name = "Pray"

	if (say_disabled)	//This is here to try to identify lag problems
		to_chat(usr, SPAN_RED("Speech is currently admin-disabled."))
		return

	// Players pick their god from the staff's divine names (code/modules/divine/identity.dm).
	var/deity = null
	var/deity_label = null
	var/list/gods = divine_god_choices()
	if (gods.len)
		var/list/options = list("The gods") + gods
		var/picked = player_input(src, "To whom do you pray?", "Pray", null, "anything", options, TRUE)
		if (!picked)
			return
		if (picked != "The gods")
			deity = gods[picked]
			deity_label = picked

	var/msg = player_input(src, deity_label ? "What do you say to [deity_label]?" : "What do you say?", "Pray", null, "text", null, TRUE)
	msg = sanitize(msg)
	if (!msg)	return

	if (usr.client)
		if (usr.client.prefs.muted & MUTE_PRAY)
			to_chat(usr, SPAN_RED("You cannot pray (muted)."))
			return
		if (client.handle_spam_prevention(msg,MUTE_PRAY))
			return

	var/image/cross = image('icons/obj/storage.dmi',"bible")
	var/answer_link = ""
	var/mob/living/human/follower = src
	if (istype(follower) && follower.divine_patron)
		answer_link = " (<A HREF='?_src_=holder;divine_reply=\ref[src]'>Answer</A>)"
	else if (istype(follower))
		// Not devoted to any god yet: the god hearing this may invite them to follow.
		answer_link = " (<A HREF='?_src_=holder;divine_invite=\ref[src]'>Invite</A>)"
	var/text = "<span class = 'notice'>\icon[getFlatIcon(cross)] <b><font color=purple>PRAY[deity_label ? " to [deity_label]" : ""]: </font>[key_name(src, TRUE)] (<A HREF='?_src_=holder;adminmoreinfo=\ref[src]'>?</A>) (<A HREF='?_src_=holder;adminplayeropts=\ref[src]'>PP</A>) (<A HREF='?_src_=vars;Vars=\ref[src]'>VV</A>) (<A HREF='?_src_=holder;subtlemessage=\ref[src]'>SM</A>) ([admin_jump_link(src, src)]) (<A HREF='?_src_=holder;secretsadmin=check_antagonist'>CA</A>) (<A HREF='?_src_=holder;adminspawncookie=\ref[src]'>SC</a>)[answer_link]:</b> [msg]</span>"
	// Staff see the praying player's hidden karma beside the links.
	var/karma_ckey = karma_mob_ckey(src)
	if (karma_ckey)
		text = replacetext(text, "[answer_link]:</b>", "[answer_link][karma_staff_badge(karma_ckey)]:</b>")
	var/list/hearers = prayer_hearers()
	for (var/client/C in hearers)
		to_chat(C, CHAT_TYPED(CHAT_PRAYER, text))

	// The god's own staff hear it even with prayers hidden, with a sound.
	if (deity)
		for (var/client/C in divine_staff_for(deity))
			if (!(C in hearers))
				to_chat(C, CHAT_TYPED(CHAT_PRAYER, text))
			C << 'sound/effects/adminhelp.ogg'

	// The player's own copy, in their Prayer tab.
	to_chat(usr, CHAT_TYPED(CHAT_PRAYER, "<span class='notice'><i>You pray to [deity_label ? deity_label : "the gods"]:</i> [msg]</span>"))

	//log_admin("HELP: [key_name(src)]: [msg]")

// Staff who see every prayer: admins with prayers shown, and every admin who
// plays a god (code/modules/divine/identity.dm), whatever their setting.
/proc/prayer_hearers()
	. = list()
	for (var/client/C in admins)
		if (!C.holder || !(R_ADMIN & C.holder.rights))
			continue
		if (C.is_preference_enabled(/datum/client_preference/admin/show_chat_prayers) || divine_identity_of(C.ckey))
			. += C
