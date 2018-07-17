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
//	origin_tech = list(TECH_MATERIAL = TRUE)
	var/list/datum/stack_recipe/recipes
	var/singular_name
	var/amount = TRUE
	var/max_amount //also see stack recipes initialisation, param "max_res_amount" must be equal to this max_amount
	var/stacktype //determines whether different stack types can merge
	var/build_type = null //used when directly applied to a turf
	var/uses_charge = FALSE
	var/list/charge_costs = null
	var/list/datum/matter_synth/synths = null

/obj/item/stack/New(var/loc, var/_amount=0)
	..()
	if (!stacktype)
		stacktype = type
	if (_amount)
		amount = _amount
	return

/obj/item/stack/Destroy()
	if (uses_charge)
		return TRUE
	if (src && usr && usr.using_object == src)
		usr << browse(null, "window=stack")
	return ..()

/obj/item/stack/examine(mob/user)
	if (..(user, TRUE))
		if (!uses_charge)
			user << "There [amount == TRUE ? "is" : "are"] [amount] [singular_name]\s in the stack."
		else
			user << "There is enough charge for [get_amount()]."

/obj/item/stack/attack_self(mob/user as mob)
	list_recipes(user)

/obj/item/stack/proc/list_recipes(mob/user as mob, recipes_sublist)
	if (!recipes)
		return
	if (!src || get_amount() <= 0)
		user << browse(null, "window=stack")
	user.set_using_object(src) //for correct work of onclose
	var/list/recipe_list = recipes
	if (recipes_sublist && recipe_list[recipes_sublist] && istype(recipe_list[recipes_sublist], /datum/stack_recipe_list))
		var/datum/stack_recipe_list/srl = recipe_list[recipes_sublist]
		recipe_list = srl.recipes
	var/t1 = text("<HTML><HEAD><title>Constructions from []</title></HEAD><body><TT>Amount Left: []<br>", src, get_amount())
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
			var/max_multiplier = round(get_amount() / R.req_amount)
			var/title as text
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
				t1 += text("[]", title)
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

/mob/var/can_build_recipe = TRUE
/obj/item/stack/proc/produce_recipe(datum/stack_recipe/recipe, var/quantity, mob/user)
	var/required = quantity*recipe.req_amount
	var/produced = min(quantity*recipe.res_amount, recipe.max_res_amount)
	var/atom/movable/build_override_object = null

	if (findtext(recipe.title, "locked") && findtext(recipe.title, "door") && !findtext(recipe.title, "unlocked"))

		var/material = null
		if (findtext(recipe.title, "wood"))
			material = "wood"

		if (!ishuman(user))
			return

		var/mob/living/carbon/human/H = user
		if (!istype(H.l_hand, /obj/item/weapon/key) && !istype(H.r_hand, /obj/item/weapon/key))
			user << "<span class = 'warning'>You need to have a key in one of your hands to make a locked door.</span>"
			return

		var/obj/item/weapon/key = H.l_hand
		if (!key || !istype(key))
			key = H.r_hand
		if (!key || !istype(key))
			return // should never happen

		var/texttype = "[key.type]"
		var/uniquepart = replacetext(texttype, "/obj/item/weapon/key/", "")
		var/doorbasepath = "/obj/structure/simple_door/key_door/"
		var/doorpath = text2path("[doorbasepath][uniquepart]")
		build_override_object = new doorpath(null, material)

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

	var/mob/living/carbon/human/H = null
	if (ishuman(user))
		H = user

	if (ispath(recipe.result_type, /obj/structure))
		if (!ispath(recipe.result_type, /obj/structure/noose))
			for (var/obj/structure/multiz/M in get_turf(H))
				H << "<span class = 'danger'>You can't build a structure here.</span>"
				return

	if (recipe.result_type == /obj/structure/noose)
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

	else if (recipe.result_type == /obj/structure/barbwire)
		if (locate(/obj/structure/barbwire) in get_turf(H))
			return
		if (H)
			if (H.original_job)
				var/area/H_area = get_area(H)
				if (H_area.location == AREA_INSIDE)
					if (H.original_job.base_type_flag() == GERMAN)
						if (istype(H_area, /area/prishtina/german))
							user << "<span class = 'warning'>This isn't a great place for barbwire.</span>"
							return
					else if (H.original_job.base_type_flag() == SOVIET)
						if (istype(H_area, /area/prishtina/soviet))
							user << "<span class = 'warning'>This isn't a great place for barbwire.</span>"
							return

	else if (engineer_exclusive_recipe_types.Find(recipe.result_type))
		if (H)
			if (H.getStatCoeff("engineering") < GET_MIN_STAT_COEFF(STAT_VERY_HIGH))
				H << "<span class = 'notice'>You have no idea of how to build this.</span>"
				return

	if (recipe.time)
		var/buildtime = recipe.time
		if (H)
			buildtime /= H.getStatCoeff("strength")
			buildtime /= (H.getStatCoeff("engineering") * H.getStatCoeff("engineering"))

		buildtime = round(buildtime)

		user << "<span class='notice'>Building [recipe.title] ...</span>"
		if (!do_after(user, buildtime))
			return

		if (H)
			H.adaptStat("engineering", 1*recipe.req_amount)

	if (use(required))
		var/atom/O
		if (recipe.use_material)
			O = new recipe.result_type(user.loc, recipe.use_material)
		else
			O = new recipe.result_type(user.loc)

		if (build_override_object)
			build_override_object.loc = get_turf(O)
			build_override_object.set_dir(user.dir)
			build_override_object.add_fingerprint(user)
			qdel(O)
			return

		O.set_dir(user.dir)
		O.add_fingerprint(user)

		if (istype(O, /obj/item/stack))
			var/obj/item/stack/S = O
			S.amount = produced
			S.add_to_stacks(user)

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

		if (get_amount() < 1)
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
			var/mob/living/carbon/human/H = usr
			if (H.can_build_recipe)
				H.can_build_recipe = FALSE
				produce_recipe(R, multiplier, usr)
				H.can_build_recipe = TRUE

	if (src && usr.using_object == src) //do not reopen closed window
		spawn( FALSE )
			interact(usr)
			return
	return

