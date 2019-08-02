// To clarify:
// For use_to_pickup and allow_quick_gather functionality,
// see item/attackby() (/game/objects/items.dm)
// Do not remove this functionality without good reason, cough reagent_containers cough.
// -Sayu


/obj/item/weapon/storage
	name = "storage"
	icon = 'icons/obj/storage.dmi'
	w_class = 3
	var/list/can_hold = new/list() //List of objects which this item can store (if set, it can't store anything else)
	var/list/cant_hold = new/list() //List of objects which this item can't store (in effect only if can_hold isn't set)
	var/list/is_seeing = new/list() //List of mobs which are currently seeing the contents of this item's storage
	var/max_w_class = 3 //Max size of objects that this object can store (in effect only if can_hold isn't set)
	var/max_storage_space = 8 //The sum of the storage costs of all the items in this storage item.
	var/storage_slots = null //The number of storage slots in this container.
	var/obj/screen/storage/boxes = null
	var/obj/screen/storage/storage_start = null //storage UI
	var/obj/screen/storage/storage_continue = null
	var/obj/screen/storage/storage_end = null
	var/obj/screen/storage/stored_start = null
	var/obj/screen/storage/stored_continue = null
	var/obj/screen/storage/stored_end = null
	var/obj/screen/close/closer = null
	var/use_to_pickup	//Set this to make it possible to use this item in an inverse way, so you can have the item in your hand and click items on the floor to pick them up.
	var/display_contents_with_number	//Set this to make the storage item group contents of the same type and display them as a number.
	var/allow_quick_empty	//Set this variable to allow the object to have the 'empty' verb, which dumps all the contents on the floor.
	var/allow_quick_gather	//Set this variable to allow the object to have the 'toggle mode' verb, which quickly collects all items from a tile.
	var/collection_mode = TRUE;  //0 = pick one at a time, TRUE = pick all on tile
	var/use_sound = "rustle"	//sound played when used. null for no sound.

/obj/item/weapon/storage/Destroy()
	close_all()
	qdel(boxes)
	qdel(storage_start)
	qdel(storage_continue)
	qdel(storage_end)
	qdel(stored_start)
	qdel(stored_continue)
	qdel(stored_end)
	qdel(closer)
	..()

/obj/item/weapon/storage/MouseDrop(obj/over_object as obj)
	if (!canremove)
		return

	if ((ishuman(usr) || issmall(usr)) && !ismouse(usr)) //so monkeys can take off their backpacks -- Urist

		if (over_object == usr && Adjacent(usr)) // this must come before the screen objects only block
			open(usr)
			return

		if (!( istype(over_object, /obj/screen) ))
			return ..()

		//makes sure that the storage is equipped, so that we can't drag it into our hand from miles away.
		//there's got to be a better way of doing this.
		if (!(loc == usr) || (loc && loc.loc == usr))
			return

		if (( usr.restrained() ) || ( usr.stat ))
			return


		if ((loc == usr) && !(istype(over_object, /obj/screen)) && !usr.unEquip(src))
			return

		if (istype(over_object, /obj/screen/inventory/hand))
			if ( !usr.get_active_hand() )
				var/obj/screen/inventory/hand/H = over_object
				switch(H.slot_id)
					if (slot_r_hand)
						if (!usr.r_hand)
							usr.u_equip(src)
							usr.put_in_r_hand(src)
						else
							usr << "<span class='notice'>Your right hand is already holding the [usr.r_hand].</span>"
					if (slot_l_hand)
						if (!usr.l_hand)
							usr.u_equip(src)
							usr.put_in_l_hand(src)
						else
							usr << "<span class='notice'>Your left hand is already holding the [usr.l_hand].</span>"
			else
				usr << "<span class='notice'>Your hand is too busy to grab the [src].</span>"

		add_fingerprint(usr)


/obj/item/weapon/storage/proc/return_inv()

	var/list/L = list(  )

	L += contents

	for (var/obj/item/weapon/storage/S in src)
		L += S.return_inv()
	return L

