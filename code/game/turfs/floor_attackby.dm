/turf/floor
	var/busy = FALSE

/turf/floor/proc/collapse_check()
	return

/turf/floor/dirt/underground/collapse_check()
	spawn(50)
		if (get_area(src).location == AREA_INSIDE)
			//check for supports
			var/supportfound = FALSE
			var/supportcount = 0

			for (var/obj/structure/mine_support/RS in range(2))
				supportfound = TRUE

			for (var/turf/wall/W in range(1))
				supportfound = TRUE

			for (var/turf/TT in range(1))
				if (get_area(TT).location == AREA_OUTSIDE)
					supportfound = TRUE

			for (var/turf/floor/dirt/underground/U in get_turf(locate(x-1,y,z)))
				supportcount++
			for (var/turf/floor/dirt/underground/U in get_turf(locate(x+1,y,z)))
				supportcount++
			for (var/turf/floor/dirt/underground/U in get_turf(locate(x,y+1,z)))
				supportcount++
			for (var/turf/floor/dirt/underground/U in get_turf(locate(x,y-1,z)))
				supportcount++
			if (supportcount >= 3 && !supportfound)
				supportfound = TRUE

			//if no support >> cave starts to fall
			if (!supportfound)
				if (prob(80))
					visible_message("The mine is unstable! Some rocks get loose and fall around!")
					playsound(src,'sound/effects/rocksfalling.ogg',75,0,2)
					for (var/mob/living/human/M in range(1, src))
						M.adjustBruteLoss(rand(9,21))
						M.Weaken(12)
					var/turf/floor/dirt/underground/DT = get_turf(src)
					if (!istype(DT, /turf/floor/dirt/underground))
						DT.ChangeTurf(/turf/floor/dirt/underground/empty)
				else
					visible_message("The mine starts to cave in!")
					playsound(src,'sound/effects/rocksfalling.ogg',100,0,6)
					for (var/mob/living/human/M in range(2, src))
						M.adjustBruteLoss(rand(28,39))
						M.Weaken(23)
					for (var/turf/floor/UT in range (1))
						if (!istype(UT, /turf/floor/dirt/underground))
							UT.ChangeTurf(/turf/floor/dirt/underground/empty)
					new/obj/effect/effect/smoke(src)
			/*var/area/A = get_area(src) //Removed this, caused a very big glitch, this code seems unnecessary.
			if (supportfound)
				if(map.ID == MAP_NOMADS_DESERT)
					ChangeTurf(/turf/floor/dirt/dust)
				else if (A.climate == "jungle" || A.climate == "savanna")
					ChangeTurf(/turf/floor/dirt/jungledirt)
				else
					ChangeTurf(/turf/floor/dirt)*/