//Return TRUE if an immediate subsequent call to use() would succeed.
//Ensures that code dealing with stacks uses the same logic
/obj/item/stack/proc/can_use(var/used)
	if (get_amount() < used)
		return FALSE
	return TRUE

/obj/item/stack/proc/use(var/used)
	if (!can_use(used))
		return FALSE
	if (!uses_charge)
		amount -= used
		if (amount <= 0)
			if (usr)
				usr.remove_from_mob(src)
			qdel(src) //should be safe to qdel immediately since if someone is still using this stack it will persist for a little while longer
		return TRUE
	else
		if (get_amount() < used)
			return FALSE
		for (var/i = TRUE to charge_costs.len)
			var/datum/matter_synth/S = synths[i]
			S.use_charge(charge_costs[i] * used) // Doesn't need to be deleted
		return TRUE
	return FALSE

/obj/item/stack/proc/add(var/extra)
	if (!uses_charge)
		if (amount + extra > get_max_amount())
			return FALSE
		else
			amount += extra
		return TRUE
	else if (!synths || synths.len < uses_charge)
		return FALSE
	else
		for (var/i = TRUE to uses_charge)
			var/datum/matter_synth/S = synths[i]
			S.add_charge(charge_costs[i] * extra)

/*
	The transfer and split procs work differently than use() and add().
	Whereas those procs take no action if the desired amount cannot be added or removed these procs will try to transfer whatever they can.
	They also remove an equal amount from the source stack.
*/

//attempts to transfer amount to S, and returns the amount actually transferred
/obj/item/stack/proc/transfer_to(obj/item/stack/S, var/tamount=null, var/type_verified)
	if (!get_amount())
		return FALSE
	if ((stacktype != S.stacktype) && !type_verified)
		return FALSE
	if (isnull(tamount))
		tamount = get_amount()

	var/transfer = max(min(tamount, get_amount(), (S.get_max_amount() - S.get_amount())), FALSE)

	var/orig_amount = get_amount()
	if (transfer && use(transfer))
		S.add(transfer)
		if (prob(transfer/orig_amount * 100))
			transfer_fingerprints_to(S)
			if (blood_DNA)
				S.blood_DNA |= blood_DNA
		return transfer
	return FALSE

//creates a new stack with the specified amount
/obj/item/stack/proc/split(var/tamount)
	if (!amount)
		return null
	if (uses_charge)
		return null

	var/transfer = max(min(tamount, amount, initial(max_amount)), FALSE)

	var/orig_amount = amount
	if (transfer && use(transfer))
		var/obj/item/stack/newstack = new type(loc, transfer)
		newstack.color = color
		if (prob(transfer/orig_amount * 100))
			transfer_fingerprints_to(newstack)
			if (blood_DNA)
				newstack.blood_DNA |= blood_DNA
		return newstack
	return null

/obj/item/stack/proc/get_amount()
	if (uses_charge)
		if (!synths || synths.len < uses_charge)
			return FALSE
		var/datum/matter_synth/S = synths[1]
		. = round(S.get_charge() / charge_costs[1])
		if (charge_costs.len > 1)
			for (var/i = 2 to charge_costs.len)
				S = synths[i]
				. = min(., round(S.get_charge() / charge_costs[i]))
		return
	return amount

/obj/item/stack/proc/get_max_amount()
	if (uses_charge)
		if (!synths || synths.len < uses_charge)
			return FALSE
		var/datum/matter_synth/S = synths[1]
		. = round(S.max_energy / charge_costs[1])
		if (uses_charge > 1)
			for (var/i = 2 to uses_charge)
				S = synths[i]
				. = min(., round(S.max_energy / charge_costs[i]))
		return
	return max_amount

/obj/item/stack/proc/add_to_stacks(mob/user as mob)
	for (var/obj/item/stack/item in user.loc)
		if (item==src)
			continue
		var/transfer = transfer_to(item)
		if (transfer)
			user << "<span class='notice'>You add a new [item.singular_name] to the stack. It now contains [item.amount] [item.singular_name]\s.</span>"
		if (!amount)
			break

/obj/item/stack/attack_hand(mob/user as mob)
	if (user.get_inactive_hand() == src)
		var/obj/item/stack/F = split(1)
		if (F)
			user.put_in_hands(F)
			add_fingerprint(user)
			F.add_fingerprint(user)
			spawn(0)
				if (src && usr.using_object == src)
					interact(usr)
	else
		..()
	return

/obj/item/stack/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack))
		var/obj/item/stack/S = W
		if (user.get_inactive_hand()==src)
			transfer_to(S, TRUE)
		else
			transfer_to(S)

		spawn(0) //give the stacks a chance to delete themselves if necessary
			if (S && usr.using_object == S)
				S.interact(usr)
			if (src && usr.using_object == src)
				interact(usr)
	else
		return ..()