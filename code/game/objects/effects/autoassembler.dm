//automatically assembles a vehicle in a certain range.
//requirements: 1 engine, 1 fueltank, 1 axis, 1 driving seat. All must have frames in their respective tiles.

/obj/effect/autoassembler
	name = "auto assembler"
	desc = "automatically assembles a vehicle in range."
	icon = 'icons/mob/screen/effects.dmi'
	icon_state = "AA"
	invisibility = 101
	anchored = TRUE
	density = TRUE
	opacity = FALSE
	var/rangef = 5

/obj/effect/autoassembler/New()
	..()
	spawn(50)
		var/rangeto = range(rangef,loc)
		//first we assign the axis
		var/done1 = FALSE
		var/obj/structure/vehicleparts/frame/central = null
		for (var/obj/structure/vehicleparts/axis/A in rangeto)
			if (!done1)
				for (var/obj/structure/vehicleparts/frame/F in A.loc)
					if (!done1)
						A.MouseDrop(F)
						done1 = TRUE
						central = F
		if (central)
			world.log << "Assigned the axis to the central frame."
		else
			world.log << "Axis error!"
			return FALSE
		//now connect all the frames
		var/count = 0
		for (var/obj/structure/vehicleparts/frame/A in rangeto)
			if (!A.axis)
				A.MouseDrop(central)
				count++
		world.log << "Added [count] frames."
		//then the engine
		var/done2 = FALSE
		for (var/obj/structure/engine/internal/E in rangeto)
			if (!done2)
				for (var/obj/structure/vehicleparts/frame/F in E.loc)
					if (!done2)
						central.axis.engine = E
						E.anchored = TRUE
						done2 = TRUE
		if (done2)
			world.log << "Added the engine."
		else
			world.log << "Engine error!"
			return FALSE
		//then the fueltank
		var/done3 = FALSE
		for (var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/E in rangeto)
			if (!done3)
				for (var/obj/structure/engine/internal/I in range(1,E))
					if (!done3)
						I.fueltank = E
						E.anchored = TRUE
						done3 = TRUE
		if (done3)
			world.log << "Added fueltank."
		else
			world.log << "Fueltank error!"
			return FALSE
		//finally, the drivers seat
		var/done4 = FALSE
		for (var/obj/structure/bed/chair/drivers/D in rangeto)
			if (!done4)
				for (var/obj/structure/vehicleparts/frame/F in D.loc)
					if (!done4)
						D.anchored = TRUE
						D.dir = dir
						central.axis.wheel = D.wheel
						central.axis.wheel.control = F
						done4 = TRUE
		if (done4)
			world.log << "Added driver's seat."
		else
			world.log << "Driver's Seat error!"
			return FALSE
		//and the tracks
		count = 0
		for (var/obj/structure/vehicleparts/movement/M in rangeto)
			M.MouseDrop(central)
			count++
		world.log << "Added [count] wheels/tracks."
		world.log << "Assembly complete."
		qdel(src)
		return TRUE