/turf/floor/attackby(obj/item/C as obj, mob/user as mob)

	if (!C || !user)
		return FALSE

	if (istype(src, /turf/floor/beach/water))
		var/turf/floor/beach/water/WT = src
		if (istype(C, /obj/item/weapon/reagent_containers/glass) || istype(C, /obj/item/weapon/reagent_containers/food/drinks))
			var/obj/item/weapon/reagent_containers/RG = C
			if (istype(RG) && RG.is_open_container())
				if (do_after(user, 15, src, check_for_repeats = FALSE))
					var/sumex = 0
					if (WT.sickness > 0)
						RG.reagents.add_reagent("cholera", min(RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this)*(WT.sickness*0.05))
						sumex += min(RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this)*(WT.sickness*0.05)
					if (WT.salty)
						RG.reagents.add_reagent("sodiumchloride", min(RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this)*0.04)
						sumex += min(RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this)*0.04
					var/watertype = "water"
					if (radiation > 0)
						watertype = "irradiated_water"
					RG.reagents.add_reagent(watertype, min(RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this)-sumex)
					user.visible_message("<span class='notice'>[user] fills \the [RG] with water.</span>","<span class='notice'>You fill \the [RG] with water.</span>")
					playsound(user, 'sound/effects/watersplash.ogg', 100, TRUE)
					user.setClickCooldown(5)
				return
		if (istype(C, /obj/item/clothing) && !busy)
			var/obj/item/clothing/CL = C
			usr << "<span class='notice'>You start washing \the [C].</span>"
			var/turf/location = user.loc

			busy = TRUE
			sleep(40)
			busy = FALSE

			if (user.loc != location) return				//User has moved
			if (!C) return 								//Item's been destroyed while washing
			if (user.get_active_hand() != C) return		//Person has switched hands or the item in their hands

			CL.clean_blood()
			CL.radiation = 0
			CL.dirtyness = 0
			CL.fleas = FALSE
			user.visible_message( \
				"<span class='notice'>[user] washes \a [C] using \the [src].</span>", \
				"<span class='notice'>You wash \a [C] using \the [src].</span>")

	if (istype(src, /turf/floor/dirt))
		if (C.fertilizer_value > 0)
			user << "You start fertilizing the dirt..."
			var/mob/living/human/H = user
			var/turf/floor/dirt/D = src
			if (do_after(user, 60/H.getStatCoeff("farming"), src))
				user << "You fertilize the dirt around this plot."
				for (D in range(1,src))
					if(D.soil_nutrition + C.fertilizer_value <= D.max_soil_nutrition) // Do not let players over fertilize the dirt
						D.soil_nutrition += C.fertilizer_value
					else
						D.soil_nutrition = D.max_soil_nutrition // Capped at max soil nutrition
				if (istype(C, /obj/item/stack/dung))
					C.amount--
					if (C.amount <= 0)
						qdel(C)
				else
					qdel(C)
				if (ishuman(user))
					H.adaptStat("farming", 1)
				return

	if ((flooring && istype(C, /obj/item/stack/rods)))
		return ..(C, user)

	else if (istype(C, /obj/item/weapon/reagent_containers/food/drinks))
		if (user.a_intent == I_HARM)
			if (istype(C, /obj/item/weapon/reagent_containers/food/drinks/bottle))
				var/obj/item/weapon/reagent_containers/food/drinks/bottle/B = C
				if (B.rag)
					return
			visible_message("<span class='notice'>\The [user] tips the contents of \the [C] on \the [src].</span>")
			if (C.reagents.has_reagent("petroleum", 5))
				new/obj/effect/decal/cleanable/blood/oil(user.loc)
			if (C.reagents.has_reagent("gasoline", 5))
				new/obj/effect/decal/cleanable/blood/oil(user.loc)
			if (C.reagents.has_reagent("diesel", 10))
				new/obj/effect/decal/cleanable/blood/oil(user.loc)
			if (C.reagents.has_reagent("biodiesel", 10))
				new/obj/effect/decal/cleanable/blood/oil(user.loc)
			if (C.reagents.has_reagent("olive_oil", 15))
				new/obj/effect/decal/cleanable/blood/oil(user.loc)
			if (C.reagents.has_reagent("water", 75))
				new/obj/effect/flooding(user.loc)
			if (C.reagents.has_reagent("water", 50))
				new/obj/effect/flooding(user.loc)
			if (C.reagents.has_reagent("water", 25))
				new/obj/effect/flooding(user.loc)
			var/obj/item/weapon/reagent_containers/food/drinks/DK = C
			DK.proper_spill(src, DK.reagents.total_volume)
			C.reagents.clear_reagents()
			C.update_icon()
			C.reagents.del_reagent("cholera")
			return

	else if (istype(C, /obj/item/weapon/material/shovel) || istype(C, /obj/item/weapon/material/kitchen/utensil/spoon))
		var/turf/T = get_turf(src)
		var/mob/living/human/H = user
		var/obj/item/weapon/material/shovel/SH = C
		if (H.a_intent != I_DISARM)

			if (T.icon == 'icons/turf/snow.dmi' && istype(H) && !H.shoveling_snow)
				if (T.available_snow >= 1)
					H.shoveling_snow = TRUE
					visible_message("<span class = 'notice'>[user] starts to shovel snow into a pile.</span>", "<span class = 'notice'>You start to shovel snow into a pile.</span>")
					playsound(src,'sound/effects/shovelling.ogg',100,1)
					if (do_after(user, (80/(H.getStatCoeff("strength"))/SH.usespeed)))
						visible_message("<span class = 'notice'>[user] shovels snow into a pile.</span>", "<span class = 'notice'>You shovel snow into a pile.</span>")
						H.shoveling_snow = FALSE
						H.adaptStat("strength", 1)
						T.available_snow -= 1
						new /obj/item/weapon/snowwall(T)
						if (T.available_snow <= 0)
							if (istype(T, /turf/floor/winter/grass))
								T.ChangeTurf(/turf/floor/grass)
							else if (istype(T, /turf/floor/dirt/winter))
								T.ChangeTurf(/turf/floor/dirt)

					else
						H.shoveling_snow = FALSE
				else
					user << "<span class='notice'>All the loose snow has been shoveled out of this spot already.</span>"

			else if (istype(T, /turf/floor/dirt) && istype(H) && !H.shoveling_dirt)
				if (T.available_dirt >= 1)
					H.shoveling_dirt = TRUE
					visible_message("<span class = 'notice'>[user] starts to shovel dirt into a pile.</span>", "<span class = 'notice'>You start to shovel dirt into a pile.</span>")
					playsound(src,'sound/effects/shovelling.ogg',100,1)
					if (do_after(user, (80/(H.getStatCoeff("strength"))/SH.usespeed)))
						visible_message("<span class = 'notice'>[user] shovels dirt into a pile.</span>", "<span class = 'notice'>You shovel dirt into a pile.</span>")
						H.shoveling_dirt = FALSE
						H.adaptStat("strength", 1)
						T.available_dirt -= 1
						new /obj/item/weapon/barrier(T)
					else
						H.shoveling_dirt = FALSE
				else
					user << "<span class='notice'>All the loose dirt has been shoveled out of this spot already.</span>"
			else if (istype(T, /turf/floor/beach/sand) && istype(H) && !H.shoveling_sand)
				if (T.available_sand >= 1)
					H.shoveling_sand = TRUE
					visible_message("<span class = 'notice'>[user] starts to shovel sand into a pile.</span>", "<span class = 'notice'>You start to shovel sand into a pile.</span>")
					playsound(src,'sound/effects/shovelling.ogg',100,1)
					if (do_after(user, (80/(H.getStatCoeff("strength"))/SH.usespeed)))
						visible_message("<span class = 'notice'>[user] shovels sand into a pile.</span>", "<span class = 'notice'>You shovel sand into a pile.</span>")
						H.shoveling_sand = FALSE
						H.adaptStat("strength", 1)
						T.available_sand -= 1
						new /obj/item/stack/ore/glass(T)
					else
						H.shoveling_sand = FALSE

			else
				return ..(C, user)
		else
			if (radiation >= 1 && (istype(src, /turf/floor/dirt) || istype(src, /turf/floor/grass)))
				visible_message("<span class = 'notice'>[user] starts to clean the irradiated soil.</span>", "<span class = 'notice'>You start to clean the irradiated soil.</span>")
				playsound(src,'sound/effects/shovelling.ogg',100,1)
				if (do_after(user, (150/(H.getStatCoeff("strength"))/SH.usespeed)))
					visible_message("<span class = 'notice'>[user] finishes cleaning the irradiated soil.</span>", "<span class = 'notice'>You finish cleaning the irradiated soil.</span>")
					H.adaptStat("strength", 1)
					radiation *= 0.1
					if (istype(src, /turf/floor/grass/jungle))
						src.ChangeTurf(/turf/floor/dirt/jungledirt)
					else
						src.ChangeTurf(/turf/floor/dirt)
					rad_act(0.01)
					update_icon()
			else
				return ..(C, user)
	else if (istype(C, /obj/item/weapon/poster/religious) && istype(get_turf(src), /turf/floor/dirt/underground))
		user << "You start placing the [C] on the [src]..."
		if (do_after(user, 70, src))
			visible_message("[user] places the [C] on the [src].")
			var/obj/structure/poster/religious/RP = new/obj/structure/poster/religious(get_turf(src))
			var/obj/item/weapon/poster/religious/P = C
			RP.religion = P.religion
			RP.symbol = P.symbol
			RP.color1 = P.color1
			RP.color2 = P.color2
			user.drop_from_inventory(C)
			qdel(C)
			return
	else if (istype(C, /obj/item/weapon/poster/faction) && istype(get_turf(src), /turf/floor/dirt/underground))
		user << "You start placing the [C] on the [src]..."
		if (do_after(user, 70, src))
			visible_message("[user] places the [C] on the [src].")
			var/obj/structure/poster/faction/RP = new/obj/structure/poster/faction(get_turf(src))
			var/obj/item/weapon/poster/faction/P = C
			RP.faction = P.faction
			RP.bstyle = P.bstyle
			RP.color1 = P.color1
			RP.color2 = P.color2
			user.drop_from_inventory(C)
			qdel(C)
			return
	else if (istype(C, /obj/item/weapon/material/pickaxe) || istype(C, /obj/item/weapon/material/kitchen/utensil))
		var/obj/item/weapon/material/pickaxe/SH = C
		var/turf/T = get_turf(src)
		var/mob/living/human/H = user
		if (istype(T, /turf/floor/dirt/underground) && istype(H))
			visible_message("<span class = 'notice'>[user] starts to break the rock with the [C.name].</span>", "<span class = 'notice'>You start to break the rock with the [C.name].</span>")
			playsound(src,'sound/effects/pickaxe.ogg',100,1)
			if (do_after(user, (320/(H.getStatCoeff("strength"))/SH.usespeed)))
				collapse_check()
				if (istype(src, /turf/floor/dirt/underground/empty))
					var/turf/floor/dirt/underground/empty/TT = src
					TT.mining_clear_debris()
					return
				else if (!istype(src, /turf/floor/dirt/underground/empty))
					mining_proc(H)
	else if (istype(C, /obj/item/weapon/reagent_containers/glass/extraction_kit))
		var/mob/living/human/H = user
		var/obj/item/weapon/reagent_containers/glass/extraction_kit/ET = C
		if (ET.reagents.total_volume > 0)
			H << "<span class = 'notice'>Empty \the [ET] first.</span>"
			return
		if (istype(H))
			visible_message("<span class = 'notice'>[user] carefully examines \the [src] with \the [C.name]...</span>", "<span class = 'notice'>You start to carefully examine \the [src] with \the [C.name].</span>")
			playsound(src,'sound/effects/pickaxe.ogg',100,1)
			var/timera = 110/(H.getStatCoeff("dexterity"))
			if (do_after(user, timera))
				extracting_proc(H, C)
		else
			return ..(C, user)

	else if (istype(C, /obj/item/weapon/barrier/sandbag))
		var/obj/item/weapon/barrier/sandbag/bag = C
		if (bag.sand_amount <= 0)
			user << "<span class = 'notice'>You need to fill the sandbag with sand first!</span>"

		var/sandbag_time = 50

		if (ishuman(user))
			var/mob/living/human/H = user
			sandbag_time /= H.getStatCoeff("strength")
			sandbag_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))

		if (src == get_step(user, user.dir))
			if (WWinput(user, "This will start building a sandbag wall [dir2text(user.dir)] of you.", "Sandbag Wall Construction", "Continue", list("Continue", "Stop")) == "Continue")
				visible_message("<span class='danger'>[user] starts constructing the base of a sandbag wall.</span>", "<span class='danger'>You start constructing the base of a sandbag wall.</span>")
				if (do_after(user, sandbag_time, user.loc))
					var/progress = bag.sand_amount
					qdel(C)
					var/obj/structure/window/barrier/sandbag/incomplete/sb = new/obj/structure/window/barrier/sandbag/incomplete(src, user)
					sb.progress = progress
					visible_message("<span class='danger'>[user] finishes constructing the base of a sandbag wall. Anyone can now add to it.</span>")
					if (ishuman(user))
						var/mob/living/human/H = user
						H.adaptStat("crafting", 3)
				return

	else if (istype(C, /obj/item/weapon/barrier))

		var/sandbag_time = 50

		if (ishuman(user))
			var/mob/living/human/H = user
			sandbag_time /= H.getStatCoeff("strength")
			sandbag_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))

		if (src == get_step(user, user.dir))
			if (WWinput(user, "This will start building a dirt barricade [dir2text(user.dir)] of you.", "Dirt Barricade Construction", "Continue", list("Continue", "Stop")) == "Continue")
				visible_message("<span class='danger'>[user] starts constructing the base of a dirt barricade.</span>", "<span class='danger'>You start constructing the base of a dirt barricade.</span>")
				if (do_after(user, sandbag_time, user.loc))
					var/obj/item/weapon/barrier/bag = C
					var/progress = bag.sand_amount
					qdel(C)
					var/obj/structure/window/barrier/incomplete/sandbag = new/obj/structure/window/barrier/incomplete(src, user)
					sandbag.progress = progress
					visible_message("<span class='danger'>[user] finishes constructing the base of a dirt barricade. Anyone can now add to it.</span>")
					if (ishuman(user))
						var/mob/living/human/H = user
						H.adaptStat("crafting", 3)
				return

	else if (istype(C, /obj/item/weapon/snowwall))
		var/sandbag_time = 50

		if (ishuman(user))
			var/mob/living/human/H = user
			sandbag_time /= H.getStatCoeff("strength")
			sandbag_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))

		if (src == get_step(user, user.dir))
			if (WWinput(user, "This will start building a snow barricade [dir2text(user.dir)] of you.", "Snow Barricade Construction", "Continue", list("Continue", "Stop")) == "Continue")
				visible_message("<span class='danger'>[user] starts constructing the base of a snow barricade.</span>", "<span class='danger'>You start constructing the base of a snow barricade.</span>")
				if (do_after(user, sandbag_time, user.loc))
					var/obj/item/weapon/snowwall/bag = C
					var/progress = bag.sand_amount
					qdel(C)
					var/obj/structure/window/barrier/snowwall/sandbag = new/obj/structure/window/barrier/snowwall/incomplete(src, user)
					sandbag.progress = progress
					visible_message("<span class='danger'>[user] finishes constructing the base of a snow barricade. Anyone can now add to it.</span>")
					if (ishuman(user))
						var/mob/living/human/H = user
						H.adaptStat("crafting", 3)
				return
	else if (istype(C, /obj/item/stack/farming/seeds) || istype(C, /obj/item/stack/medical/advanced/herbs))
		var/mob/living/human/H = user
		var/obj/item/stack/farming/seeds/TS
		if (istype(src, /turf/floor/dirt/ploughed) && istype(H) && is_plowed == TRUE)
			if (locate(/obj/structure/farming/plant) in src)
				user << "<span class='warning'>There already is something planted here.</span>"
				return
			if (ishuman(user))
				H.adaptStat("farming", 1)
			H.visible_message("<span class='notice'>[user] places some in the ploughed field.</span>",
				"<span class='notice'>You place [C] in the ploughed field.</span>",
				"<span class='notice'>Someone is poking around in dirt.</span>")
			if (istype(C, /obj/item/stack/medical/advanced/herbs))
				TS = new /obj/item/stack/farming/seeds/herbs
				TS.spawn_plant(src)
				qdel(TS)
			else
				TS = C
				TS.spawn_plant(src)
			if (C.amount>1)
				C.amount -= 1
			else
				qdel(C)
			return
		else
			user << "<span class='danger'>You can't plant here. Find a ploughed plot.</span>"
			return
	else if (istype(C, /obj/item/weapon/plough))
		var/obj/item/weapon/plough/PL = C
		var/turf/T = get_turf(src)
		if (user.a_intent == I_DISARM)
			if (istype(T, /turf/floor/grass) || istype(T, /turf/floor/dirt) || istype(T, /turf/floor/beach/sand) || istype(T, /turf/floor/winter))
				for(var/obj/covers/CV in T)
					user << "<span class='danger'>You can't make a dirt road here.</span>"
					return
				user << "You start making a dirt road..."
				if (do_after(user, 50/PL.usespeed, user.loc))
					user << "You finish the dirt road."
					var/obj/covers/roads/dirt/DR = new/obj/covers/roads/dirt(T)
					if (user.dir == NORTH || user.dir == SOUTH)
						DR.vertical = TRUE
						DR.dir = 1
						DR.icon_state = "d_roadvr"
					else
						DR.vertical = FALSE
						DR.dir = 4
						DR.icon_state = "d_roadhr"
					return
		else
			if (istype(T, /turf/floor/grass/jungle)) //whyyyyyyy????? don't know, seriously...
				user << "<span class='danger'>Jungle terrain is too poor to be farmed. Find a flood plain.</span>"
				return
			else if (istype(T, /turf/floor/dirt/burned))
				user << "<span class='danger'>This floor is burned! Wait for it to recover first.</span>"
				return
			else if (istype(T, /turf/floor/dirt/jungledirt))
				user << "<span class='danger'>Jungle terrain is too poor to be farmed. Find a flood plain.</span>"
				return
			else if (istype(T, /turf/floor/grass) && !istype(T, /turf/floor/grass/jungle))
				if (do_after(user, 50/PL.usespeed, user.loc))
					ChangeTurf(/turf/floor/dirt)
					return
			else if (istype(T, /turf/floor/dirt) && !(istype(T, /turf/floor/dirt/ploughed)) && !(istype(T, /turf/floor/dirt/dust)))
				var/mob/living/human/H = user
				if (do_after(user, (70/H.getStatCoeff("farming"))/PL.usespeed, user.loc))
					if (istype(T, /turf/floor/dirt/flooded))
						ChangeTurf(/turf/floor/dirt/ploughed/flooded)
						if (ishuman(user))
							H.adaptStat("farming", 2)
						return
					else if (istype(T, /turf/floor/dirt/underground))
						user << "<span class='danger'>You can't plough this type of terrain.</span>"
						return
					else
						ChangeTurf(/turf/floor/dirt/ploughed)
						if (ishuman(user))
							H.adaptStat("farming", 2)
						return

			else
				user << "<span class='danger'>You can't plough this type of terrain.</span>"
				return

	else if (istype(C, /obj/item/weapon/covers))
		if (!istype(src, /turf/floor/beach/water/deep/saltwater) || map.ID == MAP_VOYAGE)
			var/covers_time = 80

			if (ishuman(user))
				var/mob/living/human/H = user
				covers_time /= H.getStatCoeff("strength")
				covers_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))

			if (src == get_step(user, user.dir))
				if (WWinput(user, "This will start building a floor cover [dir2text(user.dir)] of you.", "Floor Cover Construction", "Continue", list("Continue", "Stop")) == "Continue")
					visible_message("<span class='danger'>[user] starts constructing the floor cover.</span>", "<span class='danger'>You start constructing the floor cover.</span>")
					if (do_after(user, covers_time, user.loc))
						if (!istype(src, /turf/floor/beach/water/deep/saltwater) || map.ID == MAP_VOYAGE)
							qdel(C)
							if (istype(C, /obj/item/weapon/covers/ship))
								new/obj/covers/repairedfloor/ship(src, user)
							else
								new/obj/covers/repairedfloor(src, user)
							visible_message("<span class='danger'>[user] finishes placing the floor cover.</span>")
							if (ishuman(user))
								var/mob/living/human/H = user
								H.adaptStat("crafting", 3)
					return


	if (flooring)
		if (istype(C, /obj/item/weapon/crowbar))
			if (broken || burnt)
				user << "<span class='notice'>You remove the broken [flooring.descriptor].</span>"
				make_grass()
			else if (flooring.flags & TURF_IS_FRAGILE)
				user << "<span class='danger'>You forcefully pry off the [flooring.descriptor], destroying them in the process.</span>"
				make_grass()
			else if (flooring.flags & TURF_REMOVE_CROWBAR)
				user << "<span class='notice'>You lever off the [flooring.descriptor].</span>"
				make_grass()
			else
				return
			playsound(src, 'sound/items/Crowbar.ogg', 80, TRUE)
			return
		else if (istype(C, /obj/item/weapon/hammer) && (flooring.flags & TURF_REMOVE_SCREWDRIVER))
			if (broken || burnt || src.z > 1)
				return
			user << "<span class='notice'>You unscrew and remove the [flooring.descriptor].</span>"
			make_grass()
			playsound(src, 'sound/items/Screwdriver.ogg', 80, TRUE)
			return
		else if (istype(C, /obj/item/weapon/wrench) && (flooring.flags & TURF_REMOVE_WRENCH))
			if (src.z > 1)
				return
			user << "<span class='notice'>You unwrench and remove the [flooring.descriptor].</span>"
			make_grass()
			playsound(src, 'sound/items/Ratchet.ogg', 80, TRUE)
			return
		else if (istype(C, /obj/item/weapon/material/shovel) && (flooring.flags & TURF_REMOVE_SHOVEL))
			user << "<span class='notice'>You shovel off the [flooring.descriptor].</span>"
			make_grass()
			playsound(src, 'sound/items/Deconstruct.ogg', 80, TRUE)
			return
	else
		if (istype(C, /obj/item/stack))
			if (broken || burnt)
				user << "<span class='warning'>This section is too damaged to support anything. Use a welder to fix the damage.</span>"
				return
			var/obj/item/stack/S = C
			var/decl/flooring/use_flooring
			for (var/flooring_type in flooring_types)
				var/decl/flooring/F = flooring_types[flooring_type]
				if (!F.build_type)
					continue
				if ((ispath(S.type, F.build_type) || ispath(S.build_type, F.build_type)) && ((S.type == F.build_type) || (S.build_type == F.build_type)))
					use_flooring = F
					break
			if (!use_flooring)
				return
			// Do we have enough?
			if (use_flooring.build_cost && S.amount < use_flooring.build_cost)
				user << "<span class='warning'>You require at least [use_flooring.build_cost] [S.name] to complete the [use_flooring.descriptor].</span>"
				return
			// Stay still and focus...
			if (use_flooring.build_time && !do_after(user, use_flooring.build_time, src))
				return
			if (flooring || !S || !user || !use_flooring)
				return
			if (S.use(use_flooring.build_cost))
				set_flooring(use_flooring)
				playsound(src, 'sound/items/Deconstruct.ogg', 80, TRUE)
				return
		// Repairs.
	return ..()

