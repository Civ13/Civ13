/client/proc/dsay(msg as text)
	set category = "Special"
	set name = "Dsay" //Gave this shit a shorter name so you only have to time out "dsay" rather than "dead say" to use it --NeoFite
	set hidden = TRUE
	if (!holder)
		src << "Only administrators may use this command."
		return
	if (!mob)
		return
	if (prefs.muted & MUTE_DEADCHAT)
		src << "<span class='warning'>You cannot send DSAY messages (muted).</span>"
		return

	if (!is_preference_enabled(/datum/client_preference/show_dsay))
		src << "<span class='warning'>You have deadchat muted.</span>"
		return

	if (handle_spam_prevention(msg,MUTE_DEADCHAT))
		return

	if (quickBan_isbanned("OOC"))
		src << "<span class = 'danger'>You're banned from OOC.</span>"
		return

	var/stafftype = uppertext(holder.rank)

	msg = sanitize(msg)
	log_admin("DSAY: [key_name(src)] : [msg]")

	if (!msg)
		return

	say_dead_direct("<span class='name'>[stafftype]([holder.fakekey ? holder.fakekey : key])</span> says, <span class='message'>\"[msg]\"</span>")