/obj/item/weapon/storage/proc/show_to(mob/user as mob)
	if (user.s_active != src)
		for (var/obj/item/I in src)
			if (I.on_found(user))
				return
	if (!user.client)
		return
	if (user.s_active)
		user.s_active.hide_from(user)
	user.client.screen -= boxes
	user.client.screen -= storage_start
	user.client.screen -= storage_continue
	user.client.screen -= storage_end
	user.client.screen -= closer
	user.client.screen -= contents
	if (closer)
		closer.icon = user.client.prefs.UI_file
		user.client.screen += closer
	user.client.screen += contents
	if (storage_slots)
		boxes.icon = user.client.prefs.UI_file
		user.client.screen += boxes
	else
		storage_start.icon = user.client.prefs.UI_file
		storage_end.icon = user.client.prefs.UI_file
		storage_continue.icon = user.client.prefs.UI_file
		user.client.screen += storage_start
		user.client.screen += storage_continue
		user.client.screen += storage_end
	user.s_active = src
	is_seeing |= user
	return

/obj/item/weapon/storage/proc/hide_from(mob/user as mob)

	if (!user.client)
		return
	user.client.screen -= boxes
	user.client.screen -= storage_start
	user.client.screen -= storage_continue
	user.client.screen -= storage_end
	user.client.screen -= closer
	user.client.screen -= contents
	if (user.s_active == src)
		user.s_active = null
	is_seeing -= user

/obj/item/weapon/storage/proc/open(mob/user as mob)
	if (use_sound)
		playsound(loc, use_sound, 50, TRUE, -5)

	orient2hud(user)
	if (user.s_active)
		user.s_active.close(user)
	show_to(user)

/obj/item/weapon/storage/proc/close(mob/user as mob)
	hide_from(user)
	user.s_active = null
	return

/obj/item/weapon/storage/proc/close_all()
	for (var/mob/M in can_see_contents())
		close(M)
		. = TRUE

/obj/item/weapon/storage/proc/can_see_contents()
	var/list/cansee = list()
	for (var/mob/M in is_seeing)
		if (M.s_active == src && M.client)
			cansee |= M
		else
			is_seeing -= M
	return cansee

//This proc draws out the inventory and places the items on it. tx and ty are the upper left tile and mx, my are the bottm right.
//The numbers are calculated from the bottom-left The bottom-left slot being TRUE,1.
/obj/item/weapon/storage/proc/orient_objs(tx, ty, mx, my)
	var/cx = tx
	var/cy = ty
	boxes.screen_loc = "[tx],[ty] to [mx],[my]"
	for (var/obj/O in contents)
		O.screen_loc = "[cx],[cy]"
		O.layer = 20
		O.plane = HUD_PLANE
		cx++
		if (cx > mx)
			cx = tx
			cy--
	closer.screen_loc = "[mx+1],[my]"
	return

//This proc draws out the inventory and places the items on it. It uses the standard position.
/obj/item/weapon/storage/proc/slot_orient_objs(var/rows, var/cols, var/list/obj/item/display_contents, Xcord=4, Ycord=2)
	var/cx = Xcord
	var/cy = Ycord+rows
	if (boxes)
		boxes.screen_loc = "[Xcord]:16,2:16 to [Xcord+cols]:16,[Ycord+rows]:16"

	if (display_contents_with_number)
		for (var/datum/numbered_display/ND in display_contents)
			ND.sample_object.screen_loc = "[cx]:16,[cy]:16"
			ND.sample_object.maptext = "<font color='white'>[(ND.number > 1)? "[ND.number]" : ""]</font>"
			ND.sample_object.layer = 20
			ND.sample_object.plane = HUD_PLANE
			cx++
			if (cx > (Xcord+cols))
				cx = Xcord
				cy--
	else
		for (var/obj/O in contents)
			O.screen_loc = "[cx]:16,[cy]:16"
			O.maptext = ""
			O.layer = 20
			O.plane = HUD_PLANE
			cx++
			if (cx > (Xcord+cols))
				cx = Xcord
				cy--
	closer.screen_loc = "[Xcord+cols+1]:16,[Ycord]:16"
	return