/turf/floor/mining/attackby(obj/item/C as obj, mob/user as mob)
	if (istype(C, /obj/item/weapon/material/pickaxe))
		var/mob/living/human/H = user
		if (istype(H))
			visible_message("<span class = 'notice'>[user] starts to break the rocky floor with the [C.name].</span>", "<span class = 'notice'>You start to break the rocky floor with the [C.name].</span>")
			playsound(src,'sound/effects/pickaxe.ogg',100,1)
			var/timera = 320/(H.getStatCoeff("strength"))
			if (do_after(user, timera))
				mining_proc(H)
		else
			return ..(C, user)
	else if (istype(C, /obj/item/weapon/reagent_containers/glass/extraction_kit))
		var/mob/living/human/H = user
		var/obj/item/weapon/reagent_containers/glass/extraction_kit/ET = C
		if (ET.reagents.total_volume > 0)
			H << "<span class = 'notice'>Empty \the [ET] first.</span>"
			return
		if (istype(H))
			visible_message("<span class = 'notice'>[user] carefully examine \the [src] with \the [C.name]...</span>", "<span class = 'notice'>You start to carefully examine \the [src] with \the [C.name].</span>")
			playsound(src,'sound/effects/pickaxe.ogg',100,1)
			var/timera = 110/(H.getStatCoeff("dexterity"))
			if (do_after(user, timera))
				extracting_proc(H, C)
		else
			return ..(C, user)

