/mob/living/human/verb/mob_sleep()
	set name = "Sleep"
	set category = "IC"

	if (usr != src || !client || client.mob != src)
		return
	var/client/sleeping_client = client
	if (persistence_sleep_transfer_blocked())
		to_chat(src, SPAN_RED("Wait for the world save or load to finish before sleeping."))
		return

	if(map && map.ID == MAP_VOYAGE)
		WWalert("You cannot use this function on this map.","Disabled",src)
		return

	if (disease)
		to_chat(src, SPAN_RED("You toss and turn but you are too unwell to sleep."))
		return

	for (var/obj/item/clothing/C in list(wear_suit,w_uniform,shoes))
		if (C.fleas == TRUE)
			to_chat(src, SPAN_RED("You toss and turn but your skin is crawling and you can not sleep."))
			return

	if (hygiene <= 80)
		to_chat(src, SPAN_RED("You toss and turn but you are too filthy to sleep."))
		return

	if (sleeping)
		to_chat(src, SPAN_RED("You are already sleeping."))
		return
	var/found = FALSE
	for (var/obj/structure/bed/B in get_turf(src))
		if (B)
			found = TRUE
	if (!found)
		to_chat(src, SPAN_RED("You need to be over a bed."))
		return
	var/sleep_message = "Are you sure you want to sleep for a while? This will protect you when disconnected, but you must stay ingame for 2 minutes for it to take effect."
	if (persistence_bed_return_enabled())
		sleep_message = "Sleep here and assign this bed for saved-character returns? This takes two minutes. Your body stays here and can be harmed. Only a completed world save preserves it on disk."
	if (WWinput(src, sleep_message, "Sleep", "Yes", list("Yes","No")) == "Yes")
		to_chat(src, SPAN_NOTICE("You will start sleeping in two minutes."))
		return do_after(src, 2 MINUTES, src, FALSE)