/obj/item/weapon/storage/proc/space_orient_objs(var/list/obj/item/display_contents,var/Xcord = 4,var/Ycord = 2)

	var/baseline_max_storage_space = 16 //should be equal to default backpack capacity
	var/storage_cap_width = 2 //length of sprite for start and end of the box representing total storage space
	var/stored_cap_width = 4 //length of sprite for start and end of the box representing the stored item
	var/storage_width = min( round( 224 * max_storage_space/baseline_max_storage_space ,1) ,284) //length of sprite for the box representing total storage space

	storage_start.overlays.Cut()

	var/matrix/M = matrix()
	M.Scale((storage_width-storage_cap_width*2+3)/32,1)
	storage_continue.transform = M

	storage_start.screen_loc = "[Xcord]:16,[Ycord]:16"
	storage_continue.screen_loc = "[Xcord]:[storage_cap_width+(storage_width-storage_cap_width*2)/2+2],[Ycord]:16"
	storage_end.screen_loc = "[Xcord]:[19+storage_width-storage_cap_width],[Ycord]:16"

	var/startpoint = FALSE
	var/endpoint = TRUE

	for (var/obj/item/O in contents)
		startpoint = endpoint + 1
		endpoint += storage_width * O.get_storage_cost()/max_storage_space

		var/matrix/M_start = matrix()
		var/matrix/M_continue = matrix()
		var/matrix/M_end = matrix()

		M_start.Translate(startpoint,0)
		M_continue.Scale((endpoint-startpoint-stored_cap_width*2)/32,1)
		M_continue.Translate(startpoint+stored_cap_width+(endpoint-startpoint-stored_cap_width*2)/2 - 16,0)
		M_end.Translate(endpoint-stored_cap_width,0)
		stored_start.transform = M_start
		stored_continue.transform = M_continue
		stored_end.transform = M_end
		storage_start.overlays += stored_start
		storage_start.overlays += stored_continue
		storage_start.overlays += stored_end

		O.screen_loc = "[Xcord]:[round((startpoint+endpoint)/2)+2],[Ycord]:16"
		O.maptext = ""
		O.layer = 20
		O.plane = HUD_PLANE

	closer.screen_loc = "[Xcord]:[storage_width+19],[Ycord]:16"
	return

/datum/numbered_display
	var/obj/item/sample_object
	var/number

	New(obj/item/sample as obj)
		if (!istype(sample))
			qdel(src)
		sample_object = sample
		number = TRUE

//This proc determins the size of the inventory to be displayed. Please touch it only if you know what you're doing.
/obj/item/weapon/storage/proc/orient2hud(mob/user as mob)

	var/adjusted_contents = contents.len

	var/Xcor = 4
	var/Ycor = 2
	var/ColCountDatum = 7
	var/Xslot = 6
	var/Yslot = 2

	if (user)
		var/datum/hud/HUDdatum = global.HUDdatums[user.defaultHUD]
		if (HUDdatum)
			Xcor = HUDdatum.ConteinerData["Xspace"]
			Ycor = HUDdatum.ConteinerData["Yspace"]
			ColCountDatum = HUDdatum.ConteinerData["ColCount"]
			Xslot = HUDdatum.ConteinerData["Xslot"]
			Yslot = HUDdatum.ConteinerData["Yslot"]

	//Numbered contents display
	var/list/datum/numbered_display/numbered_contents
	if (display_contents_with_number)
		numbered_contents = list()
		adjusted_contents = FALSE
		for (var/obj/item/I in contents)
			var/found = FALSE
			for (var/datum/numbered_display/ND in numbered_contents)
				if (ND.sample_object.type == I.type)
					ND.number++
					found = TRUE
					break
			if (!found)
				adjusted_contents++
				numbered_contents.Add( new/datum/numbered_display(I) )

	if (storage_slots == null)
		space_orient_objs(numbered_contents,Xcor,Ycor)
	else
		var/row_num = FALSE
		var/col_count = min(ColCountDatum,storage_slots) -1
		if (adjusted_contents > ColCountDatum)
			row_num = round((adjusted_contents-1) / ColCountDatum) // ColCountDatum is the maximum allowed width.
		slot_orient_objs(row_num, col_count, numbered_contents,Xslot,Yslot)
	return

