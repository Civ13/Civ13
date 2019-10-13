/obj/structure/converter
	name = "philosophers stone"
	desc = "DONT USE THIS!!! (Lead to Gold)"
	icon = 'icons/obj/structures.dmi'
	icon_state = "wood_pole1"
	var/idlesprite = "wood_pole1" //Icon when not full.
	var/activesprite = "impaledskull" //Icon when full.
	density = FALSE
	anchored = TRUE
	var/delay = 120 //Time to wait for the conversion to complete.
	var/input = "/obj/item/stack/material/lead" //Input material
	var/inputamount = 1 //How much material is required
	var/output = "/obj/item/stack/material/gold" //Finished material
	var/outputamount = 1 //How much material is produced.
	var/actiontext = "magicify"
	var/activesound = null
	var/endsound = null
	var/filled = FALSE
	not_movable = TRUE
	not_disassemblable = FALSE
	/* Broke plz fix i am too tired rn.
/obj/structure/converter/attackby(obj/item/M as obj, mob/user as mob)
	if(!filled)
		if(M.health < M.maxhealth)
			if(istype(M, input))
				if(M.amount >= inputamount)
					M.amount -= inputamount
					if(M.amount <= 0)
						qdel(M)
					user << "<span class='notice'>You insert [inputamount] [M.name] into the [name]!</span>"
					user << "<span class='notice'>The [name] starts to [actiontext] the [M.name].</span>"
					icon_state = activesprite
					playsound(src,activesound,60,1)
					filled = TRUE
					spawn(delay)
						visible_message("<span class='alert'>The [name] finishes.</span>")
						var/result = output(src.loc)
						result.amount = inputamount
						icon_state = idlesprite
						filled = FALSE
						playsound(src,endsound,60,1)

				else
					user << "<span class='alert'> You need to insert [inputamount] of the object! </span>"
		else
			user << "<span class='alert'> That object is [actiontext]ed enough! </span>"
	else
		user << "<span class='alert'> You empty the [name]. </span>"
		var/result = new/input(src.loc)
		result.amount = inputamount
		filled = FALSE
		*/
