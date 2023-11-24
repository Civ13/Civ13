/obj/item/weapon/grenade/smokebomb
	desc = "It is set to detonate in 2 seconds."
	name = "smoke grenade"
	icon = 'icons/obj/grenade.dmi'
	icon_state = "smoke_grenade"
	det_time = 20
	item_state = "smoke_grenade"
	slot_flags = SLOT_BELT
	var/datum/effect/effect/system/smoke_spread/bad/smoke

/obj/item/weapon/grenade/smokebomb/New()
	..()
	smoke = PoolOrNew(/datum/effect/effect/system/smoke_spread/bad)
	smoke.attach(src)

/obj/item/weapon/grenade/smokebomb/Destroy()
	qdel(smoke)
	smoke = null
	return ..()

/obj/item/weapon/grenade/smokebomb/prime()
	if (active)
		playsound(loc, 'sound/effects/smoke.ogg', 50, TRUE, -3)
		smoke.set_up(10, FALSE, usr ? usr.loc : loc)
		spawn(0)
			smoke.start()
			sleep(10)
			smoke.start()
			sleep(10)
			smoke.start()
			sleep(10)
			smoke.start()

		sleep(80)
		qdel(src)
		return

/obj/item/weapon/grenade/smokebomb/fast_activate()
	spawn(round(det_time/10))
		visible_message(SPAN_WARNING("\The [src] goes off!"))
		active = TRUE
		prime()

/obj/item/weapon/grenade/smokebomb/m18smoke
	desc = "It is set to detonate in 3 seconds."
	name = "M18 smoke grenade"
	icon_state = "m18smoke"
	det_time = 30
	item_state = "m18smoke"

/obj/item/weapon/grenade/smokebomb/rdg1
	desc = "It is set to detonate in 4 seconds."
	name = "RDG-1 smoke grenade"
	icon_state = "rdg1"
	det_time = 40
	item_state = "rdg1"

/obj/item/weapon/grenade/smokebomb/rdg2
	desc = "It is set to detonate in 3 seconds."
	name = "RDG-2 smoke grenade"
	icon_state = "rdg2"
	det_time = 30
	item_state = "rdg2"

//////////Signal Smoke//////////////////////////////////////////

/obj/item/weapon/grenade/smokebomb/signal
	desc = "It is set to detonate in 5 seconds. A helicopter will drop a crate of supplies at its location."
	name = "M18 signal smoke grenade (supplies)"
	icon_state = "m18smoke_purple"
	det_time = 50
	item_state = "m18smoke_purple"
	var/smoke_color = /datum/effect/effect/system/smoke_spread/purple
	var/list/things_to_spawn
	var/triggered = FALSE

/obj/item/weapon/grenade/smokebomb/signal/New()
	..()
	smoke = PoolOrNew(smoke_color)
	smoke.attach(src)

/obj/item/weapon/grenade/smokebomb/signal/Destroy()
	qdel(smoke)
	smoke = null
	return ..()