//This proc return TRUE if the item can be picked up and FALSE if it can't.
//Set the stop_messages to stop it from printing messages
/obj/item/weapon/storage/proc/can_be_inserted(obj/item/W as obj, stop_messages = FALSE)
	if (!istype(W)) return //Not an item

	if (usr && usr.isEquipped(W) && !usr.canUnEquip(W))
		return FALSE

	if (loc == W)
		return FALSE //Means the item is already in the storage item

	if (storage_slots != null && contents.len >= storage_slots)
		if (!stop_messages)
			usr << "<span class='notice'>[src] is full, make some space.</span>"
		return FALSE //Storage item is full

	if (W.anchored)
		return FALSE

	if (can_hold.len)
		if (!is_type_in_list(W, can_hold))
			if (!stop_messages)
				usr << "<span class='notice'>[src] cannot hold \the [W].</span>"
			return FALSE
		var/max_instances = can_hold[W.type]
		if (max_instances && instances_of_type_in_list(W, contents) >= max_instances)
			if (!stop_messages)
				usr << "<span class='notice'>[src] has no more space specifically for \the [W].</span>"
			return FALSE

	if (cant_hold.len && is_type_in_list(W, cant_hold))
		if (!stop_messages)
			usr << "<span class='notice'>[src] cannot hold [W].</span>"
		return FALSE

	if (max_w_class != null && W.w_class > max_w_class)
		if (!stop_messages)
			usr << "<span class='notice'>[W] is too long for this [src].</span>"
		return FALSE

	var/total_storage_space = W.get_storage_cost()
	for (var/obj/item/I in contents)
		total_storage_space += I.get_storage_cost() //Adds up the combined w_classes which will be in the storage item if the item is added to it.

	if (total_storage_space > max_storage_space)
		if (!stop_messages)
			usr << "<span class='notice'>[src] is too full, make some space.</span>"
		return FALSE

	if (W.w_class >= w_class && (istype(W, /obj/item/weapon/storage)))
		if (!stop_messages)
			usr << "<span class='notice'>[src] cannot hold [W] as it's a storage item of the same size.</span>"
		return FALSE //To prevent the stacking of same sized storage items.

	return TRUE

//This proc handles items being inserted. It does not perform any checks of whether an item can or can't be inserted. That's done by can_be_inserted()
//The stop_warning parameter will stop the insertion message from being displayed. It is intended for cases where you are inserting multiple items at once,
//such as when picking up all the items on a tile with one click.
/obj/item/weapon/storage/proc/handle_item_insertion(obj/item/W as obj, prevent_warning = FALSE)
	if (!istype(W)) return FALSE
	if (usr)
		usr.remove_from_mob(W)
		usr.update_icons()	//update our overlays
	W.loc = src
	W.on_enter_storage(src)
	if (usr)
		if (usr.client && usr.s_active != src)
			usr.client.screen -= W
		W.dropped(usr)
		add_fingerprint(usr)

		if (!prevent_warning)
			for (var/mob/M in viewers(usr, null))
				if (M == usr)
					usr << "<span class='notice'>You put \the [W] into [src].</span>"
				else if (M in range(1)) //If someone is standing close enough, they can tell what it is...
					M.show_message("<span class='notice'>\The [usr] puts [W] into [src].</span>")
				else if (W && W.w_class >= 3) //Otherwise they can only see large or normal items from a distance...
					M.show_message("<span class='notice'>\The [usr] puts [W] into [src].</span>")
		if (istype(W, /obj/item/weapon/bedroll))
			icon_state = "backpack1"
		orient2hud(usr)
		if (usr.s_active)
			usr.s_active.show_to(usr)
	update_icon()
	return TRUE

