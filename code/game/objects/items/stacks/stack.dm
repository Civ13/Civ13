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
	value = 1
	var/can_stack = FALSE //Determines if stacks should be auto-merged.
	var/customcolor = "#FFFFFF"
	var/customcolor1 = "#000000"
	var/customcolor2 = "#FFFFFF"
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
/obj/item/stack/Crossed(var/atom/movable/AM)
	if(istype(AM, /obj/item/stack))
		var/obj/item/stack/S = AM
		//Checking if stack types match and if it isn't thrown to avoid scooping up stacks in flight.
		if(amount > 0 && S.amount > 0 && istype(S, stacktype) && !S.throwing)
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
	src.update_strings()
	S.update_strings()
	if(src.amount <= 0)
		qdel(src)
	return transfer

//Return TRUE if an immediate subsequent call to use() would succeed.
//Ensures that code dealing with stacks uses the same logic
/obj/item/stack/proc/can_use(var/used)
	if (amount < used)
		return FALSE
	return TRUE

/obj/item/stack/proc/zero_amount()//Teeth shit
	if (amount < 1)
		qdel(src)
		return TRUE
	return FALSE

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
		S.update_strings()
		src.update_icon()
		src.update_strings()
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
		if (zero_amount() || amount <= 1) // Prevents Alt-clicking if the amount is 0 or 1
			return
		var/max = amount
		var/stackmaterial = round(player_input(user, "How many to take out of the stack? (Maximum  [max])", null, null, "num", null, TRUE))
		max = amount
		stackmaterial = min(max, stackmaterial)
		if(stackmaterial == null || stackmaterial <= 0)
			return
		else if (!user.item_is_in_hands(src) && !user.Adjacent(src))
			to_chat(user, SPAN_WARNING("The stack isn't in your hands or next to you!"))
			return
		else
			change_stack(user, stackmaterial)
			update_strings(stackmaterial)
			to_chat(user, SPAN_NOTICE("You take [stackmaterial] out of the stack."))

/obj/item/stack/proc/update_strings()
    return

/obj/item/stack/proc/change_stack(mob/user, amount)
	var/obj/item/stack/F = split(amount)
	if (F)
		user.put_in_hands(F)
		F.update_icon()
		F.update_strings()
		src.update_icon()
		src.update_strings()
		add_fingerprint(user)
		F.add_fingerprint(user)
		spawn(0)
			if (src && usr.using_object == src)
				interact(usr)
	return

/obj/item/stack/examine(mob/user)
	if (..(user, TRUE))
		to_chat(user, "There [amount == TRUE ? "is" : "are"] [amount] [singular_name]\s in the stack.")

/obj/item/stack/attack_self(mob/user as mob)
	list_recipes(user)

/obj/item/stack/allows_smooth_movement_ui(mob/living/human/user)
	// Browsing held recipes is passive. Topic still owns crafting admission,
	// do_after interruption and once-only material/handle consumption.
	return user && !QDELETED(user) && !QDELETED(src) && recipes && amount > 0 && loc == user && user.get_active_hand() == src && user.using_object == src