/turf/proc/extracting_proc(var/mob/living/human/H, var/obj/item/weapon/reagent_containers/glass/extraction_kit/E)
	if (!H || !src || !E)
		return
	var/list/elements = list("hydrogen","oxygen","helium", "lithium", "nitrogen", "fluorine", "sodium", "magnesium", "aluminum", "silicon", "phosphorus", "chlorine", "potassium", "calcium", "arsenic", "iodine", "tungsten", "radium", "thorium", "bromine")
	var/list/elements1 = list("nitrogen", "phosphorus", "chlorine", "potassium", "iodine")
	var/list/elements2 = list("lithium", "fluorine", "magnesium", "aluminum", "calcium", "arsenic", "tungsten", "bromine")

	var/randreg = pick(elements)
	if (prob(70))
		randreg = pick(elements1)
	else
		randreg = pick(elements2)
	if (E.reagents.total_volume <= 0)
		E.reagents.add_reagent(randreg,5)
		E.update_icon()

/turf/proc/change_the_turf()
	var/area/A = get_area(src)
	if(map.ID == MAP_NOMADS_DESERT)
		ChangeTurf(/turf/floor/dirt/dust)
	else if (A.climate == "jungle" || A.climate == "savanna")
		ChangeTurf(/turf/floor/dirt/jungledirt)
	else
		ChangeTurf(/turf/floor/dirt)
	is_mineable = FALSE