/obj/item/weapon/grenade/smokebomb/signal/attack_self(mob/living/human/user as mob)
	if (!active)
		switch (user.faction_text)
			if (AMERICAN)
				if (time_of_day != "Night")
					var/list/options = list()
					options["Ammunition"] = list(/obj/structure/closet/crate/ww2/vietnam/us_ammo)
					options["Medical supplies"] = list(/obj/structure/closet/crate/ww2/vietnam/us_medical)
					options["Explosives"] = list(/obj/structure/closet/crate/ww2/vietnam/us_explosives)
					options["Engineering supplies"] = list(/obj/structure/closet/crate/ww2/vietnam/us_engineering)
					options["AP mines"] = list(/obj/structure/closet/crate/ww2/vietnam/us_ap_mines)
					var/choice = input(user,"What type of supply drop?") as null|anything in options
					if(src && choice)
						things_to_spawn = options[choice]
						user << "<span class='warning'>You light \the [name]! [det_time/10] seconds!</span>"
						firer = user
						activate(user)
						add_fingerprint(user)
						if (ishuman(user))
							var/mob/living/human/H = user
							if(istype(H) && !H.in_throw_mode)
								H.throw_mode_on()
						triggered = TRUE
				else
					visible_message("<span class = 'danger'>There is no sufficient visibility for a supply drop!</span>")
			if (DUTCH)
				if (time_of_day != "Night")
					var/list/options = list()
					options["Ammunition"] = list(/obj/structure/closet/crate/ww2/un/m16ammo)
					options["Medical supplies"] = list(/obj/structure/closet/crate/ww2/airdrops/medical)
					options["Engineering supplies"] = list(/obj/structure/closet/crate/ww2/airdrops/engineering)
					options["Area denial"] = list(/obj/structure/closet/crate/ww2/airdrops/ap)
					options["FOB Supply Crate"] = list(/obj/structure/supply_crate/faction1)
					var/choice = input(user,"What type of supply drop?") as null|anything in options
					if(src && choice)
						things_to_spawn = options[choice]
						user << "<span class='warning'>You light \the [name]! [det_time/10] seconds!</span>"
						firer = user
						activate(user)
						add_fingerprint(user)
						if (ishuman(user))
							var/mob/living/human/H = user
							if(istype(H) && !H.in_throw_mode)
								H.throw_mode_on()
						triggered = TRUE
				else
					visible_message("<span class = 'danger'>There is no sufficient visibility for a supply drop!</span>")
			if (RUSSIAN)
				if (time_of_day != "Night")
					var/list/options = list()
					options["Ammunition"] = list(/obj/structure/closet/crate/ww2/russian/ammo)
					options["Medical supplies"] = list(/obj/structure/closet/crate/ww2/airdrops/medical)
					options["Engineering supplies"] = list(/obj/structure/closet/crate/ww2/airdrops/engineering)
					options["Area denial"] = list(/obj/structure/closet/crate/ww2/airdrops/ap)
					options["FOB Supply Crate"] = list(/obj/structure/supply_crate/faction2)
					var/choice = input(user,"What type of supply drop?") as null|anything in options
					if(src && choice)
						things_to_spawn = options[choice]
						user << "<span class='warning'>You light \the [name]! [det_time/10] seconds!</span>"
						firer = user
						activate(user)
						add_fingerprint(user)
						if (ishuman(user))
							var/mob/living/human/H = user
							if(istype(H) && !H.in_throw_mode)
								H.throw_mode_on()
						triggered = TRUE	
				else
					visible_message("<span class = 'danger'>There is no sufficient visibility for a supply drop!</span>")
			else
				firer = user
				activate(user)
				add_fingerprint(user)
				if (ishuman(user))
					var/mob/living/human/H = user
					if(istype(H) && !H.in_throw_mode)
						H.throw_mode_on()

/obj/item/weapon/grenade/smokebomb/signal/prime(mob/living/human/user as mob)
	if (active)
		if (user)
			playsound(loc, 'sound/effects/smoke.ogg', 50, TRUE, -3)
			smoke.set_up(5, FALSE, usr ? usr.loc : loc)
			spawn(0)
				smoke.start()
			if (triggered)
				sleep(300)
				if (time_of_day != "Night")
					var/helicopter_name
					if (map.ID == MAP_ROAD_TO_DAK_TO || map.ID == MAP_COMPOUND || map.ID == MAP_HUE || map.ID == MAP_ONG_THAHN)
						new /obj/effect/helicopter_flyby/uh1(get_turf(src))
						helicopter_name = "US Army UH-1B helicopter"
					else if (user.faction_text == RUSSIAN)
						new /obj/effect/helicopter_flyby/mi8(get_turf(src))
						helicopter_name = "Russian Mil Mi-8 helicopter"
					else if (user.faction_text == DUTCH)
						new /obj/effect/helicopter_flyby/ch47(get_turf(src))
						helicopter_name = "Dutch Boeing CH-47 Chinook"
					else
						new /obj/effect/helicopter_flyby/uh60(get_turf(src))
						helicopter_name = "UH-60 Blackhawk helicopter"

					sleep(200)
					var/anti_air_in_range = FALSE
					for (var/obj/structure/milsim/anti_air/AA in range(60, get_turf(src)))
						if (AA.faction_text != user.faction_text)
							anti_air_in_range++
					if (anti_air_in_range)
						var/sound/sam_sound = sound('sound/effects/aircraft/sa6_sam_site.ogg', repeat = FALSE, wait = FALSE, channel = 777)
						sam_sound.priority = 250
						for (var/mob/M in player_list)
							if (!new_player_mob_list.Find(M))
								to_chat(M, SPAN_DANGER("<big>A SAM site fires at the [helicopter_name]!</big>"))
								M.client << sam_sound
						spawn(5 SECONDS)
							var/sound/uploaded_sound = sound((pick('sound/effects/aircraft/effects/metal1.ogg','sound/effects/aircraft/effects/metal2.ogg')), repeat = FALSE, wait = FALSE, channel = 777)
							uploaded_sound.priority = 250
							for (var/mob/M in player_list)
								if (!new_player_mob_list.Find(M))
									to_chat(M, SPAN_DANGER("<big>The SAM directly hits the [helicopter_name], shooting it down!</big>"))
									if (M.client)
										M.client << uploaded_sound
							
							message_admins("[helicopter_name] has been shot down.")
							log_game("[helicopter_name] has been shot down.")
					else
						for(var/new_type in things_to_spawn)
							new new_type(get_turf(src))
						visible_message(SPAN_NOTICE("A [helicopter_name] flies by and drops off a crate at the smoke's location."))
			sleep(20)
			qdel(src)
			return

