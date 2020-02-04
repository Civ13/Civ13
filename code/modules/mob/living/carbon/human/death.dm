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
	else if (map && map.ID == MAP_GULAG13 && client)
		var/obj/map_metadata/gulag13/GD = map
		if (original_job && istype(original_job, /datum/job/civilian/prisoner))
			var/datum/job/civilian/prisoner/PJ = original_job
			for(var/i in GD.points)
				if (i[1]==PJ.nationality)
					i[3]-=50

	var/list/poss_list = list()
	for(var/cmp in map.custom_company_nr)
		if (find_company_member(src,cmp))
			poss_list += cmp
	if (!isemptylist(poss_list))
		for(var/stocky in poss_list)
			for(var/list/lx in map.custom_company[stocky])
				if (lx[1] == src)
					map.sales_registry += list(list(stocky,lx[2],map.custom_company_value[stocky]*(lx[2]/100)*2,null,1))
			for(var/l=1, l <= map.custom_company[stocky].len, l++)
				if (map.custom_company[stocky][l][1] == src)
					map.custom_company[stocky][l][1] = null
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
