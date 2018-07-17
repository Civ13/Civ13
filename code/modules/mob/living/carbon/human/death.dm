/mob/living/carbon/human/gib()

	ghostize() // preserve our body's icon before it explodes

	for (var/obj/item/organ/I in internal_organs)
		I.removed()
		if (istype(loc,/turf))
			I.throw_at(get_edge_target_turf(src,pick(alldirs)),rand(1,3),30)

	for (var/obj/item/organ/external/E in organs)
		E.droplimb(0,DROPLIMB_EDGE,1)

	sleep(1)

	for (var/obj/item/I in src)
		drop_from_inventory(I)
		I.throw_at(get_edge_target_turf(src,pick(alldirs)), rand(1,3), round(30/I.w_class))

	..(species.gibbed_anim)
	gibs(loc, null, species.flesh_color, species.blood_color)

/mob/living/carbon/human/crush()

	sleep(1)

	for (var/obj/item/I in contents)
		if (!istype(I, /obj/item/organ))
			drop_from_inventory(I)

	..(species.gibbed_anim)
	gibs(loc, null, species.flesh_color, species.blood_color)

/mob/living/carbon/human/maim()
	next_emote["vocal"] = world.time + 50
	..()
	next_emote["vocal"] = world.time - 1
	emote("scream")

/mob/living/carbon/human/dust()
	if (species)
		..(species.dusted_anim, species.remains_type)
	else
		..()

/mob/living/carbon/human/death(gibbed = FALSE)

	if (stat == DEAD) return

	src << browse(null, "window=memory")

	if (original_job)
		switch (original_job.base_type_flag())
			if (GERMAN)
				++processes.battle_report.german_deaths_this_cycle
			if (SOVIET)
				++processes.battle_report.soviet_deaths_this_cycle

	//Handle species-specific deaths.
	species.handle_death(src)

	animate_tail_stop()

	callHook("death", list(src, gibbed))

	if (l_hand) unEquip(l_hand)
	if (r_hand) unEquip(r_hand)
/*
	if (ticker && ticker.mode)

		ticker.mode.check_win()*/

	if (client)
		client.next_normal_respawn = world.realtime + (map ? map.respawn_delay : 3000)
		client << RESPAWN_MESSAGE

	. = ..(gibbed)//,species.death_message)
	if (!gibbed)
		handle_organs()
		if (species.death_sound)
			playsound(loc, species.death_sound, 80, TRUE, TRUE)
	handle_hud_list()

/mob/living/carbon/human/proc/ChangeToHusk()
	if (HUSK in mutations)	return

	if (f_style)
		f_style = "Shaved"		//we only change the icon_state of the hair datum, so it doesn't mess up their UI/UE
	if (h_style)
		h_style = "Bald"
	update_hair(0)

	mutations.Add(HUSK)
	status_flags |= DISFIGURED	//makes them unknown without fucking up other stuff like admintools
	update_body(1)
	return

/mob/living/carbon/human/proc/Drain()
	ChangeToHusk()
	mutations |= HUSK
	return

/mob/living/carbon/human/proc/ChangeToSkeleton()
	if (SKELETON in mutations)	return

	if (f_style)
		f_style = "Shaved"
	if (h_style)
		h_style = "Bald"
	update_hair(0)

	mutations.Add(SKELETON)
	status_flags |= DISFIGURED
	update_body(0)
	return
