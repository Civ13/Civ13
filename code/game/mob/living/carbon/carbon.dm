/mob/living/human/New()
	//setup reagent holders
	bloodstr = new/datum/reagents/metabolism(1000, src, CHEM_BLOOD)
	ingested = new/datum/reagents/metabolism(1000, src, CHEM_INGEST)
	touching = new/datum/reagents/metabolism(1000, src, CHEM_TOUCH)
	reagents = bloodstr
	..()

/mob/living/human/Life()
	..()

	// Increase germ_level regularly
	if (germ_level < GERM_LEVEL_AMBIENT && prob(30))	//if you're just standing there, you shouldn't get more germs beyond an ambient level
		germ_level++

/mob/living/human/Destroy()
	qdel(ingested)
	qdel(touching)
	// We don't qdel(bloodstr) because it's the same as qdel(reagents)
	for (var/guts in internal_organs)
		qdel(guts)
	for (var/food in stomach_contents)
		qdel(food)
	return ..()

/mob/living/human/rejuvenate()
	bloodstr.clear_reagents()
	ingested.clear_reagents()
	touching.clear_reagents()
	nutrition = 400
	..()


/mob/living/human/relaymove(var/mob/living/user, direction)
	if ((user in stomach_contents) && istype(user))
		if (user.last_special <= world.time)
			user.last_special = world.time + 50
			visible_message("<span class='danger'>You hear something rumbling inside [src]'s stomach...</span>")
			var/obj/item/I = user.get_active_hand()
			if (I && I.force)
				var/d = rand(round(I.force / 4), I.force)
				if (istype(src, /mob/living/human))
					var/mob/living/human/H = src
					var/obj/item/organ/external/organ = H.get_organ("chest")
					if (istype(organ))
						if (organ.take_damage(d, FALSE))
							H.UpdateDamageIcon()
					H.updatehealth()
				else
					take_organ_damage(d)
				user.visible_message("<span class='danger'>[user] attacks [src]'s stomach wall with the [I.name]!</span>")

				if (prob(getBruteLoss() - 50))
					for (var/atom/movable/A in stomach_contents)
						A.loc = loc
						stomach_contents.Remove(A)
					gib()

/mob/living/human/gib()
	for (var/mob/M in src)
		if (M in stomach_contents)
			stomach_contents.Remove(M)
		M.loc = loc
		for (var/mob/N in viewers(src, null))
			if (N.client)
				N.show_message(text("<span class = 'red'><b>[M] bursts out of [src]!</b></span>"), 2)
	..()

/mob/living/human/attack_hand(mob/M as mob)
	if (!istype(M, /mob/living/human)) return
	if (ishuman(M))
		var/mob/living/human/H = M
		var/obj/item/organ/external/temp = H.organs_by_name["r_hand"]
		if (H.hand)
			temp = H.organs_by_name["l_hand"]
		if (temp && !temp.is_usable())
			H << "<span class = 'red'>You can't use your [temp.name].</span>"
			return

	return

/mob/living/human/electrocute_act(var/shock_damage, var/obj/source, var/siemens_coeff = 1.0, var/def_zone = null)
	if (status_flags & GODMODE)	return FALSE	//godmode
	shock_damage *= siemens_coeff
	if (shock_damage<1)
		return FALSE

	apply_damage(shock_damage, BURN, def_zone, used_weapon="Electrocution")
	playsound(loc, "sparks", 50, TRUE, -1)
	if (shock_damage > 15)
		visible_message(
			"<span class = 'red'>[src] was shocked by the [source]!</span>", \
			"<span class = 'red'><b>You feel a powerful shock course through your body!</b></span>", \
			"<span class = 'red'>You hear a heavy electrical crack.</span>" \
		)
		Stun(10)//This should work for now, more is really silly and makes you lay there forever
		Weaken(10)
	else
		visible_message(
			"<span class = 'red'>[src] was mildly shocked by the [source].</span>", \
			"<span class = 'red'>You feel a mild shock course through your body.</span>", \
			"<span class = 'red'>You hear a light zapping.</span>" \
		)

	var/datum/effect/effect/system/spark_spread/s = new /datum/effect/effect/system/spark_spread
	s.set_up(5, TRUE, loc)
	s.start()

	return shock_damage

/mob/living/human/swap_hand()
	hand = !( hand )
	for (var/obj/screen/inventory/hand/H in HUDinventory)
		H.update_icon()
	if (istype(src, /mob/living/human))
		var/mob/living/human/H = src
		if (H.using_look())
			look_into_distance(src, FALSE)
	return

/mob/living/human/proc/activate_hand(var/selhand) //0 or "r" or "right" for right hand; TRUE or "l" or "left" for left hand.

	if (istext(selhand))
		selhand = lowertext(selhand)

		if (selhand == "right" || selhand == "r")
			selhand = FALSE
		if (selhand == "left" || selhand == "l")
			selhand = TRUE

	if (selhand != hand)
		swap_hand()

