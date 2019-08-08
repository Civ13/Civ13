/turf/floor/proc/collapse_check()
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
				for (var/mob/living/carbon/human/M in range(1, src))
					M.adjustBruteLoss(rand(9,21))
					M.Weaken(12)
				var/turf/floor/dirt/underground/DT = get_turf(src)
				DT.ChangeTurf(/turf/floor/dirt/underground/empty)
			else
				visible_message("The mine starts to cave in!")
				playsound(src,'sound/effects/rocksfalling.ogg',100,0,6)
				for (var/mob/living/carbon/human/M in range(2, src))
					M.adjustBruteLoss(rand(28,39))
					M.Weaken(23)
				for (var/turf/floor/UT in range (1))
					if (!istype(UT, /turf/floor/dirt/underground))
						UT.ChangeTurf(/turf/floor/dirt/underground/empty)
				new/obj/effect/effect/smoke(src)
		if (supportfound)
			if(map.ID == MAP_NOMADS_DESERT)
				ChangeTurf(/turf/floor/dirt/dust)
			else
				ChangeTurf(/turf/floor/dirt)

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
					RG.reagents.add_reagent("water", min(RG.volume - RG.reagents.total_volume, RG.amount_per_transfer_from_this)-sumex)
					user.visible_message("<span class='notice'>[user] fills \the [RG] with water.</span>","<span class='notice'>You fill \the [RG] with water.</span>")
					playsound(user, 'sound/effects/watersplash.ogg', 100, TRUE)
					user.setClickCooldown(5)
				return


	if ((flooring && istype(C, /obj/item/stack/rods)))
		return ..(C, user)

	else if (istype(C, /obj/item/weapon/reagent_containers/food/drinks))
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
		C.reagents.splash(src, C.reagents.total_volume)
		C.reagents.clear_reagents()
		C.update_icon()
		C.reagents.del_reagent("cholera")
		return

	else if (istype(C, /obj/item/weapon/shovel))
		var/turf/T = get_turf(src)
		var/mob/living/carbon/human/H = user

		if (T.icon == 'icons/turf/snow.dmi' && istype(H) && !H.shoveling_snow)
			if (T.available_snow >= 1)
				H.shoveling_snow = TRUE
				visible_message("<span class = 'notice'>[user] starts to shovel snow into a pile.</span>", "<span class = 'notice'>You start to shovel snow into a pile.</span>")
				playsound(src,'sound/effects/shovelling.ogg',100,1)
				if (do_after(user, rand(45,60)))
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
				if (do_after(user, rand(45,60)))
					visible_message("<span class = 'notice'>[user] shovels dirt into a pile.</span>", "<span class = 'notice'>You shovel dirt into a pile.</span>")
					H.shoveling_dirt = FALSE
					H.adaptStat("strength", 1)
					T.available_dirt -= 1
					new /obj/item/weapon/sandbag(T)
				else
					H.shoveling_dirt = FALSE
			else
				user << "<span class='notice'>All the loose dirt has been shoveled out of this spot already.</span>"
		else if (istype(T, /turf/floor/beach/sand) && istype(H) && !H.shoveling_sand)
			if (T.available_sand >= 1)
				H.shoveling_sand = TRUE
				visible_message("<span class = 'notice'>[user] starts to shovel sand into a pile.</span>", "<span class = 'notice'>You start to shovel sand into a pile.</span>")
				playsound(src,'sound/effects/shovelling.ogg',100,1)
				if (do_after(user, rand(45,60)))
					visible_message("<span class = 'notice'>[user] shovels sand into a pile.</span>", "<span class = 'notice'>You shovel sand into a pile.</span>")
					H.shoveling_sand = FALSE
					H.adaptStat("strength", 1)
					T.available_sand -= 1
					new /obj/item/stack/ore/glass(T)
				else
					H.shoveling_sand = FALSE

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
	else if (istype(C, /obj/item/weapon/pickaxe))
		var/turf/T = get_turf(src)
		var/mob/living/carbon/human/H = user
		if (istype(T, /turf/floor/dirt/underground) && istype(H))
			visible_message("<span class = 'notice'>[user] starts to break the rock with the [C.name].</span>", "<span class = 'notice'>You start to break the rock with the [C.name].</span>")
			playsound(src,'sound/effects/pickaxe.ogg',100,1)
			if (do_after(user, 160/(H.getStatCoeff("strength"))))
				collapse_check()
				if (istype(src, /turf/floor/dirt/underground/empty))
					return
				else if (!istype(src, /turf/floor/dirt/underground/empty))
					mining_proc(H)
		else
			return ..(C, user)

	else if (istype(C, /obj/item/weapon/sandbag/sandbag))

		var/your_dir = "NORTH"

		switch (user.dir)
			if (NORTH)
				your_dir = "NORTH"
			if (SOUTH)
				your_dir = "SOUTH"
			if (EAST)
				your_dir = "EAST"
			if (WEST)
				your_dir = "WEST"

		var/sandbag_time = 50

		if (ishuman(user))
			var/mob/living/carbon/human/H = user
			sandbag_time /= H.getStatCoeff("strength")
			sandbag_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))

		if (src == get_step(user, user.dir))
			if (WWinput(user, "This will start building a sandbag wall [your_dir] of you.", "Sandbag Wall Construction", "Continue", list("Continue", "Stop")) == "Continue")
				visible_message("<span class='danger'>[user] starts constructing the base of a sandbag wall.</span>", "<span class='danger'>You start constructing the base of a sandbag wall.</span>")
				if (do_after(user, sandbag_time, user.loc))
					var/obj/item/weapon/sandbag/sandbag/bag = C
					var/progress = bag.sand_amount
					qdel(C)
					var/obj/structure/window/sandbag/sandbag/incomplete/sb = new/obj/structure/window/sandbag/sandbag/incomplete(src, user)
					sb.progress = progress
					visible_message("<span class='danger'>[user] finishes constructing the base of a sandbag wall. Anyone can now add to it.</span>")
					if (ishuman(user))
						var/mob/living/carbon/human/H = user
						H.adaptStat("crafting", 3)
				return

	else if (istype(C, /obj/item/weapon/sandbag))

		var/your_dir = "NORTH"

		switch (user.dir)
			if (NORTH)
				your_dir = "NORTH"
			if (SOUTH)
				your_dir = "SOUTH"
			if (EAST)
				your_dir = "EAST"
			if (WEST)
				your_dir = "WEST"

		var/sandbag_time = 50

		if (ishuman(user))
			var/mob/living/carbon/human/H = user
			sandbag_time /= H.getStatCoeff("strength")
			sandbag_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))

		if (src == get_step(user, user.dir))
			if (WWinput(user, "This will start building a dirt barricade [your_dir] of you.", "Dirt Barricade Construction", "Continue", list("Continue", "Stop")) == "Continue")
				visible_message("<span class='danger'>[user] starts constructing the base of a dirt barricade.</span>", "<span class='danger'>You start constructing the base of a dirt barricade.</span>")
				if (do_after(user, sandbag_time, user.loc))
					var/obj/item/weapon/sandbag/bag = C
					var/progress = bag.sand_amount
					qdel(C)
					var/obj/structure/window/sandbag/incomplete/sandbag = new/obj/structure/window/sandbag/incomplete(src, user)
					sandbag.progress = progress
					visible_message("<span class='danger'>[user] finishes constructing the base of a dirt barricade. Anyone can now add to it.</span>")
					if (ishuman(user))
						var/mob/living/carbon/human/H = user
						H.adaptStat("crafting", 3)
				return

	else if (istype(C, /obj/item/weapon/snowwall))

		var/your_dir = "NORTH"

		switch (user.dir)
			if (NORTH)
				your_dir = "NORTH"
			if (SOUTH)
				your_dir = "SOUTH"
			if (EAST)
				your_dir = "EAST"
			if (WEST)
				your_dir = "WEST"

		var/sandbag_time = 50

		if (ishuman(user))
			var/mob/living/carbon/human/H = user
			sandbag_time /= H.getStatCoeff("strength")
			sandbag_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))

		if (src == get_step(user, user.dir))
			if (WWinput(user, "This will start building a snow barricade [your_dir] of you.", "Snow Barricade Construction", "Continue", list("Continue", "Stop")) == "Continue")
				visible_message("<span class='danger'>[user] starts constructing the base of a snow barricade.</span>", "<span class='danger'>You start constructing the base of a snow barricade.</span>")
				if (do_after(user, sandbag_time, user.loc))
					var/obj/item/weapon/snowwall/bag = C
					var/progress = bag.sand_amount
					qdel(C)
					var/obj/structure/window/snowwall/sandbag = new/obj/structure/window/snowwall/incomplete(src, user)
					sandbag.progress = progress
					visible_message("<span class='danger'>[user] finishes constructing the base of a snow barricade. Anyone can now add to it.</span>")
					if (ishuman(user))
						var/mob/living/carbon/human/H = user
						H.adaptStat("crafting", 3)
				return
	else if (istype(C, /obj/item/stack/farming/seeds))
		var/mob/living/carbon/human/H = user
		if (istype(src, /turf/floor/dirt/ploughed) && istype(H) && is_plowed == TRUE)
			if (locate(/obj/structure/farming/plant) in src)
				user << "<span class='notice'>There already is something planted here.</span>"
				return
			if (istype(C, /obj/item/stack/farming/seeds/potato))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/potato(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
			if (istype(C, /obj/item/stack/farming/seeds/carrot))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/carrot(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
			else if (istype(C, /obj/item/stack/farming/seeds/tomato))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/tomato(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
			else if (istype(C, /obj/item/stack/farming/seeds/hemp))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/hemp(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
			else if (istype(C, /obj/item/stack/farming/seeds/corn))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/corn(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
			else if (istype(C, /obj/item/stack/farming/seeds/wheat))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/wheat(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
			else if (istype(C, /obj/item/stack/farming/seeds/apple))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/apple(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
			else if (istype(C, /obj/item/stack/farming/seeds/orange))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/orange(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
			else if (istype(C, /obj/item/stack/farming/seeds/sugarcane))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/sugarcane(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
			else if (istype(C, /obj/item/stack/farming/seeds/tobacco))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/tobacco(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
			else if (istype(C, /obj/item/stack/farming/seeds/poppy))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/poppy(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
			else if (istype(C, /obj/item/stack/farming/seeds/cabbage))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/cabbage(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
			else if (istype(C, /obj/item/stack/farming/seeds/tea))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/tea(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
			else if (istype(C, /obj/item/stack/farming/seeds/peyote))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/peyote(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
			else if (istype(C, /obj/item/stack/farming/seeds/coffee))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/coffee(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
			else if (istype(C, /obj/item/stack/farming/seeds/tree))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/tree(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
			else if (istype(C, /obj/item/stack/farming/seeds/cotton))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/cotton(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
			else if (istype(C, /obj/item/stack/farming/seeds/banana))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/banana(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
			else if (istype(C, /obj/item/stack/farming/seeds/rice))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/rice(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
			else if (istype(C, /obj/item/stack/farming/seeds/grapes))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/grapes(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
			else if (istype(C, /obj/item/stack/farming/seeds/olives))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/olives(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
			else if (istype(C, /obj/item/stack/farming/seeds/mushroom))
				visible_message("[user] places the mushroom spores in the ploughed field.")
				new/obj/structure/farming/plant/mushroom(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
			else if (istype(C, /obj/item/stack/farming/seeds/coca))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/coca(src)
				if (C.amount>1)
					C.amount -= 1
				else
					qdel(C)
				return
/*					if (ishuman(user)) todo: farming skills
						var/mob/living/carbon/human/H = user
						H.adaptStat("crafting", 3) */
			return

		else
			user << "<span class='danger'>You can't plant here. Find a ploughed plot.</span>"
			return
	else if (istype(C, /obj/item/weapon/plough))
		var/turf/T = get_turf(src)
		if (istype(T, /turf/floor/grass/jungle))
			user << "<span class='danger'>Jungle terrain is too poor to be farmed. Find a flood plain.</span>"
			return
		else if (istype(T, /turf/floor/dirt/burned))
			user << "<span class='danger'>This floor is burned! Wait for it to recover first.</span>"
			return
		else if (istype(T, /turf/floor/dirt/jungledirt))
			user << "<span class='danger'>Jungle terrain is too poor to be farmed. Find a flood plain.</span>"
			return
		else if (istype(T, /turf/floor/grass) && !istype(T, /turf/floor/grass/jungle))
			if (do_after(user, 50, user.loc))
				ChangeTurf(/turf/floor/dirt)
				return
		else if (istype(T, /turf/floor/dirt) && !(istype(T, /turf/floor/dirt/ploughed)) && !(istype(T, /turf/floor/dirt/dust)))
			if (do_after(user, 70, user.loc))
				if (istype(T, /turf/floor/dirt/flooded))
					ChangeTurf(/turf/floor/dirt/ploughed/flooded)
					return
				else if (istype(T, /turf/floor/dirt/underground))
					user << "<span class='danger'>You can't plough this type of terrain.</span>"
					return
				else
					ChangeTurf(/turf/floor/dirt/ploughed)
					return

		else
			user << "<span class='danger'>You can't plough this type of terrain.</span>"
			return

	else if (istype(C, /obj/item/weapon/covers) && !istype(src, /turf/floor/beach/water/deep/saltwater))

		var/your_dir = "NORTH"

		switch (user.dir)
			if (NORTH)
				your_dir = "NORTH"
			if (SOUTH)
				your_dir = "SOUTH"
			if (EAST)
				your_dir = "EAST"
			if (WEST)
				your_dir = "WEST"

		var/covers_time = 80

		if (ishuman(user))
			var/mob/living/carbon/human/H = user
			covers_time /= H.getStatCoeff("strength")
			covers_time /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))

		if (src == get_step(user, user.dir))
			if (WWinput(user, "This will start building a floor cover [your_dir] of you.", "Floor Cover Construction", "Continue", list("Continue", "Stop")) == "Continue")
				visible_message("<span class='danger'>[user] starts constructing the floor cover.</span>", "<span class='danger'>You start constructing the floor cover.</span>")
				if (do_after(user, covers_time, user.loc))
					if (!istype(src, /turf/floor/beach/water/deep/saltwater))
						qdel(C)
						new/obj/covers/repairedfloor(src, user)
						visible_message("<span class='danger'>[user] finishes placing the floor cover.</span>")
						if (ishuman(user))
							var/mob/living/carbon/human/H = user
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
			if (broken || burnt)
				return
			user << "<span class='notice'>You unscrew and remove the [flooring.descriptor].</span>"
			make_grass()
			playsound(src, 'sound/items/Screwdriver.ogg', 80, TRUE)
			return
		else if (istype(C, /obj/item/weapon/wrench) && (flooring.flags & TURF_REMOVE_WRENCH))
			user << "<span class='notice'>You unwrench and remove the [flooring.descriptor].</span>"
			make_grass()
			playsound(src, 'sound/items/Ratchet.ogg', 80, TRUE)
			return
		else if (istype(C, /obj/item/weapon/shovel) && (flooring.flags & TURF_REMOVE_SHOVEL))
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
			if (use_flooring.build_cost && S.get_amount() < use_flooring.build_cost)
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
	if (istype(C, /obj/item/weapon/pickaxe))
		var/mob/living/carbon/human/H = user
		if (istype(H))
			visible_message("<span class = 'notice'>[user] starts to break the rocky floor with the [C.name].</span>", "<span class = 'notice'>You start to break the rocky floor with the [C.name].</span>")
			playsound(src,'sound/effects/pickaxe.ogg',100,1)
			var/timera = 110/(H.getStatCoeff("strength"))
			if (do_after(user, timera))
				mining_proc(H)
		else
			return ..(C, user)

/turf/proc/mining_proc(var/mob/living/carbon/human/H)
	if (!H || !src)
		return
	var/turf/T = get_turf(src)
	if (prob(25))
		if (prob(60))
			var/obj/item/stack/ore/copper/mineral = new/obj/item/stack/ore/copper(src)
			mineral.amount = rand(2,6)
			if (istype(get_area(src), /area/caribbean/void/caves/special))
				mineral.amount *= 2
			H << "<span class='danger'>You found some copper ore!</span>"
			if(map.ID == MAP_NOMADS_DESERT)
				T.ChangeTurf(/turf/floor/dirt/dust)
			else
				T.ChangeTurf(/turf/floor/dirt)
			T.is_mineable = FALSE
			H.adaptStat("strength", 1)
			return
		else
			var/obj/item/stack/ore/tin/mineral = new/obj/item/stack/ore/tin(src)
			mineral.amount = rand(2,6)
			if (istype(get_area(src), /area/caribbean/void/caves/special))
				mineral.amount *= 2
			H << "<span class='danger'>You found some tin ore!</span>"
			if(map.ID == MAP_NOMADS_DESERT)
				T.ChangeTurf(/turf/floor/dirt/dust)
			else
				T.ChangeTurf(/turf/floor/dirt)
			T.is_mineable = FALSE
			H.adaptStat("strength", 1)
			return
	if (prob(40) && map.ordinal_age >= 1)
		var/obj/item/stack/ore/iron/mineral = new/obj/item/stack/ore/iron(src)
		mineral.amount = rand(2,6)
		if (istype(get_area(src), /area/caribbean/void/caves/special))
			mineral.amount *= 2
		H << "<span class='danger'>You found some iron ore!</span>"
		if(map.ID == MAP_NOMADS_DESERT)
			T.ChangeTurf(/turf/floor/dirt/dust)
		else
			T.ChangeTurf(/turf/floor/dirt)
		T.is_mineable = FALSE
		H.adaptStat("strength", 1)
		return
	if (prob(25))
		if (map.ordinal_age <= 1)
			var/obj/item/stack/ore/coal/mineral = new/obj/item/stack/ore/coal(src)
			if (istype(get_area(src), /area/caribbean/void/caves/special))
				mineral.amount *= 2
			H << "<span class='danger'>You found some coal!</span>"
			if(map.ID == MAP_NOMADS_DESERT)
				T.ChangeTurf(/turf/floor/dirt/dust)
			else
				T.ChangeTurf(/turf/floor/dirt)
			T.is_mineable = FALSE
			H.adaptStat("strength", 1)
			return
		else
			var/pickperc = pick(1,2,3,4)
			if (pickperc == 1)
				var/obj/item/stack/ore/coal/mineral = new/obj/item/stack/ore/coal(src)
				mineral.amount = 2
				if (istype(get_area(src), /area/caribbean/void/caves/special))
					mineral.amount *= 2
				H << "<span class='danger'>You found some coal!</span>"
				if(map.ID == MAP_NOMADS_DESERT)
					T.ChangeTurf(/turf/floor/dirt/dust)
				else
					T.ChangeTurf(/turf/floor/dirt)
				T.is_mineable = FALSE
				H.adaptStat("strength", 1)
				return
			else if (pickperc == 2)
				var/obj/item/stack/ore/saltpeter/mineral = new/obj/item/stack/ore/saltpeter(src)
				mineral.amount = 2
				if (istype(get_area(src), /area/caribbean/void/caves/special))
					mineral.amount *= 2
				H << "<span class='danger'>You found some saltpeter!</span>"
				if(map.ID == MAP_NOMADS_DESERT)
					T.ChangeTurf(/turf/floor/dirt/dust)
				else
					T.ChangeTurf(/turf/floor/dirt)
				T.is_mineable = FALSE
				H.adaptStat("strength", 1)
				return
			else if (pickperc == 3)
				var/obj/item/stack/ore/sulphur/mineral = new/obj/item/stack/ore/sulphur(src)
				mineral.amount = 2
				if (istype(get_area(src), /area/caribbean/void/caves/special))
					mineral.amount *= 2
				H << "<span class='danger'>You found some sulphur!</span>"
				if(map.ID == MAP_NOMADS_DESERT)
					T.ChangeTurf(/turf/floor/dirt/dust)
				else
					T.ChangeTurf(/turf/floor/dirt)
				T.is_mineable = FALSE
				H.adaptStat("strength", 1)
				return
			else if (pickperc == 4)
				if (prob(50))
					var/obj/item/stack/ore/lead/mineral = new/obj/item/stack/ore/lead(src)
					mineral.amount = 2
					if (istype(get_area(src), /area/caribbean/void/caves/special))
						mineral.amount *= 2
					H << "<span class='danger'>You found some lead!</span>"
					if(map.ID == MAP_NOMADS_DESERT)
						T.ChangeTurf(/turf/floor/dirt/dust)
					else
						T.ChangeTurf(/turf/floor/dirt)
					T.is_mineable = FALSE
					H.adaptStat("strength", 1)
					return
				else
					if (prob(40))
						var/obj/item/stack/ore/uranium/mineral = new/obj/item/stack/ore/uranium(src)
						mineral.amount = 2
						if (istype(get_area(src), /area/caribbean/void/caves/special))
							mineral.amount *= 2
						H << "<span class='danger'>You found some uranium!</span>"
						if(map.ID == MAP_NOMADS_DESERT)
							T.ChangeTurf(/turf/floor/dirt/dust)
						else
							T.ChangeTurf(/turf/floor/dirt)
						T.is_mineable = FALSE
						H.adaptStat("strength", 1)
						return
					else
						var/obj/item/stack/ore/mercury/mineral = new/obj/item/stack/ore/mercury(src)
						mineral.amount = 2
						if (istype(get_area(src), /area/caribbean/void/caves/special))
							mineral.amount *= 2
						H << "<span class='danger'>You found some mercury!</span>"
						if(map.ID == MAP_NOMADS_DESERT)
							T.ChangeTurf(/turf/floor/dirt/dust)
						else
							T.ChangeTurf(/turf/floor/dirt)
						T.is_mineable = FALSE
						H.adaptStat("strength", 1)
						return
	if (prob(5))
		var/obj/item/stack/ore/silver/mineral = new/obj/item/stack/ore/silver(src)
		mineral.amount = 2
		if (istype(get_area(src), /area/caribbean/void/caves/special))
			mineral.amount *= 2
		H << "<span class='danger'>You found some silver ore!</span>"
		if(map.ID == MAP_NOMADS_DESERT)
			T.ChangeTurf(/turf/floor/dirt/dust)
		else
			T.ChangeTurf(/turf/floor/dirt)
		T.is_mineable = FALSE
		H.adaptStat("strength", 1)
		return
	if (prob(2))
		var/obj/item/stack/ore/gold/mineral = new/obj/item/stack/ore/gold(src)
		mineral.amount = 2
		if (istype(get_area(src), /area/caribbean/void/caves/special))
			mineral.amount *= 2
		H << "<span class='danger'>You found some gold ore!</span>"
		if(map.ID == MAP_NOMADS_DESERT)
			T.ChangeTurf(/turf/floor/dirt/dust)
		else
			T.ChangeTurf(/turf/floor/dirt)
		T.is_mineable = FALSE
		H.adaptStat("strength", 1)
		return
	if (prob(1))
		var/obj/item/stack/ore/diamond/mineral = new/obj/item/stack/ore/diamond(src)
		mineral.amount = 2
		if (istype(get_area(src), /area/caribbean/void/caves/special))
			mineral.amount *= 2
		H << "<span class='danger'>You found some raw diamonds!</span>"
		if(map.ID == MAP_NOMADS_DESERT)
			T.ChangeTurf(/turf/floor/dirt/dust)
		else
			T.ChangeTurf(/turf/floor/dirt)
		T.is_mineable = FALSE
		H.adaptStat("strength", 1)
		return
	var/obj/item/stack/material/stone/mineral = new/obj/item/stack/material/stone(src)
	mineral.amount = rand(4,8)
	if (istype(get_area(src), /area/caribbean/void/caves/special))
		mineral.amount *= 2
	H << "<span class='danger'>You found some usable stone blocks!</span>"
	if(map.ID == MAP_NOMADS_DESERT)
		T.ChangeTurf(/turf/floor/dirt/dust)
	else if (map.ID == MAP_NOMADS_JUNGLE)
		T.ChangeTurf(/turf/floor/dirt/jungledirt)
	else
		T.ChangeTurf(/turf/floor/dirt)
	T.is_mineable = FALSE
	H.adaptStat("strength", 1)
	return

/turf/floor/dirt/underground/attack_hand(mob/user)
	if (istype(src, /turf/floor/dirt/underground) && ishuman(user))
		var/turf/floor/dirt/underground/U = src
		var/mob/living/carbon/human/H = user
		if (H.ant && H.a_intent == I_GRAB)
			visible_message("<span class = 'notice'>[user] starts to break the rock with their hands...</span>", "<span class = 'notice'>You start to break the rock with the your hands...</span>")
			playsound(src,'sound/effects/pickaxe.ogg',100,1)
			if (do_after(user, (160/(H.getStatCoeff("strength"))/1.5)))
				U.collapse_check()
				if (istype(src, /turf/floor/dirt/underground/empty))
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
		var/mob/living/carbon/human/H = user
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
						new /obj/item/weapon/sandbag(T)
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

	var/mob/living/carbon/human/user

	if (ishuman(usr))
		user = usr
	else
		return
	var/turf/floor/TB = src
	if (user.ant && (TB.is_diggable) && !(locate(/obj/structure/multiz/) in user.loc))
		if (user.z < 2)
			user << "<span class='notice'>You can't dig a tunnel here, the bedrock is right below.</span>"
		else
			var/digging_tunnel_time = 200
			digging_tunnel_time /= user.getStatCoeff("strength")
			digging_tunnel_time /= (user.getStatCoeff("crafting") * user.getStatCoeff("crafting"))
			visible_message("<span class='danger'>[user] starts digging a tunnel entrance!</span>", "<span class='danger'>You start digging a tunnel entrance.</span>")
			if (do_after(user, digging_tunnel_time, user.loc))
				if (!TB.is_diggable)
					return
				new/obj/structure/multiz/ladder/ww2/tunneltop(user.loc)
				new/obj/structure/multiz/ladder/ww2/tunnelbottom(locate(user.x, user.y, user.z-1))
				var/turf/BL = get_turf(locate(user.x, user.y, user.z-1))
				if (istype(BL, /turf/floor/dirt/underground))
					BL.ChangeTurf(/turf/floor/dirt)
				visible_message("<span class='danger'>[user] finishes digging the tunnel entrance.</span>")
				if (ishuman(user))
					var/mob/living/carbon/human/H = user
					H.adaptStat("crafting", 1)
					H.adaptStat("strength", 1)
			return
	else if (locate(/obj/structure/multiz/) in user.loc)
		user << "<span class='warning'>There already is something here.</span>"
		return
	else if (!TB.is_diggable)
		user << "<span class='warning'>You cannot dig a hole here!</span>"
		return