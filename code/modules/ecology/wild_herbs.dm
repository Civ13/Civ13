// Wild herbs: yarrow, comfrey, elderflower and milk thistle.
//
// Herb patches grow wild on ecology worlds. Pick a few sprigs by hand (help
// intent); a patch regrows one sprig every 20 minutes and has none in winter.
// Yarrow and comfrey are field dressings: yarrow staunches bleeding like a
// bandage, comfrey soothes bruises like a salve. Elderflower and milk thistle
// are tea herbs: hold one and click an open container holding 10 or more
// water to steep it. Elderflower tea eases colds and fever; milk thistle tea
// slowly clears poisons.

#define WILD_HERB_SPRIGS 3
#define WILD_HERB_REGROW 12000 // one sprig per 20 minutes
#define WILD_HERB_SEED_DELAY_FIRES 160 // ticker fires (2 s) after the round starts
#define WILD_HERB_SEED_MAX 120
#define WILD_HERB_SEED_MIN 4
#define WILD_HERB_GRASS_PER_PATCH 1500
#define WILD_HERB_SEED_VIEW_MARGIN 20
#define HERB_STEEP_WATER 10 // water a container needs before any herb is steeped

/////////////////////////////// Herb patches ///////////////////////////////

/obj/structure/wild/flowers/wild_herb
	name = "wild herb"
	desc = "A wild herb."
	icon = 'icons/farming/humanity_wild_herbs.dmi'
	icon_state = "yarrow"
	fixed_flower_appearance = TRUE
	var/sprigs = WILD_HERB_SPRIGS
	var/sprig_type = null
	var/use_hint = ""
	var/tmp/sprig_regrow_pending = FALSE
	var/tmp/sprig_busy = FALSE

var/global/list/wild_herb_list = list()

/obj/structure/wild/flowers/wild_herb/New()
	..()
	wild_herb_list += src
	// Restored patches get their saved sprig count after New; check later.
	schedule_sprig_regrowth()

/obj/structure/wild/flowers/wild_herb/Destroy()
	wild_herb_list -= src
	return ..()

/obj/structure/wild/flowers/wild_herb/get_saved_vars()
	. = ..()
	// Wild objects use an allowlist. Include zero as well as positive stock.
	. |= "sprigs"

/obj/structure/wild/flowers/wild_herb/persistence_runtime_var(key)
	return key == "sprig_regrow_pending" || key == "sprig_busy" || ..()

/obj/structure/wild/flowers/wild_herb/proc/schedule_sprig_regrowth()
	if (sprig_regrow_pending)
		return
	sprig_regrow_pending = TRUE
	addtimer(CALLBACK(src, PROC_REF(regrow_sprig)), WILD_HERB_REGROW)

/obj/structure/wild/flowers/wild_herb/proc/regrow_sprig()
	if (QDELETED(src))
		return
	sprig_regrow_pending = FALSE
	if (!isnum(sprigs) || sprigs < 0)
		sprigs = 0
	if (sprigs < WILD_HERB_SPRIGS)
		sprigs++
	if (sprigs < WILD_HERB_SPRIGS)
		schedule_sprig_regrowth()

/obj/structure/wild/flowers/wild_herb/proc/herb_dormant()
	return season == "WINTER" || radiation >= 15

/obj/structure/wild/flowers/wild_herb/examine(mob/user, distance = -1)
	..()
	if (herb_dormant())
		to_chat(user, SPAN_NOTICE("It has died back for now; there is nothing worth picking."))
	else if (sprigs > 0)
		to_chat(user, SPAN_NOTICE("You could pick a sprig by hand. [use_hint]"))
	else
		to_chat(user, SPAN_NOTICE("It has been picked bare and is growing back."))

/obj/structure/wild/flowers/wild_herb/attack_hand(mob/user)
	if (!user || user.a_intent != I_HELP || !ishuman(user))
		return ..()
	pick_sprig(user)
	return TRUE