/obj/item/weapon/grenade/smokebomb/signal/fast_activate()
	spawn(round(det_time/10))
		visible_message(SPAN_WARNING("\The [src] goes off!"))
		active = TRUE
		prime()
///////////////////////////////////////////////////////////////////////////////

/obj/item/weapon/grenade/smokebomb/signal/rdg2_yellow
	desc = "It is set to detonate in 5 seconds. A helicopter will drop a crate of supplies at its location."
	name = "RDG-2 yellow signal smoke grenade (supplies)"
	icon_state = "rdg2_yellow"
	det_time = 50
	item_state = "rdg2_yellow"
	smoke_color = /datum/effect/effect/system/smoke_spread/yellow

/obj/item/weapon/grenade/smokebomb/signal/m18_red
	desc = "It is set to detonate in 5 seconds. A helicopter will drop a crate of supplies at its location."
	name = "M18 signal smoke grenade (supplies)"
	icon_state = "m18smoke_red"
	det_time = 50
	item_state = "m18smoke_red"
	smoke_color = /datum/effect/effect/system/smoke_spread/red

///////////////////////////////////////////////////////////////////////////////

/obj/item/weapon/grenade/incendiary
	desc = "It is set to detonate in 6 seconds."
	name = "incendiary grenade"
	icon = 'icons/obj/grenade.dmi'
	icon_state = "incendiary"
	det_time = 60
	item_state = "incendiary"
	slot_flags = SLOT_BELT
	var/spread_range = 2

/obj/item/weapon/grenade/incendiary/incendiarydetonator
	name = "Incendiary Detonator"
	desc = "A grenade-like incendiary weapon popular among military personnel, criminals, bountyhunters, and mercenaries."
	icon_state = "detonator"
	det_time = 35
	throw_range = 12

/obj/item/weapon/grenade/incendiary/anm14
	name = "AN/M14 incendiary grenade"

/obj/item/weapon/grenade/incendiary/prime()
	if (active)
		var/turf/LT = get_turf(src)

		playsound(loc, 'sound/effects/smoke.ogg', 50, TRUE, -3)
		explosion(LT,0,1,1,3)

		if (!ismob(loc))
			for (var/turf/floor/T in circlerangeturfs(spread_range, LT))
				ignite_turf(T, 12, 35)
		else
			ignite_turf(LT, 12, 90)
		spawn(5)
			qdel(src)

/obj/item/weapon/grenade/incendiary/fast_activate()
	spawn(round(det_time/10))
		visible_message(SPAN_WARNING("\The [src] goes off!</span>"))
		active = TRUE
		prime()


/obj/item/weapon/grenade/chemical
	desc = "It is set to detonate in 5 seconds."
	name = "chemical grenade"
	icon = 'icons/obj/grenade.dmi'
	icon_state = "smoke_generic"
	det_time = 50
	item_state = "smoke_generic"
	slot_flags = SLOT_BELT
	var/datum/effect/effect/system/smoke_spread/bad/smoke
	var/stype = /datum/effect/effect/system/smoke_spread/bad

