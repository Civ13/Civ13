// Butter: churning, salted butter, buttered bread and potting under fat.
//
// Butter churn: 3 soft wood. Pour in milk (or cream), put the lid on, then
// Alt-click it (or use Churn Butter) and work the dasher. Every 30 milk gives
// a pat of butter and leaves 20 buttermilk; every 15 cream gives a pat and 5
// buttermilk. With table salt in the churn, 1 salt per pat makes salted butter.
//
// Butter goes rancid in about an hour on the ground. Salted butter (churned
// with salt, or a pat salted afterwards like meat) keeps four times as long.
// A pat spreads two slices of buttered bread.
//
// Potting: pack cooked meat or fish into an open clay crock (preserves.dm),
// press butter over it or pour in lard (5 for each piece), and close the lid.
// After 3 working spells the food is potted. Potted food ages six times more
// slowly while it sits in a closed crock; taken out, it spoils as usual.

#define CHURN_TIME 200
#define CHURN_MILK 30
#define CHURN_MILK_BUTTERMILK 20
#define CHURN_CREAM 15
#define CHURN_CREAM_BUTTERMILK 5
#define BUTTER_PER_PAT 10
#define BUTTER_PER_SPREAD 5
#define BUTTER_SALT 1
#define SALTED_BUTTER_KEEPING 4
#define POT_FAT_PER_FOOD 5
#define CROCK_POT_STEPS 3
#define POTTED_DECAY_STEP 50

/obj/item/weapon/reagent_containers/food/snacks/var/potted = FALSE // sealed under fat in a crock

/////////////////////////////// Churn ///////////////////////////////

/obj/item/weapon/reagent_containers/glass/butter_churn
	name = "butter churn"
	desc = "A tall staved wooden churn with a plunging dasher. Pour in milk or cream, put the lid on and churn it into butter."
	icon = 'icons/obj/food/butter.dmi'
	icon_state = "butter_churn"
	item_state = null
	volume = 60
	amount_per_transfer_from_this = 10
	possible_transfer_amounts = list(5,10,20,30,60)
	w_class = ITEM_SIZE_LARGE
	dropsound = 'sound/effects/drop_default.ogg'
	value = 3

/obj/item/weapon/reagent_containers/glass/butter_churn/after_load()
	..()
	update_icon()

/obj/item/weapon/reagent_containers/glass/butter_churn/update_icon()
	overlays.Cut()
	icon_state = is_open_container() ? "butter_churn" : "butter_churn_closed"

/obj/item/weapon/reagent_containers/glass/butter_churn/examine(mob/user, distance = -1)
	..()
	if (is_open_container())
		to_chat(user, SPAN_NOTICE("Pour in at least [CHURN_MILK] milk or [CHURN_CREAM] cream, then put the lid on to churn."))
	else if (churn_batches())
		to_chat(user, SPAN_NOTICE("Alt-click it to churn the butter."))

/obj/item/weapon/reagent_containers/glass/butter_churn/AltClick(mob/user)
	if (!user || !Adjacent(user) || user.incapacitated())
		return ..()
	churn(user)

/obj/item/weapon/reagent_containers/glass/butter_churn/verb/churn_butter()
	set name = "Churn Butter"
	set category = null
	set src in view(1)
	churn(usr)

// How many pats the churn holds the makings of: list(milk batches, cream batches).
/obj/item/weapon/reagent_containers/glass/butter_churn/proc/churn_batch_counts()
	if (!reagents)
		return list(0, 0)
	return list(round(reagents.get_reagent_amount("milk") / CHURN_MILK), round(reagents.get_reagent_amount("cream") / CHURN_CREAM))

/obj/item/weapon/reagent_containers/glass/butter_churn/proc/churn_batches()
	var/list/counts = churn_batch_counts()
	return counts[1] + counts[2]

