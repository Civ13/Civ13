/* Stack type objects!
 * Contains:
 * 		Stacks
 * 		Recipe datum
 * 		Recipe list datum
 */

/*
 * Stacks
 */

/obj/item/stack
	gender = PLURAL
	var/list/datum/stack_recipe/recipes
	var/singular_name
	amount = 1
	var/max_amount //also see stack recipes initialisation, param "max_res_amount" must be equal to this max_amount
	var/stacktype //determines whether different stack types can merge
	var/build_type = null //used when directly applied to a turf
	var/real_value = 1
	value = 1
	var/can_stack = FALSE //Determines if stacks should be auto-merged.
	var/customcolor = "#FFFFFF"
	var/customcolor1 = "#000000"
	var/customcolor2 = "#FFFFFF"
	var/customcode = "0000"
	var/customname = ""

/obj/item/stack/New(var/loc, var/_amount=0, var/merge = can_stack)
	..()
	if (!stacktype)
		stacktype = type
	if (_amount)
		amount = _amount
	//Check if it should be merged on creation
	if(merge)
		//For every stack in location, repeat the code.
		for(var/obj/item/stack/S in loc)
			if(istype(S, src)) // If stack types match, we merge.
				merge(S)
	return

//If a stack is pulled over another stack, this proc is called.
obj/item/stack/Crossed(var/obj/item/stack/S)
	//Checking if stack types match and if it isn't thrown to avoid scooping up stacks in flight.
	if(istype(S, stacktype) && !S.throwing)
		merge(S)
	. = ..()

//Merging two stacks, logic to avoid going over the max_amount cap.
//If we get stack with amount 0, we delete it.
/obj/item/stack/proc/merge(obj/item/stack/S)
	if(S.amount == S.max_amount || src.amount == src.max_amount)
		return
	var/transfer = src.amount
	transfer = min(transfer, S.max_amount - S.amount)
	if(pulledby)
		pulledby.start_pulling(S)
	src.amount -= transfer
	S.amount += transfer
	src.update_icon()
	S.update_icon()
	if(src.amount <= 0)
		qdel(src)
	return transfer

//Return TRUE if an immediate subsequent call to use() would succeed.
//Ensures that code dealing with stacks uses the same logic
/obj/item/stack/proc/can_use(var/used)
	if (amount < used)
		return FALSE
	return TRUE

/obj/item/stack/proc/use(var/used,var/mob/living/human/H = null)
	if (!can_use(used))
		return FALSE
	if (H)
		if (H.religion_check() == "Production")
			if (used < 4)
				amount -= used
			else if (used >= 4 && used < 10)
				amount -= (used-1)
			else if (used >= 10)
				amount -= (used-2)
			else
				amount -= used
		else
			amount -= used
	else
		amount -= used
	if (amount <= 0)
		if (usr)
			usr.remove_from_mob(src)
		qdel(src) //should be safe to qdel immediately since if someone is still using this stack it will persist for a little while longer
	return TRUE

/*
	The transfer and split procs work differently than use() and add().
	Whereas those procs take no action if the desired amount cannot be added or removed these procs will try to transfer whatever they can.
	They also remove an equal amount from the source stack.
*/

//attempts to transfer amount to S, and returns the amount actually transferred
/obj/item/stack/proc/transfer_to(obj/item/stack/S, var/_amount=null)
	if (stacktype != S.stacktype)
		return FALSE
	if (isnull(_amount))
		_amount = amount
	var/transfer = _amount
	transfer = min(transfer, S.max_amount - S.amount)
	if (transfer)
		if (prob(transfer/amount * 100))
			transfer_fingerprints_to(S)
			if (blood_DNA)
				S.blood_DNA |= blood_DNA
		amount -= transfer
		S.amount += transfer
		if (amount <= 0)
			qdel(src)
		return S
	return FALSE

//creates a new stack with the specified amount
/obj/item/stack/proc/split(var/_amount)
	if(!amount)
		return null
	if (_amount)
		var/obj/item/stack/S = new type(src.loc, _amount, FALSE)
		S.color = color
		if (prob(_amount/amount * 100))
			transfer_fingerprints_to(S)
			if (blood_DNA)
				S.blood_DNA |= blood_DNA
		amount -= _amount
		if (amount <= 0)
			qdel(src)
		return S
	return FALSE

/obj/item/stack/attack_hand(mob/user as mob)
	if (user.get_inactive_hand() == src)
		var/obj/item/stack/F = split(min(1, src.amount))
		if (F)
			F.update_icon()
			src.update_icon()
			user.put_in_hands(F)
			add_fingerprint(user)
			F.add_fingerprint(user)
			src.update_icon()
			spawn(0)
				if (src && usr.using_object == src)
					interact(usr)
	else
		..()
	return

/obj/item/stack/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, type))
		var/obj/item/stack/S = W
		merge(S)
		S.update_icon()
		src.update_icon()
		spawn(0) //give the stacks a chance to delete themselves if necessary
		if (S && usr.using_object == S)
			S.interact(usr)
		if (src && usr.using_object == src)
			interact(usr)
	else
		return ..()

/obj/item/stack/Destroy()
	if (src && usr && usr.using_object == src)
		usr << browse(null, "window=stack")
	return ..()

/obj/item/stack/AltClick(mob/living/user)
	var/turf/T = get_turf(src)
	if (T && user.TurfAdjacent(T))
		if(zero_amount())
			return
		var/max = amount
		var/stackmaterial = round(input(user,"How many to take out of the stack? (Maximum  [max])") as null|num)
		max = amount
		stackmaterial = min(max, stackmaterial)
		if(stackmaterial == null || stackmaterial <= 0)
			return
		else if (!user.item_is_in_hands(src) && !user.Adjacent(src))
			to_chat(user, "<span class='warning'>The stack isn't in your hands or next to you!</span>")
			return
		else
			change_stack(user, stackmaterial)
			to_chat(user, "<span class='notice'>You take [stackmaterial] out of the stack.</span>")

/obj/item/stack/proc/change_stack(mob/user, amount)
	var/obj/item/stack/F = split(amount)
	if (F)
		user.put_in_hands(F)
		F.update_icon()
		src.update_icon()
		add_fingerprint(user)
		F.add_fingerprint(user)
		spawn(0)
			if (src && usr.using_object == src)
				interact(usr)
	else
		..()
	return

/obj/item/stack/examine(mob/user)
	if (..(user, TRUE))
		user << "There [amount == TRUE ? "is" : "are"] [amount] [singular_name]\s in the stack."

/obj/item/stack/attack_self(mob/user as mob)
	list_recipes(user)

