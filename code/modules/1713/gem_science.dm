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
#define CRYSTAL_SET_WIRE 10

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
	if (!bearing_type || !is_tool(W, TOOL_CHISEL) || !ishuman(user))
		return FALSE
	var/mob/living/human/H = user
	if (!is_tool(H.get_inactive_hand(), TOOL_HAMMER))
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
	if (istype(W, /obj/item/stack/jewel_bearing) && !quartz_movement && fit_jewel_bearings(src, W, user))
		return
	if (istype(W, /obj/item/quartz_crystal_unit) && ishuman(user))
		fit_quartz(W, user)
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
	if (watch && (watch.jewelled || watch.quartz_movement))
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
	if (is_tool(W, TOOL_HAMMER) && ishuman(user))
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

// ---- Quartz, galena and the crystal set ----

/obj/item/stack/ore/gem/quartz
	name = "rough quartz"
	singular_name = "rough quartz"
	desc = "A cloudy six-sided crystal in a scrap of rock. A chisel and a hammer would clear it."
	icon = 'icons/obj/gem_science.dmi'
	icon_state = "quartz_uncut"
	value = 2
	cut_type = /obj/item/stack/gemstone/quartz

/obj/item/stack/gemstone/quartz
	name = "quartz crystals"
	singular_name = "quartz crystal"
	desc = "A clear, cut rock crystal. Set it into clothing as a stone, or with a sheet of tin in your other hand use it to mount it as a radio crystal."
	icon = 'icons/obj/gem_science.dmi'
	icon_state = "quartz"
	gem_colour = "#e8eef2"
	value = 6

// Cut quartz in the active hand, tin sheet in the other: a crystal unit
// for frequency control (quartz oscillators, 1920s).
/obj/item/stack/gemstone/quartz/attack_self(mob/user)
	var/mob/living/human/H = user
	if (!istype(H) || !istype(H.get_inactive_hand(), /obj/item/stack/material/tin))
		return ..()
	var/obj/item/stack/material/tin/T = H.get_inactive_hand()
	if (!H.may_do_after || !crafting_node_allowed_or_warn(H, "assembly_line"))
		return
	to_chat(H, SPAN_NOTICE("You start grinding \a [singular_name] to a thin plate and sealing it in a tin case..."))
	if (!do_after(H, 60, src))
		return
	if (QDELETED(src) || QDELETED(T) || amount < 1 || T.loc != H || loc != H || !use(1) || !T.use(1))
		return
	H.put_in_hands(new /obj/item/quartz_crystal_unit(get_turf(H)))
	to_chat(H, SPAN_NOTICE("You make a quartz crystal unit."))

/obj/item/quartz_crystal_unit
	name = "quartz crystal unit"
	desc = "A thin quartz plate sealed in a tin case with two pins. Fit it into a radio to hold a second frequency it always listens to, or into a wrist watch to make it keep perfect time."
	icon = 'icons/obj/gem_science.dmi'
	icon_state = "quartz_crystal_unit"
	w_class = ITEM_SIZE_TINY
	flags = CONDUCT
	value = 12

/obj/item/weapon/radio
	var/crystal_freq = 0 // second frequency held by a quartz crystal unit

/obj/item/weapon/radio/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/quartz_crystal_unit) && ishuman(user) && transmitter)
		var/mob/living/human/H = user
		if (crystal_freq)
			to_chat(H, SPAN_NOTICE("\The [src] already holds a crystal for [crystal_freq]kHz."))
			return
		if (!crafting_node_allowed_or_warn(H, "assembly_line"))
			return
		var/input = player_input(H, "Which frequency should the crystal hold? (150-300 kHz)", null, null, "num", null, FALSE)
		if (!input || QDELETED(W) || W.loc != H || !H.Adjacent(src))
			return
		crystal_freq = sanitize_integer(input, min = 150, max = 300, default = 150)
		H.drop_from_inventory(W)
		qdel(W)
		to_chat(H, SPAN_NOTICE("You fit the crystal. \The [src] now also listens on [crystal_freq]kHz."))
		return
	..()

// A crystal unit in a receiving radio also holds it to its second frequency.
/obj/item/weapon/radio/check_freq(var/obj/original)
	return ..() || radio_crystal_matches(original, freq, multifreq, multifreqlist)

/obj/structure/radio/check_freq(var/obj/original)
	return ..() || radio_crystal_matches(original, freq, multifreq, multifreqlist)

/proc/radio_crystal_matches(obj/original, source_freq, source_multifreq, list/source_multifreqlist)
	var/obj/item/weapon/radio/R = original
	if (!istype(R) || !R.crystal_freq)
		return FALSE
	if (source_multifreq)
		return (R.crystal_freq in source_multifreqlist)
	return R.crystal_freq == source_freq

