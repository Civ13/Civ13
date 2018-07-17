//With air
/turf/floor/plating/asteroid //floor piece
	name = "sand"
	icon = 'icons/turf/floors.dmi'
	icon_state = "asteroid"
	interior = FALSE
	stepsound = "dirt"

/turf/shuttle/helicopter
	name = "Helicopter cassis"
	icon = 'icons/WW2/helicopter.dmi'
	opacity = FALSE
	density = TRUE

	New()
		..()
//		if (!istype(src, /turf/shuttle/helicopter/sdkfz))
	//		var/turf/shuttle/helicopter/sdkfz/truck = new/turf/shuttle/helicopter/sdkfz(src, "0[icon_state]")
		update()

	proc/update()
		for (var/turf/t in range(1, src))
			if (!istype(t, /turf/shuttle/helicopter))
				if (!(t.y < y))
					density = TRUE
					return
		density = FALSE

/turf/shuttle/helicopter/sdkfz // "trucks"
	name = "Truck cassis"
	icon = 'icons/WW2/sdkfz.dmi'
	opacity = FALSE
	density = TRUE

	New(var/state)
		icon_state = state
		..()
		update()