/obj/structure/wild/flowers/wild_herb/proc/pick_sprig(mob/user)
	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	if (sprig_busy || QDELETED(src) || !isturf(loc) || !user.Adjacent(src) || user.stat != CONSCIOUS || user.incapacitated())
		return FALSE
	if (herb_dormant())
		to_chat(user, SPAN_NOTICE("\The [src] has died back; there is nothing worth picking."))
		return FALSE
	if (sprigs <= 0)
		to_chat(user, SPAN_NOTICE("\The [src] has been picked bare. Give it time to grow back."))
		return FALSE
	sprig_busy = TRUE
	user.visible_message(SPAN_NOTICE("[user] starts picking \the [src]."), SPAN_NOTICE("You start picking \the [src]."))
	var/completed = do_after(user, 20, src)
	if (QDELETED(src))
		return FALSE
	sprig_busy = FALSE
	if (!completed || QDELETED(user) || !user.Adjacent(src))
		return FALSE
	return finish_pick(user)

// The picking itself, after the wait.
/obj/structure/wild/flowers/wild_herb/proc/finish_pick(mob/user)
	if (QDELETED(src) || !user || sprigs <= 0 || herb_dormant())
		return FALSE
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		to_chat(user, SPAN_WARNING("You cannot pick herbs during persistence operations."))
		return FALSE
	sprigs--
	var/obj/item/stack/medical/wild_herb/S = new sprig_type(get_turf(user), 1)
	user.put_in_hands(S)
	to_chat(user, SPAN_NOTICE("You pick \a [S.singular_name]."))
	schedule_sprig_regrowth()
	return S

/obj/structure/wild/flowers/wild_herb/yarrow
	name = "yarrow"
	desc = "A flowering yarrow plant. Its feathery leaves have long been pressed into wounds to stop bleeding."
	icon_state = "yarrow"
	sprig_type = /obj/item/stack/medical/wild_herb/yarrow
	use_hint = "Pressed into a wound, yarrow slows bleeding."

/obj/structure/wild/flowers/wild_herb/comfrey
	name = "comfrey"
	desc = "A bristly comfrey plant with drooping bell flowers. Its leaves make a soothing poultice."
	icon_state = "comfrey"
	sprig_type = /obj/item/stack/medical/wild_herb/comfrey
	use_hint = "Comfrey leaves soothe bruises as a poultice."

/obj/structure/wild/flowers/wild_herb/elderflower
	name = "elderflower"
	desc = "Clusters of pale elder flowers over broad leaves. They steep into a fragrant tea."
	icon_state = "elderflower"
	sprig_type = /obj/item/stack/medical/wild_herb/elderflower
	use_hint = "Steeped in water, elderflowers make a tea for colds."

/obj/structure/wild/flowers/wild_herb/milk_thistle
	name = "milk thistle"
	desc = "An upright thistle with purple flower heads. Its seed heads steep into a bitter tea."
	icon_state = "milk_thistle"
	sprig_type = /obj/item/stack/medical/wild_herb/milk_thistle
	use_hint = "Steeped in water, milk thistle makes a tea that clears poisons."

/////////////////////////////// Picked herbs ///////////////////////////////

/obj/item/stack/medical/wild_herb
	name = "wild herbs"
	singular_name = "wild herb"
	desc = "A handful of wild herbs."
	icon = 'icons/obj/food/food.dmi'
	icon_state = "yarrow_sprig"
	item_state = null
	amount = 1
	max_amount = 10
	w_class = ITEM_SIZE_TINY
	flammable = TRUE
	value = 1
	var/steep_reagent = null
	var/steep_amount = 10
	var/steep_message = ""

/obj/item/stack/medical/wild_herb/attack(mob/living/M, mob/user)
	if (!treat_flags)
		to_chat(user, SPAN_NOTICE("\The [src] is no use on wounds. [steep_reagent ? "Steep it in water instead." : ""]"))
		return TRUE
	return ..()

// Hold the herb and click an open container with at least 10 water.
/obj/item/stack/medical/wild_herb/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (!steep_reagent || !isobj(A) || !A.reagents || istype(A, /obj/item/weapon/reagent_containers/food/snacks))
		return ..()
	var/obj/vessel = A
	if (!vessel.is_open_container() || !vessel.reagents.has_reagent("water"))
		return ..()
	steep(vessel, user)
	return TRUE