// The wait, as a proc so a test fixture can stand in for do_after.
/obj/item/weapon/reagent_containers/glass/butter_churn/proc/churn_wait(mob/user)
	return do_after(user, CHURN_TIME, src)

/obj/item/weapon/reagent_containers/glass/butter_churn/proc/churn(mob/user)
	if (!user || user.incapacitated() || !Adjacent(user))
		return FALSE
	if (is_open_container())
		to_chat(user, SPAN_WARNING("Put the lid on \the [src] first, or it will splash everywhere."))
		return FALSE
	if (!churn_batches())
		to_chat(user, SPAN_WARNING("\The [src] needs at least [CHURN_MILK] milk or [CHURN_CREAM] cream to churn."))
		return FALSE
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		to_chat(user, SPAN_WARNING("You cannot do that during persistence operations."))
		return FALSE
	user.visible_message(SPAN_NOTICE("[user] works the dasher of \the [src] up and down."), SPAN_NOTICE("You start churning."))
	if (!churn_wait(user))
		to_chat(user, SPAN_WARNING("You stop churning before the butter comes."))
		return FALSE
	if (QDELETED(src) || is_open_container())
		return FALSE
	return churn_finish(user)

// Turns every full batch in the churn into butter. Returns the pats made.
/obj/item/weapon/reagent_containers/glass/butter_churn/proc/churn_finish(mob/user)
	var/list/counts = churn_batch_counts()
	var/pats = counts[1] + counts[2]
	if (!pats)
		return list()
	reagents.remove_reagent("milk", counts[1] * CHURN_MILK)
	reagents.remove_reagent("cream", counts[2] * CHURN_CREAM)
	reagents.add_reagent("buttermilk", counts[1] * CHURN_MILK_BUTTERMILK + counts[2] * CHURN_CREAM_BUTTERMILK)
	var/turf/T = get_turf(src)
	. = list()
	var/salted = 0
	for (var/i = 1, i <= pats, i++)
		var/obj/item/weapon/reagent_containers/food/snacks/butter/B
		if (reagents.get_reagent_amount("sodiumchloride") >= BUTTER_SALT)
			reagents.remove_reagent("sodiumchloride", BUTTER_SALT)
			B = new /obj/item/weapon/reagent_containers/food/snacks/butter/salted(T)
			salted++
		else
			B = new /obj/item/weapon/reagent_containers/food/snacks/butter(T)
		. += B
	if (user)
		to_chat(user, SPAN_NOTICE("The butter gathers. You lift out [pats == 1 ? "a pat" : "[pats] pats"] of [salted == pats ? "salted " : ""]butter[salted && salted < pats ? ", [salted] of them salted" : ""], leaving the buttermilk."))

/////////////////////////////// Butter ///////////////////////////////

/obj/item/weapon/reagent_containers/food/snacks/butter
	name = "butter"
	desc = "A pat of fresh butter churned from milk. Spread it on bread, or press it over cooked food in a crock to seal it."
	icon = 'icons/obj/food/butter.dmi'
	icon_state = "butter"
	rotten_icon_state = "butter_rancid"
	rots = TRUE
	filling_color = "#F4E28A"
	center_of_mass = list("x"=16, "y"=16)
	nutriment_amt = 0
	bitesize = 2
	decay = 60*600
	satisfaction = 1
	value = 3

/obj/item/weapon/reagent_containers/food/snacks/butter/New()
	..()
	reagents.add_reagent("butter", BUTTER_PER_PAT)

/obj/item/weapon/reagent_containers/food/snacks/butter/rot()
	if (rotten || !rots)
		return
	..()
	name = salted_meat ? "rancid salted butter" : "rancid butter"
	desc = "Butter gone sour and rancid. Nobody should eat this."

/obj/item/weapon/reagent_containers/food/snacks/butter/salted
	name = "salted butter"
	desc = "A pat of butter worked with salt. It keeps far longer than fresh butter. Spread it on bread, or press it over cooked food in a crock to seal it."
	icon_state = "butter_salted"
	salted_meat = TRUE
	decay = 60*600*SALTED_BUTTER_KEEPING

