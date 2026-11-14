// Staff playing a god write that god's one original book (see
// code/modules/divine/divine_book.dm). Hidden mechanic: keep it out of
// changelog lines and the wiki.
/client/proc/cmd_admin_create_divine_book()
	set category = "Admin"
	set name = "Write God's Book"
	set desc = "As a god, write your one original book and entrust it to a player."
	if (!check_rights(R_ADMIN))
		return
	var/deity = sanitize(input(usr, "Which god is writing? Each god has one original book at a time.", "God's Book") as text|null)
	if (!deity)
		return
	var/problem = divine_book_problem(deity)
	if (problem)
		to_chat(usr, SPAN_WARNING(problem))
		return
	var/title = sanitize(input(usr, "Ordinary public title (visible to everyone):", "God's Book", "book") as text|null)
	if (!title)
		return
	var/raw = input(usr, "Private contents (sealed until character initiation is implemented):", "God's Book") as message|null
	var/text = raw ? copytext(raw, 1, MAX_BOOK_MESSAGE_LEN + 1) : null
	var/cover = input(usr, "Optional ordinary pages (visible and copyable by everyone):", "God's Book") as message|null
	var/public_text = cover ? replacetext(sanitize(cover, MAX_BOOK_MESSAGE_LEN), "\n", "<br>") : null
	var/list/choices = list()
	for (var/mob/living/human/H in human_mob_list)
		if (!QDELETED(H) && H.stat != DEAD && H.client && get_turf(H))
			choices["[H.real_name] ([H.ckey])"] = H
	var/list/options = list("Where I am") + sortList(choices.Copy())
	var/pick = input(usr, "Entrust the book to whom?", "God's Book") as null|anything in options
	if (!pick)
		return
	var/mob/living/human/recipient = pick == "Where I am" ? null : choices[pick]
	var/atom/destination = recipient ? recipient : mob
	if (recipient && (QDELETED(recipient) || !get_turf(recipient)))
		to_chat(usr, SPAN_WARNING("[pick] is no longer there."))
		return
	if (!check_rights(R_ADMIN))
		return
	var/result = create_divine_book(deity, title, text, destination, public_text)
	if (istext(result))
		to_chat(usr, SPAN_WARNING(result))
		return
	var/obj/item/weapon/book/divine/B = result
	if (recipient)
		recipient.put_in_hands(B)
		to_chat(recipient, SPAN_NOTICE("You receive \the [B]."))
	log_admin("[key_name(usr)] wrote the original book of [B.divine_deity] ([B.title])[recipient ? " for [key_name(recipient)]" : ""].")
	message_admins("[key_name_admin(usr)] wrote the original book of [B.divine_deity] ([B.title])[recipient ? " for [key_name_admin(recipient)]" : ""].")
	to_chat(usr, SPAN_NOTICE("You wrote [B.title][recipient ? " and entrusted it to [recipient.real_name]" : ""]."))