/obj/item/stack/medical/wild_herb/proc/steep(obj/vessel, mob/user)
	if (!steep_reagent || QDELETED(src) || amount < 1)
		return FALSE
	if (!herb_steep_into(singular_name, vessel, user, steep_reagent, steep_amount, steep_message))
		return FALSE
	use(1)
	return TRUE

// Shared by every steepable herb: turns water in an open container held by
// or next to the user into the same amount of tea.
/proc/herb_steep_into(source_name, obj/vessel, mob/user, reagent, amount, message)
	if (!reagent || !user || QDELETED(vessel) || amount <= 0)
		return FALSE
	var/needed = max(HERB_STEEP_WATER, amount)
	if (!vessel.reagents || !vessel.is_open_container() || !vessel.reagents.has_reagent("water", needed) || !(vessel.loc == user || (isturf(vessel.loc) && user.Adjacent(vessel))))
		to_chat(user, SPAN_WARNING("Steep \the [source_name] in an open container holding at least [needed] units of water."))
		return FALSE
	// The tea replaces the water it was brewed in.
	vessel.reagents.remove_reagent("water", amount)
	vessel.reagents.add_reagent(reagent, amount)
	to_chat(user, SPAN_NOTICE("You steep \a [source_name] in \the [vessel]. [message]"))
	return TRUE

/obj/item/stack/medical/wild_herb/yarrow
	name = "yarrow"
	singular_name = "yarrow sprig"
	desc = "Feathery yarrow leaves. Press them into a wound to slow the bleeding."
	icon_state = "yarrow_sprig"
	treat_flags = MED_BANDAGE
	heal_brute = 1
	heals_wounds = TRUE
	treat_verb = "presses yarrow leaves into"
	treat_verb_self = "press yarrow leaves into"

/obj/item/stack/medical/wild_herb/comfrey
	name = "comfrey"
	singular_name = "comfrey leaf"
	desc = "Broad, bristly comfrey leaves. Crushed over a bruise, they soothe it. Not for eating."
	icon_state = "comfrey_sprig"
	treat_flags = MED_SALVE
	heal_brute = 4
	heals_wounds = TRUE
	treat_verb = "spreads crushed comfrey over"
	treat_verb_self = "spread crushed comfrey over"

/obj/item/stack/medical/wild_herb/elderflower
	name = "elderflowers"
	singular_name = "elderflower sprig"
	desc = "A cluster of pale, fragrant elder flowers. Steep them in water for a tea that eases colds."
	icon_state = "elderflower_sprig"
	steep_reagent = "elderflower_tea"
	steep_message = "The water turns a pale gold and smells of summer."

/obj/item/stack/medical/wild_herb/milk_thistle
	name = "milk thistle"
	singular_name = "milk thistle head"
	desc = "A spiny milk thistle head full of seeds. Steep it in water for a bitter tea that clears poisons."
	icon_state = "milk_thistle_sprig"
	steep_reagent = "milk_thistle_tea"
	steep_message = "The water turns a cloudy, bitter green."

/////////////////////////////// Herbal teas ///////////////////////////////

/datum/reagent/drink/elderflower_tea
	name = "Elderflower Tea"
	id = "elderflower_tea"
	description = "A fragrant tea of elder flowers. It eases colds and brings down a fever."
	taste_description = "sweet flowers"
	color = "#E8D98A"
	adj_temp = 10
	metabolism = 0.1

/datum/reagent/drink/elderflower_tea/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	if (M.bodytemperature > 310.7)
		M.bodytemperature = max(310, M.bodytemperature - 0.2)
	if (istype(M, /mob/living/human))
		var/mob/living/human/HH = M
		if (HH.disease == 1 && HH.disease_type == "flu")
			HH.disease_treatment = TRUE

