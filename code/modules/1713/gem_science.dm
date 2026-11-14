// Practical uses for gemstones, following their real history (reviewed by
// Fable, 2026-11-14). See docs/gemstones.md.
// Included after gemstones.dm and lanyards.dm.

#define JEWEL_DRILL_TIME 60
#define JEWEL_FIT_TIME 40
#define JEWELS_PER_INSTRUMENT 2
#define DIAMOND_GRIT_PER_STONE 3
#define LAP_CHARGES_PER_GRIT 3
#define LAP_MAX_CHARGES 30
#define DRILL_BIT_CHARGES 6

/obj/item
	var/jewelled = FALSE // pivots run in jewel bearings (watches, compasses)

// ---- Jewel bearings (drilled watch jewels, 1704) ----

/obj/item/stack/jewel_bearing
	name = "jewel bearings"
	singular_name = "jewel bearing"
	desc = "Tiny drilled stones that hold the pivots of a watch or compass. They wear far slower than brass. Fit two into a watch or compass."
	icon = 'icons/obj/gem_science.dmi'
	icon_state = "jewel_bearing"
	w_class = ITEM_SIZE_TINY
	max_amount = 50
	amount = 1
	flammable = FALSE
	value = 3

/obj/item/stack/jewel_bearing/garnet
	name = "garnet jewel bearings"
	singular_name = "garnet jewel bearing"
	desc = "Tiny drilled garnets, the cheaper jewels for a watch or compass. Fit two into a watch or compass."
	icon_state = "jewel_bearing_garnet"
	value = 2

/obj/item/stack/gemstone
	var/bearing_type = null // jewel bearings drilled from this stone
	var/bearing_yield = 0

/obj/item/stack/gemstone/ruby
	bearing_type = /obj/item/stack/jewel_bearing
	bearing_yield = 4

/obj/item/stack/gemstone/sapphire
	bearing_type = /obj/item/stack/jewel_bearing
	bearing_yield = 4

/obj/item/stack/gemstone/garnet
	bearing_type = /obj/item/stack/jewel_bearing/garnet
	bearing_yield = 2

/obj/item/stack/gemstone/attackby(obj/item/W, mob/user)
	if (drill_jewel_bearings(W, user))
		return
	..()

// Chisel in the active hand, hammer in the other: drills one cut stone into
// jewel bearings. Returns TRUE when the click was a drilling attempt.
/obj/item/stack/gemstone/proc/drill_jewel_bearings(obj/item/W, mob/user)
	if (!bearing_type || !istype(W, /obj/item/weapon/chisel) || !ishuman(user))
		return FALSE
	var/mob/living/human/H = user
	if (!istype(H.get_inactive_hand(), /obj/item/weapon/hammer))
		to_chat(H, SPAN_WARNING("You need a hammer in your other hand to drill jewel bearings."))
		return TRUE
	if (!H.may_do_after || !crafting_node_allowed_or_warn(H, "optics_instruments"))
		return TRUE
	H.visible_message(SPAN_NOTICE("[H] starts drilling \a [singular_name] into jewel bearings."), SPAN_NOTICE("You start drilling \a [singular_name] into jewel bearings."))
	if (!do_after(H, JEWEL_DRILL_TIME / max(0.5, H.getStatCoeff("dexterity")), src))
		return TRUE
	if (QDELETED(src) || amount < 1 || H.get_active_hand() != W || !(loc == H || (isturf(loc) && get_dist(src, H) <= 1)))
		return TRUE
	var/turf/T = get_turf(src)
	var/made_type = bearing_type
	var/made = bearing_yield
	if (!use(1))
		return TRUE
	H.adaptStat("crafting", 1)
	var/obj/item/stack/jewel_bearing/J = new made_type(T)
	J.amount = made
	J.update_icon()
	to_chat(H, SPAN_NOTICE("You drill [made] [J.name]."))
	return TRUE

