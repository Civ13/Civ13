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
				qdel(S)
			else
				H.shoveling_snow = FALSE
		else if (istype(T, /turf/floor/dirt) && istype(H) && !H.shoveling_dirt)
			if (T.available_dirt >= 1)
				H.shoveling_dirt = TRUE
				visible_message("<span class = 'notice'>[user] starts to shovel dirt into a pile.</span>", "<span class = 'notice'>You start to shovel dirt into a pile.</span>")
				playsound(src,'sound/effects/shovelling.ogg',75,1)
				if (do_after(user, rand(45,60)))
					visible_message("<span class = 'notice'>[user] shovels dirt into a pile.</span>", "<span class = 'notice'>You shovel dirt into a pile.</span>")
					H.shoveling_dirt = FALSE
					T.available_dirt -= 1
					new /obj/item/weapon/sandbag(T)
				else
					H.shoveling_dirt = FALSE
			else
				user << "<span class='notice'>All the loose dirt has been shoveled out of this spot already.</span>"
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
			sandbag_time /= (H.getStatCoeff("engineering") * H.getStatCoeff("engineering"))

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
						H.adaptStat("engineering", 3)
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
		else if (istype(C, /obj/item/weapon/screwdriver) && (flooring.flags & TURF_REMOVE_SCREWDRIVER))
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