/obj/item/stack/proc/list_recipes(mob/user as mob, recipes_sublist)
	if (!recipes)
		return
	if (!src || amount <= 0)
		user << browse(null, "window=stack")
	user.set_using_object(src) //for correct work of onclose
	var/list/recipe_list = recipes
	if (recipe_list && recipes_sublist && recipe_list[recipes_sublist] && istype(recipe_list[recipes_sublist], /datum/stack_recipe_list))
		var/datum/stack_recipe_list/srl = recipe_list[recipes_sublist]
		recipe_list = srl.recipes
	var/t1 = text("[common_browser_style]<HTML style=\"line-height: 1.8;\"><HEAD><title>Crafting</title></HEAD><body bgcolor=\"#392611\" style=\"border-color: #392611;\"><br><tt><center><strong><font color=\"white\" size=\"4\">[]</font><br><font color=\"white\" size=\"3\">Amount Left: []</strong></font><br><br><font color=\"white\" size=\"2\">", src, amount)
	for (var/i=1;i<=recipe_list.len,i++)
		var/E = recipe_list[i]
		if (isnull(E))
			t1 += "<hr>"
			continue

		if (i>1 && !isnull(recipe_list[i-1]))
			t1+="<br>"

		if (istype(E, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/srl = E
			t1 += "<a href='?src=\ref[src];sublist=[i]'>[srl.title]</a>"

		if (istype(E, /datum/stack_recipe))
			var/datum/stack_recipe/R = E
			var/max_multiplier = round(amount / R.req_amount)
			var/title
			var/can_build = TRUE
			can_build = can_build && (max_multiplier>0)
			if (R.res_amount>1)
				title+= "[R.res_amount]x [R.title]\s"
			else
				title+= "[R.title]"
			title+= " ([R.req_amount] [singular_name]\s)"
			if (can_build)
				t1 += text("<A href='?src=\ref[src];sublist=[recipes_sublist];make=[i];multiplier=1'>[title]</A>  ")
			else
				t1 += text("<strike><font style=\"background: #2A2A2A;border-color: #392611;\">[]</font></strike>", title)
				continue
			if (R.max_res_amount>1 && max_multiplier>1)
				max_multiplier = min(max_multiplier, round(R.max_res_amount/R.res_amount))
				t1 += " |"
				var/list/multipliers = list(5,10,25)
				for (var/n in multipliers)
					if (max_multiplier>=n)
						t1 += " <A href='?src=\ref[src];make=[i];multiplier=[n]'>[n*R.res_amount]x</A>"
				if (!(max_multiplier in multipliers))
					t1 += " <A href='?src=\ref[src];make=[i];multiplier=[max_multiplier]'>[max_multiplier*R.res_amount]x</A>"

	t1 += "</TT></body></HTML>"
	user << browse(t1, "window=stack")
	onclose(user, "stack")
	return

// Custom qdel to allow returning of objects to hands on canceled build
/obj/item/stack/var/handReturnMap[0]
/obj/item/stack/proc/qdelHandReturn(var/datum/A, var/mob/user)
// add the item to the handReturnMap
	if (!(user.key in handReturnMap))
		handReturnMap[user.key] = list()
	var/datum/I = A
	handReturnMap[user.key] += list(I)
	// qdel the item
	qdel(A)

/mob/var/can_build_recipe = TRUE
/obj/item/stack/proc/produce_recipe(datum/stack_recipe/recipe, var/quantity, mob/user)
	var/required = quantity*recipe.req_amount
	var/produced = min(quantity*recipe.res_amount, recipe.max_res_amount)
	var/atom/movable/build_override_object = null
	var/customname = ""
	var/customvar = ""
	var/customvar2 = ""
	var/customdesc = ""
	var/turn_dir = 0
	var/mob/living/human/H = user
	var/obj/structure/religious/totem/newtotem = null
	var/obj/structure/simple_door/key_door/custom/build_override_door = null
	var/obj/structure/simple_door/key_door/faction_door/faction_override_door = null
	var/obj/item/weapon/key/civ/build_override_key = null
	var/obj/item/stack/money/coppercoin/build_override_coins_copper = null
	var/obj/item/stack/money/silvercoin/build_override_coins_silver = null
	var/obj/item/stack/money/goldcoin/build_override_coins_gold = null
	var/obj/item/weapon/gun/projectile/ancient/firelance/build_override_firelance = null
	var/obj/structure/vending/sales/build_override_vending = null
	var/obj/structure/supplier/build_override_supply = null
	if (istype(get_turf(H), /turf/floor/beach/water/deep) && map.ID != MAP_VOYAGE)
		H << "<span class = 'danger'>You can't build here!</span>"
		return
	if (findtext(recipe.title, "talisman"))
		if (H.religion == "none")
			H << "<span class = 'danger'>You cannot make a [recipe.title] as you have no religion.</span>"
			return
		else if (H.religion == "Priests")
			H << "<span class = 'danger'>You cannot make a [recipe.title]; your religion type doesn't allow this.</span>"
			return
		else if (H.religion == "Monks")
			H << "<span class = 'danger'>You cannot make a [recipe.title]; your religion type doesn't allow this.</span>"
			return
		else if (H.religion == "Clerics")
			H << "<span class = 'danger'>You cannot make a [recipe.title]; your religion type doesn't allow this.</span>"
			return
	else if (findtext(recipe.title, "totem"))
		if (H.religion == "none")
			H << "<span class = 'danger'>You cannot make a [recipe.title] as you have no religion.</span>"
			return
		else if (H.religion == "Priests")
			H << "<span class = 'danger'>You cannot make a [recipe.title]; your religion type doesn't allow this.</span>"
			return
		else if (H.religion == "Monks")
			H << "<span class = 'danger'>You cannot make a [recipe.title]; your religion type doesn't allow this.</span>"
			return
		else if (H.religion == "Clerics")
			H << "<span class = 'danger'>You cannot make a [recipe.title]; your religion type doesn't allow this.</span>"
			return
		else if (H.religion == "Cultists")
			H << "<span class = 'danger'>You cannot make a [recipe.title]; your religion type doesn't allow this.</span>"
			return
	else if (findtext(recipe.title, "monumental ominous statue of the deep-one") || findtext(recipe.title, "monumental ominous statue of the evil-one") || findtext(recipe.title, "monumental ominous statue of the outsider") || findtext(recipe.title, "monumental ominous statue of the ruler"))
		if (H.religion == "none")
			H << "<span class = 'danger'>You cannot make a [recipe.title] as you have no religion.</span>"
			return
		else if (H.religion == "Shamans")
			H << "<span class = 'danger'>You cannot make a [recipe.title]; your religion type doesn't allow this.</span>"
			return
		else if (H.religion == "Priests")
			H << "<span class = 'danger'>You cannot make a [recipe.title]; your religion type doesn't allow this.</span>"
			return
		else if (H.religion == "Monks")
			H << "<span class = 'danger'>You cannot make a [recipe.title]; your religion type doesn't allow this.</span>"
			return
		else if (H.religion == "Clerics")
			H << "<span class = 'danger'>You cannot make a [recipe.title]; your religion type doesn't allow this.</span>"
			return
	else if (findtext(recipe.title, "monumental stone buddha"))
		if (H.religion == "none")
			H << "<span class = 'danger'>You cannot make a [recipe.title] as you have no religion.</span>"
			return
		else if (H.religion == "Shamans")
			H << "<span class = 'danger'>You cannot make a [recipe.title]; your religion type doesn't allow this.</span>"
			return
		else if (H.religion == "Priests")
			H << "<span class = 'danger'>You cannot make a [recipe.title]; your religion type doesn't allow this.</span>"
			return
		else if (H.religion == "Cultists")
			H << "<span class = 'danger'>You cannot make a [recipe.title]; your religion type doesn't allow this.</span>"
			return
		else if (H.religion == "Clerics")
			H << "<span class = 'danger'>You cannot make a [recipe.title]; your religion type doesn't allow this.</span>"
			return
	else if (findtext(recipe.title, "monumental statue of a giant ape"))
		if (H.religion == "none")
			H << "<span class = 'danger'>You cannot make a [recipe.title] as you have no religion.</span>"
			return
		else if (H.religion == "Monks")
			H << "<span class = 'danger'>You cannot make a [recipe.title]; your religion type doesn't allow this.</span>"
			return
		else if (H.religion == "Priests")
			H << "<span class = 'danger'>You cannot make a [recipe.title]; your religion type doesn't allow this.</span>"
			return
		else if (H.religion == "Cultists")
			H << "<span class = 'danger'>You cannot make a [recipe.title]; your religion type doesn't allow this.</span>"
			return
		else if (H.religion == "Clerics")
			H << "<span class = 'danger'>You cannot make a [recipe.title]; your religion type doesn't allow this.</span>"
			return
	else if (H.original_job_title == "Gorilla tribesman" || H.original_job_title == "Ant tribesman")
		if (findtext(recipe.title, "wood sarissa") || findtext(recipe.title, "wood dory") || findtext(recipe.title, "soft wood wall") || findtext(recipe.title, "log wall"))
			H << "<span class = 'danger'>You don't know how to make this.</span>"
			return
		if (recipe.result_type == /obj/structure/simple_door/key_door/anyone/wood)
			H << "<span class = 'danger'>You don't know how to make this.</span>"
			return
		if (H.original_job_title == "Ant tribesman")
			if (findtext(recipe.title, "wall") || findtext(recipe.title, "door"))
				H << "<span class = 'danger'>You don't know how to make this.</span>"
				return
	if (findtext(recipe.title, "custom") && findtext(recipe.title, "sign"))
		customname = input(user, "Choose a name for this sign:") as text|null
		if (customname == null)
			customname = "Sign"
		customdesc = input(user, "Choose a description for this sign:") as text|null
		if (customdesc == null)
			customdesc = "An empty sign."
	else if (findtext(recipe.title, "castle gate control"))
		for(var/obj/structure/gatecontrol/GC in range(6, user.loc))
			user << "<span class = 'danger'>You cannot build a control so close to another one!</span>"
			return
	else if (findtext(recipe.title, "blast door control"))
		for(var/obj/structure/gatecontrol/blastcontrol/GC in range(10, user.loc))
			user << "<span class = 'danger'>You cannot build a control so close to another one!</span>"
			return
	else if (findtext(recipe.title, "signpost"))
		var/indesc = input(user, "Add a West sign? Leave empty to not add one.", "Signpost", "") as text|null
		if (indesc != null && indesc != "")
			customdesc = "<b>West:</b> [indesc]"
		indesc = null
		indesc = input(user, "Add a North sign? Leave empty to not add one.", "Signpost", "") as text|null
		if (indesc != null && indesc != "")
			customdesc += "<br><b>North:</b> [indesc]"
		indesc = null
		indesc = input(user, "Add a East sign? Leave empty to not add one.", "Signpost", "") as text|null
		if (indesc != null && indesc != "")
			customdesc += "<br><b>East:</b> [indesc]"
		indesc = null
		indesc = input(user, "Add a South sign? Leave empty to not add one.", "Signpost", "") as text|null
		if (indesc != null && indesc != "")
			customdesc += "<br><b>South:</b> [indesc]"

	else if (findtext(recipe.title, "carriage"))
		if (H.getStatCoeff("crafting") < 1.7)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return

	else if (findtext(recipe.title, "faction") && findtext(recipe.title, "door"))
		if (H.getStatCoeff("crafting") < 1)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return

		if (!ishuman(user))
			return
		if(H.civilization == "none")
			H << "You must be part of a faction to craft this door"
			return
		else
			faction_override_door = new /obj/structure/simple_door/key_door/faction_door
			faction_override_door.faction = H.civilization
			faction_override_door.name = "[H.civilization]'s Door"

	else if (istype(recipe.result_type,/obj/structure/barricade/ship))
		if (user.z == 1)
			if (recipe.result_type == /obj/structure/barricade/ship/wood/a7 || recipe.result_type == /obj/structure/barricade/ship/blue/b9 || recipe.result_type == /obj/structure/barricade/ship/wood/a6 || recipe.result_type == /obj/structure/barricade/ship/wood/a2 || recipe.result_type == /obj/structure/window/barrier/ship/wood/port0/north || recipe.result_type == /obj/structure/window/barrier/ship/blue/bport0/south || recipe.result_type == /obj/structure/window/barrier/ship/wood/port2/north || recipe.result_type == /obj/structure/window/barrier/ship/blue/bport3/south)
				user << "You cannot build this on the lower deck."
				return
		else
			if (recipe.result_type == /obj/structure/barricade/ship/aport0/north || recipe.result_type == /obj/structure/barricade/ship/aport0 || recipe.result_type == /obj/structure/barricade/ship/wall2)
				user << "You cannot build this on the upper deck."
				return
	else if (findtext(recipe.title, "locked") && findtext(recipe.title, "door") && !findtext(recipe.title, "unlocked"))
		if (H.getStatCoeff("crafting") < 1)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return

		if (!ishuman(user))
			return

		if (H.faction_text == INDIANS)
			H << "<span class = 'danger'>You don't know how to make this.</span>"
			return


			return
		if (!istype(H.l_hand, /obj/item/weapon/key) && !istype(H.r_hand, /obj/item/weapon/key))
			user << "<span class = 'warning'>You need to have a key in one of your hands to make a locked door.</span>"
			return

		var/obj/item/weapon/key/key = H.l_hand
		if (!key || !istype(key))
			key = H.r_hand
		if (!key || !istype(key))
			return // should never happen

		if (key)
			var/keyname = input(user, "Choose a name for the door:") as text|null
			if (keyname == null)
				keyname = "Locked"
			if (findtext(recipe.title, "iron door"))
				build_override_door = new /obj/structure/simple_door/key_door/custom
			if (findtext(recipe.title, "jail door"))
				build_override_door = new /obj/structure/simple_door/key_door/custom/jail/steeljail
			if (findtext(recipe.title, "wood jail"))
				build_override_door = new /obj/structure/simple_door/key_door/custom/jail/woodjail
			build_override_door.name = keyname
			build_override_door.custom_code = key.code

	else if (findtext(recipe.title, "tin can"))
		customname = input(user, "Choose a brand for this can:", "Tin Can Brand" , "")
		if (customname == "" || customname == null)
			customname = ""
		customcolor1 = WWinput(user, "Choose a main color:", "Tin Can Main Color" , "#000000", "color")
		if (customcolor1 == null || customcolor1 == "")
			customcolor1 = "#000000"

		customcolor2 = WWinput(user, "Choose a secondary color:", "Tin Can Secondary Color" , "#FFFFFF", "color")
		if (customcolor2 == null || customcolor2 == "")
			customcolor2 = "#FFFFFF"

	else if (findtext(recipe.title, "cigarette pack"))
		customname = input(user, "Choose a name for this pack:", "Cigarette Pack Name" , "cigarette pack")
		if (customname == "" || customname == null)
			customname = "cigarette pack"
		customcolor = WWinput(user, "Choose a color:", "Cigarette Pack Color" , "#000000", "color")
		if (customcolor == null || customcolor == "")
			return

	else if (recipe.result_type == /obj/structure/religious/statue)
		customname = input("What name to give to the statue?", "Statue", "[recipe.use_material] statue") as text
		customdesc = input("What description to add to the statue?", "Statue", "A [recipe.use_material] statue.") as text

	else if (recipe.result_type == /obj/structure/researchdesk)
		if (map && !map.resourceresearch)
			user << "\The [recipe.title] can only be built during <b>Research</b> gamemodes."
			return

	else if (recipe.result_type == /obj/structure/researchdesk/chad)
		if (!map.chad_mode_plus)
			user << "\The [recipe.title] can only be built during <b>Chad Mode +</b>."
			return

	else if (recipe.result_type == /obj/structure/oil_deposits)
		if (map && map.gamemode != "Oil Rush")
			user << "\The [recipe.title] can only be built during the <b>Oil Rush</b> gamemode."
			return
	else if (recipe.result_type == /obj/item/weapon/researchkit)
		if (map && !map.research_active)
			user << "\The [recipe.title] can only be built during the <b>Classic Research</b> gamemode."
			return

	else if (recipe.result_type == /obj/item/weapon/book/language_book)
		if (H.getStatCoeff("philosophy") < 1.35)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return

	else if (findtext(recipe.title, "motorcycle frame") || findtext(recipe.title, "boat frame"))
		if (H.getStatCoeff("crafting") < 1.35)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return
		customname = input(user, "Choose a name for this vehicle:", "Vehicle Name" , "motorcycle")
		if (customname == "" || customname == null)
			customname = "motorcycle"
		customcolor = WWinput(user, "Choose a color:", "Vehicle Color" , "#FFFFFF", "color")
		if (customcolor == null || customcolor == "")
			return

	else if (findtext(recipe.title, "locomotive"))
		if (H.getStatCoeff("crafting") < 1.9)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return

	else if (findtext(recipe.title, "fuel pump"))
		if (H.getStatCoeff("crafting") < 1.35)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return

		var/list/clist = list()
		for(var/i in map.custom_company_nr)
			for(var/list/L in map.custom_company[i])
				if (L[1]==H)
					clist += i
		if (isemptylist(clist))
			H << "You are not part of any companies!"
			return
		clist += "Cancel"
		customvar = WWinput(user, "Which company will own this [recipe.title]?","[recipe.title]","Cancel",clist)

		customname = input(user, "Choose a name for this pump:", "Fuel Pump Name" , "fuel pump")
		if (customname == "" || customname == null)
			customname = "fuel pump"
		customcolor = WWinput(user, "Fuel Pump - Choose a color:", "Fuel Pump Color" , "#FFFFFF", "color")
		if (customcolor == null || customcolor == "")
			return

	else if (findtext(recipe.title, "oil deposit"))
		if (H.civilization == null || H.civilization == "none")
			user << "You need to be part of a faction to build this!"
			return
		for(var/obj/structure/oil_deposits/OD in range(H,4))
			user << "You are too close to an existing deposit!"
			return

	else if (findtext(recipe.title, "passport"))
		if (H.civilization == null || H.civilization == "none")
			user << "You need to be part of a faction to craft a passport!"
			return

	else if (findtext(recipe.title, "holy book"))
		if (H.getStatCoeff("philosophy") < 2.4 || H.religion == "none" || (H.religious_leader == FALSE && H.religious_leader != "Clerics"))
			H << "<span class = 'danger'>You can't make a holy book.</span>"
			return
		customname = input(user, "Choose a title for the holy book:", "Holy Book Name" , "[H.religion]'s Holy Book")

	else if (findtext(recipe.title, "altar"))
		if (H.religious_leader == FALSE)
			if (H.religious_clergy == 0)
				H << "<span class = 'danger'>You can't make an altar as you are not part of the clergy.</span>"
				return

	else if (findtext(recipe.title, "nun hood") || findtext(recipe.title, "nun dress"))
		if (H.religious_leader == FALSE)
			if (H.religious_clergy == 0)
				H << "<span class = 'danger'>You can't make nun clothes as you are not part of the clergy.</span>"
				return

	else if (findtext(recipe.title, "black priest outfit"))
		if (H.religious_leader == FALSE)
			if (H.religious_clergy == 0)
				H << "<span class = 'danger'>You can't make priest clothes as you are not part of the clergy.</span>"
				return

	else if (findtext(recipe.title, "sterile mask"))
		if (H.getStatCoeff("medical") < 0.5)
			H << "<span class = 'danger'>This is too complex for your current medical skill level.</span>"
			return
	else if (findtext(recipe.title, "plague doctor mask") || findtext(recipe.title, "plague doctor suit") | findtext(recipe.title, "plague doctor hat"))
		if (H.getStatCoeff("medical") < 1.0)
			H << "<span class = 'danger'>This is too complex for your current medical skill level.</span>"
			return
	else if (findtext(recipe.title, "nightingale dress") || findtext(recipe.title, "nurse hat"))
		if (H.getStatCoeff("medical") < 1.0)
			H << "<span class = 'danger'>This is too complex for your current medical skill level.</span>"
			return

	else if (findtext(recipe.title, "religious poster") || findtext(recipe.title, "altar") || findtext(recipe.title, "religious banner"))
		if (H.religion == "none")
			H << "<span class = 'danger'>You can't make a [recipe.title] since you have no religion!</span>"
			return
	else if (findtext(recipe.title, "propaganda poster") || findtext(recipe.title, "faction banner") || findtext(recipe.title, "official faction paper"))
		if (H.civilization == "none")
			H << "<span class = 'danger'>You can't make a [recipe.title] since you have no faction!</span>"
			return
	else if (findtext(recipe.title, "wall") || findtext(recipe.title, "well"))
		if (H.getStatCoeff("crafting") < 1.1 && map.ID != MAP_VOYAGE)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return
	else if (findtext(recipe.title, "locked large stone double doors") || findtext(recipe.title, "locked large sandstone double doors") || findtext(recipe.title, "locked large lead double doors") || findtext(recipe.title, "locked large copper double doors") || findtext(recipe.title, "locked large bronze double doors") || findtext(recipe.title, "locked large silver double doors") || findtext(recipe.title, "locked large gold double doors") || findtext(recipe.title, "locked large bone double doors"))
		if (H.getStatCoeff("crafting") < 1.1)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return
	else if (findtext(recipe.title, "locked wooden privacy door"))
		if (H.getStatCoeff("crafting") < 1.1)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return
	else if (findtext(recipe.title, "unlocked iron door") || findtext(recipe.title, "unlocked large iron double doors"))
		if (H.getStatCoeff("crafting") < 1.1)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return
	else if (findtext(recipe.title, "arquebus") || findtext(recipe.title, "matchlock musket"))
		if (H.getStatCoeff("crafting") < 1.55)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return
	else if (findtext(recipe.title, "monumental stone pillar") || findtext(recipe.title, "monumental ominous statue of the deep-one") || findtext(recipe.title, "monumental ominous statue of the evil-one") || findtext(recipe.title, "monumental ominous statue of the outsider") || findtext(recipe.title, "monumental stone buddha") || findtext(recipe.title, "monumental saint statue"))
		if (H.getStatCoeff("crafting") < 1.55)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return
	else if (findtext(recipe.title, "locked reinforced large steel double doors"))
		if (H.getStatCoeff("crafting") < 1.55)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return
	else if (findtext(recipe.title, "fire lance"))
		if (H.getStatCoeff("crafting") < 1.25)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return
	else if (findtext(recipe.title, "moai") || findtext(recipe.title, "long moai") || findtext(recipe.title, "monumental sandstone obelisk") || findtext(recipe.title, "monumental stone megalith"))
		if (H.getStatCoeff("crafting") < 1.25)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return
	else if (findtext(recipe.title, "hand cannon") || findtext(recipe.title, "dragoon helmet"))
		if (H.getStatCoeff("crafting") < 1.35)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return
	else if (findtext(recipe.title, "monumental crucero cross") || findtext(recipe.title, "stone statue") || findtext(recipe.title, "sandstone statue"))
		if (H.getStatCoeff("crafting") < 1.35)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return
	else if (findtext(recipe.title, "grandfather clock") || findtext(recipe.title, "standing clock"))
		if (H.getStatCoeff("crafting") < 1.35)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return
	else if (findtext(recipe.title, "locked iron door") || findtext(recipe.title, "locked large iron double doors"))
		if (H.getStatCoeff("crafting") < 1.35)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return
	else if (findtext(recipe.title, "reinforced large steel double doors"))
		if (H.getStatCoeff("crafting") < 1.35)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return
	else if (findtext(recipe.title, "fire lance"))
		if (!istype(H.l_hand, /obj/item/weapon/material/spear) && !istype(H.r_hand, /obj/item/weapon/material/spear))
			user << "<span class = 'warning'>You need to have a spear in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/weapon/material/spear))
				build_override_firelance = new /obj/item/weapon/gun/projectile/ancient/firelance
				build_override_firelance.desc = "A spear with a gunpowder container near the tip, that can be filled with gunpowder and projectiles."
				build_override_firelance.force = round(H.l_hand.force*0.9)
				build_override_firelance.throwforce = round(H.l_hand.throwforce*0.65)
				qdelHandReturn(H.l_hand, H)
			else if (istype(H.r_hand, /obj/item/weapon/material/spear))
				build_override_firelance = new /obj/item/weapon/gun/projectile/ancient/firelance
				build_override_firelance.desc = "A spear with a gunpowder container near the tip, that can be filled with gunpowder and projectiles."
				build_override_firelance.force = round(H.r_hand.force*0.9)
				build_override_firelance.throwforce = round(H.r_hand.throwforce*0.65)
				qdelHandReturn(H.r_hand, H)
	//Handle Craftin.
	if (!findtext(recipe.title, "wood spear") && !findtext(recipe.title, "mold"))
		if (findtext(recipe.title, "hatchet") || findtext(recipe.title, "shovel") || findtext(recipe.title, "pickaxe") || findtext(recipe.title, "spear") || findtext(recipe.title, "battle axe") || findtext(recipe.title, "stone sledgehammer") || findtext(recipe.title, "lead sledgehammer") || findtext(recipe.title, "bronze sledgehammer")|| findtext(recipe.title, "iron sledgehammer")|| findtext(recipe.title, "steel sledgehammer")|| findtext(recipe.title, "uranium sledgehammer"))
			if (!istype(H.l_hand, /obj/item/weapon/material/handle) && !istype(H.r_hand, /obj/item/weapon/material/handle))
				user << "<span class = 'warning'>You need to have a wood handle in one of your hands in order to make this.</span>"
				return
			else
				if (istype(H.l_hand, /obj/item/weapon/material/handle))
					qdelHandReturn(H.l_hand, H)
				else if (istype(H.r_hand, /obj/item/weapon/material/handle))
					qdelHandReturn(H.r_hand, H)

	if (findtext(recipe.title, "carriage"))
		if (!istype(H.l_hand, /obj/item/stack/material/rope) && !istype(H.r_hand, /obj/item/stack/material/rope))
			user << "<span class = 'warning'>You need at least 20 ropes on one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/rope))
				var/obj/item/stack/material/rope/NR = H.l_hand
				if (NR.amount >= 20)
					NR.amount -= 20
					if (NR.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need at least 20 ropes on one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/rope))
				var/obj/item/stack/material/rope/NR = H.r_hand
				if (NR.amount >= 20)
					NR.amount -= 20
					if (NR.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need at least 20 ropes on one of your hands in order to make this.</span>"
					return

	if (findtext(recipe.title, "raft"))
		if (!istype(H.l_hand, /obj/item/stack/material/rope) && !istype(H.r_hand, /obj/item/stack/material/rope))
			user << "<span class = 'warning'>You need at least a stack of 2 ropes on one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/rope))
				var/obj/item/stack/material/rope/NR = H.l_hand
				if (NR.amount >= 2)
					NR.amount -= 2
					if (NR.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need at least a stack of 2 ropes on one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/rope))
				var/obj/item/stack/material/rope/NR = H.r_hand
				if (NR.amount >= 2)
					NR.amount -= 2
					if (NR.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need at least a stack of 2 ropes on one of your hands in order to make this.</span>"
					return
	else if (recipe.result_type == /obj/item/stack/material/electronics)
		if (H.getStatCoeff("crafting") < 2.2)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return
		if (!istype(H.l_hand, /obj/item/stack/material/iron) && !istype(H.r_hand, /obj/item/stack/material/iron))
			user << "<span class = 'warning'>You need to have iron in the other hand to craft electronic circuits.</span>"
			return
		if (istype(H.l_hand, /obj/item/stack/material/electronics))
			var/obj/item/stack/material/electronics/NR = H.l_hand
			NR.amount -= 1
			if (NR.amount <= 0)
				qdelHandReturn(H.l_hand, H)
		else if (istype(H.r_hand, /obj/item/stack/material/electronics))
			var/obj/item/stack/material/electronics/NR = H.r_hand
			NR.amount -= 1
			if (NR.amount <= 0)
				qdelHandReturn(H.r_hand, H)

	else if (recipe.result_type == /obj/structure/religious/totem)
		newtotem = new /obj/structure/religious/totem
		if (H.original_job_title == "Red Goose Tribesman")
			customname = "Stone Goose Totem"
			newtotem.icon_state = "goose"
			newtotem.desc = "A stone goose totem."
		else if (H.original_job_title == "Blue Turkey Tribesman")
			newtotem.name = "Stone Turkey Totem"
			newtotem.icon_state = "turkey"
			newtotem.desc = "A stone turkey totem."
		else if (H.original_job_title == "Blue Monkey Tribesman")
			newtotem.name = "Stone Monkey Totem"
			newtotem.icon_state = "monkey"
			newtotem.desc = "A stone monkey totem."
		else if (H.original_job_title == "Yellow Mouse Tribesman")
			newtotem.name = "Stone Mouse Totem"
			newtotem.icon_state = "mouse"
			newtotem.desc = "A stone mouse totem."
		else if (H.original_job_title == "White Wolf Tribesman")
			newtotem.name = "Stone Wolf Totem"
			newtotem.icon_state = "wolf"
			newtotem.desc = "A stone wolf totem."
		else if (H.original_job_title == "Black Bear Tribesman")
			newtotem.name = "Stone Bear Totem"
			newtotem.icon_state = "bear"
			newtotem.desc = "A stone bear totem."
		else
			newtotem.icon_state = pick("bear","goose", "turkey", "monkey", "mouse", "wolf")
			newtotem.name = "[H.religion] totem."
			newtotem.desc = "A stone totem, dedicated to the [H.religion] religion."
			newtotem.religion = H.religion

	else if (recipe.result_type == /obj/structure/religious/impaledskull)
		if (!istype(H.l_hand, /obj/item/organ/external/head) && !istype(H.r_hand, /obj/item/organ/external/head))
			user << "<span class = 'warning'>You need to have a human head in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/organ/external/head))
				var/targetskull = H.l_hand.name
				targetskull = replacetext(targetskull, " head", "")
				targetskull = "impaled [targetskull] skull"
				customname = targetskull
				qdelHandReturn(H.l_hand, H)
			else if (istype(H.r_hand, /obj/item/organ/external/head))
				var/targetskull = H.r_hand.name
				targetskull = replacetext(targetskull, " head", "")
				targetskull = "impaled [targetskull] skull"
				customname = targetskull
				qdelHandReturn(H.r_hand, H)

	else if (findtext(recipe.title, "copper coins"))
		build_override_coins_copper = new /obj/item/stack/money/coppercoin
		customname = input(user, "Choose a name for these coins:") as text|null
		if (H.civilization != "none")
			if (customname == null)
				customname = "[H.civilization]'s copper coins"
			else
				customname = "[H.civilization]'s copper [customname]"
			customdesc = "copper coins, minted by the [H.civilization]."
			build_override_coins_copper.name = customname
			build_override_coins_copper.desc = customdesc
		else
			build_override_coins_copper.name = "copper [customname]"
			build_override_coins_copper.desc = "copper coins, minted by [H]."

	else if (findtext(recipe.title, "silver coins"))
		build_override_coins_silver = new /obj/item/stack/money/silvercoin
		customname = input(user, "Choose a name for these coins:") as text|null
		if (H.civilization != "none")
			if (customname == null)
				customname = "[H.civilization]'s silver coins"
			else
				customname = "[H.civilization]'s silver [customname]"
			customdesc = "silver coins, minted by the [H.civilization]."
			build_override_coins_silver.name = customname
			build_override_coins_silver.desc = customdesc
		else
			build_override_coins_silver.name = "silver [customname]"
			build_override_coins_silver.desc = "silver coins, minted by [H]."

	else if (findtext(recipe.title, "gold coins"))
		build_override_coins_gold = new /obj/item/stack/money/goldcoin
		customname = input(user, "Choose a name for these coins:") as text|null
		if (H.civilization != "none")
			if (customname == null)
				customname = "[H.civilization]'s gold coins"
			else
				customname = "[H.civilization]'s gold [customname]"
			customdesc = "gold coins, minted by the [H.civilization]."
			build_override_coins_gold.name = customname
			build_override_coins_gold.desc = customdesc
		else
			build_override_coins_gold.name = "gold [customname]"
			build_override_coins_gold.desc = "gold coins, minted by [H]."

	if (findtext(recipe.title, "gravestone"))
		customname = input(user, "Choose a name to inscribe on this gravestone:") as text|null
		if (customname == "" || customname == null)
			customname = "gravestone"
		customdesc = input(user, "Choose an epitaph to inscribe on this gravestone:") as text|null
		if (customdesc == "" || customdesc == null)
			customdesc = "A gravestone made with polished stone."

	else if (findtext(recipe.title, "market stall") || findtext(recipe.title, "vending machine"))
		customname = input(user, "Choose a name for this [recipe.title]:") as text|null
		if (customname == "" || customname == null)
			customname = recipe.title
		var/list/clist = list()
		for(var/i in map.custom_company_nr)
			for(var/list/L in map.custom_company[i])
				if (L[1]==H)
					clist += i
		if (isemptylist(clist))
			H << "You are not part of any companies!"
			return
		customvar2 = recipe.title
		clist += "Cancel"
		customvar = WWinput(user, "Which company will own this [recipe.title]?","[recipe.title]","Cancel",clist)
		if (customvar == "Cancel")
			return
	else if (findtext(recipe.title, "supply stall"))
		customname = input(user, "Choose a name for this [recipe.title]:") as text|null
		if (customname == "" || customname == null)
			customname = recipe.title
		var/list/clist = list()
		for(var/i in map.custom_company_nr)
			for(var/list/L in map.custom_company[i])
				if (L[1]==H)
					clist += i
		if (isemptylist(clist))
			H << "You are not part of any companies!"
			return
		customvar2 = recipe.title
		clist += "Cancel"
		customvar = WWinput(user, "Which company will own this [recipe.title]?","[recipe.title]","Cancel",clist)
		if (customvar == "Cancel")
			return

	if (findtext(recipe.title, "well") && !findtext(recipe.title, "oil well"))
		var/puddly = FALSE
		for (var/obj/structure/sink/puddle/P in get_turf(H))
			puddly = TRUE
		if (puddly == FALSE)
			H << "<span class = 'danger'>You need to build this over a puddle.</span>"
			return
	else if (findtext(recipe.title, "cannon") || findtext(recipe.title, "catapult") || findtext(recipe.title, "spadroon") || findtext(recipe.title, "arming sword") || findtext(recipe.title, "small sword"))
		if (H.getStatCoeff("crafting") < 1.8 && !findtext(recipe.title, "catapult projectile"))
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return
	else if (findtext(recipe.title, "stormy sea") || findtext(recipe.title, "city street") || findtext(recipe.title, "sea sunset") || findtext(recipe.title, "valley") || findtext(recipe.title, "still life") || findtext(recipe.title, "bird and blossom") || findtext(recipe.title, "pine on the shore") || findtext(recipe.title, "temple by the river") || findtext(recipe.title, "desert camp") || findtext(recipe.title, "barque at sea"))
		if (H.getStatCoeff("crafting") < 2)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return

		if (!istype(H.l_hand, /obj/item/stack/material/cloth) && !istype(H.r_hand, /obj/item/stack/material/cloth))
			user << "<span class = 'warning'>You need a stack of at least 3 pieces of cloth in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/cloth))
				var/obj/item/stack/material/cloth/NCL = H.l_hand
				if (NCL.amount >= 3)
					NCL.amount -= 3
					if (NCL.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 3 pieces of cloth in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/cloth))
				var/obj/item/stack/material/cloth/NCL = H.r_hand
				if (NCL.amount >= 3)
					NCL.amount -= 3
					if (NCL.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 3 pieces of cloth in one of your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "monumental marble statue of venus") || findtext(recipe.title, "monumental bronze statue of karl marx"))
		if (H.getStatCoeff("crafting") < 2)
			H << "<span class = 'danger'>This is too complex for your skill level.</span>"
			return

	else if (findtext(recipe.title, "gong") && !findtext(recipe.title, "gong mallet"))
		if (!istype(H.l_hand, /obj/item/stack/material/bronze) && !istype(H.r_hand, /obj/item/stack/material/bronze))
			user << "<span class = 'warning'>You need a stack of at least 5 bronze ingots in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/bronze))
				var/obj/item/stack/material/bronze/NB = H.l_hand
				if (NB.amount >= 5)
					NB.amount -= 5
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 5 bronze ingots in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/bronze))
				var/obj/item/stack/material/bronze/NB = H.r_hand
				if (NB.amount >= 5)
					NB.amount -= 5
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 5 bronze ingots in one of your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "bell stand"))
		if (!istype(H.l_hand, /obj/item/stack/material/copper) && !istype(H.r_hand, /obj/item/stack/material/copper))
			user << "<span class = 'warning'>You need a stack of at least 3 copper ingots in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/copper))
				var/obj/item/stack/material/copper/NB = H.l_hand
				if (NB.amount >= 3)
					NB.amount -= 3
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 3 copper ingots in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/copper))
				var/obj/item/stack/material/copper/NB = H.r_hand
				if (NB.amount >= 3)
					NB.amount -= 3
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 3 copper ingots in one of your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "macuahuitl"))
		if (!istype(H.l_hand, /obj/item/stack/material/obsidian) && !istype(H.r_hand, /obj/item/stack/material/obsidian))
			user << "<span class = 'warning'>You need a stack of at least 4 cut rocks of obsidian in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/obsidian))
				var/obj/item/stack/material/obsidian/NB = H.l_hand
				if (NB.amount >= 4)
					NB.amount -= 4
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 4 cut rocks of obsidian in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/obsidian))
				var/obj/item/stack/material/obsidian/NB = H.r_hand
				if (NB.amount >= 4)
					NB.amount -= 4
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 4 cut rocks of obsidian in one of your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "chimalli"))
		if (!istype(H.l_hand, /obj/item/stack/material/leather) && !istype(H.r_hand, /obj/item/stack/material/leather))
			user << "<span class = 'warning'>You need a stack of at least 2 leather sheets in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/leather))
				var/obj/item/stack/material/leather/NB = H.l_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 leather sheets in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/leather))
				var/obj/item/stack/material/leather/NB = H.r_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 leather sheets in one of your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "aztec harness"))
		if (!istype(H.l_hand, /obj/item/stack/material/leather) && !istype(H.r_hand, /obj/item/stack/material/leather))
			user << "<span class = 'warning'>You need at least 0.2 parts of a leather sheet in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/leather))
				var/obj/item/stack/material/leather/NB = H.l_hand
				if (NB.amount >= 0.2)
					NB.amount -= 0.2
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need at least 0.2 parts of a leather sheet in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/leather))
				var/obj/item/stack/material/leather/NB = H.r_hand
				if (NB.amount >= 0.2)
					NB.amount -= 0.2
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need at least 0.2 parts of a leather sheet in one of your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "primitive wood armor"))
		if (!istype(H.l_hand, /obj/item/stack/material/wood) && !istype(H.r_hand, /obj/item/stack/material/wood))
			user << "<span class = 'warning'>You need at least 15 units of wood in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/rope))
				var/obj/item/stack/material/rope/NB = H.l_hand
				if (NB.amount >= 3)
					NB.amount -= 3
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need at least 3 lengths of rope in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/rope))
				var/obj/item/stack/material/rope/NB = H.r_hand
				if (NB.amount >= 3)
					NB.amount -= 3
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need at least 3 lengths of rope in one of your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "primitive bone hair-pipe armor"))
		if (!istype(H.l_hand, /obj/item/stack/material/bone) && !istype(H.r_hand, /obj/item/stack/material/bone))
			user << "<span class = 'warning'>You need at least 5 pieces of bone in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/rope))
				var/obj/item/stack/material/rope/NB = H.l_hand
				if (NB.amount >= 3)
					NB.amount -= 3
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need at least 3 lengths of rope in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/rope))
				var/obj/item/stack/material/rope/NB = H.r_hand
				if (NB.amount >= 3)
					NB.amount -= 3
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need at least 3 lengths of rope in one of your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "doge hat"))
		if (!istype(H.l_hand, /obj/item/stack/material/cloth) && !istype(H.r_hand, /obj/item/stack/material/cloth))
			user << "<span class = 'warning'>You need a stack of at least 4 cloth in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/gold))
				var/obj/item/stack/material/gold/NB = H.l_hand
				if (NB.amount >= 1)
					NB.amount -= 1
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 1 gold in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/gold))
				var/obj/item/stack/material/gold/NB = H.r_hand
				if (NB.amount >= 1)
					NB.amount -= 1
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 1 gold in one your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "doge outfit"))
		if (!istype(H.l_hand, /obj/item/stack/material/cloth) && !istype(H.r_hand, /obj/item/stack/material/cloth))
			user << "<span class = 'warning'>You need a stack of at least 8 cloth in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/gold))
				var/obj/item/stack/material/gold/NB = H.l_hand
				if (NB.amount >= 1)
					NB.amount -= 1
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 1 gold in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/gold))
				var/obj/item/stack/material/gold/NB = H.r_hand
				if (NB.amount >= 1)
					NB.amount -= 1
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 1 gold in one your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "gold laurel crown"))
		if (!istype(H.l_hand, /obj/item/stack/material/leaf) && !istype(H.r_hand, /obj/item/stack/material/leaf))
			user << "<span class = 'warning'>You need a stack of at least 6 leaves in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/gold))
				var/obj/item/stack/material/gold/NB = H.l_hand
				if (NB.amount >= 1)
					NB.amount -= 1
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 1 gold in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/gold))
				var/obj/item/stack/material/gold/NB = H.r_hand
				if (NB.amount >= 1)
					NB.amount -= 1
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 1 gold in one your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "imperial gold laurel crown")) // for crabs
		if (!istype(H.l_hand, /obj/item/stack/material/leaf) && !istype(H.r_hand, /obj/item/stack/material/leaf))
			user << "<span class = 'warning'>You need a stack of at least 3 leaves in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/gold))
				var/obj/item/stack/material/gold/NB = H.l_hand
				if (NB.amount >= 1)
					NB.amount -= 1
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 1 gold in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/gold))
				var/obj/item/stack/material/gold/NB = H.r_hand
				if (NB.amount >= 1)
					NB.amount -= 1
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 1 gold in one your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "leaf crown") || findtext(recipe.title, "ceremonial leaf crown"))
		if (!istype(H.l_hand, /obj/item/stack/material/leaf) && !istype(H.r_hand, /obj/item/stack/material/leaf))
			user << "<span class = 'warning'>You need a stack of at least 4 leaves in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/leather))
				var/obj/item/stack/material/leather/NB = H.l_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 leather in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/leather))
				var/obj/item/stack/material/leather/NB = H.r_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 leather in one your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "fiendish headdress"))
		if (!istype(H.l_hand, /obj/item/stack/material/cloth) && !istype(H.r_hand, /obj/item/stack/material/cloth))
			user << "<span class = 'warning'>You need a stack of at least 2 cloth in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/bone))
				var/obj/item/stack/material/bone/NB = H.l_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 bone in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/bone))
				var/obj/item/stack/material/bone/NB = H.r_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 bone in one your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "black african mask") || findtext(recipe.title, "ceremonial black african mask"))
		if (!istype(H.l_hand, /obj/item/stack/material/wood) && !istype(H.r_hand, /obj/item/stack/material/wood))
			user << "<span class = 'warning'>You need a stack of at least 3 wood in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/pelt/cowpelt))
				var/obj/item/stack/material/pelt/cowpelt/NB = H.l_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 cowpelts in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/pelt/cowpelt))
				var/obj/item/stack/material/pelt/cowpelt/NB = H.r_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 cowpelts in one of your hands in order to make this.</span>"
					return