//Call this proc to handle the removal of an item from the storage item. The item will be moved to the atom sent as new_target
/obj/item/weapon/storage/proc/remove_from_storage(obj/item/W as obj, atom/new_location)
	if (!istype(W)) return FALSE


	for (var/mob/M in range(1, loc))
		if (M.s_active == src)
			if (M.client)
				M.client.screen -= W

	if (new_location)
		if (ismob(loc))
			W.dropped(usr)
		if (ismob(new_location))
			W.layer = 20
			W.plane = GAME_PLANE
		else
			W.layer = initial(W.layer)
			W.plane = GAME_PLANE
		W.loc = new_location
	else
		W.loc = get_turf(src)

	if (istype(W, /obj/item/weapon/bedroll))
		icon_state = "backpack0"
	if (usr)
		orient2hud(usr)
		if (usr.s_active)
			usr.s_active.show_to(usr)
	if (W.maptext)
		W.maptext = ""
	W.on_exit_storage(src)
	update_icon()
	return TRUE

//This proc is called when you want to place an item into the storage item.
/obj/item/weapon/storage/attackby(obj/item/W as obj, mob/user as mob)
	..()

	if (!can_be_inserted(W))
		return

	if (istype(W, /obj/item/weapon/tray))
		var/obj/item/weapon/tray/T = W
		if (T.calc_carry() > 0)
			if (prob(85))
				user << "<span class='warning'>The tray won't fit in [src].</span>"
				return
			else
				W.loc = user.loc
				if ((user.client && user.s_active != src))
					user.client.screen -= W
				W.dropped(user)
				user << "<span class='warning'>God damnit!</span>"

	W.add_fingerprint(user)
	return handle_item_insertion(W)
/*
/obj/item/weapon/storage/dropped(mob/user as mob)
	return ..()*/

/obj/item/weapon/storage/attack_hand(mob/user as mob)
	if (ishuman(user))
		var/mob/living/carbon/human/H = user
		if (H.l_store == src && !H.get_active_hand())	//Prevents opening if it's in a pocket.
			H.put_in_hands(src)
			H.l_store = null
			return
		if (H.r_store == src && !H.get_active_hand())
			H.put_in_hands(src)
			H.r_store = null
			return

	if (loc == user)
		open(user)
	else
		..()
		for (var/mob/M in range(1))
			if (M.s_active == src)
				close(M)
	add_fingerprint(user)
	return

/obj/item/weapon/storage/verb/toggle_gathering_mode()
	set name = "Switch Gathering Method"
	set category = null

	collection_mode = !collection_mode
	switch (collection_mode)
		if (1)
			usr << "[src] now picks up all items in a tile at once."
		if (0)
			usr << "[src] now picks up one item at a time."


/obj/item/weapon/storage/verb/quick_empty()
	set name = "Empty Contents"
	set category = null

	if ((!ishuman(usr) && (loc != usr)) || usr.stat || usr.restrained())
		return

	var/turf/T = get_turf(src)
	hide_from(usr)
	for (var/obj/item/I in contents)
		remove_from_storage(I, T)

