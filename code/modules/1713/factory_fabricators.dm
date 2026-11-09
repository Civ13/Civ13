// Fabricators (phase 3 of docs/factory-automation-design.md).
//
// A fabricator is set once to a recipe from the curated factory recipe list in
// config/crafting/factory_recipes.txt, then runs without a person: arms and
// belts fill its input buffer, each cycle needs cable power for its whole
// duration, and inputs are consumed only when a cycle completes, so a power
// cut pauses it without losing anything. Output is left on its own tile for
// arms to take. Higher tiers run longer recipes and cycle faster.

#define FACTORY_FAB_BUFFER_CYCLES 2 // cycles of each input a fabricator buffers
#define FACTORY_FAB_OUTPUT_LIMIT 12 // loose items left on the tile before it waits
#define FACTORY_FAB_STEP 10 // deciseconds of work per powered step

/datum/factory_recipe
	var/name = ""
	var/output_type = null
	var/output_amount = 1
	var/list/inputs = null // type => amount per cycle
	var/time = 10 // deciseconds at tier 1
	var/tier = 1
	var/node = null

var/global/list/factory_recipes = null // name => /datum/factory_recipe
var/global/list/factory_recipe_errors = list()
var/global/list/factory_active_fabricators = list()

/proc/factory_load_recipes(path = "config/crafting/factory_recipes.txt")
	factory_recipes = list()
	factory_recipe_errors = list()
	if (!fexists(path))
		factory_recipe_errors += "missing [path]"
		return factory_recipes
	for (var/line in splittext(file2text(path), "\n"))
		line = trim(line)
		if (findtext(line, "FACTORY: ") != 1)
			continue
		var/list/fields = splittext(copytext(line, 10), "|")
		if (fields.len != 7)
			factory_recipe_errors += "expected 7 fields: [line]"
			continue
		var/datum/factory_recipe/R = new
		R.name = trim(fields[1])
		R.output_type = text2path(trim(fields[2]))
		R.output_amount = text2num(fields[3])
		R.time = text2num(fields[5])
		R.tier = text2num(fields[6])
		R.node = trim(fields[7])
		R.inputs = list()
		var/valid = R.name && ispath(R.output_type, /obj/item) && R.output_amount >= 1 && R.time >= FACTORY_FAB_STEP && R.tier >= 1 && R.node
		for (var/entry in splittext(fields[4], ";"))
			var/list/parts = splittext(entry, "=")
			var/input_type = parts.len == 2 ? text2path(trim(parts[1])) : null
			var/amount = parts.len == 2 ? text2num(parts[2]) : 0
			if (!ispath(input_type, /obj/item) || amount < 1)
				valid = FALSE
				break
			R.inputs[input_type] = amount
		if (!valid || !R.inputs.len || factory_recipes[R.name])
			factory_recipe_errors += "invalid recipe: [line]"
			continue
		factory_recipes[R.name] = R
	return factory_recipes

/proc/factory_get_recipes()
	if (!factory_recipes)
		factory_load_recipes()
	return factory_recipes

/obj/structure/factory_fabricator
	name = "assembly fabricator"
	desc = "A powered machine that turns parts fed by arms and belts into goods from the factory recipe list. Set its recipe by hand; cable it to run. Output is left in front of it on its own tile."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "bakelizer"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	powerneeded = 6
	var/base_state = "bakelizer"
	var/tier = 1
	var/work_speed = 1 // time multiplier
	var/recipe_name = null
	var/progress = 0 // powered deciseconds into the current cycle
	var/tmp/fab_active = FALSE
	var/tmp/fab_status = "idle" // for the factory monitor
	var/tmp/datum/factory_rate/output_rate = null

/obj/structure/factory_fabricator/automated
	name = "automated fabricator"
	icon_state = "uranium_refinery"
	base_state = "uranium_refinery"
	tier = 2
	work_speed = 0.75
	powerneeded = 10

/obj/structure/factory_fabricator/computerized
	name = "computerized fabricator"
	icon_state = "uranium_refinery"
	base_state = "uranium_refinery"
	color = "#9fc7ff"
	tier = 3
	work_speed = 0.5
	powerneeded = 15

// Digital Age (2026). Prints only the tier-4 printing recipes, from plastic
// feedstock. Unlike the other fabricators it also takes feedstock by hand, so
// a workshop without belts or arms can still run one.
#define FACTORY_PRINTER_TIER 4
/obj/structure/factory_fabricator/printer
	name = "3D printer"
	desc = "An additive manufacturing printer that builds plastic goods layer by layer. Set what it prints by hand, then load plastic by hand or with arms and belts. Cable it to run; prints are left in front of it."
	icon_state = "autoclaveb"
	base_state = "autoclaveb"
	tier = FACTORY_PRINTER_TIER
	work_speed = 0.5
	powerneeded = 8

