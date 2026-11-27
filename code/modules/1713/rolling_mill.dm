// Rolling mill: hot metal squeezed between two iron rolls into long stock.
//
// The mill makes the same rails and armour plate a smith makes by hand, from
// less metal and in less time. Its rolls are far too heavy to turn by hand:
// it only works while a prime mover turns next to it (mechanical_power.dm),
// and a faster mover rolls faster. Nothing is stored and nothing ticks.

// What is rolled: label -> list(stock type, units in, product type, amount out, deciseconds).
// By hand a unit of iron makes one pair of rails in 5 seconds and a hull
// armour plate takes 15 steel and 15 seconds.
var/global/list/rolling_mill_products = list(
	"rails from iron" = list(/obj/item/stack/material/iron, 1, /obj/item/stack/rail_lengths, 2, 50),
	"rails from steel" = list(/obj/item/stack/material/steel, 1, /obj/item/stack/rail_lengths, 3, 50),
	"hull armour plate" = list(/obj/item/stack/material/steel, 10, /obj/item/hull_plate, 1, 200),
)

// The stock a stack counts as at the mill. Preset-count stacks (mapped or
// job-issued) are ordinary iron and steel; special steel grades stay distinct.
/proc/rolling_mill_stock_type(obj/item/I)
	if (!I)
		return null
	switch (I.type)
		if (/obj/item/stack/material/iron/twentyfive)
			return /obj/item/stack/material/iron
		if (/obj/item/stack/material/steel/twentyfive)
			return /obj/item/stack/material/steel
	return I.type

/obj/structure/workshop_machine/rolling_mill
	name = "rolling mill"
	desc = "Two heavy iron rolls in a pair of housings. Fasten it next to a turning treadwheel, horse gin, mill wheel or windmill, then use iron or steel on it to roll rails, or steel to roll hull armour plate, from less metal than forging them takes. It keeps rolling until the metal runs out or you step away."
	icon = 'icons/obj/rolling_mill.dmi'
	icon_state = "rolling_mill"

// TRUE while a prime mover next to the fastened mill is turning its rolls.
/obj/structure/workshop_machine/rolling_mill/proc/rolling()
	return anchored && isturf(loc) && mechanical_drive_factor(src) < 1

/obj/structure/workshop_machine/rolling_mill/examine(mob/user, distance)
	..(user, distance)
	if (!anchored)
		to_chat(user, SPAN_WARNING("It is not fastened down."))
	else if (rolling())
		to_chat(user, SPAN_NOTICE("Its rolls are turning."))
	else
		to_chat(user, SPAN_WARNING("Nothing is turning its rolls. It needs a turning prime mover next to it."))

// What this worker may roll from this stock: list(label, ...).
/obj/structure/workshop_machine/rolling_mill/proc/roll_choices(mob/living/human/H, obj/item/stack/S)
	var/list/choices = list()
	for (var/label in rolling_mill_products)
		var/list/row = rolling_mill_products[label]
		if (rolling_mill_stock_type(S) == row[1] && crafting_recipe_allowed(H, "[row[3]]"))
			choices += label
	return choices

/obj/structure/workshop_machine/rolling_mill/proc/takes(obj/item/I)
	if (!I)
		return FALSE
	for (var/label in rolling_mill_products)
		var/list/row = rolling_mill_products[label]
		if (rolling_mill_stock_type(I) == row[1])
			return TRUE
	return FALSE

/obj/structure/workshop_machine/rolling_mill/attack_hand(mob/living/human/H)
	if (istype(H))
		examine(H, 1)

/obj/structure/workshop_machine/rolling_mill/attackby(obj/item/I, mob/living/human/H)
	if (!istype(H))
		return
	if (handle_machine_tool(I, H))
		return
	if (!takes(I))
		return ..()
	if (!can_start_material_work(H))
		return
	if (!rolling())
		to_chat(H, SPAN_WARNING("Nothing is turning \the [src]'s rolls. It needs a turning prime mover next to it."))
		return
	if (!crafting_recipe_allowed(H, "[type]"))
		return
	var/list/choices = roll_choices(H, I)
	if (!length(choices))
		to_chat(H, SPAN_WARNING("You do not know how to roll anything from that yet."))
		return
	var/choice = length(choices) == 1 ? choices[1] : player_input(H, "What should \the [src] roll?", "Rolling mill", null, "anything", choices, TRUE)
	if (!choice || !(choice in choices))
		return
	roll_stock(H, I, choice)

// Roll the stack in hand into product on the mill's tile. Returns the pieces made.
/obj/structure/workshop_machine/rolling_mill/proc/roll_stock(mob/living/human/H, obj/item/stack/S, label)
	var/list/row = rolling_mill_products[label]
	if (busy || !row || !worker_ready(H, S) || rolling_mill_stock_type(S) != row[1] || !rolling())
		return 0
	if (S.amount < row[2])
		to_chat(H, SPAN_WARNING("You need [row[2]] of \the [S] for that."))
		return 0
	busy = TRUE
	icon_state = "rolling_mill_on"
	visible_message(SPAN_NOTICE("[H] feeds a glowing bar into \the [src]."))
	var/made = 0
	var/product_type = row[3]
	var/obj/item/stack/pile = null
	while (worker_ready(H, S) && S.amount >= row[2] && rolling())
		if (!do_after(H, driven_time(row[5]), src))
			break
		if (!worker_ready(H, S) || S.amount < row[2] || !rolling() || !crafting_recipe_allowed(H, "[product_type]"))
			break
		var/last = S.amount <= row[2]
		S.use(row[2])
		if (ispath(product_type, /obj/item/stack))
			var/left = row[4]
			while (left > 0)
				if (QDELETED(pile) || pile.loc != get_turf(src) || pile.amount >= pile.max_amount)
					pile = new product_type(get_turf(src))
					pile.amount = 0
				var/put = min(left, pile.max_amount - pile.amount)
				pile.amount += put
				left -= put
				pile.update_icon()
		else
			for (var/i = 1 to row[4])
				new product_type(get_turf(src))
		made += row[4]
		if (last)
			break
	busy = FALSE
	if (!QDELETED(src))
		icon_state = "rolling_mill"
	if (made)
		to_chat(H, SPAN_NOTICE("You roll [made] [label == "hull armour plate" ? "armour plates" : "pairs of rails"]."))
	return made
