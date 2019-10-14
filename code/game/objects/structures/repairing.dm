//Structure
//Grinding Stone
//Electric Sharpener

//Handheld
//Gun Cleaning Kit
//Sharpening Stone
/obj/structure/repair
	name = "repair bench"
	desc = "Repair your gear!."
	icon = 'icons/obj/structures.dmi'
	icon_state = "gunbench1"
	density = FALSE
	anchored = TRUE
	var/idlesprite = "gunbench1"
	var/activesprite = "gunbench1"
	var/delay = 120 //Time to do the action.
	var/noise = 'sound/machines/grindstone.ogg' //Noise to do when doing the action.
	var/repairamount = 0 //0 is full repair, any other number adds until it hits max.
	var/damageamount = 0 //How much max durability to take away.
	not_movable = TRUE
	not_disassemblable = FALSE

/* i'm sleepy i'll do this tommorow.

					visible_message("<span class='alert'>[user] starts to [actiontext] the [M.name]</span>")
					icon_state = activesprite
					if (do_after(user, delay, src))

					else
					*/