// Salt from a shaker or salt pile works into a pat just as it preserves meat
// (condiment.dm calls can_salt_meat and salt_meat).
/obj/item/weapon/reagent_containers/food/snacks/butter/can_salt_meat()
	return TRUE

/obj/item/weapon/reagent_containers/food/snacks/butter/mark_salted_meat()
	salted_meat = TRUE
	decay *= SALTED_BUTTER_KEEPING
	decaytimer *= SALTED_BUTTER_KEEPING
	name = "salted butter"
	icon_state = "butter_salted"

/obj/item/weapon/reagent_containers/food/snacks/butter/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (istype(A, /obj/item/weapon/reagent_containers/food/snacks/breadslice) && user && user.Adjacent(A))
		spread_butter(A, user)
		return TRUE
	return ..()

/obj/item/weapon/reagent_containers/food/snacks/butter/proc/spread_butter(obj/item/weapon/reagent_containers/food/snacks/breadslice/S, mob/user)
	if (rotten)
		to_chat(user, SPAN_WARNING("\The [src] is rancid."))
		return FALSE
	if (!reagents || reagents.get_reagent_amount("butter") < 1)
		to_chat(user, SPAN_WARNING("There is not enough butter left."))
		return FALSE
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		to_chat(user, SPAN_WARNING("You cannot do that during persistence operations."))
		return FALSE
	var/turf/T = get_turf(S)
	var/held = (S.loc == user)
	var/obj/item/weapon/reagent_containers/food/snacks/buttered_bread/BB = new(T)
	S.transfer_reagents_to_spread(BB.reagents, BUTTER_PER_SPREAD)
	var/spread = min(BUTTER_PER_SPREAD, reagents.get_reagent_amount("butter"))
	reagents.remove_reagent("butter", spread)
	BB.reagents.add_reagent("butter", spread)
	qdel(S)
	if (held)
		user.put_in_hands(BB)
	to_chat(user, SPAN_NOTICE("You spread butter on the bread."))
	if (reagents.get_reagent_amount("butter") < 1)
		qdel(src)
	return BB

/obj/item/weapon/reagent_containers/food/snacks/buttered_bread
	name = "buttered bread"
	desc = "A slice of bread spread thick with butter."
	icon = 'icons/obj/food/butter.dmi'
	icon_state = "buttered_bread"
	filling_color = "#F4E28A"
	center_of_mass = list("x"=16, "y"=8)
	nutriment_amt = 0
	decay = 15*600
	satisfaction = 4

/////////////////////////////// Potting ///////////////////////////////

// Fats that seal potted food, in the order they are used up.
/proc/crock_sealing_fats()
	return list("butter", "lard")

/proc/crock_can_pot(obj/item/weapon/reagent_containers/food/snacks/S)
	if (!istype(S) || istype(S, /obj/item/weapon/reagent_containers/food/snacks/grown) || istype(S, /obj/item/weapon/reagent_containers/food/snacks/butter))
		return FALSE
	if (S.potted || S.raw || S.rotten || S.decay <= 0 || S.decaytimer >= S.decay)
		return FALSE
	if (S.rots && S.decaytimer >= S.decay / 2)
		return FALSE
	if (!S.reagents || S.reagents.get_reagent_amount("protein") <= 0)
		return FALSE
	return TRUE

/proc/pot_food(obj/item/weapon/reagent_containers/food/snacks/S)
	S.potted = TRUE
	S.name = "potted [S.name]"
	S.desc = "[S.desc] It is sealed under fat, and keeps far longer while its crock stays closed."
	S.satisfaction = max(S.satisfaction, 3)

/obj/item/weapon/reagent_containers/glass/crock/var/pot_progress = 0

