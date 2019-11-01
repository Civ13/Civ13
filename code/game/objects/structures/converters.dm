/obj/structure/converter
	name = "philosophers stone"
	desc = "DONT USE THIS!!! (Lead to Gold)"
	icon = 'icons/obj/structures.dmi'
	icon_state = "wood_pole1"
	var/idlesprite = "wood_pole1" //Icon when not full.
	var/activesprite = "impaledskull" //Icon when full.
	density = FALSE
	anchored = TRUE
	var/delay = 10 //Time to wait for the conversion to complete.
	var/input = /obj/item/stack/material/lead //Input material
	var/inputamount = 1 //How much material is required
	var/output = /obj/item/stack/material/gold //Finished material
	var/outputamount = 1 //How much material is produced.
	var/actiontext = "magicify"
	var/activesound = null
	var/endsound = null
	var/filled = FALSE
	var/overlayed = FALSE //if it should display the item on the thing.
	not_movable = TRUE
	not_disassemblable = FALSE


/obj/structure/converter/attackby(obj/item/M as obj, mob/user as mob)
	if(!filled)
		if(istype(M, input))
			if(M.amount >= inputamount)
				M.amount -= inputamount
				if(M.amount <= 0)
					qdel(M)
				user << "<span class='notice'>You insert [inputamount] [M.name] into the [name]!</span>"
				visible_message("<span class='notice'>The [M.name] starts to [actiontext].</span>")
				icon_state = activesprite
				playsound(src,activesound,60,1)
				if(overlayed)
					load_overlay(M)
				filled = TRUE
				spawn(delay)
					visible_message("<span class='alert'>The [name] finishes [actiontext]ing.</span>")
					for(outputamount)
						new output(src.loc)
					icon_state = idlesprite
					if(overlayed)
						remove_overlay(M)
					playsound(src,endsound,60,1)
					filled = FALSE
			else
				user << "<span class='alert'> You need to insert [inputamount] [M.name]! </span>"
		else
			user << "<span class='alert'> That is not the right resource! </span>"
	else
		user << "<span class='alert'> You empty the [name]. </span>"
		for(outputamount)
			new input(src.loc)
		icon_state = idlesprite
		if(overlayed)
			remove_overlay(M)
		filled = FALSE

/obj/structure/converter/proc/remove_overlay()
	src.overlays = null

/obj/structure/converter/proc/load_overlay(var/obj/A as obj)
	//remove all overlays
	remove_overlay()
	//add overlay
	src.overlays += icon(A.icon,A.icon_state)

/obj/structure/converter/tanning
	name = "tanning rack"
	desc = "Turns hide into leather"
	icon = 'icons/obj/structures.dmi'
	icon_state = "drying_rack_empty"
	idlesprite = "drying_rack_empty"
	activesprite = "drying_rack_full"
	delay = 300
	input = /obj/item/stack/material/hairlesshide
	inputamount = 1
	output = /obj/item/stack/material/leather
	outputamount = 6
	actiontext = "tan"
	overlayed = TRUE