/obj/item/stack/proc/list_recipes(mob/user as mob, recipes_sublist)
	if (!recipes)
		return
	if (!src || amount <= 0)
		user << browse(null, "window=stack")
		return
	// The Crafting window (crafting_window.dm) takes over where the client can run it.
	if (crafting_window_shown(user))
		return
	user.set_using_object(src) //for correct work of onclose
	// Flatten only the display, never the source recipe lists. Every action keeps
	// its original category and index for Topic and produce_recipe validation.
	var/list/rows = list()
	var/categories = "<option value=''>All categories</option>"
	for (var/i=1;i<=recipes.len;i++)
		var/E = recipes[i]
		if (istype(E, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/srl = E
			var/selected = (recipes_sublist == i) ? " selected" : ""
			categories += "<option value='[i]'[selected]>[html_encode(srl.title)]</option>"
			for (var/j=1;j<=srl.recipes.len;j++)
				if (istype(srl.recipes[j], /datum/stack_recipe))
					rows += list(list("recipe" = srl.recipes[j], "sublist" = i, "index" = j, "category" = srl.title))
		else if (istype(E, /datum/stack_recipe))
			rows += list(list("recipe" = E, "sublist" = "", "index" = i, "category" = "General"))

	var/t1 = "<!DOCTYPE html><html><head><meta http-equiv='X-UA-Compatible' content='IE=edge'>[common_browser_style]<title>Crafting</title><style>body{background:#392611;color:#eee;font:14px Arial;margin:12px}a{color:#f5d99b}.craft-toolbar{background:#2a2118;padding:10px;margin-bottom:8px}input{width:65%}input,select,button{font:inherit;margin:3px;padding:4px}.craft-row{padding:8px 4px;border-bottom:1px solid #725635}.craft-meta{font-size:12px;color:#ccc;margin-top:4px}.craft-status{color:#ddd}.craft-details{margin:6px 0;padding:6px;background:#2a2118}.craft-batch{display:inline-block}h2{margin:0 0 6px}#craft-empty{padding:12px}#craft-makeable{width:auto}</style></head><body data-stack='\ref[src]'>"
	t1 += "<h2>[html_encode("[src]")]</h2><p>Amount Left: [amount]. <a href='?src=\ref[crafting_atlas_reference];atlas_open=1'>Crafting Atlas</a></p>"
	t1 += "<div class='craft-toolbar'><label for='craft-search'>Find a recipe across categories</label><br><input id='craft-search' type='text' maxlength='64' placeholder='Search recipes...'><button id='craft-clear' type='button'>Clear</button><br><label for='craft-category'>Browse: </label><select id='craft-category'>[categories]</select><span id='craft-count'></span><br><label><input id='craft-makeable' type='checkbox' data-pref='byond://?src=\ref[held_crafting_filter];makeable_only='[user.craft_makeable_only() ? " checked" : ""]> Only what I can make</label></div>"
	t1 += "<noscript>Search and batch controls require JavaScript. Single-item crafting links and recipe details are listed below.</noscript>"
	var/row_number = 0
	for (var/list/row in rows)
		row_number++
		var/datum/stack_recipe/R = row["recipe"]
		var/sublist = row["sublist"]
		var/index = row["index"]
		var/category = row["category"]
		var/max_multiplier = round(amount / R.req_amount)
		var/title = R.res_amount > 1 ? "[R.res_amount]x [R.title]\s" : R.title
		var/cost = "[R.req_amount] [singular_name]\s"
		var/details = ""
		var/list/joint_spec = furniture_joinery_spec(R)
		if (stone_mold_type(R.result_type))
			details += "Chisel and hammer/mallet equipped or at your feet. "
		if (joint_spec)
			if (joint_spec["component_cost"])
				cost += " + [joint_spec["component_cost"]] wooden dowel set(s)"
				details += "Chisel and hammer/mallet equipped or at your feet. "
			else
				details += "Sharpened flint or a sharp knife harder than the plank equipped or at your feet. "
		var/manual_hint = crafting_recipe_manual_hint(user, "[R.result_type]")
		var/makeable = recipe_makeable_now(user, R)
		var/search_text = html_encode("[R.title] [category]")
		t1 += "<div class='craft-row' data-search='[search_text]' data-category='[sublist]' data-makeable='[makeable ? 1 : 0]'>"
		var/action = "byond://?src=\ref[src];sublist=[sublist];make=[index]"
		if (manual_hint)
			t1 += "<strong>[html_encode(title)]</strong><div class='craft-status'>[html_encode(manual_hint)]</div>"
		else if (max_multiplier < 1)
			t1 += "<strong>[html_encode(title)]</strong><div class='craft-status'>Not enough material</div>"
		else
			t1 += "<a href='[action];multiplier=1'>[html_encode(title)]</a>"
			if (R.max_res_amount>1 && max_multiplier>1)
				max_multiplier = min(max_multiplier, round(R.max_res_amount/R.res_amount))
				t1 += " <span class='craft-batch'><label for='craft-quantity-[row_number]'>Quantity: </label><select id='craft-quantity-[row_number]'><option value='[action];multiplier=1'>[R.res_amount]</option>"
				var/list/multipliers = list(5,10,25)
				for (var/n in multipliers)
					if (max_multiplier>=n)
						t1 += "<option value='[action];multiplier=[n]'>[n*R.res_amount]</option>"
				if (max_multiplier>1 && !(max_multiplier in multipliers))
					t1 += "<option value='[action];multiplier=[max_multiplier]'>[max_multiplier*R.res_amount] (max)</option>"
				t1 += "</select><button type='button' data-craft-quantity='craft-quantity-[row_number]'>Craft</button></span>"
			if (!makeable)
				t1 += "<div class='craft-status'>Missing a tool, skill or second material</div>"
		t1 += "<div class='craft-meta'>[html_encode(category)] | Cost: [html_encode(cost)]</div>"
		if (details)
			// Visible without scripts; the client collapses it only after binding.
			t1 += "<button type='button' data-craft-details='craft-details-[row_number]' aria-expanded='true'>Tool details</button><div class='craft-details' id='craft-details-[row_number]'>[html_encode(details)]</div>"
		t1 += "</div>"
	t1 += "<p id='craft-empty' style='display:none'>No matching recipes. Try another name, clear the search or untick Only what I can make.</p><script src='stack_crafting.js'></script></body></html>"
	user << browse_rsc('code/js/stack_crafting.js', "stack_crafting.js")
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

// Secondary craft inputs (rope, bronze, circuits...) are taken before the build checks.
// Record each take so a refused or cancelled build can give them back.
/mob/var/list/craft_secondary_takes = null
/obj/item/stack/proc/secondary_take(obj/item/stack/S, amt, mob/user)
	S.amount -= amt
	if (!user)
		return
	if (!user.craft_secondary_takes)
		user.craft_secondary_takes = list()
	user.craft_secondary_takes += list(list(S, S.type, amt))
	S.update_icon()

/obj/item/stack/proc/secondary_forget(mob/user)
	if (!user)
		return
	user.craft_secondary_takes = null
	if (user.key in handReturnMap)
		handReturnMap.Remove(user.key)

/obj/item/stack/proc/secondary_refund(mob/user)
	if (!user)
		return
	for (var/list/T in user.craft_secondary_takes)
		var/obj/item/stack/S = T[1]
		if (S && !QDELETED(S))
			S.amount += T[3]
			S.update_icon()
		else
			var/stack_type = T[2]
			var/obj/item/stack/N = new stack_type(get_turf(user))
			N.amount = T[3]
			N.update_icon()
			user.put_in_hands(N)
	// Non-stack inputs (spears, heads) consumed whole: recreate them as before.
	if (user.key in handReturnMap)
		for (var/datum/A in handReturnMap[user.key])
			if (istype(A, /obj/item/stack))
				continue
			var/atom/O = new A.type()
			user.put_in_hands(O)
	secondary_forget(user)

/mob/var/can_build_recipe = TRUE
// options: answers to the recipe's craft_product prompts (craft_products.dm); missing ones are asked.
/obj/item/stack/proc/produce_recipe(datum/stack_recipe/recipe, var/quantity, mob/user, list/options = null)
	var/required = quantity*recipe.req_amount
	var/produced = min(quantity*recipe.res_amount, recipe.max_res_amount)
	var/atom/movable/build_override_object = null
	var/customname = ""
	var/customvar = ""
	var/customvar2 = ""
	var/customdesc = ""
	var/mob/living/human/H = user
	secondary_forget(H)
	if (!crafting_recipe_allowed(H, "[recipe.result_type]"))
		to_chat(user, crafting_recipe_refusal(H, "[recipe.result_type]"))
		return
	var/datum/cloth_recipe_payment/cloth_payment
	if (is_cloth_sheet(src))
		cloth_payment = new(src, H, recipe, quantity)
		if (!cloth_payment.valid()) return
	var/datum/furniture_joinery_action/joinery
	var/datum/stone_mold_carving/carving
	if (stone_mold_type(recipe.result_type))
		carving = new(src, H, recipe)
		if (quantity != 1 || !carving.valid())
			to_chat(user, SPAN_WARNING("Carving molds needs sandstone, completed research, a chisel and a hammer or mallet equipped or at your feet."))
			return
	var/datum/tablet_press_construction/press_construction
	if (recipe.result_type == /obj/structure/chem_master/tablet_press/constructed)
		press_construction = new(src, H, recipe, quantity)
		if (!press_construction.valid())
			return
	if (findtext(recipe.title, "joinery: ") == 1)
		joinery = new(src, H, recipe)
		if (quantity != 1 || !joinery.valid())
			to_chat(user, SPAN_WARNING("Joinery needs its materials, research and equipped tools. Check the Crafting Atlas."))
			return
	var/needs_crafting_handle = FALSE
	// The used handle's wood, quality and condition carry into the tool.
	var/handle_material_name = null
	var/handle_quality = 1
	var/handle_condition = 1
	var/obj/item/weapon/material/handle/crafting_handle = null
	var/atom/handle_crafting_source_loc = null
	var/guard_refusal = craft_guard_refusal(H, recipe, CRAFT_GUARD_START)
	if (!isnull(guard_refusal))
		if (guard_refusal)
			to_chat(user, guard_refusal)
		return
	// Tools and second materials declared in config/craft_needs.json.
	var/needs_refusal = craft_needs_refusal(H, recipe, quantity, src)
	if (needs_refusal)
		to_chat(user, needs_refusal)
		return
	var/obj/structure/religious/totem/newtotem = null
	var/obj/structure/simple_door/key_door/custom/build_override_door = null
	var/obj/structure/simple_door/key_door/faction_door/faction_override_door = null
	var/obj/item/weapon/key/civ/build_override_key = null
	var/obj/item/weapon/gun/projectile/ancient/firelance/build_override_firelance = null
	var/obj/structure/vending/sales/build_override_vending = null
	var/obj/structure/supplier/build_override_supply = null
	if (findtext(recipe.title, "custom") && findtext(recipe.title, "sign"))
		var/list/chosen = craft_product_options(user, recipe, options)
		if (!chosen)
			return
		customname = chosen["name"]
		customdesc = chosen["desc"]
	else if (findtext(recipe.title, "castle gate control"))
		for(var/obj/structure/gatecontrol/GC in range(6, user.loc))
			to_chat(user, "<span class = 'danger'>You cannot build a control so close to another one!</span>")
			return
	else if (findtext(recipe.title, "blast door control"))
		for(var/obj/structure/gatecontrol/blastcontrol/GC in range(10, user.loc))
			to_chat(user, "<span class = 'danger'>You cannot build a control so close to another one!</span>")
			return
	else if (findtext(recipe.title, "signpost"))
		var/list/chosen = craft_product_options(user, recipe, options)
		if (!chosen)
			return
		customdesc = chosen["desc"]

	else if (findtext(recipe.title, "carriage"))
		if (recipe_skill_short(H, recipe))
			return

	else if (findtext(recipe.title, "faction") && findtext(recipe.title, "door"))
		if (recipe_skill_short(H, recipe))
			return

		if (!ishuman(user))
			return
		if(H.civilization == "none")
			to_chat(H, "You must be part of a faction to craft this door")
			return
		else
			faction_override_door = new /obj/structure/simple_door/key_door/faction_door
			faction_override_door.faction = H.civilization
			faction_override_door.name = "[H.civilization]'s Door"

	else if (istype(recipe.result_type,/obj/structure/barricade/ship))
		if (user.z == 1)
			if (recipe.result_type == /obj/structure/barricade/ship/wood/a7 || recipe.result_type == /obj/structure/barricade/ship/blue/b9 || recipe.result_type == /obj/structure/barricade/ship/wood/a6 || recipe.result_type == /obj/structure/barricade/ship/wood/a2 || recipe.result_type == /obj/structure/window/barrier/ship/wood/port0/north || recipe.result_type == /obj/structure/window/barrier/ship/blue/bport0/south || recipe.result_type == /obj/structure/window/barrier/ship/wood/port2/north || recipe.result_type == /obj/structure/window/barrier/ship/blue/bport3/south)
				to_chat(user, "You cannot build this on the lower deck.")
				return
		else
			if (recipe.result_type == /obj/structure/barricade/ship/aport0/north || recipe.result_type == /obj/structure/barricade/ship/aport0 || recipe.result_type == /obj/structure/barricade/ship/wall2)
				to_chat(user, "You cannot build this on the upper deck.")
				return
	else if (findtext(recipe.title, "locked") && findtext(recipe.title, "door") && !findtext(recipe.title, "unlocked"))
		if (recipe_skill_short(H, recipe))
			return

		if (!ishuman(user))
			return

		if (H.faction_text == INDIANS)
			to_chat(H, "<span class = 'danger'>You don't know how to make this.</span>")
			return

		if (!istype(H.l_hand, /obj/item/weapon/key) && !istype(H.r_hand, /obj/item/weapon/key))
			to_chat(user, "<span class = 'warning'>You need to have a key in one of your hands to make a locked door.</span>")
			return

		var/obj/item/weapon/key/key = H.l_hand
		if (!key || !istype(key))
			key = H.r_hand
		if (!key || !istype(key))
			return // should never happen

		if (key)
			var/list/chosen = craft_product_options(user, recipe, options)
			if (!chosen)
				return
			var/keyname = chosen["name"]
			if (findtext(recipe.title, "iron door"))
				build_override_door = new /obj/structure/simple_door/key_door/custom
			if (findtext(recipe.title, "jail door"))
				build_override_door = new /obj/structure/simple_door/key_door/custom/jail/steeljail
			if (findtext(recipe.title, "wood jail"))
				build_override_door = new /obj/structure/simple_door/key_door/custom/jail/woodjail
			build_override_door.name = keyname
			build_override_door.custom_code = key.code

	else if (findtext(recipe.title, "tin can"))
		var/list/chosen = craft_product_options(user, recipe, options)
		if (!chosen)
			return
		customname = chosen["name"]
		customcolor1 = chosen["color1"]
		customcolor2 = chosen["color2"]

	else if (findtext(recipe.title, "cigarette pack"))
		var/list/chosen = craft_product_options(user, recipe, options)
		if (!chosen)
			return
		customname = chosen["name"]
		customcolor = chosen["color"]

	else if (recipe.result_type == /obj/structure/religious/statue)
		var/list/chosen = craft_product_options(user, recipe, options)
		if (!chosen)
			return
		customname = chosen["name"]
		customdesc = chosen["desc"]

	else if (recipe.result_type == /obj/structure/research_bench)
		// Anyone may build one; only a bench a faction will own counts
		// toward that faction's cap (bench_owner_faction()).
		var/bench_faction = map ? map.bench_owner_faction(H) : null
		if (bench_faction && map.count_faction_benches(bench_faction) >= map.get_bench_cap(bench_faction))
			to_chat(user, "Your faction already has as many research benches as it can support ([map.get_bench_cap(bench_faction)]). Build a resource forge to raise the cap.")
			return

	else if (recipe.result_type == /obj/structure/researchdesk)
		if (map && !map.resourceresearch)
			to_chat(user, "\The [recipe.title] can only be built during <b>Research</b> gamemodes.")
			return

	else if (recipe.result_type == /obj/structure/researchdesk/chad)
		if (!map.chad_mode_plus)
			to_chat(user, "\The [recipe.title] can only be built during <b>Chad Mode +</b>.")
			return

	else if (recipe.result_type == /obj/structure/oil_deposits)
		if (map && map.gamemode != "Oil Rush")
			to_chat(user, "\The [recipe.title] can only be built during the <b>Oil Rush</b> gamemode.")
			return
	else if (recipe.result_type == /obj/item/weapon/researchkit)
		if (map && !map.research_active)
			to_chat(user, "\The [recipe.title] can only be built during the <b>Classic Research</b> gamemode.")
			return

	else if (recipe.result_type == /obj/item/weapon/book/language_book)
		if (recipe_skill_short(H, recipe))
			return

	else if (findtext(recipe.title, "motorcycle frame") || findtext(recipe.title, "boat frame"))
		if (recipe_skill_short(H, recipe))
			return
		var/list/chosen = craft_product_options(user, recipe, options)
		if (!chosen)
			return
		customname = chosen["name"]
		customcolor = chosen["color"]

	else if (findtext(recipe.title, "locomotive"))
		if (recipe_skill_short(H, recipe))
			return

	else if (findtext(recipe.title, "fuel pump"))
		if (recipe_skill_short(H, recipe))
			return

		var/list/chosen = craft_product_options(user, recipe, options)
		if (!chosen)
			return
		customvar = chosen["company"]
		customname = chosen["name"]
		customcolor = chosen["color"]

	else if (findtext(recipe.title, "oil deposit"))
		if (H.civilization == null || H.civilization == "none")
			to_chat(user, "You need to be part of a faction to build this!")
			return
		for(var/obj/structure/oil_deposits/OD in range(4, user.loc))
			to_chat(user, "You are too close to an existing deposit!")
			return

	else if (findtext(recipe.title, "passport"))
		if (H.civilization == null || H.civilization == "none")
			to_chat(user, "You need to be part of a faction to craft a passport!")
			return

	else if (findtext(recipe.title, "holy book"))
		if (H.getStatCoeff("philosophy") < 2.4 || H.religion == "none" || (H.religious_leader == FALSE && H.religious_leader != "Clerics"))
			to_chat(H, "<span class = 'danger'>You can't make a holy book.</span>")
			return
		var/list/chosen = craft_product_options(user, recipe, options)
		if (!chosen)
			return
		customname = chosen["name"]

	else if (findtext(recipe.title, "farmer's almanac"))
		if (H.getStatCoeff("farming") < GET_MIN_STAT_COEFF(STAT_HIGH))
			to_chat(H, "<span class = 'danger'>You need more farming experience to write an almanac.</span>")
			return

	else if (findtext(recipe.title, "altar"))
		if (H.religious_leader == FALSE)
			if (H.religious_clergy == 0)
				to_chat(H, "<span class = 'danger'>You can't make an altar as you are not part of the clergy.</span>")
				return

	else if (findtext(recipe.title, "nun hood") || findtext(recipe.title, "nun dress"))
		if (H.religious_leader == FALSE)
			if (H.religious_clergy == 0)
				to_chat(H, "<span class = 'danger'>You can't make nun clothes as you are not part of the clergy.</span>")
				return

	else if (findtext(recipe.title, "black priest outfit"))
		if (H.religious_leader == FALSE)
			if (H.religious_clergy == 0)
				to_chat(H, "<span class = 'danger'>You can't make priest clothes as you are not part of the clergy.</span>")
				return

	else if (findtext(recipe.title, "sterile mask"))
		if (H.getStatCoeff("medical") < 0.5)
			to_chat(H, "<span class = 'danger'>This is too complex for your current medical skill level.</span>")
			return
	else if (findtext(recipe.title, "plague doctor mask") || findtext(recipe.title, "plague doctor suit") | findtext(recipe.title, "plague doctor hat"))
		if (H.getStatCoeff("medical") < 1.0)
			to_chat(H, "<span class = 'danger'>This is too complex for your current medical skill level.</span>")
			return
	else if (findtext(recipe.title, "nightingale dress") || findtext(recipe.title, "nurse hat"))
		if (H.getStatCoeff("medical") < 1.0)
			to_chat(H, "<span class = 'danger'>This is too complex for your current medical skill level.</span>")
			secondary_refund(H)
			return

	else if (findtext(recipe.title, "religious poster") || findtext(recipe.title, "altar") || findtext(recipe.title, "religious banner"))
		if (H.religion == "none")
			to_chat(H, "<span class = 'danger'>You can't make a [recipe.title] since you have no religion!</span>")
			secondary_refund(H)
			return
	else if (findtext(recipe.title, "propaganda poster") || findtext(recipe.title, "faction banner") || findtext(recipe.title, "official faction paper"))
		if (H.civilization == "none")
			to_chat(H, "<span class = 'danger'>You can't make a [recipe.title] since you have no faction!</span>")
			secondary_refund(H)
			return
	else if ((findtext(recipe.title, "wall") && !findtext(recipe.title, "wallet")) || craft_recipe_builds_well(recipe))
		if (recipe_skill_short(H, recipe))
			secondary_refund(H)
			return
	else if (findtext(recipe.title, "locked large stone double doors") || findtext(recipe.title, "locked large sandstone double doors") || findtext(recipe.title, "locked large lead double doors") || findtext(recipe.title, "locked large copper double doors") || findtext(recipe.title, "locked large bronze double doors") || findtext(recipe.title, "locked large silver double doors") || findtext(recipe.title, "locked large gold double doors") || findtext(recipe.title, "locked large bone double doors"))
		if (recipe_skill_short(H, recipe))
			secondary_refund(H)
			return
	else if (findtext(recipe.title, "locked wooden privacy door"))
		if (recipe_skill_short(H, recipe))
			secondary_refund(H)
			return
	else if (findtext(recipe.title, "unlocked iron door") || findtext(recipe.title, "unlocked large iron double doors"))
		if (recipe_skill_short(H, recipe))
			secondary_refund(H)
			return
	else if (findtext(recipe.title, "arquebus") || findtext(recipe.title, "matchlock musket"))
		if (recipe_skill_short(H, recipe))
			secondary_refund(H)
			return
	else if (findtext(recipe.title, "monumental stone pillar") || findtext(recipe.title, "monumental ominous statue of the deep-one") || findtext(recipe.title, "monumental ominous statue of the evil-one") || findtext(recipe.title, "monumental ominous statue of the outsider") || findtext(recipe.title, "monumental stone buddha") || findtext(recipe.title, "monumental saint statue"))
		if (recipe_skill_short(H, recipe))
			secondary_refund(H)
			return
	else if (findtext(recipe.title, "locked reinforced large steel double doors"))
		if (recipe_skill_short(H, recipe))
			secondary_refund(H)
			return
	else if (findtext(recipe.title, "fire lance"))
		if (recipe_skill_short(H, recipe))
			secondary_refund(H)
			return
	else if (findtext(recipe.title, "moai") || findtext(recipe.title, "long moai") || findtext(recipe.title, "monumental sandstone obelisk") || findtext(recipe.title, "monumental stone megalith"))
		if (recipe_skill_short(H, recipe))
			secondary_refund(H)
			return
	else if (findtext(recipe.title, "handcannon") || findtext(recipe.title, "dragoon helmet"))
		if (recipe_skill_short(H, recipe))
			secondary_refund(H)
			return
	else if (findtext(recipe.title, "monumental crucero cross") || findtext(recipe.title, "stone statue") || findtext(recipe.title, "sandstone statue"))
		if (recipe_skill_short(H, recipe))
			secondary_refund(H)
			return
	else if (findtext(recipe.title, "grandfather clock") || findtext(recipe.title, "standing clock"))
		if (recipe_skill_short(H, recipe))
			secondary_refund(H)
			return
	else if (findtext(recipe.title, "locked iron door") || findtext(recipe.title, "locked large iron double doors"))
		if (recipe_skill_short(H, recipe))
			secondary_refund(H)
			return
	else if (findtext(recipe.title, "reinforced large steel double doors"))
		if (recipe_skill_short(H, recipe))
			secondary_refund(H)
			return
	else if (findtext(recipe.title, "fire lance"))
		if (!istype(H.l_hand, /obj/item/weapon/material/spear) && !istype(H.r_hand, /obj/item/weapon/material/spear))
			to_chat(user, "<span class = 'warning'>You need to have a spear in one of your hands in order to make this.</span>")
			secondary_refund(H)
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
	if (recipe_needs_crafting_handle(recipe.title))
		needs_crafting_handle = TRUE
		crafting_handle = find_crafting_handle(H)
		if (!crafting_stack_accessible(H) || !crafting_handle)
			to_chat(user, SPAN_WARNING("You need an accessible wood handle in your hands or equipment to make this."))
			secondary_refund(H)
			return
		// Keep this exact item through the wait; cancellation must not recreate it.
		handle_crafting_source_loc = loc

	if (recipe.result_type == /obj/item/stack/material/electronics)
		if (recipe_skill_short(H, recipe))
			secondary_refund(H)
			return
		if (!electronics_construction_iron(H, quantity))
			to_chat(user, SPAN_WARNING("You need to have iron in the other hand to craft electronic circuits."))
			secondary_refund(H)
			return

	else if (recipe.result_type == /obj/structure/sawmill/powered)
		if (recipe_skill_short(H, recipe))
			secondary_refund(H)
			return
		if (!istype(H.l_hand, /obj/item/stack/material/electronics) && !istype(H.r_hand, /obj/item/stack/material/electronics))
			to_chat(user, SPAN_WARNING("You need to have electronic circuits in the other hand to craft the powered saw mill."))
			secondary_refund(H)
			return
		if (istype(H.l_hand, /obj/item/stack/material/electronics))
			var/obj/item/stack/material/electronics/NR = H.l_hand
			secondary_take(NR, 1, H)
			if (NR.amount <= 0)
				qdelHandReturn(H.l_hand, H)
		else if (istype(H.r_hand, /obj/item/stack/material/electronics))
			var/obj/item/stack/material/electronics/NR = H.r_hand
			secondary_take(NR, 1, H)
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
			to_chat(user, "<span class = 'warning'>You need to have a human head in one of your hands in order to make this.</span>")
			secondary_refund(H)
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

	if (findtext(recipe.title, "gravestone") || findtext(recipe.title, "cairn"))
		var/list/chosen = craft_product_options(user, recipe, options)
		if (!chosen)
			secondary_refund(H)
			return
		customname = chosen["name"]
		customdesc = chosen["desc"]

	else if (findtext(recipe.title, "market stall") || findtext(recipe.title, "vending machine"))
		var/list/chosen = craft_product_options(user, recipe, options)
		if (!chosen)
			secondary_refund(H)
			return
		customname = chosen["name"]
		customvar = chosen["company"]
		customvar2 = recipe.title
	else if (findtext(recipe.title, "supply stall"))
		var/list/chosen = craft_product_options(user, recipe, options)
		if (!chosen)
			secondary_refund(H)
			return
		customname = chosen["name"]
		customvar = chosen["company"]
		customvar2 = recipe.title

	if (craft_recipe_builds_well(recipe))
		if (!well_build_site(get_turf(H)))
			to_chat(H, "<span class = 'danger'>You need to build this over a puddle, or over a waterhole dug with a shovel.</span>")
			secondary_refund(H)
			return
	else if (findtext(recipe.title, "cannon") || findtext(recipe.title, "catapult") || findtext(recipe.title, "spadroon") || findtext(recipe.title, "arming sword") || findtext(recipe.title, "small sword"))
		if (recipe_skill_short(H, recipe))
			secondary_refund(H)
			return
	else if (findtext(recipe.title, "stormy sea") || findtext(recipe.title, "city street") || findtext(recipe.title, "sea sunset") || findtext(recipe.title, "valley") || findtext(recipe.title, "still life") || findtext(recipe.title, "bird and blossom") || findtext(recipe.title, "pine on the shore") || findtext(recipe.title, "temple by the river") || findtext(recipe.title, "desert camp") || findtext(recipe.title, "barque at sea"))
		if (recipe_skill_short(H, recipe))
			secondary_refund(H)
			return

		cloth_payment = new(src, H, recipe, quantity, 3)
		if (!cloth_payment.valid())
			to_chat(user, SPAN_WARNING("Hold at least [3 * quantity] cloth or woolcloth sheets for the painting(s)."))
			secondary_refund(H)
			return

	else if (findtext(recipe.title, "monumental marble statue of venus") || findtext(recipe.title, "monumental bronze statue of karl marx"))
		if (recipe_skill_short(H, recipe))
			secondary_refund(H)
			return

	else if (findtext(recipe.title, "gong") && !findtext(recipe.title, "gong mallet"))
		if (!istype(H.l_hand, /obj/item/stack/material/bronze) && !istype(H.r_hand, /obj/item/stack/material/bronze))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 5 bronze ingots in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/bronze))
				var/obj/item/stack/material/bronze/NB = H.l_hand
				if (NB.amount >= 5)
					secondary_take(NB, 5, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 5 bronze ingots in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/bronze))
				var/obj/item/stack/material/bronze/NB = H.r_hand
				if (NB.amount >= 5)
					secondary_take(NB, 5, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 5 bronze ingots in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (findtext(recipe.title, "bell stand"))
		if (!istype(H.l_hand, /obj/item/stack/material/copper) && !istype(H.r_hand, /obj/item/stack/material/copper))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 3 copper ingots in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/copper))
				var/obj/item/stack/material/copper/NB = H.l_hand
				if (NB.amount >= 3)
					secondary_take(NB, 3, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 3 copper ingots in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/copper))
				var/obj/item/stack/material/copper/NB = H.r_hand
				if (NB.amount >= 3)
					secondary_take(NB, 3, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 3 copper ingots in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (findtext(recipe.title, "chimalli"))
		if (!istype(H.l_hand, /obj/item/stack/material/leather) && !istype(H.r_hand, /obj/item/stack/material/leather))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 2 leather sheets in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/leather))
				var/obj/item/stack/material/leather/NB = H.l_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 leather sheets in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/leather))
				var/obj/item/stack/material/leather/NB = H.r_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 leather sheets in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (findtext(recipe.title, "aztec harness"))
		if (!istype(H.l_hand, /obj/item/stack/material/leather) && !istype(H.r_hand, /obj/item/stack/material/leather))
			to_chat(user, "<span class = 'warning'>You need at least 0.2 parts of a leather sheet in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/leather))
				var/obj/item/stack/material/leather/NB = H.l_hand
				if (NB.amount >= 0.2)
					secondary_take(NB, 0.2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need at least 0.2 parts of a leather sheet in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/leather))
				var/obj/item/stack/material/leather/NB = H.r_hand
				if (NB.amount >= 0.2)
					secondary_take(NB, 0.2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need at least 0.2 parts of a leather sheet in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (findtext(recipe.title, "primitive wood armor"))
		if (!istype(H.l_hand, /obj/item/stack/material/wood) && !istype(H.r_hand, /obj/item/stack/material/wood))
			to_chat(user, "<span class = 'warning'>You need at least 15 units of wood in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/rope))
				var/obj/item/stack/material/rope/NB = H.l_hand
				if (NB.amount >= 3)
					secondary_take(NB, 3, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need at least 3 lengths of rope in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/rope))
				var/obj/item/stack/material/rope/NB = H.r_hand
				if (NB.amount >= 3)
					secondary_take(NB, 3, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need at least 3 lengths of rope in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (findtext(recipe.title, "primitive bone hair-pipe armor"))
		if (!istype(H.l_hand, /obj/item/stack/material/bone) && !istype(H.r_hand, /obj/item/stack/material/bone))
			to_chat(user, "<span class = 'warning'>You need at least 5 pieces of bone in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/rope))
				var/obj/item/stack/material/rope/NB = H.l_hand
				if (NB.amount >= 3)
					secondary_take(NB, 3, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need at least 3 lengths of rope in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/rope))
				var/obj/item/stack/material/rope/NB = H.r_hand
				if (NB.amount >= 3)
					secondary_take(NB, 3, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need at least 3 lengths of rope in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (findtext(recipe.title, "doge hat"))
		if (!cloth_payment || !cloth_payment.select_secondary(/obj/item/stack/material/gold, 1 * quantity) || !cloth_payment.valid())
			to_chat(user, SPAN_WARNING("Hold the cloth or woolcloth and at least [1 * quantity] gold for this recipe."))
			secondary_refund(H)
			return

	else if (findtext(recipe.title, "doge outfit"))
		if (!cloth_payment || !cloth_payment.select_secondary(/obj/item/stack/material/gold, 1 * quantity) || !cloth_payment.valid())
			to_chat(user, SPAN_WARNING("Hold the cloth or woolcloth and at least [1 * quantity] gold for this recipe."))
			secondary_refund(H)
			return

	else if (findtext(recipe.title, "gold laurel crown"))
		if (!istype(H.l_hand, /obj/item/stack/material/leaf) && !istype(H.r_hand, /obj/item/stack/material/leaf))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 6 leaves in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/gold))
				var/obj/item/stack/material/gold/NB = H.l_hand
				if (NB.amount >= 1)
					secondary_take(NB, 1, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 1 gold in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/gold))
				var/obj/item/stack/material/gold/NB = H.r_hand
				if (NB.amount >= 1)
					secondary_take(NB, 1, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 1 gold in one your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (findtext(recipe.title, "imperial gold laurel crown")) // for crabs
		if (!istype(H.l_hand, /obj/item/stack/material/leaf) && !istype(H.r_hand, /obj/item/stack/material/leaf))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 3 leaves in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/gold))
				var/obj/item/stack/material/gold/NB = H.l_hand
				if (NB.amount >= 1)
					secondary_take(NB, 1, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 1 gold in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/gold))
				var/obj/item/stack/material/gold/NB = H.r_hand
				if (NB.amount >= 1)
					secondary_take(NB, 1, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 1 gold in one your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (findtext(recipe.title, "leaf crown") || findtext(recipe.title, "ceremonial leaf crown"))
		if (!istype(H.l_hand, /obj/item/stack/material/leaf) && !istype(H.r_hand, /obj/item/stack/material/leaf))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 4 leaves in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/leather))
				var/obj/item/stack/material/leather/NB = H.l_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 leather in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/leather))
				var/obj/item/stack/material/leather/NB = H.r_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 leather in one your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (findtext(recipe.title, "fiendish headdress"))
		if (!cloth_payment || !cloth_payment.select_secondary(/obj/item/stack/material/bone, 2 * quantity) || !cloth_payment.valid())
			to_chat(user, SPAN_WARNING("Hold the cloth or woolcloth and at least [2 * quantity] bone for this recipe."))
			secondary_refund(H)
			return

	else if (findtext(recipe.title, "black african mask") || findtext(recipe.title, "ceremonial black african mask"))
		if (!istype(H.l_hand, /obj/item/stack/material/wood) && !istype(H.r_hand, /obj/item/stack/material/wood))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 3 wood in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/pelt/cowpelt))
				var/obj/item/stack/material/pelt/cowpelt/NB = H.l_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 cowpelts in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/pelt/cowpelt))
				var/obj/item/stack/material/pelt/cowpelt/NB = H.r_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 cowpelts in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