/*
	else if (findtext(recipe.title, "armorbench"))
		if (!istype(H.l_hand, /obj/item/stack/material/wood) && !istype(H.r_hand, /obj/item/stack/material/wood))
			user << "<span class = 'warning'>You need a stack of at least 10 wood in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.l_hand
				if (NB.amount >= 3)
					NB.amount -= 3
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 3 iron in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.r_hand
				if (NB.amount >= 3)
					NB.amount -= 3
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 3 iron in one of your hands in order to make this.</span>"
					return
*/
	else if (findtext(recipe.title, "fortress wall"))
		if (!istype(H.l_hand, /obj/item/stack/material/stone) && !istype(H.r_hand, /obj/item/stack/material/stone))
			user << "<span class = 'warning'>You need a stack of at least 8 stone in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/stonebrick))
				var/obj/item/stack/material/stonebrick/NB = H.l_hand
				if (NB.amount >= 8)
					NB.amount -= 8
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 8 stone bricks in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/stonebrick))
				var/obj/item/stack/material/stonebrick/NB = H.r_hand
				if (NB.amount >= 8)
					NB.amount -= 8
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 8 stone bricks in one of your hands in order to make this.</span>"
					return
	else if (findtext(recipe.title, "sandstone fortress wall"))
		if (!istype(H.l_hand, /obj/item/stack/material/sandstone) && !istype(H.r_hand, /obj/item/stack/material/sandstone))
			user << "<span class = 'warning'>You need a stack of at least 8 sandstone in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/stonebrick))
				var/obj/item/stack/material/stonebrick/NB = H.l_hand
				if (NB.amount >= 5)
					NB.amount -= 5
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 5 stone bricks in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/stonebrick))
				var/obj/item/stack/material/stonebrick/NB = H.r_hand
				if (NB.amount >= 5)
					NB.amount -= 5
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 5 stone bricks in one of your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "purple arabic turban helmet") || findtext(recipe.title, "red arabic turban helmet") || findtext(recipe.title, "green arabic turban helmet") || findtext(recipe.title, "blue arabic turban helmet"))
		if (!istype(H.l_hand, /obj/item/stack/material/cloth) && !istype(H.r_hand, /obj/item/stack/material/cloth))
			user << "<span class = 'warning'>You need a stack of at least 5 cloth in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.l_hand
				if (NB.amount >= 3)
					NB.amount -= 3
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 3 iron in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.r_hand
				if (NB.amount >= 3)
					NB.amount -= 3
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 3 iron in one your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "emirate turban"))
		if (!istype(H.l_hand, /obj/item/stack/material/cloth) && !istype(H.r_hand, /obj/item/stack/material/cloth))
			user << "<span class = 'warning'>You need a stack of at least 7 cloth in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.l_hand
				if (NB.amount >= 3)
					NB.amount -= 3
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 3 iron in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.r_hand
				if (NB.amount >= 3)
					NB.amount -= 3
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 3 iron in one your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "leather samurai armor") || findtext(recipe.title, "red leather samurai armor") || findtext(recipe.title, "blue leather samurai armor") || findtext(recipe.title, "black leather samurai armor"))
		if (!istype(H.l_hand, /obj/item/stack/material/leather) && !istype(H.r_hand, /obj/item/stack/material/leather))
			user << "<span class = 'warning'>You need a stack of at least 10 leather in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.l_hand
				if (NB.amount >= 5)
					NB.amount -= 5
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 5 iron in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.r_hand
				if (NB.amount >= 5)
					NB.amount -= 5
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 5 iron in one your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "leather samurai helmet") || findtext(recipe.title, "red leather samurai helmet") || findtext(recipe.title, "blue leather samurai helmet") || findtext(recipe.title, "black leather samurai helmet"))
		if (!istype(H.l_hand, /obj/item/stack/material/leather) && !istype(H.r_hand, /obj/item/stack/material/leather))
			user << "<span class = 'warning'>You need a stack of at least 7 leather in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.l_hand
				if (NB.amount >= 3)
					NB.amount -= 3
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 3 iron in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.r_hand
				if (NB.amount >= 3)
					NB.amount -= 3
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 3 iron in one your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "grandfather clock"))
		if (!istype(H.l_hand, /obj/item/stack/material/wood) && !istype(H.r_hand, /obj/item/stack/material/wood))
			user << "<span class = 'warning'>You need a stack of at least 9 wood in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/glass))
				var/obj/item/stack/material/glass/NB = H.l_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 glass in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/glass))
				var/obj/item/stack/material/glass/NB = H.r_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 glass in one your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "standing clock"))
		if (!istype(H.l_hand, /obj/item/stack/material/wood) && !istype(H.r_hand, /obj/item/stack/material/wood))
			user << "<span class = 'warning'>You need a stack of at least 6 wood in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/glass))
				var/obj/item/stack/material/glass/NB = H.l_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 glass in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/glass))
				var/obj/item/stack/material/glass/NB = H.r_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 glass in one your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "wooden house door"))
		if (!istype(H.l_hand, /obj/item/stack/material/wood) && !istype(H.r_hand, /obj/item/stack/material/wood))
			user << "<span class = 'warning'>You need a stack of at least 5 wood in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/glass))
				var/obj/item/stack/material/glass/NB = H.l_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 glass in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/glass))
				var/obj/item/stack/material/glass/NB = H.r_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 glass in one your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "plague doctor mask"))
		if (!istype(H.l_hand, /obj/item/stack/material/cloth) && !istype(H.r_hand, /obj/item/stack/material/cloth))
			user << "<span class = 'warning'>You need a stack of at least 4 cloth in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/medical/advanced/herbs))
				var/obj/item/stack/medical/advanced/herbs/NB = H.l_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need at least a stack of two medicinal herbs in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/medical/advanced/herbs))
				var/obj/item/stack/medical/advanced/herbs/NB = H.r_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need at least a stack of two medicinal herbs in one of your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "khepresh war crown"))
		if (!istype(H.l_hand, /obj/item/stack/material/leather) && !istype(H.r_hand, /obj/item/stack/material/leather))
			user << "<span class = 'warning'>You need a stack of at least 3 leather in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/gold))
				var/obj/item/stack/material/gold/NB = H.l_hand
				if (NB.amount >= 1)
					NB.amount -= 1
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 1 gold in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/gold))
				var/obj/item/stack/material/gold/NB = H.r_hand
				if (NB.amount >= 1)
					NB.amount -= 1
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 1 gold in one your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "steppe leather helmet"))
		if (!istype(H.l_hand, /obj/item/stack/material/leather) && !istype(H.r_hand, /obj/item/stack/material/leather))
			user << "<span class = 'warning'>You need a stack of at least 3 leather in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.l_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 iron in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.r_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 iron in one your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "leather skullcap helmet"))
		if (!istype(H.l_hand, /obj/item/stack/material/leather) && !istype(H.r_hand, /obj/item/stack/material/leather))
			user << "<span class = 'warning'>You need a stack of at least 5 leather in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.l_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 iron in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.r_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 iron in one your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "television"))
		if (!istype(H.l_hand, /obj/item/stack/material/electronics) && !istype(H.r_hand, /obj/item/stack/material/electronics))
			user << "<span class = 'warning'>You need a stack of at least 3 electronics in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.l_hand
				if (NB.amount >= 4)
					NB.amount -= 4
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 4 iron in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.r_hand
				if (NB.amount >= 4)
					NB.amount -= 4
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 4 iron in one your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "brown napoleonic bearskin hat"))
		if (!istype(H.l_hand, /obj/item/stack/material/pelt/bearpelt/brown) && !istype(H.r_hand, /obj/item/stack/material/pelt/bearpelt/brown))
			user << "<span class = 'warning'>You need a stack of at least 4 brown bear pelts in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/bronze))
				var/obj/item/stack/material/bronze/NB = H.l_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 bronze in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/bronze))
				var/obj/item/stack/material/bronze/NB = H.r_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 bronze in one your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "black napoleonic bearskin hat"))
		if (!istype(H.l_hand, /obj/item/stack/material/pelt/bearpelt/black) && !istype(H.r_hand, /obj/item/stack/material/pelt/bearpelt/black))
			user << "<span class = 'warning'>You need a stack of at least 4 black bear pelts in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/bronze))
				var/obj/item/stack/material/bronze/NB = H.l_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 bronze in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/bronze))
				var/obj/item/stack/material/bronze/NB = H.r_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 bronze in one your hands in order to make this.</span>"
					return

	else if (findtext(recipe.title, "white napoleonic bearskin hat"))
		if (!istype(H.l_hand, /obj/item/stack/material/pelt/bearpelt/white) && !istype(H.r_hand, /obj/item/stack/material/pelt/bearpelt/white))
			user << "<span class = 'warning'>You need a stack of at least 4 white bear pelts in one of your hands in order to make this.</span>"
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/bronze))
				var/obj/item/stack/material/bronze/NB = H.l_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 bronze in one of your hands in order to make this.</span>"
					return
			else if (istype(H.r_hand, /obj/item/stack/material/bronze))
				var/obj/item/stack/material/bronze/NB = H.r_hand
				if (NB.amount >= 2)
					NB.amount -= 2
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					user << "<span class = 'warning'>You need a stack of at least 2 bronze in one your hands in order to make this.</span>"
					return

	if (!can_use(required))
		if (produced>1)
			user << "<span class='warning'>You haven't got enough [src] to build \the [produced] [recipe.title]\s!</span>"
		else
			user << "<span class='warning'>You haven't got enough [src] to build \the [recipe.title]!</span>"
		return

	if (recipe.one_per_turf && (locate(recipe.result_type) in user.loc))
		user << "<span class='warning'>There is another [recipe.title] here!</span>"
		return

	if (recipe.on_floor && !isfloor(user.loc))
		user << "<span class='warning'>\The [recipe.title] must be constructed on the floor!</span>"
		return

	if (ishuman(user))
		H = user

	if (ispath(recipe.result_type, /obj/structure))
		if (!ispath(recipe.result_type, /obj/structure/noose))
			for (var/obj/structure/multiz/M in get_turf(H))
				if (recipe.title != "mine support")
					H << "<span class = 'danger'>You can't build a structure here.</span>"
					return
	else if (recipe.result_type == /obj/item/weapon/key)
		if (H.faction_text == INDIANS)
			H << "<span class = 'danger'>You don't know how to make this.</span>"
			return
		else
			var/keycode = input(user, "Choose a code for the key(From 1000 to 9999):") as num
			keycode = Clamp(keycode, 1000, 9999)
			var/keyname = input(user, "Choose a name for the key:") as text|null
			if (keyname == null)
				keyname = "Key"
			build_override_key = new /obj/item/weapon/key/civ
			build_override_key.name = keyname
			build_override_key.code = keycode

	else if (recipe.result_type == /obj/structure/noose)
		var/structurecheck = 0

		for (var/obj/structure/structure in get_turf(H))
			if ((structure.density && !structure.low) || istype(structure, /obj/structure/bed))
				if (!(structure.flags & ON_BORDER))
					structurecheck = 2
			else if (structurecheck == 0)
				structurecheck = 1
		if (structurecheck != 2)
			for (var/obj/item/weapon/stool/stool in get_turf(H))
				structurecheck = 2

		var/area/H_area = get_area(H)

		if (structurecheck == 0)
			H << "<span class = 'warning'>You need to be on a structure to make a noose.</span>"
			return
		else if (structurecheck == 1)
			H << "<span class = 'warning'>This structure is not suitable for standing on.</span>"
			return

		if (H_area.location == AREA_OUTSIDE)

			var/turf/north = get_step(H, NORTH)

			var/structurecheck2 = FALSE
			if (north)
				for (var/obj/structure/S in north)
					if (S.density)
						structurecheck2 = TRUE
						break

			if (!structurecheck2 && !north.density)
				H << "<span class = 'warning'>You need a ceiling to make a noose.</span>"
				return

	if (recipe.time)
		var/buildtime = recipe.time
		if (H && H.getStatCoeff("strength"))
			buildtime /= H.getStatCoeff("strength")
			buildtime /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))

		buildtime = round(buildtime)

		user << "<span class='notice'>Building [recipe.title] ...</span>"
		if (!do_after(user, buildtime))
			if (H.key in handReturnMap)
				var/atom/O
				var/datum/A
				for(A in handReturnMap[H.key])
					O = new A.type()
					H.put_in_hands(O)
				handReturnMap.Remove(H.key)
			return

		if (H)
			H.adaptStat("crafting", 1*recipe.req_amount)
	if (findtext(recipe.title, "coil"))
		produced = 10