/obj/item/weapon/storage/New()
	..()
	if (allow_quick_empty)
		verbs += /obj/item/weapon/storage/verb/quick_empty
	else
		verbs -= /obj/item/weapon/storage/verb/quick_empty

	if (allow_quick_gather)
		verbs += /obj/item/weapon/storage/verb/toggle_gathering_mode
	else
		verbs -= /obj/item/weapon/storage/verb/toggle_gathering_mode

	spawn(5)
		var/total_storage_space = FALSE
		for (var/obj/item/I in contents)
			total_storage_space += I.get_storage_cost()
		max_storage_space = max(total_storage_space,max_storage_space) //prevents spawned containers from being too small for their contents

	boxes = new /obj/screen/storage(  )
	boxes.name = "storage"
	boxes.master = src
	boxes.icon_state = "block"
	boxes.screen_loc = "7,7 to 10,8"
	boxes.layer = 19

	storage_start = new /obj/screen/storage(  )
	storage_start.name = "storage"
	storage_start.master = src
	storage_start.icon_state = "storage_start"
	storage_start.screen_loc = "7,7 to 10,8"
	storage_start.layer = 19
	storage_continue = new /obj/screen/storage(  )
	storage_continue.name = "storage"
	storage_continue.master = src
	storage_continue.icon_state = "storage_continue"
	storage_continue.screen_loc = "7,7 to 10,8"
	storage_continue.layer = 19
	storage_end = new /obj/screen/storage(  )
	storage_end.name = "storage"
	storage_end.master = src
	storage_end.icon_state = "storage_end"
	storage_end.screen_loc = "7,7 to 10,8"
	storage_end.layer = 19

	stored_start = new /obj //we just need these to hold the icon
	stored_start.icon_state = "stored_start"
	stored_start.layer = 19
	stored_continue = new /obj
	stored_continue.icon_state = "stored_continue"
	stored_continue.layer = 19
	stored_end = new /obj
	stored_end.icon_state = "stored_end"
	stored_end.layer = 19

	closer = new /obj/screen/close(  )
	closer.master = src
	closer.icon_state = "x"
	closer.layer = 20
	orient2hud()

/obj/item/weapon/storage/emp_act(severity)
	if (!istype(loc, /mob/living))
		for (var/obj/O in contents)
			O.emp_act(severity)
	..()

/obj/item/weapon/storage/attack_self(mob/user as mob)
	//Clicking on itself will empty it, if it has the verb to do that.
	if (user.get_active_hand() == src)
		if (verbs.Find(/obj/item/weapon/storage/verb/quick_empty))
			quick_empty()
			return TRUE

/obj/item/weapon/storage/proc/make_exact_fit()
	storage_slots = contents.len

	can_hold.Cut()
	max_w_class = FALSE
	max_storage_space = FALSE
	for (var/obj/item/I in src)
		can_hold[I.type]++
		max_w_class = max(I.w_class, max_w_class)
		max_storage_space += I.get_storage_cost()

//Returns the storage depth of an atom. This is the number of storage items the atom is contained in before reaching toplevel (the area).
//Returns -1 if the atom was not found on container.
/atom/proc/storage_depth(atom/container)
	var/depth = FALSE
	var/atom/cur_atom = src

	while (cur_atom && !(cur_atom in container.contents))
		if (isarea(cur_atom))
			return -1
		if (istype(cur_atom.loc, /obj/item/weapon/storage))
			depth++
		cur_atom = cur_atom.loc

	if (!cur_atom)
		return -1	//inside something with a null loc.

	return depth

//Like storage depth, but returns the depth to the nearest turf
//Returns -1 if no top level turf (a loc was null somewhere, or a non-turf atom's loc was an area somehow).
/atom/proc/storage_depth_turf()
	var/depth = FALSE
	var/atom/cur_atom = src

	while (cur_atom && !isturf(cur_atom))
		if (isarea(cur_atom))
			return -1
		if (istype(cur_atom.loc, /obj/item/weapon/storage))
			depth++
		cur_atom = cur_atom.loc

	if (!cur_atom)
		return -1	//inside something with a null loc.

	return depth

/obj/item/proc/get_storage_cost()
	if (storage_cost)
		return storage_cost
	else
		if (w_class == TRUE)
			return TRUE
		if (w_class == 2)
			return 2
		if (w_class == 3)
			return 4
		if (w_class == 4)
			return 8
		if (w_class == 5)
			return 16
		else
			return 1000

		//return 2**(w_class-1) //1,2,4,8,16,...