/*
	else if (findtext(recipe.title, "armorbench"))
		if (!istype(H.l_hand, /obj/item/stack/material/wood) && !istype(H.r_hand, /obj/item/stack/material/wood))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 10 wood in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.l_hand
				if (NB.amount >= 3)
					secondary_take(NB, 3, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 3 iron in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.r_hand
				if (NB.amount >= 3)
					secondary_take(NB, 3, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 3 iron in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
*/
	else if (findtext(recipe.title, "fortress wall"))
		if (!istype(H.l_hand, /obj/item/stack/material/stone) && !istype(H.r_hand, /obj/item/stack/material/stone))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 8 stone in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/stonebrick))
				var/obj/item/stack/material/stonebrick/NB = H.l_hand
				if (NB.amount >= 8)
					secondary_take(NB, 8, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 8 stone bricks in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/stonebrick))
				var/obj/item/stack/material/stonebrick/NB = H.r_hand
				if (NB.amount >= 8)
					secondary_take(NB, 8, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 8 stone bricks in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
	else if (findtext(recipe.title, "sandstone fortress wall"))
		if (!istype(H.l_hand, /obj/item/stack/material/sandstone) && !istype(H.r_hand, /obj/item/stack/material/sandstone))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 8 sandstone in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/stonebrick))
				var/obj/item/stack/material/stonebrick/NB = H.l_hand
				if (NB.amount >= 5)
					secondary_take(NB, 5, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 5 stone bricks in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/stonebrick))
				var/obj/item/stack/material/stonebrick/NB = H.r_hand
				if (NB.amount >= 5)
					secondary_take(NB, 5, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 5 stone bricks in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (findtext(recipe.title, "purple arabic turban helmet") || findtext(recipe.title, "red arabic turban helmet") || findtext(recipe.title, "green arabic turban helmet") || findtext(recipe.title, "blue arabic turban helmet"))
		if (!cloth_payment || !cloth_payment.select_secondary(/obj/item/stack/material/iron, 3 * quantity) || !cloth_payment.valid())
			to_chat(user, SPAN_WARNING("Hold the cloth or woolcloth and at least [3 * quantity] iron for this recipe."))
			secondary_refund(H)
			return

	else if (findtext(recipe.title, "emirate turban"))
		if (!cloth_payment || !cloth_payment.select_secondary(/obj/item/stack/material/iron, 3 * quantity) || !cloth_payment.valid())
			to_chat(user, SPAN_WARNING("Hold the cloth or woolcloth and at least [3 * quantity] iron for this recipe."))
			secondary_refund(H)
			return

	else if (findtext(recipe.title, "leather samurai armor") || findtext(recipe.title, "red leather samurai armor") || findtext(recipe.title, "blue leather samurai armor") || findtext(recipe.title, "black leather samurai armor"))
		if (!istype(H.l_hand, /obj/item/stack/material/leather) && !istype(H.r_hand, /obj/item/stack/material/leather))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 10 leather in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.l_hand
				if (NB.amount >= 5)
					secondary_take(NB, 5, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 5 iron in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.r_hand
				if (NB.amount >= 5)
					secondary_take(NB, 5, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 5 iron in one your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (findtext(recipe.title, "leather samurai helmet") || findtext(recipe.title, "red leather samurai helmet") || findtext(recipe.title, "blue leather samurai helmet") || findtext(recipe.title, "black leather samurai helmet"))
		if (!istype(H.l_hand, /obj/item/stack/material/leather) && !istype(H.r_hand, /obj/item/stack/material/leather))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 7 leather in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.l_hand
				if (NB.amount >= 3)
					secondary_take(NB, 3, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 3 iron in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.r_hand
				if (NB.amount >= 3)
					secondary_take(NB, 3, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 3 iron in one your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (findtext(recipe.title, "grandfather clock"))
		if (!istype(H.l_hand, /obj/item/stack/material/woodplank) && !istype(H.r_hand, /obj/item/stack/material/woodplank))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 9 wood in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/glass))
				var/obj/item/stack/material/glass/NB = H.l_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 glass in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/glass))
				var/obj/item/stack/material/glass/NB = H.r_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 glass in one your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (findtext(recipe.title, "standing clock"))
		if (!istype(H.l_hand, /obj/item/stack/material/woodplank) && !istype(H.r_hand, /obj/item/stack/material/woodplank))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 6 wood in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/glass))
				var/obj/item/stack/material/glass/NB = H.l_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 glass in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/glass))
				var/obj/item/stack/material/glass/NB = H.r_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 glass in one your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (findtext(recipe.title, "wooden house door"))
		if (!istype(H.l_hand, /obj/item/stack/material/woodplank) && !istype(H.r_hand, /obj/item/stack/material/woodplank))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 5 wood in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/glass))
				var/obj/item/stack/material/glass/NB = H.l_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 glass in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/glass))
				var/obj/item/stack/material/glass/NB = H.r_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 glass in one your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (findtext(recipe.title, "plague doctor mask"))
		if (!cloth_payment || !cloth_payment.select_secondary(/obj/item/stack/medical/advanced/herbs, 2 * quantity) || !cloth_payment.valid())
			to_chat(user, SPAN_WARNING("Hold the cloth or woolcloth and at least [2 * quantity] herbs for this recipe."))
			secondary_refund(H)
			return

	else if (findtext(recipe.title, "khepresh war crown"))
		if (!istype(H.l_hand, /obj/item/stack/material/leather) && !istype(H.r_hand, /obj/item/stack/material/leather))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 3 leather in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/gold))
				var/obj/item/stack/material/gold/NB = H.l_hand
				if (NB.amount >= 1)
					secondary_take(NB, 1, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 1 gold in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/gold))
				var/obj/item/stack/material/gold/NB = H.r_hand
				if (NB.amount >= 1)
					secondary_take(NB, 1, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 1 gold in one your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (findtext(recipe.title, "steppe leather helmet"))
		if (!istype(H.l_hand, /obj/item/stack/material/leather) && !istype(H.r_hand, /obj/item/stack/material/leather))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 3 leather in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.l_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 iron in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.r_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 iron in one your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (findtext(recipe.title, "leather skullcap helmet"))
		if (!istype(H.l_hand, /obj/item/stack/material/leather) && !istype(H.r_hand, /obj/item/stack/material/leather))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 5 leather in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.l_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 iron in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.r_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 iron in one your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (findtext(recipe.title, "television"))
		if (!istype(H.l_hand, /obj/item/stack/material/electronics) && !istype(H.r_hand, /obj/item/stack/material/electronics))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 3 electronics in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.l_hand
				if (NB.amount >= 4)
					secondary_take(NB, 4, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 4 iron in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/iron))
				var/obj/item/stack/material/iron/NB = H.r_hand
				if (NB.amount >= 4)
					secondary_take(NB, 4, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 4 iron in one your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (ispath(recipe.result_type, /obj/structure/drill))
		if (!drill_construction_steel(H))
			to_chat(user, SPAN_WARNING("You need at least 20 steel in your other hand to build an industrial drill."))
			secondary_refund(H)
			return
	else if (findtext(recipe.title, "brown napoleonic bearskin hat"))
		if (!istype(H.l_hand, /obj/item/stack/material/pelt/bearpelt/brown) && !istype(H.r_hand, /obj/item/stack/material/pelt/bearpelt/brown))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 4 brown bear pelts in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/bronze))
				var/obj/item/stack/material/bronze/NB = H.l_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 bronze in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/bronze))
				var/obj/item/stack/material/bronze/NB = H.r_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 bronze in one your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (findtext(recipe.title, "black napoleonic bearskin hat"))
		if (!istype(H.l_hand, /obj/item/stack/material/pelt/bearpelt/black) && !istype(H.r_hand, /obj/item/stack/material/pelt/bearpelt/black))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 4 black bear pelts in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/bronze))
				var/obj/item/stack/material/bronze/NB = H.l_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 bronze in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/bronze))
				var/obj/item/stack/material/bronze/NB = H.r_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 bronze in one your hands in order to make this.</span>")
					secondary_refund(H)
					return

	else if (findtext(recipe.title, "white napoleonic bearskin hat"))
		if (!istype(H.l_hand, /obj/item/stack/material/pelt/bearpelt/white) && !istype(H.r_hand, /obj/item/stack/material/pelt/bearpelt/white))
			to_chat(user, "<span class = 'warning'>You need a stack of at least 4 white bear pelts in one of your hands in order to make this.</span>")
			secondary_refund(H)
			return
		else
			if (istype(H.l_hand, /obj/item/stack/material/bronze))
				var/obj/item/stack/material/bronze/NB = H.l_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.l_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 bronze in one of your hands in order to make this.</span>")
					secondary_refund(H)
					return
			else if (istype(H.r_hand, /obj/item/stack/material/bronze))
				var/obj/item/stack/material/bronze/NB = H.r_hand
				if (NB.amount >= 2)
					secondary_take(NB, 2, H)
					if (NB.amount <= 0)
						qdelHandReturn(H.r_hand, H)
				else
					to_chat(user, "<span class = 'warning'>You need a stack of at least 2 bronze in one your hands in order to make this.</span>")
					secondary_refund(H)
					return

	if (!can_use(required))
		if (produced>1)
			to_chat(user, "<span class='warning'>You haven't got enough [src] to build \the [produced] [recipe.title]\s!</span>")
		else
			to_chat(user, "<span class='warning'>You haven't got enough [src] to build \the [recipe.title]!</span>")
		secondary_refund(H)
		return

	if (recipe.one_per_turf && (locate(recipe.result_type) in user.loc) && !well_relining(recipe.result_type, user.loc))
		to_chat(user, "<span class='warning'>There is another [recipe.title] here!</span>")
		secondary_refund(H)
		return

	// Stairs from an upper floor go down: facing an opening, they are laid on
	// the floor below it and climb back up to the builder (edge_climbing.dm).
	var/atom/build_loc = user.loc
	var/list/stairs_down = null
	if (cover_type_is_stairs(recipe.result_type))
		var/list/stairs_why = list()
		stairs_down = stairs_down_spot(user, recipe.result_type, stairs_why)
		if (stairs_down)
			build_loc = stairs_down[1]
		else if (stairs_why.len && stairs_why[1])
			to_chat(user, SPAN_WARNING(stairs_why[1]))
			secondary_refund(H)
			return

	// One floor and one wall per tile (tile_occupancy.dm).
	var/tile_refusal = tile_build_refusal(get_turf(build_loc), recipe.result_type)
	if (tile_refusal)
		to_chat(user, SPAN_WARNING(tile_refusal))
		secondary_refund(H)
		return

	// Upper storeys are open air under a floor cover (tile_occupancy.dm).
	if (recipe.on_floor && !tile_has_floor(get_turf(user)))
		to_chat(user, "<span class='warning'>\The [recipe.title] must be constructed on the floor! Stand on the ground or a floor to build it.</span>")
		secondary_refund(H)
		return

	if (ishuman(user))
		H = user

	if (ispath(recipe.result_type, /obj/structure))
		if (!ispath(recipe.result_type, /obj/structure/noose))
			for (var/obj/structure/multiz/M in get_turf(H))
				if (recipe.title != "mine support")
					to_chat(H, "<span class = 'danger'>You can't build a structure here.</span>")
					secondary_refund(H)
					return
	else if (recipe.result_type == /obj/item/weapon/key)
		if (H.faction_text == INDIANS)
			to_chat(H, "<span class = 'danger'>You don't know how to make this.</span>")
			secondary_refund(H)
			return
		else
			var/keycode = player_input(user, "Choose a code for the key(From 1000 to 9999):", null, null, "num", null, FALSE)
			keycode = Clamp(keycode, 1000, 9999)
			var/keyname = player_input(user, "Choose a name for the key:", null, null, "text", null, TRUE)
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
			to_chat(H, "<span class = 'warning'>You need to be on a structure to make a noose.</span>")
			secondary_refund(H)
			return
		else if (structurecheck == 1)
			to_chat(H, "<span class = 'warning'>This structure is not suitable for standing on.</span>")
			secondary_refund(H)
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
				to_chat(H, "<span class = 'warning'>You need a ceiling to make a noose.</span>")
				secondary_refund(H)
				return

	if (recipe.time)
		var/buildtime = recipe.time
		if (H && H.getStatCoeff("strength"))
			buildtime /= H.getStatCoeff("strength")
			buildtime /= (H.getStatCoeff("crafting") * H.getStatCoeff("crafting"))
			buildtime *= H.trade_time_mult(stack_trade()) // trades (trade_traits.dm)

		buildtime = reference_build_time(H, "[recipe.result_type]", round(buildtime)) // working from a book (subject_prototypes.dm)

		to_chat(user, "<span class='notice'>Building [recipe.title] ...</span>")
		if (!do_after(user, buildtime) || !crafting_recipe_allowed(H, "[recipe.result_type]"))
			secondary_refund(H)
			return

		// Hammocks pay only after this wait. Do not reject legacy recipes here:
		// some already consumed secondary inputs before do_after.
		if (recipe.result_type == /obj/structure/bed/hammock && recipe.one_per_turf && (locate(recipe.result_type) in user.loc))
			to_chat(user, "<span class='warning'>There is another [recipe.title] here!</span>")
			secondary_refund(H)
			return
		// The builder may have moved, turned or changed the bay during the wait.
		var/late_refusal = craft_guard_refusal(H, recipe, CRAFT_GUARD_FINISH)
		if (!isnull(late_refusal))
			if (late_refusal)
				to_chat(user, late_refusal)
			secondary_refund(H)
			return
		if (press_construction && !press_construction.valid())
			secondary_refund(H)
			return
		secondary_forget(H)
		if (H && !joinery && !carving && !cloth_payment)
			H.adaptStat("crafting", 1*recipe.req_amount, recipe.result_type)
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
	// A well takes the place of the puddle it is built over; a dug hole is taken over by the lining (dug_wells.dm).
	if (ispath(recipe.result_type, /obj/structure/sink/well))
		for (var/obj/structure/sink/puddle/P in get_turf(H))
			if (!P.dug_depth)
				qdel(P)
	var/inpt = 50
	if (recipe.result_type == /obj/structure/cannon/modern/tank)
		inpt = player_input(user, "Choose the gun's caliber: (50mm-150mm, cost 40 steel per 75mm)", null, null, "num", null, FALSE)
		if (!isnum(inpt))
			return
		if (inpt < 50)
			inpt = 50
		else if (inpt > 150)
			inpt = 150
		required = 40*(inpt/75)
	else if (recipe.result_type == /obj/item/stack/ammopart/casing/tank)
		inpt = player_input(user, "Choose the casing's caliber: (50mm-150mm, cost 2 copper per 75mm)", null, null, "num", null, FALSE)
		if (!isnum(inpt))
			return
		if (inpt < 50)
			inpt = 50
		else if (inpt > 150)
			inpt = 150
		required = 2*(inpt/75)
	
	if (recipe.result_type == /obj/structure/barbwire)
		var/barbwire_amount = 0
		for (var/obj/structure/barbwire/B in get_turf(user))
			barbwire_amount++
		if (barbwire_amount >= 2)
			to_chat(H, SPAN_WARNING("You cannot build more barbwire here."))
			return

	// Recheck after do_after, before consuming either drill construction input.
	if (ispath(recipe.result_type, /obj/structure/drill))
		var/obj/item/stack/material/steel/drill_steel = drill_construction_steel(H)
		if (!can_use(required) || !drill_steel)
			to_chat(user, SPAN_WARNING("Keep the electronics and 20 steel in your hands until construction completes."))
			return
		drill_steel.use(20)
	else if (recipe.result_type == /obj/item/stack/material/electronics)
		var/obj/item/stack/material/iron/circuit_iron = electronics_construction_iron(H, quantity)
		if (!can_use(required) || !circuit_iron)
			to_chat(user, SPAN_WARNING("Keep the copper and iron in your hands until the circuits are complete."))
			return
		circuit_iron.use(quantity)

	// Structural floors on open air need a supported ceiling below. Recheck
	// after the action wait and before material consumption.
	var/building_floor_recipe = FALSE
	if (ispath(recipe.result_type, /obj/covers))
		var/obj/covers/floor_type = recipe.result_type
		building_floor_recipe = !initial(floor_type.wall) && initial(floor_type.layer) < 2.1
	// Anything else is built where the builder stands now.
	if (!stairs_down)
		build_loc = user.loc
	if (stairs_down)
		var/list/stairs_why = list()
		var/list/stairs_now = stairs_down_spot(user, recipe.result_type, stairs_why)
		if (!stairs_now || stairs_now[1] != stairs_down[1] || stairs_now[2] != stairs_down[2])
			to_chat(user, SPAN_WARNING(stairs_why.len && stairs_why[1] ? stairs_why[1] : "Stay facing the opening until the stairs are built."))
			return
	// A floor laid over a floor cover or upper floor replaces it (tile_occupancy.dm).
	var/obj/covers/subfloor = building_floor_recipe ? tile_subfloor_for(get_turf(build_loc), recipe.result_type) : null
	if (building_floor_recipe && !subfloor)
		var/building_error = building_floor_error(get_turf(build_loc))
		if (building_error)
			to_chat(user, SPAN_WARNING(building_error))
			return
	// The tile may have gained a floor or wall during the wait.
	tile_refusal = tile_build_refusal(get_turf(build_loc), recipe.result_type)
	if (tile_refusal)
		to_chat(user, SPAN_WARNING(tile_refusal))
		return

	if (needs_crafting_handle)
		if (loc != handle_crafting_source_loc || !crafting_stack_accessible(H) || !crafting_handle_available(H, crafting_handle))
			to_chat(user, SPAN_WARNING("Keep the materials and the selected wood handle accessible until construction completes."))
			return

	var/offer_stone_hatchet = istype(src, /obj/item/stack/material/stone) && recipe.result_type == /obj/item/weapon/material/hatchet/tribal
	// Retain and recheck tools, secondary stock, occupied tile and research after
	// the wait. No debit occurs on an interrupted or invalidated action.
	// Tools and second materials must still be there; they are paid below.
	needs_refusal = craft_needs_refusal(H, recipe, quantity, src)
	if (needs_refusal)
		to_chat(user, needs_refusal)
		return
	if (press_construction && !press_construction.valid())
		return
	if (joinery && !joinery.valid())
		to_chat(user, SPAN_WARNING("Keep the joinery materials and tools in place until construction completes."))
		return
	if (carving && !carving.valid())
		to_chat(user, SPAN_WARNING("Keep the sandstone and selected carving tools in place until carving completes."))
		return
	if (cloth_payment && !cloth_payment.valid())
		to_chat(user, SPAN_WARNING("Keep the selected cloth and other materials in place until construction completes."))
		return
	if (use(required, (joinery || carving) ? null : H))
		if (joinery)
			joinery.consume_component()
		if ((joinery || carving) && H && recipe.time)
			H.adaptStat("crafting", 1*recipe.req_amount, recipe.result_type)
		if (cloth_payment)
			cloth_payment.consume_secondary()
			if (H && recipe.time)
				H.adaptStat("crafting", 1*recipe.req_amount, recipe.result_type)
		if (needs_crafting_handle)
			// The handle's wood carries into the tool (apply_tool_handle).
			handle_material_name = crafting_handle.material ? crafting_handle.material.name : "wood"
			handle_quality = crafting_handle.crafting_quality
			if (crafting_handle.maxhealth > 0)
				handle_condition = crafting_handle.health / crafting_handle.maxhealth
			// No wait between revalidation and commit. Clear the actual equipment slot.
			H.remove_from_mob(crafting_handle)
			qdel(crafting_handle)
		craft_needs_pay(H, recipe, quantity, src)
		// Trial and error: an early attempt at an unknown subject can fail (subject_prototypes.dm).
		if (trial_craft_ruined(user, "[recipe.result_type]"))
			return
		var/atom/O
		if (recipe && recipe.use_material && recipe.result_type)
			O = new recipe.result_type(build_loc, recipe.use_material)
		else
			O = new recipe.result_type(build_loc)
		if (offer_stone_hatchet)
			offer_crafted_axe_to_active_hand(user, O)

		if (istype(O, /obj/structure/civ_generator/waterwheel))
			var/obj/structure/civ_generator/waterwheel/WW = O
			if (!WW.persistence_set_loc(waterwheel_build_target(user))) return FALSE
			WW.update_icon()
			return

		if (building_floor_recipe)
			var/obj/covers/floor = O
			if (!subfloor || !floor.replace_subfloor(subfloor))
				floor.building_finish_floor()

		// The handle's wood sets the tool's durability and speed (material_weapons.dm).
		if (handle_material_name)
			apply_tool_handle(O, handle_material_name, handle_quality, handle_condition)
		// A tiki torch remembers its pole material so dismantling returns the same.
		if (istype(O, /obj/item/flashlight/tiki_torch) && istype(src, /obj/item/stack/material))
			var/obj/item/stack/material/pole_stack = src
			var/obj/item/flashlight/tiki_torch/tiki = O
			if (pole_stack.material)
				tiki.frame_material = pole_stack.material.name
		// Tailoring: the project is made of whichever woven fabric paid for it.
		if (istype(O, /obj/item/tailoring_project))
			var/obj/item/tailoring_project/project = O
			project.fabric_kind = tailoring_fabric_kind_of(src) || project.fabric_kind
		// Alloys: a smith who knows it forges longer-lasting metal (node_effects.dm).
		apply_crafting_node_effects(user, O)
		// Practice: making it counts as field work for the next node (practice_work.dm).
		note_craft_practice(user, "[recipe.result_type]")
		player_activity.crafted(H, recipe.result_type)
		// Built only through a demonstration kit: a crude experimental machine (demonstrations.dm).
		mark_experimental_build(H, O, "[recipe.result_type]")

		if(istype(O, /obj/structure/cannon/modern/tank))
			var/obj/structure/cannon/modern/tank/T = O
			T.caliber = inpt
			T.name = "[T.caliber]mm tank cannon"
			T.w_class = ITEM_SIZE_GARGANTUAN
			return

		if(istype(O, /obj/item/stack/ammopart/casing/tank))
			var/obj/item/stack/ammopart/casing/tank/T = O
			T.caliber = inpt
			T.name = "[T.caliber]mm cannon casing"
			return

		if (istype(O, /obj/item/ammo_magazine/emptymagazine/rifle))
			var/obj/item/ammo_magazine/emptymagazine/rifle/T = O
			if (map.ID == MAP_NOMADS_PERSISTENCE_BETA || map.ID == MAP_NATIONSRP_COLDWAR_CMP)
				if (H.faction_text == BLUEFACTION)
					T.icon_state = "ak74"
				else if (H.faction_text == REDFACTION)
					T.icon_state = "m16"
			return

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
				if (!M.persistence_set_loc(get_step(user, user.dir))) return FALSE
				var/image/mailbox_color_overlay = image("icon" = 'icons/obj/mail.dmi', "icon_state" = "wall_mailbox_closed")
				mailbox_color_overlay.color = input
				M.mailbox_color = input
				M.overlays += mailbox_color_overlay
				return

		if (istype(O, /obj/structure/sign) && !istype(O, /obj/structure/sign/signpost))
			if (customname != "")
				O.name = customname
			if (customdesc != "")
				O.desc = customdesc
			var/obj/structure/sign/S = O
			if (!S.persistence_set_loc(get_step(user, user.dir))) return FALSE
			return

		if (istype(O, /obj/structure/noticeboard) || istype(O, /obj/structure/mirror))
			var/obj/structure/noticeboard/N = O
			if (!N.persistence_set_loc(get_step(user, user.dir))) return FALSE
			return

		if (istype(O, /obj/item/clothing/accessory/medal))
			if (customdesc != "")
				O.desc = customdesc
			var/obj/item/clothing/accessory/medal/M = O
			if (!M.persistence_set_loc(get_turf(user))) return FALSE
			return

		if (build_override_firelance)
			if (!build_override_firelance.persistence_set_loc(get_turf(O))) return FALSE
			build_override_firelance.set_dir(user.dir)
			build_override_firelance.add_fingerprint(user)
			qdel(O)
			return

		if (build_override_key)
			if (!build_override_key.persistence_set_loc(get_turf(O))) return FALSE
			build_override_key.set_dir(user.dir)
			build_override_key.add_fingerprint(user)
			qdel(O)
			return

		if (build_override_object)
			if (!build_override_object.persistence_set_loc(get_turf(O))) return FALSE
			build_override_object.set_dir(user.dir)
			build_override_object.add_fingerprint(user)
			qdel(O)
			return

		if (newtotem)
			if (!newtotem.persistence_set_loc(get_turf(O))) return FALSE
			newtotem.set_dir(user.dir)
			newtotem.add_fingerprint(user)
			qdel(O)
			return
		if (build_override_door)
			if (!build_override_door.persistence_set_loc(get_turf(O))) return FALSE
			build_override_door.set_dir(user.dir)
			build_override_door.add_fingerprint(user)
			qdel(O)
			spawn(0)
				build_override_door.door_choose_inside(user)
			return
		if (faction_override_door)
			if (!faction_override_door.persistence_set_loc(get_turf(O))) return FALSE
			faction_override_door.set_dir(user.dir)
			faction_override_door.add_fingerprint(user)
			qdel(O)
			spawn(0)
				faction_override_door.door_choose_inside(user)
			return
		if (customname != "")
			O.name = customname

		if (customdesc != "")
			O.desc = customdesc
		if (istype(O, /obj/structure/sign/signpost))
			O.desc = customdesc
			var/obj/structure/sign/signpost/STR = O
			STR.update_icon()
		O.set_dir(stairs_down ? stairs_down[2] : user.dir)
		if (stairs_down)
			user.visible_message(SPAN_NOTICE("[user] builds \a [O] down to the level below."), SPAN_NOTICE("You build \the [O] down through the opening. They climb back up to where you stand."))
		if (istype(O, /obj/structure/vehicleparts/frame))
			O.dir = 1
		// A crenelated wall covers the side its builder faced (castle_defences.dm).
		battlement_after_build(O, user)
		O.add_fingerprint(user)
		if (istype(O, /obj/structure/simple_door))
			var/obj/structure/simple_door/new_door = O
			spawn(0)
				new_door.door_choose_inside(user)
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
		else if (istype(O, /obj/structure/research_bench))
			// The bench belongs to the faction that built it (Phase 4.1);
			// a factionless builder, or any builder under book research,
			// makes an unowned bench (bench_owner_faction()).
			// Re-check the cap HERE, not just pre-build: the earlier check
			// passed ~25s ago and several members can build in parallel
			// (time-of-check/time-of-use), so validate again now that the
			// bench exists but hasn't been assigned to the faction yet --
			// count_faction_benches() only counts assigned benches, so the
			// count is still accurate at this point.
			var/obj/structure/research_bench/RBN = O
			var/owner_faction = map ? map.bench_owner_faction(H) : null
			if (owner_faction)
				if (map.count_faction_benches(owner_faction) >= map.get_bench_cap(owner_faction))
					to_chat(H, SPAN_WARNING("Your faction hit its research bench cap while this one was being built - it falls apart, and you recover the materials."))
					// Refund: the materials were already consumed by use() above.
					if (required > 0)
						new type(get_turf(H), required)
					qdel(O)
					return
				RBN.faction = owner_faction
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
			var/list/possible_clothes = era_options(list("none" = null, "toga" = null, "tunic" = 1, "medieval" = 2, "king" = 2,
				"templar" = 2, "knight" = 2, "colonial" = 3, "modern civilian" = 4, "modern military" = 5))
			var/inpc = WWinput(user, "What clothing to add?", "Statue", "none", possible_clothes)
			var/list/possible_objects = era_options(list("none" = null, "spear" = null, "spear and roman shield" = 1,
				"spear and oval shield" = 1, "spear and semioval shield" = 2, "sword and roman shield" = 2,
				"sword and oval shield" = 2, "sword and semioval shield" = 2, "flag" = 2, "rifle" = 3,
				"pistol" = list(4, 6), "assault rifle" = 7))

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
			if (!build_override_supply.persistence_set_loc(get_turf(O))) return FALSE
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
			if (!build_override_vending.persistence_set_loc(get_turf(O))) return FALSE
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