/obj/item/weapon/reagent_containers/glass/crock/proc/unpotted_food()
	. = list()
	for (var/obj/item/weapon/reagent_containers/food/snacks/S in contents)
		if (crock_can_pot(S))
			. += S

/obj/item/weapon/reagent_containers/glass/crock/proc/crock_fat_amount()
	. = 0
	for (var/id in crock_sealing_fats())
		. += reagents.get_reagent_amount(id)

/obj/item/weapon/reagent_containers/glass/crock/proc/has_seal_for(count)
	return count > 0 && reagents && crock_fat_amount() >= POT_FAT_PER_FOOD * count

/obj/item/weapon/reagent_containers/glass/crock/proc/use_sealing_fat(amount)
	for (var/id in crock_sealing_fats())
		var/used = min(amount, reagents.get_reagent_amount(id))
		if (used > 0)
			reagents.remove_reagent(id, used)
			amount -= used
		if (amount <= 0)
			return

// One working spell of potting (crock_work in preserves.dm). TRUE if it changed anything.
/obj/item/weapon/reagent_containers/glass/crock/proc/crock_pot_work()
	var/list/food = unpotted_food()
	if (!has_seal_for(food.len))
		return FALSE
	pot_progress++
	if (pot_progress >= CROCK_POT_STEPS)
		pot_progress = 0
		use_sealing_fat(POT_FAT_PER_FOOD * food.len)
		for (var/obj/item/weapon/reagent_containers/food/snacks/S in food)
			pot_food(S)
	return TRUE

// Pressing a pat of butter into an open crock melts it in as sealing fat.
/obj/item/weapon/reagent_containers/glass/crock/proc/press_butter(obj/item/weapon/reagent_containers/food/snacks/butter/B, mob/user)
	if (!is_open_container())
		to_chat(user, SPAN_WARNING("Take the lid off \the [src] first."))
		return FALSE
	if (B.rotten)
		to_chat(user, SPAN_WARNING("\The [B] is rancid; it would spoil everything it touched."))
		return FALSE
	if (reagents.get_free_space() < B.reagents.get_reagent_amount("butter"))
		to_chat(user, SPAN_WARNING("\The [src] is too full."))
		return FALSE
	B.reagents.trans_id_to(src, "butter", B.reagents.get_reagent_amount("butter"))
	if (user)
		user.remove_from_mob(B)
	qdel(B)
	to_chat(user, SPAN_NOTICE("You press the butter down into \the [src]."))
	return TRUE

// Food inside a crock ages like stored food, but potted food in a closed crock barely ages (food.dm).
/proc/crock_food_decay_step(obj/item/weapon/reagent_containers/food/F, obj/item/weapon/reagent_containers/glass/crock/C)
	var/obj/item/weapon/reagent_containers/food/snacks/S = F
	if (istype(S) && S.potted && !C.is_open_container())
		return POTTED_DECAY_STEP
	return 300

/////////////////////////////// Reagents ///////////////////////////////

/datum/reagent/nutriment/butter
	name = "Butter"
	id = "butter"
	description = "The fat of milk, churned until it gathers. Rich, and good for sealing food from the air."
	taste_description = "rich butter"
	nutriment_factor = 15
	reagent_state = SOLID
	color = "#F4E28A"

/datum/reagent/drink/milk/buttermilk
	name = "Buttermilk"
	id = "buttermilk"
	description = "The thin, tangy milk left in the churn once the butter has come."
	taste_description = "tangy milk"
	color = "#EDEBDC"

#undef CHURN_TIME
#undef CHURN_MILK
#undef CHURN_MILK_BUTTERMILK
#undef CHURN_CREAM
#undef CHURN_CREAM_BUTTERMILK
#undef BUTTER_PER_PAT
#undef BUTTER_PER_SPREAD
#undef BUTTER_SALT
#undef SALTED_BUTTER_KEEPING
#undef POT_FAT_PER_FOOD
#undef CROCK_POT_STEPS
#undef POTTED_DECAY_STEP
