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
	var/input1 = /obj/item/stack/material/lead //Just for you fwoosh!
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
		if(istype(M, input) || (input1 && istype(M, input1)))
			if(M.amount >= inputamount)
				M.amount -= inputamount
				if(M.amount <= 0)
					qdel(M)
				to_chat(user, "<span class='notice'>You insert [inputamount] [M.name] into the [name]!</span>")
				visible_message("<span class='notice'>The [M.name] starts [actiontext]ing.</span>")
				icon_state = activesprite
				playsound(src,activesound,60,1)
				if(overlayed)
					load_overlay(M)
				filled = TRUE
				spawn(delay)
					visible_message("<span class='alert'>The [name] finishes [actiontext]ing.</span>")
					for(var/i=1,i<=outputamount,i++)
						new output(src.loc)
					icon_state = idlesprite
					if(overlayed)
						remove_overlay(M)
					playsound(src,endsound,60,1)
					filled = FALSE
			else
				to_chat(user, "<span class='alert'> You need to insert [inputamount] [M.name]! </span>")
		else if (istype(M, /obj/item/weapon/hammer) || istype(M, /obj/item/weapon/wrench))
			..()
			return
		else
			to_chat(user, "<span class='alert'> That is not the right resource! </span>")
			return
	/*else
		to_chat(user, "<span class='alert'> You empty the [name]. </span>")
		for(var/i=0,i<=inputamount,i++)
			new input(src.loc)
		icon_state = idlesprite
		if(overlayed)
			remove_overlay(M)
		filled = FALSE*/

/obj/structure/converter/proc/remove_overlay()
	src.overlays = null

/obj/structure/converter/proc/load_overlay(var/obj/item/stack/material/A as obj)
	//remove all overlays
	remove_overlay()
	//add overlay
	src.overlays += icon(A.icon,A.icon_state)

/obj/structure/converter/tanning
	name = "tanning rack"
	desc = "Dries a stack of washed hides in 30 seconds. Remove it by hand to cancel; apply bark tannin to the dried hides afterward."
	icon = 'icons/obj/structures.dmi'
	icon_state = "drying_rack_empty"
	idlesprite = "drying_rack_empty"
	activesprite = "drying_rack_full"
	delay = 300
	input = /obj/item/stack/material/wethide
	input1 = null
	inputamount = 1
	output = /obj/item/stack/material/dryhide
	outputamount = 1
	actiontext = "dry"
	overlayed = FALSE
	var/tmp/drying_epoch = 0

/obj/structure/converter/tanning/persistence_runtime_var(key)
	return (key in list("drying_epoch", "filled")) || ..()

/obj/structure/converter/tanning/attackby(obj/item/W, mob/living/user)
	if (istype(W, /obj/item/stack/material/wethide))
		if (QDELETED(src) || contents.len || !hide_worker_can_reach(user, W) || W.loc != user || !user.item_is_in_hands(W) || !isturf(loc) || !user.Adjacent(src))
			return TRUE
		var/obj/item/stack/material/wethide/hide = W
		if (hide.amount < 1 || hide.amount > hide.max_amount)
			return TRUE
		var/count = hide.amount
		var/turf/site = loc
		// Preserve the actual stack without exposing it to floor Crossed/merge hooks.
		if (!user.transfer_held_item_to(hide, src))
			to_chat(user, SPAN_WARNING("The hides could not be placed on the rack."))
			return TRUE
		if (QDELETED(src) || QDELETED(hide))
			return TRUE
		if (QDELETED(user) || loc != site || !user.Adjacent(src) || user.stat != CONSCIOUS || !user.hide_worker_connected() || contents.len != 1 || hide.loc != src || hide.amount != count)
			if (hide.loc == src)
				if (!QDELETED(user))
					user.put_in_hands(hide) // Normal inventory API falls back to a safe turf.
				else
					hide.forceMove(site)
			return TRUE
		start_hide_drying(hide)
		return TRUE
	if (istype(W, /obj/item/weapon/hammer) || istype(W, /obj/item/weapon/wrench))
		return ..()
	to_chat(user, SPAN_WARNING("Only washed wet hides go on this rack."))
	return TRUE

/obj/structure/converter/tanning/proc/start_hide_drying(obj/item/stack/material/wethide/hide)
	if (QDELETED(src) || QDELETED(hide) || hide.loc != src || !isturf(loc))
		return FALSE
	drying_epoch++
	var/epoch = drying_epoch
	var/turf/site = loc
	var/count = hide.amount
	filled = TRUE
	icon_state = activesprite
	spawn(delay)
		finish_hide_drying(hide, count, epoch, site)
	return TRUE

/obj/structure/converter/tanning/proc/finish_hide_drying(obj/item/stack/material/wethide/hide, count, epoch, turf/site)
	if (QDELETED(src) || epoch != drying_epoch || !filled || loc != site || QDELETED(hide) || hide.loc != src || hide.amount != count || count < 1 || count > hide.max_amount)
		return FALSE
	filled = FALSE
	// No yield between payment and output. Each piece stays one piece.
	if (!hide.use(count))
		return FALSE
	new /obj/item/stack/material/dryhide(src, count, FALSE)
	icon_state = activesprite
	visible_message(SPAN_NOTICE("The hides on [src] have dried. Remove them and apply tannin."))
	return TRUE

/obj/structure/converter/tanning/attack_hand(mob/living/user)
	if (QDELETED(user) || user.stat != CONSCIOUS || !user.hide_worker_connected() || !user.Adjacent(src) || !isturf(loc))
		return
	release_hides()

/obj/structure/converter/tanning/proc/release_hides()
	drying_epoch++
	filled = FALSE
	icon_state = idlesprite
	var/turf/site = get_turf(src)
	if (site)
		for (var/obj/item/I in contents.Copy())
			I.forceMove(site)

/obj/structure/converter/tanning/after_load()
	..()
	filled = FALSE
	icon_state = contents.len ? activesprite : idlesprite
	// Saved contents are durable. A restored wet batch gets a fresh full delay.
	var/obj/item/stack/material/wethide/hide = locate() in contents
	if (hide)
		start_hide_drying(hide)

/obj/structure/converter/tanning/Destroy()
	release_hides()
	return ..()

/obj/structure/converter/tanning/Del()
	release_hides()
	return ..()

/obj/structure/converter/retting_trough
	name = "retting trough"
	desc = "Soaks fiberous plants over time into retted fabric. Requires at least two seperate hemp or flax at a time."
	icon = 'icons/obj/structures.dmi'
	icon_state = "retting_trough"
	idlesprite = "retting_trough"
	activesprite = "retting_trough_full"
	delay = 250
	input = /obj/item/stack/material/hemp
	input1 = /obj/item/stack/material/flax
	inputamount = 2
	output = /obj/item/stack/material/rettedfabric
	outputamount = 1
	actiontext = "soak"
	overlayed = FALSE

/obj/structure/converter/acid_bath
	name = "industrial acidic bath"
	desc = "Soaks man-made fibres over time into usuable material. It would not be big or deep enough to fit say... a human body inside."
	icon = 'icons/obj/structures.dmi'
	icon_state = "kevlar_trough"
	idlesprite = "kevlar_trough"
	activesprite = "kevlar_trough_full"
	delay = 250
	input = /obj/item/stack/material/rawkevlar
	inputamount = 1
	output = /obj/item/stack/material/preparedkevlar
	outputamount = 1
	actiontext = "soak"
	overlayed = FALSE