/obj/structure/factory_fabricator/printer/update_icon()
	icon_state = base_state

/obj/structure/factory_fabricator/printer/available_recipes(faction)
	var/list/result = list()
	for (var/name in ..())
		var/datum/factory_recipe/R = factory_recipes[name]
		if (R.tier == FACTORY_PRINTER_TIER)
			result += name
	return result

/obj/structure/factory_fabricator/printer/attackby(obj/item/W, mob/user)
	var/datum/factory_recipe/R = current_recipe()
	if (R && ishuman(user) && recipe_input_for(W, R))
		var/amount = factory_accepts(W)
		if (amount <= 0)
			to_chat(user, SPAN_WARNING("\The [src] is already loaded with enough [W.name]."))
			return
		if (amount >= factory_item_amount(W))
			user.remove_from_mob(W)
		if (factory_insert(W) > 0)
			to_chat(user, SPAN_NOTICE("You load [amount] [W.name] into \the [src]."))
		return
	return ..()

/obj/structure/factory_fabricator/New()
	..()
	update_icon()

/obj/structure/factory_fabricator/Destroy()
	fab_sleep()
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)
	for (var/obj/item/I in contents)
		I.forceMove(get_turf(src))
	return ..()

/obj/structure/factory_fabricator/persistence_runtime_var(key)
	if (key == "fab_active" || key == "powered")
		return TRUE
	return ..()

/obj/structure/factory_fabricator/after_load()
	. = ..()
	powered = FALSE
	if (recipe_name && !current_recipe())
		recipe_name = null
	var/datum/factory_recipe/R = current_recipe()
	progress = R ? clamp(round(progress), 0, cycle_time(R)) : 0
	if (R)
		fab_wake()
	update_icon()

/obj/structure/factory_fabricator/update_icon()
	icon_state = (fab_active && powered) ? "[base_state]_on" : base_state

/obj/structure/factory_fabricator/proc/current_recipe()
	if (!recipe_name)
		return null
	var/list/recipes = factory_get_recipes()
	return recipes[recipe_name]

/obj/structure/factory_fabricator/proc/cycle_time(datum/factory_recipe/R)
	return max(FACTORY_FAB_STEP, round(R.time * work_speed))

// Recipes this fabricator can run for a person of faction.
/obj/structure/factory_fabricator/proc/available_recipes(faction)
	var/list/result = list()
	for (var/name in factory_get_recipes())
		var/datum/factory_recipe/R = factory_recipes[name]
		if (R.tier > tier)
			continue
		if (map && !map.is_node_done(faction, R.node))
			continue
		result += name
	return result

/obj/structure/factory_fabricator/examine(mob/user, distance)
	..(user, distance)
	var/datum/factory_recipe/R = current_recipe()
	if (!R)
		to_chat(user, SPAN_NOTICE("It has no recipe set."))
		return
	var/list/needs = list()
	for (var/input_type in R.inputs)
		var/atom/A = input_type
		needs += "[R.inputs[input_type]] [initial(A.name)] ([buffered(input_type)] loaded)"
	var/atom/O = R.output_type
	to_chat(user, SPAN_NOTICE("It makes [R.output_amount] [initial(O.name)] from [english_list(needs)] every [cycle_time(R) / 10] seconds of power."))
	if (fab_active && !powered)
		to_chat(user, SPAN_WARNING("It is waiting for power."))

/obj/structure/factory_fabricator/attack_hand(mob/living/human/H)
	if (!istype(H))
		return
	if (!anchored)
		to_chat(H, SPAN_WARNING("Fix \the [src] in place with a wrench first."))
		return
	var/list/choices = available_recipes(H.civilization)
	if (!choices.len)
		to_chat(H, SPAN_WARNING("Your faction has not researched any recipe this fabricator can make."))
		return
	choices += "(clear recipe)"
	var/choice = input(H, "Choose what \the [src] makes.", "Fabricator recipe", recipe_name) as null|anything in choices
	if (!choice || QDELETED(src) || !H.Adjacent(src) || H.incapacitated())
		return
	if (choice != "(clear recipe)")
		var/datum/factory_recipe/R = factory_get_recipes()[choice]
		if (!R || R.tier > tier || !crafting_node_allowed(H, R.node)) return
	set_recipe(choice == "(clear recipe)" ? null : choice)
	to_chat(H, SPAN_NOTICE(recipe_name ? "\The [src] will now make [recipe_name]." : "You clear \the [src]'s recipe."))

/obj/structure/factory_fabricator/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/cable_coil))
		connect_cable(user, W)
		return
	return ..()