/mob/living/human/proc/help_shake_act(mob/living/human/M)
	if (health >= config.health_threshold_crit)
		if (src == M && istype(src, /mob/living/human))
			var/mob/living/human/H = src
			H.exam_self()
			/*visible_message( \
				text("\blue [src] examines [].",gender==MALE?"himself":"herself"), \
				"\blue You check yourself for injuries." \
				)

			for (var/obj/item/organ/external/org in H.organs)
				var/list/status = list()
				var/brutedamage = org.brute_dam
				var/burndamage = org.burn_dam
				if (halloss > 0)
					if (prob(30))
						brutedamage += halloss
					if (prob(30))
						burndamage += halloss
				switch(brutedamage)
					if (1 to 20)
						status += "bruised"
					if (20 to 40)
						status += "wounded"
					if (40 to INFINITY)
						status += "mangled"

				switch(burndamage)
					if (1 to 10)
						status += "numb"
					if (10 to 40)
						status += "blistered"
					if (40 to INFINITY)
						status += "peeling away"

				if (org.is_stump())
					status += "MISSING"
				if (org.status & ORGAN_MUTATED)
					status += "weirdly shapen"
				if (org.dislocated == 2)
					status += "dislocated"
				if (org.status & ORGAN_BROKEN)
					status += "hurts when touched"
				if (org.status & ORGAN_DEAD)
					status += "is bruised and necrotic"
				if (!org.is_usable())
					status += "dangling uselessly"
				if (status.len)
					show_message("My [org.name] is <span class='warning'> [english_list(status)].</span>",1)
				else
					show_message("My [org.name] is <span class='notice'> OK.</span>",1)
			*/
		else if (on_fire)
			playsound(loc, 'sound/weapons/thudswoosh.ogg', 50, TRUE, -1)
			if (M.on_fire)
				M.visible_message("<span class='warning'>[M] tries to pat out [src]'s flames, but to no avail!</span>",
				"<span class='warning'>You try to pat out [src]'s flames, but to no avail! Put yourself out first!</span>")
			else
				M.visible_message("<span class='warning'>[M] tries to pat out [src]'s flames!</span>",
				"<span class='warning'>You try to pat out [src]'s flames! Hot!</span>")
				if (do_mob(M, src, 15))
					fire_stacks -= 0.5
					if (prob(10) && (M.fire_stacks <= 0))
						M.fire_stacks += 1
					M.IgniteMob()
					if (M.on_fire)
						M.visible_message("<span class='danger'>The fire spreads from [src] to [M]!</span>",
						"<span class='danger'>The fire spreads to you as well!</span>")
					else
						fire_stacks -= 0.5 //Less effective than stop, drop, and roll - also accounting for the fact that it takes half as long.
						if (fire_stacks <= 0)
							M.visible_message("<span class='warning'>[M] successfully pats out [src]'s flames.</span>",
							"<span class='warning'>You successfully pat out [src]'s flames.</span>")
							ExtinguishMob()
							fire_stacks = FALSE
		else
			var/t_him = "it"
			if (gender == MALE)
				t_him = "him"
			else if (gender == FEMALE)
				t_him = "her"
			if (istype(src,/mob/living/human) && src:w_uniform)
				var/mob/living/human/H = src
				H.w_uniform.add_fingerprint(M)

			var/show_ssd
			var/mob/living/human/H = src
			if (istype(H)) show_ssd = H.species.show_ssd
			if (show_ssd && !client && !teleop)
				M.visible_message("<span class='notice'>[M] shakes [src] trying to wake [t_him] up!</span>", \
				"<span class='notice'>You shake [src], but they do not respond... Maybe they have shell shock?</span>")
			else if (lying || sleeping)
				sleeping = max(0,sleeping-5)
				if (!sleeping)
					resting = 0
				M.visible_message("<span class='notice'>[M] shakes [src] trying to wake [t_him] up!</span>", \
									"<span class='notice'>You shake [src] trying to wake [t_him] up!</span>")
			else
				var/mob/living/human/hugger = M
				if (istype(hugger))
					hugger.species.hug(hugger,src)
				else
					M.visible_message("<span class='notice'>[M] hugs [src] to make [t_him] feel better!</span>", \
								"<span class='notice'>You hug [src] to make [t_him] feel better!</span>")
				if (M.fire_stacks >= (fire_stacks + 3))
					fire_stacks += 1
					M.fire_stacks -= 1
				if (M.on_fire)
					IgniteMob()
			AdjustParalysis(-3)
			AdjustStunned(-3)
			AdjustWeakened(-3)

			playsound(loc, 'sound/weapons/thudswoosh.ogg', 50, TRUE, -1)