/turf/proc/mining_proc(var/mob/living/human/H = null)
	if (!src)
		return
	var/turf/T = get_turf(src)
	var/area/area_above = null
	if (z==1 && world.maxz>=2)
		area_above = get_area(get_turf(locate(x,y,z+1)))
	if (prob(20))
		if (prob(60))
			var/obj/item/stack/ore/copper/mineral = new/obj/item/stack/ore/copper(src)
			mineral.amount = rand(8,12)
			if (istype(get_area(src), /area/caribbean/void/caves/special))
				mineral.amount *= 2
			if (H)
				H << "<span class='danger'>You found some <font color=[get_material_by_name("copper").icon_colour]><b>copper</font></b> ore!</span>"
			change_the_turf()
			if (H)
				H.adaptStat("strength", 1)
			return
		else
			var/obj/item/stack/ore/tin/mineral = new/obj/item/stack/ore/tin(src)
			mineral.amount = rand(8,12)
			if (istype(get_area(src), /area/caribbean/void/caves/special))
				mineral.amount *= 2
				if (H)
					H << "<span class='danger'>You found some <font color=[get_material_by_name("tin").icon_colour]><b>tin</font></b> ore!</span>"
			change_the_turf()
			if (H)
				H.adaptStat("strength", 1)
			return
	if (prob(40) && map.ordinal_age >= 1)
		var/obj/item/stack/ore/iron/mineral = new/obj/item/stack/ore/iron(src)
		mineral.amount = rand(8,12)
		if (istype(get_area(src), /area/caribbean/void/caves/special))
			mineral.amount *= 2
			if (H)
				H << "<span class='danger'>You found some <font color=[get_material_by_name("iron").icon_colour]><b>iron</font></b> ore!</span>"
		change_the_turf()
		if (H)
			H.adaptStat("strength", 1)
		return
	if (prob(25))
		if (map.ordinal_age <= 1)
			var/obj/item/stack/ore/coal/mineral = new/obj/item/stack/ore/coal(src)
			mineral.amount = rand(12,16)
			if (istype(get_area(src), /area/caribbean/void/caves/special))
				mineral.amount *= 2
			if (H)
				H << "<span class='danger'>You found some <font color=#A9A9A9><b>coal</font></b>!</span>"// no material.
			change_the_turf()
			return
		else
			var/pickperc = pick(1,2,3,4)
			if (pickperc == 1)
				var/obj/item/stack/ore/coal/mineral = new/obj/item/stack/ore/coal(src)
				mineral.amount = rand(12,16)
				if (istype(get_area(src), /area/caribbean/void/caves/special))
					mineral.amount *= 2
				if (H)
					H << "<span class='danger'>You found some <font color=#A9A9A9><b>coal</font></b>!</span>" // no material
				change_the_turf()
				if (H)
					H.adaptStat("strength", 1)
				return
			else if (pickperc == 2)
				var/obj/item/stack/ore/saltpeter/mineral = new/obj/item/stack/ore/saltpeter(src)
				mineral.amount = 4
				if (istype(get_area(src), /area/caribbean/void/caves/special))
					mineral.amount *= 2
				if (H)
					H << "<span class='danger'>You found some <font color=#f3e781]><b>saltpeter</font></b>!</span>" // no material
				change_the_turf()
				if (H)
					H.adaptStat("strength", 1)
				return
			else if (pickperc == 3)
				var/obj/item/stack/ore/sulphur/mineral = new/obj/item/stack/ore/sulphur(src)
				mineral.amount = 4
				if (istype(get_area(src), /area/caribbean/void/caves/special))
					mineral.amount *= 2
				if (mineral && mineral.get_material())
					if (H)
						H << "<span class='danger'>You found some <font color=#fffa78><b>sulphur</font></b>!</span>" // no material
				change_the_turf()
				if (H)
					H.adaptStat("strength", 1)
				return
			else if (pickperc == 4)
				if (prob(50))
					var/obj/item/stack/ore/lead/mineral = new/obj/item/stack/ore/lead(src)
					mineral.amount = 4
					if (istype(get_area(src), /area/caribbean/void/caves/special))
						mineral.amount *= 2
					if (H)
						H << "<span class='danger'>You found some <font color=[get_material_by_name("lead").icon_colour]><b>lead</font> ore</b>!</span>"
					change_the_turf()
					if (H)
						H.adaptStat("strength", 1)
					return
				else if (prob(10) && map.ordinal_age >= 7)
					var/obj/item/stack/ore/uranium/mineral = new/obj/item/stack/ore/uranium(src)
					mineral.amount = rand(4,12)
					if (istype(get_area(src), /area/caribbean/void/caves/special))
						mineral.amount *= 2
					if (H)
						H << "<span class='danger'>You found some <font color=#325202><b>uranium</font></b>! Better clear the mine.</span>" // no material
					change_the_turf()
					if (H)
						H.adaptStat("strength", 3)
					return