//this only works for stacks!!
	else if (recipe.result_type == /obj/item/stack/ammopart/stoneball)
		produced = 2
	else if (recipe.result_type == /obj/item/stack/ammopart/bullet)
		produced = 3
	else if (recipe.result_type == /obj/item/stack/ammopart/casing/rifle)
		produced = 3
	else if (recipe.result_type == /obj/item/stack/ammopart/casing/pistol)
		produced = 3
	else if (recipe.result_type == /obj/item/stack/ammopart/musketball)
		produced = 2
	else if (recipe.result_type == /obj/item/stack/ammopart/musketball_pistol)
		produced = 3
	else if (recipe.result_type == /obj/item/stack/ammopart/blunderbuss)
		produced = 2
	else if (recipe.result_type == /obj/item/stack/money/silvercoin)
		produced = 10
	else if (recipe.result_type == /obj/item/stack/money/goldcoin)
		produced = 5
	else if (recipe.result_type == /obj/item/stack/money/coppercoin)
		produced = 5
	else if (recipe.result_type == /obj/item/stack/material/barbwire)
		produced = 2
	else if (recipe.result_type == /obj/item/stack/arrowhead/stone)
		produced = 4
	else if (recipe.result_type == /obj/item/stack/arrowhead/copper)
		produced = 4
	else if (recipe.result_type == /obj/item/stack/arrowhead/bronze)
		produced = 4
	else if (recipe.result_type == /obj/item/stack/arrowhead/iron)
		produced = 4
	else if (recipe.result_type == /obj/item/stack/arrowhead/steel)
		produced = 4
	else if (recipe.result_type == /obj/item/stack/arrowhead/vial)
		produced = 4
	if (recipe.result_type == /obj/structure/sink/well || recipe.result_type == /obj/structure/sink/well/sandstone || recipe.result_type == /obj/structure/sink/well/marble)
		for (var/obj/structure/sink/puddle/P in get_turf(H))
			qdel(P)
	var/inpt = 50
	if (recipe.result_type == /obj/structure/cannon/modern/tank)
		inpt = input(user,"Choose the gun's caliber: (50mm-150mm, cost 40 steel per 75mm)") as num
		if (!isnum(inpt))
			return
		if (inpt < 50)
			inpt = 50
		else if (inpt > 150)
			inpt = 150
		required = 40*(inpt/75)
	else if (recipe.result_type == /obj/item/stack/ammopart/casing/tank)
		inpt = input(user,"Choose the casing's caliber: (50mm-150mm, cost 2 copper per 75mm)") as num
		if (!isnum(inpt))
			return
		if (inpt < 50)
			inpt = 50
		else if (inpt > 150)
			inpt = 150
		required = 2*(inpt/75)
	if (use(required,H))
		var/atom/O
		if (recipe && recipe.use_material && recipe.result_type)
			O = new recipe.result_type(user.loc, recipe.use_material)
		else
			O = new recipe.result_type(user.loc)

		if(istype(O, /obj/structure/cannon/modern/tank))
			var/obj/structure/cannon/modern/tank/T = O
			T.caliber = inpt
			T.name = "[T.caliber]mm tank cannon"
			T.w_class = T.caliber/2

		if(istype(O, /obj/item/stack/ammopart/casing/tank))
			var/obj/item/stack/ammopart/casing/tank/T = O
			T.caliber = inpt
			T.name = "[T.caliber]mm cannon casing"

		if (istype(O, /obj/structure/curtain) && !istype(O,/obj/structure/curtain/leather))
			var/input = WWinput(user, "Choose the color:", "Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				O.color = input
				return
		if (istype(O, /obj/structure/closet/crate/wall_mailbox) && !istype(O, /obj/structure/closet/crate/wall_mailbox/wood_mailbox))
			var/input = WWinput(user, "Choose the color:", "Color" , "#FFFFFF", "color")
			if (input == null || input == "")
				return
			else
				var/obj/structure/closet/crate/wall_mailbox/M = O
				var/image/mailbox_color_overlay = image("icon" = 'icons/obj/mail.dmi', "icon_state" = "wall_mailbox_closed")
				mailbox_color_overlay.color = input
				M.mailbox_color = input
				M.overlays += mailbox_color_overlay
				M.loc = get_step(user, user.dir)
				return
		if (istype(O, /obj/structure/sign) && !istype(O, /obj/structure/sign/signpost))
			if (customname != "")
				O.name = customname
			if (customdesc != "")
				O.desc = customdesc
			var/obj/structure/sign/S = O
			S.loc = get_step(user, user.dir)
			return
		if (istype(O, /obj/structure/noticeboard) || istype(O, /obj/structure/mirror))
			var/obj/structure/noticeboard/N = O
			N.loc = get_step(user, user.dir)
			return
		if (istype(O, /obj/item/clothing/accessory/medal))
			if (customdesc != "")
				O.desc = customdesc
			var/obj/item/clothing/accessory/medal/M = O
			M.loc = get_turf(user)
			return
		if (build_override_firelance)
			build_override_firelance.loc = get_turf(O)
			build_override_firelance.set_dir(user.dir)
			build_override_firelance.add_fingerprint(user)
			qdel(O)
			return
		if (build_override_key)
			build_override_key.loc = get_turf(O)
			build_override_key.set_dir(user.dir)
			build_override_key.add_fingerprint(user)
			qdel(O)
			return


		if (build_override_coins_copper)
			build_override_coins_copper.loc = get_turf(O)
			build_override_coins_copper.set_dir(user.dir)
			build_override_coins_copper.add_fingerprint(user)
			build_override_coins_copper.amount = produced
			qdel(O)
			return

		if (build_override_coins_silver)
			build_override_coins_silver.loc = get_turf(O)
			build_override_coins_silver.set_dir(user.dir)
			build_override_coins_silver.add_fingerprint(user)
			build_override_coins_silver.amount = produced
			qdel(O)
			return

		if (build_override_coins_gold)
			build_override_coins_gold.loc = get_turf(O)
			build_override_coins_gold.set_dir(user.dir)
			build_override_coins_gold.add_fingerprint(user)
			build_override_coins_gold.amount = produced
			qdel(O)
			return

		if (build_override_object)
			build_override_object.loc = get_turf(O)
			build_override_object.set_dir(user.dir)
			build_override_object.add_fingerprint(user)
			qdel(O)
			return

		if (newtotem)
			newtotem.loc = get_turf(O)
			newtotem.set_dir(user.dir)
			newtotem.add_fingerprint(user)
			qdel(O)
			return
		if (build_override_door)
			build_override_door.loc = get_turf(O)
			build_override_door.set_dir(user.dir)
			build_override_door.add_fingerprint(user)
			qdel(O)
			return
		if (faction_override_door)
			faction_override_door.loc = get_turf(O)
			faction_override_door.set_dir(user.dir)
			faction_override_door.add_fingerprint(user)
			qdel(O)
			return
		if (customname != "")
			O.name = customname

		if (customdesc != "")
			O.desc = customdesc
		if (istype(O, /obj/structure/sign/signpost))
			O.desc = customdesc
			var/obj/structure/sign/signpost/STR = O
			STR.update_icon()
		if (istype(O, /obj/structure/rails/turn))
			var/obj/structure/rails/turn/RT = O
			RT.turn_dir = turn_dir
		O.set_dir(user.dir)
		if (istype(O, /obj/structure/vehicleparts/frame))
			O.dir = 1
		O.add_fingerprint(user)
		if (istype(O, /obj/item/clothing/accessory/armband/talisman))
			var/obj/item/clothing/accessory/armband/talisman/TM = O
			TM.name = "[H.religion] bone talisman"
			TM.desc = "A [H.religion] bone talisman."
			TM.religion = H.religion
		else if (istype(O, /obj/item/weapon/book/holybook))
			var/obj/item/weapon/book/holybook/HB = O
			HB.author = "[H]"
			HB.religion = H.religion
			HB.religion_type = map.custom_religions[H.religion][2]
			HB.title = customname
		else if (istype(O, /obj/structure/religious/totem))
			var/obj/structure/religious/totem/TT = O
			TT.religion = H.religion
		else if (istype(O, /obj/item/weapon/poster/religious))
			var/obj/item/weapon/poster/religious/P = O
			P.religion = H.religion
			P.symbol = map.custom_religions[H.religion][4]
			P.color1 = map.custom_religions[H.religion][5]
			P.color2 = map.custom_religions[H.religion][6]
		else if (istype(O, /obj/item/weapon/poster/faction))
			var/obj/item/weapon/poster/faction/P = O
			P.faction = H.civilization
			P.color1 = map.custom_civs[P.faction][7]
			P.color2 = map.custom_civs[P.faction][8]
			if (istype(O, /obj/item/weapon/poster/faction/lead))
				P.bstyle = "prop_lead"
			else if (istype(O, /obj/item/weapon/poster/faction/work))
				P.bstyle = "prop_work"
			else if (istype(O, /obj/item/weapon/poster/faction/mil1))
				P.bstyle = "prop_mil1"
			else if (istype(O, /obj/item/weapon/poster/faction/mil2))
				P.bstyle = "prop_mil2"
		else if (istype(O, /obj/structure/banner/religious))
			var/obj/structure/banner/religious/RB = O
			RB.religion = H.religion
			RB.symbol = map.custom_religions[H.religion][4]
			RB.color1 = map.custom_religions[H.religion][5]
			RB.color2 = map.custom_religions[H.religion][6]
		else if (istype(O, /obj/structure/banner/faction))
			var/obj/structure/banner/faction/FB = O
			FB.faction = H.civilization
			FB.symbol = map.custom_civs[H.civilization][6]
			FB.color1 = map.custom_civs[H.civilization][7]
			FB.color2 = map.custom_civs[H.civilization][8]
		else if (istype(O, /obj/structure/altar))
			var/obj/structure/altar/P = O
			P.religion = H.religion
			P.symbol = map.custom_religions[H.religion][4]
			P.color1 = map.custom_religions[H.religion][5]
			P.color2 = map.custom_religions[H.religion][6]
		else if (istype(O,/obj/covers/roads))
			var/obj/covers/roads/DR = O
			if (H.dir == NORTH || H.dir == SOUTH)
				DR.vertical = TRUE
				DR.dir = 1
				DR.icon_state = "[DR.roadtype]vr"
			else
				DR.vertical = FALSE
				DR.dir = 4
				DR.icon_state = "[DR.roadtype]hr"

		else if (istype(O, /obj/structure/fuelpump))
			var/obj/structure/fuelpump/FP = O
			FP.customcolor = customcolor
			FP.owner = customvar
			FP.name = customname
			FP.do_color()
		else if (istype(O, /obj/item/vehicleparts/frame))
			var/obj/item/vehicleparts/frame/FF = O
			FF.customcolor = customcolor
			FF.name = customname
			FF.do_color()
		else if (istype(O, /obj/item/weapon/storage/fancy/cigarettes))
			var/obj/item/weapon/storage/fancy/cigarettes/C = O
			C.customcolor = customcolor
			C.name = customname
			C.do_color()
		else if (istype(O, /obj/item/weapon/can))
			if (istype(O, /obj/item/weapon/can/small))
				var/obj/item/weapon/can/small/C = O
				C.customcolor1 = customcolor1
				C.customcolor2 = customcolor2
				C.brand = "[customname] "
				C.name = "empty [C.brand]can"
				C.do_color()
				var/obj/item/weapon/can/C1 = new/obj/item/weapon/can/small(get_turf(O))
				C1.customcolor1 = customcolor1
				C1.customcolor2 = customcolor2
				C1.brand = "[customname] "
				C1.name = "empty [C1.brand]can"
				C1.do_color()
				var/obj/item/weapon/can/small/C2 = new/obj/item/weapon/can/small(get_turf(O))
				C2.customcolor1 = customcolor1
				C2.customcolor2 = customcolor2
				C2.brand = "[customname] "
				C2.name = "empty [C2.brand]can"
				C2.do_color()
			else if (istype(O, /obj/item/weapon/can/large))
				var/obj/item/weapon/can/large/C = O
				C.customcolor1 = customcolor1
				C.customcolor2 = customcolor2
				C.brand = "[customname] "
				C.name = "empty [C.brand]can"
				C.do_color()
			else
				var/obj/item/weapon/can/C = O
				C.customcolor1 = customcolor1
				C.customcolor2 = customcolor2
				C.brand = "[customname] "
				C.name = "empty [C.brand]can"
				C.do_color()
				var/obj/item/weapon/can/C1 = new/obj/item/weapon/can(get_turf(O))
				C1.customcolor1 = customcolor1
				C1.customcolor2 = customcolor2
				C1.brand = "[customname] "
				C1.name = "empty [C1.brand]can"
				C1.do_color()

		else if (istype(O, /obj/item/weapon/paper/official))
			var/obj/item/weapon/paper/official/C = O
			C.faction = H.civilization
			C.color1 = map.custom_civs[H.civilization][7]
			C.color2 = map.custom_civs[H.civilization][8]
			C.update_icon()
		else if (istype(O, /obj/structure/religious/statue))
			var/obj/structure/religious/statue/RB = O
			RB.statue_material = recipe.use_material
			RB.name = customname
			RB.desc = customdesc
			var/list/possible_clothes = list("none", "toga")
			if (map && map.ordinal_age == 1)
				possible_clothes += "tunic"
			else if (map && map.ordinal_age == 2)
				possible_clothes += "tunic"
				possible_clothes += "medieval"
				possible_clothes += "king"
				possible_clothes += "templar"
				possible_clothes += "knight"
			else if (map && map.ordinal_age == 3)
				possible_clothes += "tunic"
				possible_clothes += "medieval"
				possible_clothes += "king"
				possible_clothes += "templar"
				possible_clothes += "knight"
				possible_clothes += "colonial"
			else if (map && map.ordinal_age == 4)
				possible_clothes += "tunic"
				possible_clothes += "medieval"
				possible_clothes += "king"
				possible_clothes += "templar"
				possible_clothes += "knight"
				possible_clothes += "colonial"
				possible_clothes += "modern civilian"
			else if (map && map.ordinal_age >= 5)
				possible_clothes += "tunic"
				possible_clothes += "medieval"
				possible_clothes += "king"
				possible_clothes += "templar"
				possible_clothes += "knight"
				possible_clothes += "colonial"
				possible_clothes += "modern civilian"
				possible_clothes += "modern military"
			var/inpc = WWinput(user, "What clothing to add?", "Statue", "none", possible_clothes)
			var/list/possible_objects = list("none", "spear")
			if (map && map.ordinal_age == 1)
				possible_objects += "spear and roman shield"
				possible_objects += "spear and oval shield"
			else if (map && map.ordinal_age == 2)
				possible_objects += "spear and roman shield"
				possible_objects += "spear and oval shield"
				possible_objects += "spear and semioval shield"
				possible_objects += "sword and roman shield"
				possible_objects += "sword and oval shield"
				possible_objects += "sword and semioval shield"
				possible_objects += "flag"
			else if (map && map.ordinal_age == 3)
				possible_objects += "spear and roman shield"
				possible_objects += "spear and oval shield"
				possible_objects += "spear and semioval shield"
				possible_objects += "sword and roman shield"
				possible_objects += "sword and oval shield"
				possible_objects += "sword and semioval shield"
				possible_objects += "flag"
				possible_objects += "rifle"
			else if (map && map.ordinal_age >= 4 && map.ordinal_age < 7)
				possible_objects += "spear and roman shield"
				possible_objects += "spear and oval shield"
				possible_objects += "spear and semioval shield"
				possible_objects += "sword and roman shield"
				possible_objects += "sword and oval shield"
				possible_objects += "sword and semioval shield"
				possible_objects += "flag"
				possible_objects += "rifle"
				possible_objects += "pistol"
			else if (map && map.ordinal_age >= 7)
				possible_objects += "spear and roman shield"
				possible_objects += "spear and oval shield"
				possible_objects += "spear and semioval shield"
				possible_objects += "sword and roman shield"
				possible_objects += "sword and oval shield"
				possible_objects += "sword and semioval shield"
				possible_objects += "flag"
				possible_objects += "rifle"
				possible_objects += "assault rifle"

			var/inpo = WWinput(user, "What object or objects to add?", "Statue", "none", possible_objects)
			if (inpc != "none")
				RB.statue_layers += "cl_[inpc]"
			if (inpo != "none")
				if (findtext(inpo, " and "))
					if (findtext(inpo, "spear"))
						RB.statue_layers += "obj_spear"
					else if (findtext(inpo, "sword"))
						RB.statue_layers += "obj_sword"

					if (findtext(inpo, "roman shield"))
						RB.statue_layers += "obj_shield1"
					else if (findtext(inpo, "oval shield"))
						RB.statue_layers += "obj_shield3"
					else if (findtext(inpo, "semioval shield"))
						RB.statue_layers += "obj_shield2"
				else
					RB.statue_layers += "obj_[inpo]"
			RB.update_icon()

		else if (istype(O, /obj/structure/supplier))
			build_override_supply = new /obj/structure/supplier
			build_override_supply.owner = customvar
			build_override_supply.name = customname
			build_override_supply.desc = "A [customvar2], property of [customvar]."
			build_override_supply.loc = get_turf(O)
			build_override_supply.add_fingerprint(user)
			qdel(O)
			return
		else if (istype(O, /obj/structure/vending/sales))
			if (customvar2 == "market stall")
				build_override_vending = new /obj/structure/vending/sales/market_stall
			else
				build_override_vending = new /obj/structure/vending/sales/vending
			build_override_vending.owner = customvar
			build_override_vending.name = customname
			build_override_vending.desc = "A [customvar2], property of [customvar]."
			build_override_vending.loc = get_turf(O)
			build_override_vending.add_fingerprint(user)
			qdel(O)
			return
		else if (istype(O, /obj/item/stack))
			var/obj/item/stack/S = O
			S.amount = produced
			S.update_icon()
		else if (recipe.result_type == /obj/item/weapon/clay/verysmallclaypot)
			new/obj/item/weapon/clay/verysmallclaypot(get_turf(O))
		else if (istype(O, /obj/item/ammo_casing/stone))
			new/obj/item/ammo_casing/stone(get_turf(O))
			new/obj/item/ammo_casing/stone(get_turf(O))
			new/obj/item/ammo_casing/stone(get_turf(O))
			new/obj/item/ammo_casing/stone(get_turf(O))
		else if (istype(O, /obj/item/ammo_casing/arrow))
			new/obj/item/ammo_casing/arrow(get_turf(O))
			new/obj/item/ammo_casing/arrow(get_turf(O))
			new/obj/item/ammo_casing/arrow(get_turf(O))
		else if (istype(O, /obj/item/ammo_casing/bolt))
			new/obj/item/ammo_casing/bolt(get_turf(O))
			new/obj/item/ammo_casing/bolt(get_turf(O))
			new/obj/item/ammo_casing/bolt(get_turf(O))
		else if (istype(O, /obj/item/clothing/accessory/storage/passport))
			var/obj/item/clothing/accessory/storage/passport/PP = O
			PP.owner = H
			PP.own()
		if (istype(O, /obj/item/weapon/storage)) //BubbleWrap - so newly formed boxes are empty
			for (var/obj/item/I in O)
				qdel(I)

/obj/item/stack/Topic(href, href_list)
	..()
	if ((usr.restrained() || usr.stat || usr.get_active_hand() != src))
		return

	if (href_list["sublist"] && !href_list["make"])
		list_recipes(usr, text2num(href_list["sublist"]))

	if (href_list["make"])

		if (amount < 0)
			qdel(src)
			return

		var/list/recipes_list = recipes
		if (href_list["sublist"])
			var/datum/stack_recipe_list/srl = recipes_list[text2num(href_list["sublist"])]
			recipes_list = srl.recipes

		var/datum/stack_recipe/R = recipes_list[text2num(href_list["make"])]
		var/multiplier = text2num(href_list["multiplier"])
		if (!multiplier || (multiplier <= 0)) //href exploit protection
			return

		if (ishuman(usr))
			var/mob/living/human/H = usr
			if (H.can_build_recipe)
				H.can_build_recipe = FALSE
				produce_recipe(R, multiplier, usr)
				H.can_build_recipe = TRUE

	if (src && usr.using_object == src) //do not reopen closed window
		spawn( FALSE )
			interact(usr)
			return
	return