/mob/living/human/proc/eyecheck()
	return FALSE

// ++++ROCKDTBEN++++ MOB PROCS -- Ask me before touching.
// Stop! ... Hammertime! ~Carn

/mob/living/human/proc/getDNA()
	return dna

/mob/living/human/proc/setDNA(var/datum/dna/newDNA)
	return
//	dna = newDNA

// ++++ROCKDTBEN++++ MOB PROCS //END

/mob/living/human/clean_blood()
	. = ..()
	if (ishuman(src))
		var/mob/living/human/H = src
		if (H.gloves)
			if (H.gloves.clean_blood())
				H.update_inv_gloves(0)
			H.gloves.germ_level = FALSE
		else
			if (H.bloody_hands)
				H.bloody_hands = FALSE
				H.update_inv_gloves(0)
			H.germ_level = FALSE
	update_icons()	//apply the now updated overlays to the mob

//Throwing stuff
/mob/proc/throw_item(atom/target)
	return

/mob/living/human/throw_item(atom/target)

	throw_mode_off()

	if (usr.stat || !target)
		return

	if (target.type == /obj/screen) return

	var/atom/movable/item = get_active_hand()

	if (!item) return

	// hack to stop people from throwing molotovs over the grace wall - Kachnov
	if (ishuman(src) && !istype(get_area(src), /area/caribbean/admin))
		var/mob/living/human/H = src
		if (H.original_job)
			if (istype(item, /obj/item/weapon/reagent_containers/food/drinks/bottle))
				var/obj/item/weapon/reagent_containers/food/drinks/bottle/B = item
				if (B.rag && B.rag.on_fire)
					var/nothrow = FALSE
					if (map.ID == MAP_OCCUPATION)
						return
					else if (map && !map.faction1_can_cross_blocks() && H.faction_text == map.faction1)
						nothrow = TRUE
					else if (map && !map.faction2_can_cross_blocks() && H.faction_text == map.faction2)
						nothrow = TRUE
					if (nothrow)
						src << "<span class = 'danger'>You can't throw a molotov yet.</span>"
						return

	if (istype(item, /obj/item/weapon/grab))
		var/obj/item/weapon/grab/G = item
		item = G.throw_held() //throw the person instead of the grab
		if (ismob(item))
			var/turf/start_T = get_turf(loc) //Get the start and target tile for the descriptors
			var/turf/end_T = get_turf(target)
			if (start_T && end_T)
				var/mob/M = item
				var/start_T_descriptor = "<font color='#6b5d00'>tile at [start_T.x], [start_T.y], [start_T.z] in area [get_area(start_T)]</font>"
				var/end_T_descriptor = "<font color='#6b4400'>tile at [end_T.x], [end_T.y], [end_T.z] in area [get_area(end_T)]</font>"

				M.attack_log += text("\[[time_stamp()]\] <font color='orange'>Has been thrown by [usr.name] ([usr.ckey]) from [start_T_descriptor] with the target [end_T_descriptor]</font>")
				usr.attack_log += text("\[[time_stamp()]\] <font color='red'>Has thrown [M.name] ([M.ckey]) from [start_T_descriptor] with the target [end_T_descriptor]</font>")
				msg_admin_attack("[usr.name] ([usr.ckey]) has thrown [M.name] ([M.ckey]) from [start_T_descriptor] with the target [end_T_descriptor] (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[usr.x];Y=[usr.y];Z=[usr.z]'>JMP</a>)")

	if (!item || item.nothrow) return //Grab processing has a chance of returning null

	var/throwtime_divider = 4
	if (istype(item, /obj/item/weapon/material/thrown))
		var/mob/living/human/H = src
		H.adaptStat("throwing", 0.05)
	else if (isitem(item))
		var/mob/living/human/H = src
		var/obj/item/I = item
		switch (I.w_class)
			if (2)
				throwtime_divider *= 3 + H.getStat("throwing")/100
			if (3)
				throwtime_divider *= 2 + H.getStat("throwing")/100
			if (4)
				throwtime_divider *= 1 + H.getStat("throwing")/100
			if (5)
				throwtime_divider *= 0.5 + H.getStat("throwing")/100
	else if (ismob(item))
		var/mob/living/human/H = src
		throwtime_divider *= 0.5 + H.getStat("throwing")/100
	//actually throw it!

	visible_message("<span class = 'warning'>[src] prepares to throw \the [item]!</span>")
	if (item && do_after(src, max(1, round(abs_dist(src, target)/throwtime_divider)), get_turf(src)))
		playsound(src, 'sound/effects/throw.ogg', 50, TRUE)
		remove_from_mob(item)
		item.loc = loc
		visible_message("<span class = 'warning'>[src] throws \the [item]!</span>")
		if (istype(item, /obj/item/ammo_casing))
			var/obj/item/ammo_casing/NI = item
			NI.randomrotation()

		if (ismob(item))
			for (var/obj/item/weapon/grab/G in contents)
				if (G.affecting == item)
					qdel(G)
					break

		if (!lastarea)
			lastarea = get_area(loc)
		if (lastarea.has_gravity == FALSE)
			inertia_dir = get_dir(target, src)
			step(src, inertia_dir)



		/* 2 throw range for mobs, MGs
		 * 4 throw range for smgs
		 * old max throw range was 7, now its 11 - Kachnov */
		var/throw_range = 2
		if (isitem(item))
			var/obj/item/I = item
			throw_range = 12 - (I.w_class * 2)

		item.throw_at(target, throw_range, item.throw_speed, src)