/*
				else
					var/obj/item/stack/ore/mercury/mineral = new/obj/item/stack/ore/mercury(src)
					mineral.amount = 4
					if (istype(get_area(src), /area/caribbean/void/caves/special))
						mineral.amount *= 2
					H << "<span class='danger'>You found some <font color=#882c1d><b>mercury</font></b>!</span>" // no material
					change_the_turf()
					H.adaptStat("strength", 1)
					return
*/
	if (prob(5))
		var/obj/item/stack/ore/silver/mineral = new/obj/item/stack/ore/silver(src)
		mineral.amount = 4
		if (istype(get_area(src), /area/caribbean/void/caves/special))
			mineral.amount *= 2
		if (H)
			H << "<span class='danger'>You found some <font color=[get_material_by_name("silver").icon_colour]><b>silver</font> ore</b>!</span>"
		change_the_turf()
		if (H)
			H.adaptStat("strength", 1)
		return
	if (prob(2))
		var/obj/item/stack/ore/gold/mineral = new/obj/item/stack/ore/gold(src)
		mineral.amount = 4
		if (istype(get_area(src), /area/caribbean/void/caves/special))
			mineral.amount *= 2
		if (H)
			H << "<span class='danger'>You found some <font color=[get_material_by_name("gold").icon_colour]><b>gold</font> ore</b>!</span>"
		change_the_turf()
		if (H)
			H.adaptStat("strength", 1)
		return
	if (prob(1))
		var/obj/item/stack/ore/diamond/mineral = new/obj/item/stack/ore/diamond(src)
		mineral.amount = 4
		if (istype(get_area(src), /area/caribbean/void/caves/special))
			mineral.amount *= 2
		if (H)
			H << "<span class='danger'>You found some raw <font color=[get_material_by_name("diamond").icon_colour]><b>diamonds</b></font>!</span>"
		change_the_turf()
		if (H)
			H.adaptStat("strength", 1)
		return
	if (istype(T, /turf/floor/dirt/underground/icy))
		if (prob(3))
			var/obj/item/stack/material/fossil/mineral = new/obj/item/stack/material/fossil(src)
			mineral.amount = 1
			if (istype(get_area(src), /area/caribbean/void/caves/special))
				new/obj/item/stack/material/fossil(src)
			if (H)
				H << "<span class='danger'>You found a <font color=[get_material_by_name("bone").icon_colour]><b>fossil</font></b>!</span>"
			change_the_turf()
			if (H)
				H.adaptStat("strength", 1)
			return
		else
			if (prob(1))
				var/obj/item/stack/material/fossil/mineral = new/obj/item/stack/material/fossil(src)
				mineral.amount = 1
				if (istype(get_area(src), /area/caribbean/void/caves/special))
					new/obj/item/stack/material/fossil(src)
				if (H)
					H << "<span class='danger'>You found a <font color=[get_material_by_name("bone").icon_colour]><b>fossil</font></b>!</span>"
				change_the_turf()
				if (H)
					H.adaptStat("strength", 1)
				return
	if(istype(T, /turf/floor/dirt/underground/sandy) || (area_above && area_above.climate == "desert"))
		var/obj/item/stack/material/sandstone/mineral = new/obj/item/stack/material/sandstone(src)
		mineral.amount = rand(8,16)
		if (istype(get_area(src), /area/caribbean/void/caves/special))
			mineral.amount *= 2
		if (H)
			H << "<span class='danger'>You found some <font color=[get_material_by_name("sandstone").icon_colour]><b>sandstone</font> rocks</b>!</span>"
	if(prob(20) && (map.ID != MAP_NOMADS_PANGEA || map.ID != MAP_NOMADS_CONTINENTAL || map.ID != MAP_NOMADS_NEW_WORLD && map.ID != MAP_NOMADS_MEDITERRANEAN && map.ID != MAP_GULAG13 && map.ID != MAP_RIVER_KWAI) && map.ordinal_age >=1)
		var/obj/item/stack/material/marble/mineral = new/obj/item/stack/material/marble(src)
		mineral.amount = rand(8,12)
		if (istype(get_area(src), /area/caribbean/void/caves/special))
			mineral.amount *= 2
		if (H)
			H << "<span class='danger'>You found some <font color=[get_material_by_name("marble").icon_colour]><b>marble</font> rocks</b>!</span>"
		change_the_turf()
		if (H)
			H.adaptStat("strength", 1)
		return
	else if(prob(20) && (area_above && area_above.climate == "jungle") && map.ordinal_age >=1 && map.ordinal_age <= 3)
		var/obj/item/stack/ore/obsidian/mineral = new/obj/item/stack/ore/obsidian(src)
		mineral.amount = rand(8,12)
		if (istype(get_area(src), /area/caribbean/void/caves/special))
			mineral.amount *= 2
		if (H)
			H << "<span class='danger'>You found some <font color=#060606><b>obsidian</font> rocks</b>!</span>"
	else if(prob(20) && (map.ID == MAP_NOMADS_PANGEA || map.ID == MAP_NOMADS_CONTINENTAL || map.ID == MAP_NOMADS_NEW_WORLD && map.ID == MAP_NOMADS_MEDITERRANEAN) && area_above && area_above.climate == "temperate" || area_above && area_above.climate == "semiarid" && map.ordinal_age >=1)
		var/obj/item/stack/material/marble/mineral = new/obj/item/stack/material/marble(src)
		mineral.amount = rand(8,12)
		if (istype(get_area(src), /area/caribbean/void/caves/special))
			mineral.amount *= 2
		if (H)
			H << "<span class='danger'>You found some <font color=[get_material_by_name("marble").icon_colour]><b>marble</font> rocks</b>!</span>"
	else
		var/obj/item/stack/material/stone/mineral = new/obj/item/stack/material/stone(src)
		mineral.amount = rand(8,16)
		if (istype(get_area(src), /area/caribbean/void/caves/special))
			mineral.amount *= 2
		if (H)
			H << "<span class='danger'>You found some usable <font color=[get_material_by_name("stone").icon_colour]><b>stone</font> rocks</b>!</span>"
	change_the_turf()
	if (H)
		H.adaptStat("strength", 1)
	return