/datum/reagent/drink/milk_thistle_tea
	name = "Milk Thistle Tea"
	id = "milk_thistle_tea"
	description = "A bitter tea of milk thistle seeds. It slowly clears poisons from the body."
	taste_description = "bitter greens"
	color = "#9AA86A"
	adj_temp = 5
	metabolism = 0.05

/datum/reagent/drink/milk_thistle_tea/affect_ingest(var/mob/living/human/M, var/alien, var/removed)
	..()
	M.adjustToxLoss(-6 * removed)

/////////////////////////////// Herb patches in the wild ///////////////////////////////

// Ecology worlds top up wild herb patches once per boot on open natural grass
// (about one per 1500 grass tiles), so saved worlds keep the patches they have.
var/global/wild_herb_seed_state = 0 // 0 waiting, 1 running, 2 done
var/global/wild_herb_seed_wait = 0
var/global/wild_herb_seed_report = ""

/proc/wild_herb_seed_check()
	if (wild_herb_seed_state || !map || !map.ecology_wildlife)
		return
	if (!ticker || ticker.current_state != GAME_STATE_PLAYING)
		return
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
		return
	if (++wild_herb_seed_wait < WILD_HERB_SEED_DELAY_FIRES)
		return
	wild_herb_seed_state = 1
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(wild_herb_seed_run)), 1)

/proc/wild_herb_seed_run()
	wild_herb_seed_patches()
	wild_herb_seed_state = 2

// Herb types that grow in a climate.
/proc/wild_herb_types_for(climate)
	. = list()
	if (!climate)
		return
	for (var/path in subtypesof(/obj/structure/wild/flowers/wild_herb))
		if (climate in wild_herb_climates(path))
			. += path

/proc/wild_herb_climates(path)
	switch (path)
		if (/obj/structure/wild/flowers/wild_herb/yarrow)
			return list("temperate", "taiga", "semiarid")
		if (/obj/structure/wild/flowers/wild_herb/comfrey)
			return list("temperate")
		if (/obj/structure/wild/flowers/wild_herb/elderflower)
			return list("temperate", "taiga")
		if (/obj/structure/wild/flowers/wild_herb/milk_thistle)
			return list("temperate", "semiarid")
	return list()

/proc/wild_herb_site_ok(turf/T)
	if (!T || ecology_ground(T) != ECO_GRASS)
		return FALSE
	if (!wild_herb_types_for(ecology_outdoor_climate(T)).len)
		return FALSE
	return !ecology_site_blocked(T)

// Samples the registered grass turfs instead of walking the world.
/proc/wild_herb_seed_patches(force_visible = FALSE)
	var/herbs = 0
	for (var/obj/structure/wild/flowers/wild_herb/H in wild_herb_list)
		if (!QDELETED(H) && isturf(H.loc))
			herbs++
	var/target = 0
	if (grass_turf_list.len)
		target = clamp(round(grass_turf_list.len / WILD_HERB_GRASS_PER_PATCH), WILD_HERB_SEED_MIN, WILD_HERB_SEED_MAX)
	var/needed = target - herbs
	var/planted = 0
	var/attempts = max(0, needed) * 25
	while (needed > 0 && attempts-- > 0 && grass_turf_list.len)
		CHECK_TICK
		if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required)
			break
		var/turf/site = pick(grass_turf_list)
		if (!wild_herb_site_ok(site))
			continue
		if (!force_visible && ecology_visible_to_players(site, WILD_HERB_SEED_VIEW_MARGIN))
			continue
		var/path = pick(wild_herb_types_for(ecology_outdoor_climate(site)))
		new path(site)
		planted++
		needed--
	wild_herb_seed_report = "[herbs] existing, [planted] new, target [target]"
	log_game("Wild herbs: [wild_herb_seed_report].")
	return planted

#undef WILD_HERB_SPRIGS
#undef WILD_HERB_REGROW
#undef WILD_HERB_SEED_DELAY_FIRES
#undef WILD_HERB_SEED_MAX
#undef WILD_HERB_SEED_MIN
#undef WILD_HERB_GRASS_PER_PATCH
#undef WILD_HERB_SEED_VIEW_MARGIN
