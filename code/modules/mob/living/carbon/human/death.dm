/mob/living/carbon/human/gib()
	if (client)
		client.movement_busy = FALSE
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
	for(var/mob/living/carbon/human/NB in view(6,src))
		if (!NB.orc)
			NB.mood -= 15
			NB.ptsd += 3
/mob/living/carbon/human/crush()

	sleep(1)

	for (var/obj/item/I in contents)
		if (!istype(I, /obj/item/organ))
			drop_from_inventory(I)
	if (client)
		client.movement_busy = FALSE
	..(species.gibbed_anim)
	gibs(loc, null, species.flesh_color, species.blood_color)

/mob/living/carbon/human/maim()
	next_emote["vocal"] = world.time + 50
	..()
	next_emote["vocal"] = world.time - 1
	emote("painscream")

/mob/living/carbon/human/death(gibbed = FALSE)

	if (stat == DEAD) return
	if (map && map.ID == MAP_GLADIATORS && client)
		var/obj/map_metadata/gladiators/GD = map
		for (var/i = 1, i <= GD.gladiator_stats.len, i++)
			if (GD.gladiator_stats[i][1] == client.ckey && GD.gladiator_stats[i][2] == name)
				GD.gladiator_stats[i][4] = 1
				GD.save_gladiators()
		src << "<big><b>[name]'s life fades away into history...</b></big>"
	src << browse(null, "window=memory")

	if (client)
		client.movement_busy = FALSE

	//Handle species-specific deaths.
	species.handle_death(src)


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