/obj/item/weapon/grenade/chemical/New()
	..()
	smoke = PoolOrNew(stype)
	smoke.attach(src)

/obj/item/weapon/grenade/chemical/Destroy()
	qdel(smoke)
	smoke = null
	return ..()

/obj/item/weapon/grenade/chemical/prime()
	if (active)
		playsound(loc, 'sound/effects/smoke.ogg', 50, TRUE, -3)
		smoke.set_up(10, FALSE, usr ? usr.loc : loc)
		spawn(0)
			smoke.start()
			sleep(10)
			smoke.start()
			sleep(10)
			smoke.start()
			sleep(10)
			smoke.start()

		sleep(80)
		qdel(src)
		return

/obj/item/weapon/grenade/chemical/fast_activate()
	spawn(round(det_time/10))
		visible_message(SPAN_WARNING("\The [src] goes off!</span>"))
		active = TRUE
		prime()

/obj/item/weapon/grenade/chemical/chlorine
	name = "chlorine gas grenade"
	stype = /datum/effect/effect/system/smoke_spread/bad/chem/payload/chlorine_gas

/obj/item/weapon/grenade/chemical/mustard
	name = "mustard gas grenade"
	stype = /datum/effect/effect/system/smoke_spread/bad/chem/payload/mustard_gas

/obj/item/weapon/grenade/chemical/phosgene
	name = "phosgene gas grenade"
	stype = /datum/effect/effect/system/smoke_spread/bad/chem/payload/phosgene

/obj/item/weapon/grenade/chemical/white_phosphorus
	name = "white phosphorus gas grenade"
	stype = /datum/effect/effect/system/smoke_spread/bad/chem/payload/white_phosphorus_gas

/obj/item/weapon/grenade/chemical/white_phosphorus/m34
	name = "M34 WP grenade"
	desc = "An American white phosphorus smoke grenade"
	icon_state = "m34wp"

/obj/item/weapon/grenade/chemical/xylyl_bromide
	name = "xylyl bromide gas grenade"
	stype = /datum/effect/effect/system/smoke_spread/bad/chem/payload/xylyl_bromide
	icon_state = "riot"
/obj/item/weapon/grenade/chemical/zyklon_b
	name = "Zyklon B gas grenade"
	stype = /datum/effect/effect/system/smoke_spread/bad/chem/payload/zyklon_b

/obj/item/weapon/grenade/chemical/cs_gas
	name = "CS gas grenade"
	stype = /datum/effect/effect/system/smoke_spread/bad/chem/payload/csgas

/obj/item/weapon/grenade/chemical/cs_gas/m7a2
	name = "M7A2 CS gas grenade"
	desc = "An American riot control CS hand grenade used to control counter-insurgencies and for other tactical missions."
	icon_state = "m7a2"

/obj/item/weapon/grenade/chemical/cs_gas/k51
	name = "K51 CS gas grenade"
	desc = "A Soviet riot control CS hand grenade used to control counter-insurgencies and for other tactical missions."
	icon_state = "k51"
	
/obj/item/weapon/grenade/smokebomb/ugl/attack_self(mob/user)
	return

/obj/item/weapon/grenade/smokebomb/ugl/shell40mm
	name = "40x46mm 'M676' grenade shell"
	desc = "Special smoke round designed for use in an underbarrel grenade launcher. Cannot be manually throwed."
	icon_state = "M406s"

/obj/item/weapon/grenade/smokebomb/ugl/vog25
	name = "40x103mm 'GRD-50' grenade shell"
	desc = "Special smoke round designed for use in an underbarrel grenade launcher. Cannot be manually throwed."
	icon_state = "40x103mmshells"

/obj/item/weapon/grenade/chemical/ugl/attack_self(mob/user)
	return

/obj/item/weapon/grenade/chemical/ugl/teargas
	name = "tear gas grenade"
	desc = "Concentrated Capsaicin. Contents under pressure. Use with caution."
	icon_state = "M406s"
	stype = /datum/effect/effect/system/smoke_spread/bad/chem/payload/xylyl_bromide