// Fits two jewel bearings into a watch or compass.
/proc/fit_jewel_bearings(obj/item/target, obj/item/stack/jewel_bearing/J, mob/living/human/H)
	if (!istype(J) || !istype(H) || !istype(target))
		return FALSE
	if (target.jewelled)
		to_chat(H, SPAN_WARNING("\The [target] is already jewelled."))
		return TRUE
	if (J.amount < JEWELS_PER_INSTRUMENT)
		to_chat(H, SPAN_WARNING("You need [JEWELS_PER_INSTRUMENT] jewel bearings for \the [target]."))
		return TRUE
	if (!H.may_do_after || !crafting_node_allowed_or_warn(H, "optics_instruments"))
		return TRUE
	to_chat(H, SPAN_NOTICE("You open \the [target] and start fitting jewel bearings to its pivots..."))
	if (!do_after(H, JEWEL_FIT_TIME / max(0.5, H.getStatCoeff("dexterity")), target))
		return TRUE
	if (QDELETED(target) || QDELETED(J) || target.jewelled || J.loc != H || J.amount < JEWELS_PER_INSTRUMENT)
		return TRUE
	if (!J.use(JEWELS_PER_INSTRUMENT))
		return TRUE
	target.jewelled = TRUE
	target.value += 6
	if (istype(target, /obj/item/weapon/compass))
		var/obj/item/weapon/compass/C = target
		C.max_offset = min(C.max_offset, 2)
		C.time = min(C.time, 6 SECONDS)
	to_chat(H, SPAN_NOTICE("You fit jewel bearings into \the [target]. It runs smoothly now."))
	return TRUE

/obj/item/weapon/watch/pocket/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/jewel_bearing) && fit_jewel_bearings(src, W, user))
		return
	..()

/obj/item/clothing/gloves/watch/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/jewel_bearing) && fit_jewel_bearings(src, W, user))
		return
	..()

/obj/item/weapon/compass/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/jewel_bearing) && !istype(src, /obj/item/weapon/compass/modern) && fit_jewel_bearings(src, W, user))
		return
	..()

// What a watch shows. A plain movement runs unevenly, so it only gives the
// time to about the quarter hour; a jewelled one keeps time to the minute.
/proc/watch_reading(obj/item/watch)
	var/exact = clock_time()
	if (watch && watch.jewelled)
		return "It is now [exact]."
	var/hr = text2num(copytext(exact, 1, 3))
	var/min = text2num(copytext(exact, 4, 6))
	var/ampm = copytext(exact, 7)
	min = round(min / 15) * 15
	if (min >= 60)
		min = 0
		hr++
		if (hr == 12)
			ampm = (ampm == "AM") ? "PM" : "AM"
		else if (hr > 12)
			hr -= 12
	return "It is about [hr < 10 ? "0[hr]" : "[hr]"]:[min < 10 ? "0[min]" : "[min]"] [ampm]. The movement runs unevenly."

// ---- Diamond grit, the lapping wheel and the diamond drill bit ----

/obj/item/stack/diamond_grit
	name = "diamond grit"
	singular_name = "pinch of diamond grit"
	desc = "Crushed diamond, the hardest abrasive there is. Mixed with oil it charges a lapping wheel for cutting gems."
	icon = 'icons/obj/gem_science.dmi'
	icon_state = "diamond_grit"
	w_class = ITEM_SIZE_TINY
	max_amount = 50
	amount = 1
	flammable = FALSE
	value = 6

// A hammer crushes a rough diamond into grit.
/obj/item/stack/ore/diamond/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/hammer) && ishuman(user))
		var/mob/living/human/H = user
		if (!H.may_do_after || !crafting_node_allowed_or_warn(H, "regalia"))
			return
		to_chat(H, SPAN_NOTICE("You start crushing \a [singular_name] into grit..."))
		if (!do_after(H, 30, src))
			return
		if (QDELETED(src) || amount < 1 || H.get_active_hand() != W || !(loc == H || (isturf(loc) && get_dist(src, H) <= 1)))
			return
		var/turf/T = get_turf(src)
		if (!use(1))
			return
		var/obj/item/stack/diamond_grit/G = new(T)
		G.amount = DIAMOND_GRIT_PER_STONE
		G.update_icon()
		to_chat(H, SPAN_NOTICE("You crush the diamond into [DIAMOND_GRIT_PER_STONE] pinches of grit."))
		return
	..()

// What a cut that splits along a flaw leaves behind, as a phrase for the
// message, or null for nothing useful.
/proc/gem_flaw_leftovers(turf/T, cut_type)
	if (ispath(cut_type, /obj/item/stack/gemstone/diamond))
		new /obj/item/stack/diamond_grit(T)
		return "a pinch of diamond grit"
	return null