/turf/floor/dirt/underground/attack_hand(mob/user)
	if (istype(src, /turf/floor/dirt/underground) && ishuman(user))
		var/turf/floor/dirt/underground/U = src
		var/mob/living/human/H = user
		if (H.ant && H.a_intent == I_GRAB)
			visible_message("<span class = 'notice'>[user] starts to break the rock with their hands...</span>", "<span class = 'notice'>You start to break the rock with the your hands...</span>")
			playsound(src,'sound/effects/pickaxe.ogg',100,1)
			if (do_after(user, (320/(H.getStatCoeff("strength"))/1.5)))
				U.collapse_check()
				if (istype(src, /turf/floor/dirt/underground/empty))
					var/turf/floor/dirt/underground/empty/T = src
					T.mining_clear_debris()
					return TRUE
				else if (!istype(src, /turf/floor/dirt/underground/empty))
					mining_proc(H)
				return TRUE
		else
			..()
	else
		..()

/turf/floor/attack_hand(mob/user)
	if (!istype(src, /turf/floor/dirt/underground) && !istype(src, /turf/floor/dirt/underground/empty) && ishuman(user))
		var/turf/floor/T = src
		var/mob/living/human/H = user
		if (H.ant && H.a_intent == I_GRAB)
			if (T.icon == 'icons/turf/snow.dmi' && istype(H) && !H.shoveling_snow)
				if (T.available_snow >= 1)
					H.shoveling_snow = TRUE
					visible_message("<span class = 'notice'>[user] starts to collect snow into a pile.</span>", "<span class = 'notice'>You start to collect snow into a pile.</span>")
					playsound(src,'sound/effects/shovelling.ogg',100,1)
					if (do_after(user, rand(45,60)))
						visible_message("<span class = 'notice'>[user] collects the snow into a pile.</span>", "<span class = 'notice'>You collect the snow into a pile.</span>")
						H.shoveling_snow = FALSE
						H.adaptStat("strength", 1)
						T.available_snow -= 1
						new /obj/item/weapon/snowwall(T)
						if (T.available_snow <= 0)
							if (istype(T, /turf/floor/winter/grass))
								T.ChangeTurf(/turf/floor/grass)
							else if (istype(T, /turf/floor/dirt/winter))
								T.ChangeTurf(/turf/floor/dirt)

					else
						H.shoveling_snow = FALSE
				else
					user << "<span class='notice'>All the loose snow has been shoveled out of this spot already.</span>"

			else if (istype(T, /turf/floor/dirt) && istype(H) && !H.shoveling_dirt)
				if (T.available_dirt >= 1)
					H.shoveling_dirt = TRUE
					visible_message("<span class = 'notice'>[user] starts to collect dirt into a pile.</span>", "<span class = 'notice'>You start to collect dirt into a pile.</span>")
					playsound(src,'sound/effects/shovelling.ogg',100,1)
					if (do_after(user, rand(45,60)))
						visible_message("<span class = 'notice'>[user] collects the dirt into a pile.</span>", "<span class = 'notice'>You collect the dirt into a pile.</span>")
						H.shoveling_dirt = FALSE
						H.adaptStat("strength", 1)
						T.available_dirt -= 1
						new /obj/item/weapon/barrier(T)
					else
						H.shoveling_dirt = FALSE
				else
					user << "<span class='notice'>All the loose dirt has been shoveled out of this spot already.</span>"
			else if (istype(T, /turf/floor/beach/sand) && istype(H) && !H.shoveling_sand)
				if (T.available_sand >= 1)
					H.shoveling_sand = TRUE
					visible_message("<span class = 'notice'>[user] starts to collect sand into a pile.</span>", "<span class = 'notice'>You start to collect sand into a pile.</span>")
					playsound(src,'sound/effects/shovelling.ogg',100,1)
					if (do_after(user, rand(45,60)))
						visible_message("<span class = 'notice'>[user] collects the sand into a pile.</span>", "<span class = 'notice'>You collect the sand into a pile.</span>")
						H.shoveling_sand = FALSE
						H.adaptStat("strength", 1)
						T.available_sand -= 1
						new /obj/item/stack/ore/glass(T)
					else
						H.shoveling_sand = FALSE
			else
				..()
		else
			..()
	else
		..()

