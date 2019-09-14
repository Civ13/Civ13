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
	var/rangeto = range(rangef,src)
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
	//now connect all the frames
	for (var/obj/structure/vehicleparts/frame/A in rangeto)
		if (!A.axis)
			A.MouseDrop(central)
	//then the engine
	var/done2 = FALSE
	for (var/obj/structure/engine/internal/E in rangeto)
		if (!done2)
			for (var/obj/structure/vehicleparts/frame/F in E.loc)
				if (!done2)
					E.MouseDrop(F)
					done2 = TRUE
	//then the fueltank
	var/done3 = FALSE
	for (var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/E in rangeto)
		if (!done3)
			for (var/obj/structure/engine/internal/I in range(1,E))
				if (!done3)
					I.fueltank = E
					E.anchored = TRUE
					done3 = TRUE
	var/done4 = FALSE
	for (var/obj/structure/bed/chair/drivers/D in rangeto)
		if (!done4)
			for (var/obj/structure/vehicleparts/frame/F in D.loc)
				if (!done4)
					D.MouseDrop(F)
					done4 = TRUE
	world.log << "Assembly complete."
	qdel(src)
	return TRUE