/obj/item/weapon/radio/examine(mob/user)
	..()
	if (crystal_freq)
		to_chat(user, "A quartz crystal holds it to [crystal_freq]kHz as well.")

/obj/item
	var/quartz_movement = FALSE // a quartz oscillator keeps its time (1969)

/obj/item/clothing/gloves/watch/proc/fit_quartz(obj/item/quartz_crystal_unit/Q, mob/living/human/H)
	if (quartz_movement)
		to_chat(H, SPAN_NOTICE("\The [src] already keeps quartz time."))
		return
	if (!H.may_do_after || !crafting_node_allowed_or_warn(H, "digital_computing"))
		return
	to_chat(H, SPAN_NOTICE("You open \the [src] and replace its movement with the quartz crystal..."))
	if (!do_after(H, 40, src))
		return
	if (QDELETED(Q) || Q.loc != H || quartz_movement)
		return
	H.drop_from_inventory(Q)
	qdel(Q)
	quartz_movement = TRUE
	name = "quartz watch"
	desc = "A wrist watch kept to time by a quartz crystal."
	icon = 'icons/obj/gem_science.dmi'
	icon_state = "quartz_watch"
	value += 10
	update_clothing_icon()
	to_chat(H, SPAN_NOTICE("\The [src] now keeps quartz time."))

// Galena (lead ore) gives the detector crystal of a crystal set (1900s).
/obj/item/stack/ore/lead/attackby(obj/item/W, mob/user)
	if (is_tool(W, TOOL_CHISEL) && ishuman(user))
		var/mob/living/human/H = user
		if (!is_tool(H.get_inactive_hand(), TOOL_HAMMER))
			to_chat(H, SPAN_WARNING("You need a hammer in your other hand to split out a crystal."))
			return
		if (!H.may_do_after || !crafting_node_allowed_or_warn(H, "electricity"))
			return
		to_chat(H, SPAN_NOTICE("You start splitting a clean crystal of galena from the ore..."))
		if (!do_after(H, 30, src))
			return
		if (QDELETED(src) || amount < 1 || H.get_active_hand() != W || !(loc == H || (isturf(loc) && get_dist(src, H) <= 1)))
			return
		var/turf/T = get_turf(src)
		if (!use(1))
			return
		new /obj/item/galena_crystal(T)
		to_chat(H, SPAN_NOTICE("You split out a bright crystal of galena."))
		return
	..()

/obj/item/galena_crystal
	name = "galena crystal"
	desc = "A bright cube of lead ore. With some copper wire held in your other hand, use it to make a crystal radio set."
	icon = 'icons/obj/gem_science.dmi'
	icon_state = "galena"
	w_class = ITEM_SIZE_TINY
	value = 2

/obj/item/galena_crystal/attack_self(mob/user)
	var/mob/living/human/H = user
	if (!istype(H))
		return
	var/obj/item/stack/cable_coil/C = H.get_inactive_hand()
	if (!istype(C) || C.amount < CRYSTAL_SET_WIRE)
		to_chat(H, SPAN_WARNING("Hold at least [CRYSTAL_SET_WIRE] lengths of cable in your other hand to wind the coil."))
		return
	if (!H.may_do_after || !crafting_node_allowed_or_warn(H, "electricity"))
		return
	to_chat(H, SPAN_NOTICE("You start winding a coil and mounting the crystal on a board..."))
	if (!do_after(H, 60, src))
		return
	if (QDELETED(src) || QDELETED(C) || C.loc != H || loc != H || !C.use(CRYSTAL_SET_WIRE))
		return
	H.drop_from_inventory(src)
	H.put_in_hands(new /obj/item/weapon/radio/crystal_set(get_turf(H)))
	to_chat(H, SPAN_NOTICE("You make a crystal radio set."))
	qdel(src)

// Receive-only set that needs no power: one earphone, for its holder.
/obj/item/weapon/radio/crystal_set
	name = "crystal radio set"
	desc = "A coil, a galena crystal touched by a fine wire and an earphone, on a small board. It needs no power, but it can only listen."
	icon = 'icons/obj/gem_science.dmi'
	icon_state = "crystal_radio"
	item_state = "portable_radio"
	transmitter = FALSE
	transmitter_on = FALSE
	w_class = ITEM_SIZE_SMALL
	slot_flags = SLOT_BELT
	force = 1
	throwforce = 1
	value = 8

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
#undef CRYSTAL_SET_WIRE
