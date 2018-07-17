// gibs that don't use DNA - Kachnov

/proc/gibs(atom/location, gibber_type = /obj/effect/gibspawner/generic, var/fleshcolor, var/bloodcolor)
	new gibber_type(location,fleshcolor,bloodcolor)

/obj/effect/gibspawner
	var/sparks = FALSE //whether sparks spread on Gib()
	var/list/gibtypes = list()
	var/list/gibamounts = list()
	var/list/gibdirections = list() //of lists
	var/fleshcolor //Used for gibbed humans.
	var/bloodcolor //Used for gibbed humans.

	New(location, var/_fleshcolor, var/_bloodcolor)
		..()

		if (fleshcolor) fleshcolor = _fleshcolor
		if (bloodcolor) bloodcolor = _bloodcolor
		Gib(loc)

	proc/Gib(atom/location)
		if (gibtypes.len != gibamounts.len || gibamounts.len != gibdirections.len)
			world << "<span class='warning'>Gib list length mismatch!</span>"
			return

		if (sparks)
			var/datum/effect/effect/system/spark_spread/s = PoolOrNew(/datum/effect/effect/system/spark_spread)
			s.set_up(2, TRUE, get_turf(location)) // Not sure if it's safe to pass an arbitrary object to set_up, todo
			s.start()

		var/obj/effect/decal/cleanable/blood/gibs/gib = null
		for (var/i = TRUE, i<= gibtypes.len, i++)
			if (gibamounts[i])
				for (var/j = TRUE, j<= gibamounts[i], j++)
					var/gibType = gibtypes[i]
					gib = new gibType(location)

					// Apply human species colouration to masks.
					if (fleshcolor)
						gib.fleshcolor = fleshcolor
					if (bloodcolor)
						gib.basecolor = bloodcolor

					gib.update_icon()

					gib.blood_DNA = list()

					if (istype(location,/turf/))
						var/list/directions = gibdirections[i]
						if (directions.len)
							gib.streak(directions)

		qdel(src)
