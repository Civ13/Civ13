/obj/effect/decal/cleanable/liquid_fuel
	//Liquid fuel is used for things that used to rely on volatile fuels or plasma being contained to a couple tiles.
	icon = 'icons/effects/effects.dmi'
	icon_state = "fuel"
	layer = TURF_LAYER+0.2
	anchored = TRUE
	var/amount = TRUE

	New(turf/newLoc,amt=1,nologs=0)
		if (!nologs)
			message_admins("Liquid fuel has spilled in [newLoc.loc.name] ([newLoc.x],[newLoc.y],[newLoc.z]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[newLoc.x];Y=[newLoc.y];Z=[newLoc.z]'>JMP</a>)")
			log_game("Liquid fuel has spilled in [newLoc.loc.name] ([newLoc.x],[newLoc.y],[newLoc.z])")
		amount = amt

		var/has_spread = FALSE
		//Be absorbed by any other liquid fuel in the tile.
		for (var/obj/effect/decal/cleanable/liquid_fuel/other in newLoc)
			if (other != src)
				other.amount += amount
				other.Spread()
				has_spread = TRUE
				break

		. = ..()
		if (!has_spread)
			Spread()
		else
			qdel(src)

	proc/Spread(exclude=list())
		//Allows liquid fuels to sometimes flow into other tiles.
		if (amount < 15) return //lets suppose welder fuel is fairly thick and sticky. For something like water, 5 or less would be more appropriate.
		var/turf/S = loc
		if (!istype(S)) return
		for (var/d in cardinal)
			var/turf/target = get_step(src,d)
			var/turf/origin = get_turf(src)
			if (origin.CanPass(null, target, FALSE, FALSE) && target.CanPass(null, origin, FALSE, FALSE))
				var/obj/effect/decal/cleanable/liquid_fuel/other_fuel = locate() in target
				if (other_fuel)
					other_fuel.amount += amount*0.25
					if (!(other_fuel in exclude))
						exclude += src
						other_fuel.Spread(exclude)
				else
					new/obj/effect/decal/cleanable/liquid_fuel(target, amount*0.25,1)
				amount *= 0.75


	flamethrower_fuel
		icon_state = "mustard"
		anchored = FALSE
		var/list/others = list()
		var/nospread = FALSE

		New(newLoc, amt = TRUE, d = FALSE, _nospread = FALSE)
			set_dir(d) //Setting this direction means you won't get torched by your own flamethrower.
			. = ..()

			nospread = _nospread

			spawn (100)
				for (var/x in others)
					qdel(x)

				qdel(src)

		Spread()
			//The spread for flamethrower fuel is much more precise, to create a wide fire pattern.
			if (amount < 0.1) return
			var/turf/S = loc
			if (!istype(S)) return

			for (var/d in list(turn(dir,90),turn(dir,-90), dir))
				var/turf/O = get_step(S,d)
				if (locate(/obj/effect/decal/cleanable/liquid_fuel/flamethrower_fuel) in O)
					continue
				if (O.CanPass(null, S, FALSE, FALSE) && S.CanPass(null, O, FALSE, FALSE))
					if (!nospread)
						var/o = new/obj/effect/decal/cleanable/liquid_fuel/flamethrower_fuel(O,amount*0.25,d)
						others += o
						O.hotspot_expose((T20C*2) + 380,500) //Light flamethrower fuel on fire immediately.

			amount *= 0.25