/turf/floor/verb/Dig()
	set category = null
	set src in range(1, usr)

	var/mob/living/human/user

	if (ishuman(usr))
		user = usr
	else
		return
	var/turf/floor/TO = get_turf(src)
	if (TO && user.ant && (TO.is_diggable) && !(locate(/obj/structure/multiz/) in user.loc))
		if (user.z == 1)
			var/turf/TB = locate(user.x,user.y,user.z+1)
			for (var/obj/OB in TB)
				if (istype(OB, /obj/covers) || OB.density == TRUE || istype(OB, /obj/structure/multiz) || istype(OB, /obj/structure/rails))
					user << "<span class='notice'>You can't dig up here, there is something blocking the way!</span>"
					return
			if (istype(TB, /turf/floor/beach/water) || istype(TB, /turf/floor/lava))
				user << "<span class='notice'>You can't dig down here, there is something blocking the way!</span>"
				return
			if ((istype(TB, /turf/floor/beach) && !istype(TB, /turf/floor/beach/sand)) || istype(TB, /turf/floor/plating) || istype(TB, /turf/floor/broken_floor) ||istype(TB, /turf/floor/mining) ||istype(TB, /turf/floor/ship) ||istype(TB, /turf/floor/wood) ||istype(TB, /turf/floor/wood_broken) ||!istype(TB, /turf/floor))
				user << "<span class='notice'>You can't dig up on that type of floor!</span>"
				return
			var/digging_tunnel_time = 400
			digging_tunnel_time /= user.getStatCoeff("strength")
			digging_tunnel_time /= (user.getStatCoeff("crafting") * user.getStatCoeff("crafting"))
			visible_message("<span class='danger'>[user] starts digging a tunnel entrance!</span>", "<span class='danger'>You start digging a tunnel entrance.</span>")
			if (do_after(user, digging_tunnel_time, user.loc))
				if (!TB.is_diggable)
					return
				new/obj/structure/multiz/ladder/ww2/tunneltop(locate(user.x, user.y, user.z+1))
				new/obj/structure/multiz/ladder/ww2/tunnelbottom(user.loc)
				visible_message("<span class='danger'>[user] finishes digging the tunnel entrance.</span>")
				if (ishuman(user))
					var/mob/living/human/H = user
					H.adaptStat("crafting", 1)
					H.adaptStat("strength", 1)
			return
		else
			if (user.z <= 1)
				user << "<span class='notice'>You can't dig a tunnel here, the bedrock is right below.</span>"
				return
			var/digging_tunnel_time = 200
			digging_tunnel_time /= user.getStatCoeff("strength")
			digging_tunnel_time /= (user.getStatCoeff("crafting") * user.getStatCoeff("crafting"))
			visible_message("<span class='danger'>[user] starts digging a tunnel entrance!</span>", "<span class='danger'>You start digging a tunnel entrance.</span>")
			if (do_after(user, digging_tunnel_time, user.loc))
				if (!TO.is_diggable)
					return
				new/obj/structure/multiz/ladder/ww2/tunneltop(user.loc)
				new/obj/structure/multiz/ladder/ww2/tunnelbottom(locate(user.x, user.y, user.z-1))
				var/turf/BL = get_turf(locate(user.x, user.y, user.z-1))
				if (istype(BL, /turf/floor/dirt/underground))
					BL.ChangeTurf(/turf/floor/dirt)
				visible_message("<span class='danger'>[user] finishes digging the tunnel entrance.</span>")
				if (ishuman(user))
					var/mob/living/human/H = user
					H.adaptStat("crafting", 1)
					H.adaptStat("strength", 1)
			return
	else if (locate(/obj/structure/multiz/) in user.loc)
		user << "<span class='warning'>There already is something here.</span>"
		return
	else if (!TO.is_diggable)
		user << "<span class='warning'>You cannot dig a hole here!</span>"
		return

/turf/floor/beach/water/attack_hand(var/mob/living/human/H)
	if (!ishuman(H))
		return
	if (H.a_intent == I_GRAB)
		if (salty)
			H << "<span class='warning'>It´s probably not a good idea to drink saltwater.</span>"
			return
		H << "You start drinking some water from ground..."
		if (do_after(H,50,src))
			var/watertype = "water"
			if (radiation>0)
				watertype = "irradiated_water"
			if (watertype == "irradiated_water")
				H.rad_act(5)
			else
				var/dmod = 1
				if (H.find_trait("Weak Immune System"))
					dmod = 2
				if (prob(sickness*15*dmod) && !H.orc && !H.crab)
					if (H.disease == 0)
						H.disease_progression = 0
						H.disease_type ="cholera"
						H.disease = 1
			if (H.water < 0)
				H.water += rand(40,50)
			H.water += 75
			H.bladder += 25
			H << "You drink some water from."
			playsound(H.loc, 'sound/items/drink.ogg', rand(10, 50), TRUE)
			return
		else
			return
	else
		..()