// Changing the recipe returns the old buffer to the floor and restarts the cycle.
/obj/structure/factory_fabricator/proc/set_recipe(name)
	if (name && !(name in factory_get_recipes()))
		return FALSE
	if (name == recipe_name)
		return TRUE
	for (var/obj/item/I in contents)
		I.forceMove(get_turf(src))
	recipe_name = name
	progress = 0
	if (recipe_name)
		fab_wake()
	else
		fab_stop()
	update_icon()
	return TRUE

/obj/structure/factory_fabricator/proc/buffered(input_type)
	var/total = 0
	for (var/obj/item/I in contents)
		if (istype(I, input_type))
			total += factory_item_amount(I)
	return total

/obj/structure/factory_fabricator/proc/recipe_input_for(obj/item/I, datum/factory_recipe/R)
	for (var/input_type in R.inputs)
		if (istype(I, input_type))
			return input_type
	return null

/obj/structure/factory_fabricator/factory_accepts(obj/item/I, from_dir = 0)
	var/datum/factory_recipe/R = current_recipe()
	if (!R || !anchored || !factory_movable_item(I) || I.loc == src)
		return 0
	var/input_type = recipe_input_for(I, R)
	if (!input_type)
		return 0
	var/room = R.inputs[input_type] * FACTORY_FAB_BUFFER_CYCLES - buffered(input_type)
	return max(0, min(factory_item_amount(I), room))

/obj/structure/factory_fabricator/factory_insert(obj/item/I, from_dir = 0)
	var/amount = factory_accepts(I, from_dir)
	if (amount <= 0)
		return 0
	. = factory_move_units(I, src, amount)
	if (.)
		fab_wake()

/obj/structure/factory_fabricator/factory_offer(to_dir = 0, filter_type = null)
	var/datum/factory_recipe/R = current_recipe()
	if (!R)
		return null
	var/turf/T = get_turf(src)
	for (var/obj/item/I in T)
		if (istype(I, R.output_type) && (!filter_type || istype(I, filter_type)) && factory_movable_item(I))
			return I
	return null

/obj/structure/factory_fabricator/factory_take(obj/item/I, atom/destination)
	if (!destination || I.loc != get_turf(src) || !factory_movable_item(I))
		return FALSE
	I.forceMove(destination)
	return I.loc == destination

/obj/structure/factory_fabricator/proc/inputs_ready(datum/factory_recipe/R)
	for (var/input_type in R.inputs)
		if (buffered(input_type) < R.inputs[input_type])
			return FALSE
	return TRUE

/obj/structure/factory_fabricator/proc/fab_wake()
	if (!QDELETED(src) && !fab_active)
		fab_active = TRUE
		factory_active_fabricators |= src

/obj/structure/factory_fabricator/proc/fab_sleep()
	fab_active = FALSE
	factory_active_fabricators -= src

/obj/structure/factory_fabricator/proc/fab_stop()
	fab_sleep()
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)
	powered = FALSE

// One powered step of work. A fabricator without inputs leaves the process
// until an insert wakes it.
/obj/structure/factory_fabricator/proc/fab_step()
	var/datum/factory_recipe/R = current_recipe()
	if (!R || !anchored || !isturf(loc))
		fab_status = R ? "unanchored" : "no recipe"
		fab_stop()
		update_icon()
		return
	if (!inputs_ready(R))
		fab_status = "starved"
		fab_stop()
		update_icon()
		return
	var/turf/T = get_turf(src)
	if (factory_loose_items(T) >= FACTORY_FAB_OUTPUT_LIMIT)
		fab_status = "blocked"
		return
	var/was_powered = powered
	powered = draw_cable_power() ? TRUE : FALSE
	if (powered != was_powered)
		update_icon()
	if (!powered)
		fab_status = "no power"
		return
	fab_status = "running"
	progress += FACTORY_FAB_STEP
	if (progress < cycle_time(R))
		return
	progress = 0
	// Inputs are committed only now, together with the output.
	for (var/input_type in R.inputs)
		var/needed = R.inputs[input_type]
		for (var/obj/item/I in contents)
			if (needed <= 0)
				break
			if (!istype(I, input_type))
				continue
			if (istype(I, /obj/item/stack))
				needed -= factory_consume_units(I, needed)
			else
				qdel(I)
				needed--
	if (ispath(R.output_type, /obj/item/stack))
		new R.output_type(T, R.output_amount)
	else
		for (var/i in 1 to R.output_amount)
			new R.output_type(T)
	factory_rate_add(src, "output_rate", R.output_amount)

/proc/factory_fabricators_step()
	for (var/obj/structure/factory_fabricator/F in factory_active_fabricators.Copy())
		if (QDELETED(F))
			factory_active_fabricators -= F
			continue
		F.fab_step()

#undef FACTORY_FAB_BUFFER_CYCLES
#undef FACTORY_FAB_OUTPUT_LIMIT
#undef FACTORY_FAB_STEP
#undef FACTORY_PRINTER_TIER