/mob/living/human/fire_act(temperature)
	..()
	var/temp_inc = max(min(BODYTEMP_HEATING_MAX*(1-get_heat_protection()), temperature - bodytemperature), FALSE)
	bodytemperature += temp_inc

/mob/living/human/can_use_hands()
	if (handcuffed)
		return FALSE
	if (buckled && !istype(buckled, /obj/structure/bed/chair)) // buckling does not restrict hands
		return FALSE
	return TRUE

/mob/living/human/restrained()
	if (handcuffed)
		return TRUE
	return FALSE

/mob/living/human/u_equip(obj/item/W as obj)
	if (!W)	return FALSE

	else if (W == handcuffed)
		handcuffed = null
		update_inv_handcuffed()
		if (buckled && buckled.buckle_require_restraints)
			buckled.unbuckle_mob()

	else if (W == legcuffed)
		legcuffed = null
		update_inv_legcuffed()
	else
	 ..()

	return

/mob/living/human/Bump(var/atom/movable/AM, yes)
	if (istype(AM, /obj/item/football))
		var/obj/item/football/FB = AM
		if (!FB.owner && !src.football)
			FB.owner = src
			FB.last_owner = src
			src.football = FB
			FB.update_movement()
	else if (istype(AM, /mob/living/human))
		var/mob/living/human/HM = AM
		if (HM.civilization != src.civilization && (HM.dir == OPPOSITE_DIR(src.dir) || findtext(HM.original_job_title, "goalkeeper") || findtext(src.original_job_title, "goalkeeper")))
			if (src.football)
				src.football.last_owner = src
				src.football.owner = null
				src.football = null
				visible_message("[src] bumps into [HM] and loses control of the ball!")
			else if (HM.football)
				HM.football.last_owner = HM
				HM.football.owner = null
				HM.football = null
				visible_message("[HM] bumps into [src] and loses control of the ball!")
	if (now_pushing || !yes)
		return
	..()

/mob/living/human/slip(var/slipped_on,stun_duration=8)
	if (buckled)
		return FALSE
	stop_pulling()
	src << "<span class='warning'>You slipped on [slipped_on]!</span>"
	playsound(loc, 'sound/misc/slip.ogg', 50, TRUE, -3)
	Stun(stun_duration)
	Weaken(Floor(stun_duration/2))
	return TRUE

/mob/living/human/proc/add_chemical_effect(var/effect, var/magnitude = 1)
	if (effect in chem_effects)
		chem_effects[effect] += magnitude
	else
		chem_effects[effect] = magnitude

/mob/living/human/get_default_language()
	if (default_language)
		return default_language

	if (!species)
		return null
	return species.default_language ? all_languages[species.default_language] : null

/mob/living/human/show_inv(mob/user as mob)
	if(user.incapacitated()  || !user.Adjacent(src))
		return
	user.set_using_object(src)
	var/dat = {"
	<b><HR><FONT size=3>[name]</FONT></b>
	<BR><HR>
	<BR><b>Head(Mask):</b> <A href='?src=\ref[src];item=mask'>[(wear_mask ? wear_mask : "Nothing")]</A>
	<BR><b>Left Hand:</b> <A href='?src=\ref[src];item=l_hand'>[(l_hand ? l_hand  : "Nothing")]</A>
	<BR><b>Right Hand:</b> <A href='?src=\ref[src];item=r_hand'>[(r_hand ? r_hand : "Nothing")]</A>
	<BR><b>Back:</b> <A href='?src=\ref[src];item=back'>[(back ? back : "Nothing")]</A>
	<BR><A href='?src=\ref[src];item=pockets'>Empty Pockets</A>
	<BR><A href='?src=\ref[user];refresh=1'>Refresh</A>
	<BR><A href='?src=\ref[user];mach_close=mob[name]'>Close</A>
	<BR>"}
	user << browse(dat, text("window=mob[];size=325x500", name))
	onclose(user, "mob[name]")
	return

/mob/living/human/proc/get_fullness()
	return (nutrition + (reagents.get_reagent_amount("nutriment") * 25)) + 160