// The normal menu requires a held stack. Preserve direct callers using a nearby
// ground stack, while rejecting transferred, nested or remote source materials.
/obj/item/stack/proc/crafting_stack_accessible(mob/living/human/H)
	if (QDELETED(src) || QDELETED(H))
		return FALSE
	return (loc == H && H.item_is_in_hands(src)) || (isturf(loc) && H.Adjacent(src))

// Consume only removable equipment owned directly by the actor. Do not recurse
// into storage: return_inv/get_contents do not enforce container accessibility.
/obj/item/stack/proc/crafting_handle_available(mob/living/human/H, obj/item/weapon/material/handle/handle)
	return crafting_handle_usable(H, handle)

/obj/item/stack/proc/find_crafting_handle(mob/living/human/H)
	return crafting_handle_on(H)

// Circuit batches pay one iron per circuit, only after both inputs survive the wait.
/obj/item/stack/proc/electronics_construction_iron(mob/living/human/H, quantity)
	if (!istype(src, /obj/item/stack/material/copper) || !H || loc != H || quantity < 1 || quantity != round(quantity))
		return null
	if (H.l_hand != src && H.r_hand != src)
		return null
	var/obj/item/stack/material/iron/I = H.l_hand == src ? H.r_hand : H.l_hand
	if (istype(I) && I.loc == H && I.can_use(quantity))
		return I
	return null

// The recipe stack pays electronics; the other held stack pays steel.
/obj/item/stack/proc/drill_construction_steel(mob/living/human/H)
	if (!istype(src, /obj/item/stack/material/electronics) || !H)
		return null
	if (H.l_hand != src && H.r_hand != src)
		return null
	var/obj/item/stack/material/steel/S = H.l_hand == src ? H.r_hand : H.l_hand
	if (istype(S) && S.can_use(20))
		return S
	return null

// Icon suffix for a stack drawn as a growing pile: "" below the first
// threshold, then "_2", "_3"... for each threshold the amount reaches.
/proc/pile_suffix(amount, list/thresholds)
	. = ""
	for (var/i = thresholds.len, i >= 1, i--)
		if (amount >= thresholds[i])
			return "_[i + 1]"