// Iron lap for gem cutting (the scaife). Charged with diamond grit, it
// halves cutting time and takes stones down without splitting them.
/obj/structure/lapping_wheel
	name = "lapping wheel"
	desc = "A flat iron disc on a stand, turned by a crank. Charged with diamond grit and oil, it grinds gemstones down without splitting them. Cut stones next to it."
	icon = 'icons/obj/gem_science.dmi'
	icon_state = "lapping_wheel"
	density = TRUE
	anchored = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	var/charges = 0

/obj/structure/lapping_wheel/examine(mob/user)
	..()
	to_chat(user, charges ? "Its face is charged with grit for about [charges] more stone\s." : "Its face is bare. Rub diamond grit into it to charge it.")

/obj/structure/lapping_wheel/proc/use_charge()
	if (charges < 1)
		return FALSE
	charges--
	return TRUE

/obj/structure/lapping_wheel/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/stack/diamond_grit))
		var/obj/item/stack/diamond_grit/G = W
		if (charges >= LAP_MAX_CHARGES)
			to_chat(user, SPAN_NOTICE("\The [src] is fully charged."))
			return
		if (!G.use(1))
			return
		charges = min(LAP_MAX_CHARGES, charges + LAP_CHARGES_PER_GRIT)
		to_chat(user, SPAN_NOTICE("You rub the grit into \the [src] with a little oil."))
		return
	if (istype(W, /obj/item/stack/material/steel) && ishuman(user))
		make_drill_bit(W, user)
		return
	..()

// Grinding diamond-set cutting edges onto a steel crown makes a core bit
// for the industrial drill (rotary diamond drilling, 1863).
/obj/structure/lapping_wheel/proc/make_drill_bit(obj/item/stack/material/steel/S, mob/living/human/H)
	if (!H.may_do_after || !crafting_node_allowed_or_warn(H, "machined_tools"))
		return
	if (charges < DRILL_BIT_CHARGES)
		to_chat(H, SPAN_WARNING("\The [src] needs at least [DRILL_BIT_CHARGES] charges of grit to set a drill crown."))
		return
	to_chat(H, SPAN_NOTICE("You start setting a steel crown with diamond on \the [src]..."))
	if (!do_after(H, 80, src))
		return
	if (QDELETED(S) || charges < DRILL_BIT_CHARGES || S.loc != H || !S.use(1))
		return
	charges -= DRILL_BIT_CHARGES
	new /obj/item/diamond_drill_bit(get_turf(src))
	to_chat(H, SPAN_NOTICE("You finish a diamond drill bit."))

/proc/gem_lap_near(mob/living/human/H)
	for (var/obj/structure/lapping_wheel/L in range(1, H))
		if (L.charges > 0)
			return L
	return null

/obj/item/diamond_drill_bit
	name = "diamond drill bit"
	desc = "A hollow steel crown set with diamond. Fitted to an industrial drill, it cuts rock faster and brings up more ore."
	icon = 'icons/obj/gem_science.dmi'
	icon_state = "diamond_drill_bit"
	w_class = ITEM_SIZE_SMALL
	flags = CONDUCT
	value = 40

/obj/structure/drill
	var/diamond_bit = FALSE

/obj/structure/drill/attackby(obj/item/W, mob/living/human/H)
	if (istype(W, /obj/item/diamond_drill_bit) && type == /obj/structure/drill)
		if (diamond_bit)
			to_chat(H, SPAN_NOTICE("\The [src] already has a diamond bit."))
			return
		H.drop_from_inventory(W)
		qdel(W)
		diamond_bit = TRUE
		to_chat(H, SPAN_NOTICE("You fit the diamond bit to \the [src]."))
		return
	..()

/obj/structure/drill/produce_minerals(var/ore_type, var/quantity)
	if (diamond_bit)
		quantity++
	return ..(ore_type, quantity)

/obj/structure/drill/examine(mob/user)
	..()
	if (diamond_bit)
		to_chat(user, "It is fitted with a diamond drill bit.")

/obj/item/examine(mob/user, var/distance = -1)
	. = ..()
	if (jewelled)
		to_chat(user, "Its movement runs in jewel bearings.")

#undef JEWEL_DRILL_TIME
#undef JEWEL_FIT_TIME
#undef JEWELS_PER_INSTRUMENT
#undef DIAMOND_GRIT_PER_STONE
#undef LAP_CHARGES_PER_GRIT
#undef LAP_MAX_CHARGES
#undef DRILL_BIT_CHARGES
