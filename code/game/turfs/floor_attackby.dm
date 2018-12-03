/turf/floor/attackby(obj/item/C as obj, mob/user as mob)

	if (!C || !user)
		return FALSE


	if ((flooring && istype(C, /obj/item/stack/rods)))
		return ..(C, user)

	else if (istype(C, /obj/item/weapon/reagent_containers/food/drinks))
		if (istype(C, /obj/item/weapon/reagent_containers/food/drinks/bottle))
			var/obj/item/weapon/reagent_containers/food/drinks/bottle/B = C
			if (B.rag)
				return
		if (C.reagents.total_volume)
			visible_message("<span class='notice'>\The [user] tips the contents of \the [C] on \the [src].</span>")
			C.reagents.clear_reagents()
			C.update_icon()
		return

	else if (istype(C, /obj/item/weapon/shovel))
		var/obj/snow/S = has_snow()
		var/turf/T = get_turf(user)
		var/mob/living/carbon/human/H = user
		if (S && istype(H) && !H.shoveling_snow)
			H.shoveling_snow = TRUE
			var/time_modifier = S.amount/0.05
			time_modifier = min(time_modifier, 30)
			visible_message("<span class = 'notice'>[user] starts to shovel the [S.descriptor()] from [src].</span>", "<span class = 'notice'>You start to shovel the snow from [src].</span>")
			if (do_after(user, rand(9*time_modifier,12*time_modifier)))
				visible_message("<span class = 'notice'>[user] shovels the [S.descriptor()] from [src].</span>", "<span class = 'notice'>You shovel the snow from [src].</span>")
				H.shoveling_snow = FALSE
				H.adaptStat("strength", 1)
				qdel(S)
			else
				H.shoveling_snow = FALSE
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
		else if (istype(T, /turf/floor/plating/beach/sand) && istype(H) && !H.shoveling_sand)
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

	else if (istype(C, /obj/item/weapon/pickaxe))
		var/turf/T = get_turf(src)
		var/mob/living/carbon/human/H = user
		if (istype(T, /turf/floor/dirt/underground) && istype(H))
			visible_message("<span class = 'notice'>[user] starts to break the rock with the [C.name].</span>", "<span class = 'notice'>You start to break the rock with the [C.name].</span>")
			playsound(src,'sound/effects/shovelling.ogg',100,1)
			if (do_after(user, 80/(H.getStatCoeff("strength"))))
				if (prob(25))
					if (prob(30))
						var/obj/item/stack/ore/copper/mineral = new/obj/item/stack/ore/copper(src)
						mineral.amount = rand(1,3)
						H << "<span class='danger'>You found some copper ore!</span>"
						T.ChangeTurf(/turf/floor/dirt)
						T.is_mineable = FALSE
						H.adaptStat("strength", 1)
						return
					else
						var/obj/item/stack/ore/tin/mineral = new/obj/item/stack/ore/tin(src)
						mineral.amount = rand(1,3)
						H << "<span class='danger'>You found some tin ore!</span>"
						T.ChangeTurf(/turf/floor/dirt)
						T.is_mineable = FALSE
						H.adaptStat("strength", 1)
						return
				if (prob(40) && map.age != "5000 B.C.")
					var/obj/item/stack/ore/iron/mineral = new/obj/item/stack/ore/iron(src)
					mineral.amount = rand(1,4)
					H << "<span class='danger'>You found some iron ore!</span>"
					T.ChangeTurf(/turf/floor/dirt)
					T.is_mineable = FALSE
					H.adaptStat("strength", 1)
					return
				if (prob(25))
					var/pickperc = pick(1,2,3)
					if (pickperc == 1 || map.age != "1713")
						new/obj/item/stack/ore/coal(src)
						H << "<span class='danger'>You found some coal!</span>"
						T.ChangeTurf(/turf/floor/dirt)
						T.is_mineable = FALSE
						H.adaptStat("strength", 1)
						return
					else if (pickperc == 2)
						new/obj/item/stack/ore/saltpeter(src)
						H << "<span class='danger'>You found some saltpeter!</span>"
						T.ChangeTurf(/turf/floor/dirt)
						T.is_mineable = FALSE
						H.adaptStat("strength", 1)
						return
					else if (pickperc == 3)
						new/obj/item/stack/ore/sulphur(src)
						H << "<span class='danger'>You found some sulphur!</span>"
						T.ChangeTurf(/turf/floor/dirt)
						T.is_mineable = FALSE
						H.adaptStat("strength", 1)
						return
				if (prob(5))
					new/obj/item/stack/ore/silver(src)
					H << "<span class='danger'>You found some silver ore!</span>"
					T.ChangeTurf(/turf/floor/dirt)
					T.is_mineable = FALSE
					H.adaptStat("strength", 1)
					return
				if (prob(2))
					new/obj/item/stack/ore/gold(src)
					H << "<span class='danger'>You found some gold ore!</span>"
					T.ChangeTurf(/turf/floor/dirt)
					T.is_mineable = FALSE
					H.adaptStat("strength", 1)
					return
				if (prob(1))
					new/obj/item/stack/ore/diamond(src)
					H << "<span class='danger'>You found some raw diamonds!</span>"
					T.ChangeTurf(/turf/floor/dirt)
					T.is_mineable = FALSE
					H.adaptStat("strength", 1)
					return
				var/obj/item/stack/material/stone/mineral = new/obj/item/stack/material/stone(src)
				mineral.amount = rand(2,4)
				H << "<span class='danger'>You found some usable stone blocks!</span>"
				T.ChangeTurf(/turf/floor/dirt)
				T.is_mineable = FALSE
				H.adaptStat("strength", 1)
				return
		else
			return ..(C, user)

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
			if (WWinput(user, "This will start building a dirt wall [your_dir] of you.", "Dirt Wall Construction", "Continue", list("Continue", "Stop")) == "Continue")
				visible_message("<span class='danger'>[user] starts constructing the base of a dirt wall.</span>", "<span class='danger'>You start constructing the base of a dirt wall.</span>")
				if (do_after(user, sandbag_time, user.loc))
					var/obj/item/weapon/sandbag/bag = C
					var/progress = bag.sand_amount
					qdel(C)
					var/obj/structure/window/sandbag/incomplete/sandbag = new/obj/structure/window/sandbag/incomplete(src, user)
					sandbag.progress = progress
					visible_message("<span class='danger'>[user] finishes constructing the base of a dirt wall. Anyone can now add to it.</span>")
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
			var/area/A = get_area(C)
			if (istype(A, /area/caribbean/void/caves))
				user << "<span class='notice'>You can't farm underground.</span>"
				return
			else if (istype(C, /obj/item/stack/farming/seeds/potato))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/potato(src)
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
			else if (istype(C, /obj/item/stack/farming/seeds/rice))
				visible_message("[user] places the seeds in the ploughed field.")
				new/obj/structure/farming/plant/rice(src)
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
		if (istype(T, /turf/floor/plating/grass))
			if (do_after(user, 50, user.loc))
				ChangeTurf(/turf/floor/dirt)
				return
		if (istype(T, /turf/floor/dirt) && !(istype(T, /turf/floor/dirt/ploughed)))
			if (do_after(user, 70, user.loc))
				ChangeTurf(/turf/floor/dirt/ploughed)
				return
		else
			user << "<span class='danger'>You can't plough this type of terrain.</span>"
			return

	else if (istype(C, /obj/item/weapon/covers))

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
