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
#define READING_STONE_LIGHT 0.5
#define GARNET_PAPER_SHEETS 4
#define BOULE_EMERY 4
#define BOULE_BEARINGS 10
#define ROD_CHARGES 2

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
	if (ispath(cut_type, /obj/item/stack/gemstone/ruby) || ispath(cut_type, /obj/item/stack/gemstone/sapphire))
		new /obj/item/stack/emery_powder(T)
		return "a pinch of emery"
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
	var/charges = 0 // diamond grit, for any stone
	var/emery_charges = 0 // emery, for stones softer than corundum

/obj/structure/lapping_wheel/examine(mob/user)
	..()
	if (!charges && !emery_charges)
		to_chat(user, "Its face is bare. Rub diamond grit or emery into it to charge it.")
		return
	if (charges)
		to_chat(user, "It is charged with diamond grit for about [charges] more stone\s.")
	if (emery_charges)
		to_chat(user, "It is charged with emery for about [emery_charges] more soft stone\s.")

// Emery (impure corundum) cuts only stones softer than itself; diamond cuts all.
/proc/gem_needs_diamond(cut_type)
	return ispath(cut_type, /obj/item/stack/gemstone/diamond) || ispath(cut_type, /obj/item/stack/gemstone/ruby) || ispath(cut_type, /obj/item/stack/gemstone/sapphire)

/obj/structure/lapping_wheel/proc/can_cut(cut_type)
	return charges > 0 || (emery_charges > 0 && !gem_needs_diamond(cut_type))

/obj/structure/lapping_wheel/proc/use_charge(cut_type)
	if (emery_charges > 0 && !gem_needs_diamond(cut_type))
		emery_charges--
		return TRUE
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
	if (istype(W, /obj/item/stack/emery_powder))
		var/obj/item/stack/emery_powder/E = W
		if (emery_charges >= LAP_MAX_CHARGES)
			to_chat(user, SPAN_NOTICE("\The [src] is fully charged with emery."))
			return
		if (!E.use(1))
			return
		emery_charges = min(LAP_MAX_CHARGES, emery_charges + LAP_CHARGES_PER_GRIT)
		to_chat(user, SPAN_NOTICE("You rub the emery into \the [src] with a little oil."))
		return
	if (istype(W, /obj/item/stack/material/steel) && ishuman(user))
		make_drill_bit(W, user)
		return
	if (istype(W, /obj/item/ruby_boule) && ishuman(user))
		make_ruby_rod(W, user)
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

/proc/gem_lap_near(mob/living/human/H, cut_type)
	for (var/obj/structure/lapping_wheel/L in range(1, H))
		if (L.can_cut(cut_type))
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
	desc = "A clear, cut rock crystal. Set it into clothing as a stone, use it with a sheet of tin in your other hand to make a radio crystal, or shape it with a chisel and hammer into a reading stone."
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

// ---- Reading stones, emery and garnet paper ----

// Cut quartz polished into a reading stone (Visby lenses, 11th-12th c.).
/obj/item/stack/gemstone/quartz/attackby(obj/item/W, mob/user)
	if (is_tool(W, TOOL_CHISEL) && ishuman(user))
		var/mob/living/human/H = user
		if (!is_tool(H.get_inactive_hand(), TOOL_HAMMER))
			to_chat(H, SPAN_WARNING("You need a hammer in your other hand to shape a reading stone."))
			return
		if (!H.may_do_after || !crafting_node_allowed_or_warn(H, "glassworking"))
			return
		to_chat(H, SPAN_NOTICE("You start grinding \a [singular_name] into a reading stone..."))
		if (!do_after(H, 60, src))
			return
		if (QDELETED(src) || amount < 1 || H.get_active_hand() != W || !(loc == H || (isturf(loc) && get_dist(src, H) <= 1)))
			return
		var/turf/T = get_turf(src)
		if (!use(1))
			return
		new /obj/item/reading_stone(T)
		to_chat(H, SPAN_NOTICE("You polish a reading stone."))
		return
	..()

/obj/item/reading_stone
	name = "reading stone"
	desc = "A clear, domed lens of rock crystal. Held in your other hand over a page, it makes the letters large enough to read and write by poorer light."
	icon = 'icons/obj/gem_science.dmi'
	icon_state = "rock_crystal_lens"
	w_class = ITEM_SIZE_TINY
	slot_flags = SLOT_POCKET
	value = 10

/mob/living/human/reading_light_problem()
	. = ..()
	if (. && (istype(l_hand, /obj/item/reading_stone) || istype(r_hand, /obj/item/reading_stone)))
		var/turf/T = get_turf(src)
		if (T && T.get_lumcount() >= SCHOLAR_MIN_LIGHT * READING_STONE_LIGHT)
			return null

/obj/item/stack/emery_powder
	name = "emery"
	singular_name = "pinch of emery"
	desc = "Dark, gritty powder of crushed corundum. Rubbed into a lapping wheel it cuts the softer stones: garnet, amethyst, topaz, emerald and quartz."
	icon = 'icons/obj/gem_science.dmi'
	icon_state = "emery_powder"
	w_class = ITEM_SIZE_TINY
	max_amount = 50
	amount = 1
	flammable = FALSE
	value = 2

// Crushed garnet glued to paper (1878): rough garnet with paper in the other hand.
/obj/item/stack/ore/gem/garnet/attack_self(mob/user)
	var/mob/living/human/H = user
	if (!istype(H) || !istype(H.get_inactive_hand(), /obj/item/weapon/paper))
		return ..()
	var/obj/item/weapon/paper/P = H.get_inactive_hand()
	if (!H.may_do_after || !crafting_node_allowed_or_warn(H, "factories"))
		return
	to_chat(H, SPAN_NOTICE("You start crushing \a [singular_name] and gluing it to the paper..."))
	if (!do_after(H, 40, src))
		return
	if (QDELETED(src) || QDELETED(P) || P.loc != H || loc != H || !use(1))
		return
	H.drop_from_inventory(P)
	qdel(P)
	var/obj/item/stack/garnet_paper/G = new(get_turf(H))
	G.amount = GARNET_PAPER_SHEETS
	G.update_icon()
	H.put_in_hands(G)
	to_chat(H, SPAN_NOTICE("You make [GARNET_PAPER_SHEETS] sheets of garnet paper."))

/obj/item/stack/garnet_paper
	name = "garnet paper"
	singular_name = "sheet of garnet paper"
	desc = "Paper faced with crushed garnet. Use a sheet with a worn wooden tool or weapon in your other hand to sand it smooth again."
	icon = 'icons/obj/gem_science.dmi'
	icon_state = "garnet_paper"
	w_class = ITEM_SIZE_TINY
	max_amount = 20
	amount = 1
	value = 1

// Garnet paper in the active hand sands the wear out of a wooden tool or
// weapon held in the other hand, as a grindstone does for steel.
/obj/item/stack/garnet_paper/attack_self(mob/user)
	var/mob/living/human/H = user
	var/obj/item/weapon/material/M = istype(H) ? H.get_inactive_hand() : null
	if (!istype(M) || !istype(M.material, /material/wood))
		to_chat(user, SPAN_WARNING("Hold a wooden tool or weapon in your other hand to sand it."))
		return
	if (M.health >= M.maxhealth)
		to_chat(user, SPAN_NOTICE("\The [M] is already smooth."))
		return
	if (!H.may_do_after)
		return
	to_chat(H, SPAN_NOTICE("You start sanding \the [M]..."))
	playsound(get_turf(H), 'sound/effects/woodfile.ogg', 40, TRUE)
	if (!do_after(H, 30, M))
		return
	if (QDELETED(src) || QDELETED(M) || H.get_inactive_hand() != M || !use(1))
		return
	M.maxhealth = max(1, M.maxhealth - 1)
	M.health = min(M.maxhealth, M.health + round(M.maxhealth / 4))
	to_chat(H, SPAN_NOTICE("You sand the wear out of \the [M]."))

// ---- Synthetic ruby (flame fusion, 1902) and the ruby laser rod (1960) ----

// Four pinches of emery fused in the flame of a lit furnace beside you.
/obj/item/stack/emery_powder/attack_self(mob/user)
	var/mob/living/human/H = user
	if (!istype(H))
		return ..()
	var/obj/structure/furnace/F = null
	for (var/obj/structure/furnace/candidate in range(1, H))
		if (candidate.is_open_flame())
			F = candidate
			break
	if (!F)
		return ..()
	if (amount < BOULE_EMERY)
		to_chat(H, SPAN_WARNING("You need [BOULE_EMERY] pinches of emery to grow a boule."))
		return
	if (!H.may_do_after || !crafting_node_allowed_or_warn(H, "electricity"))
		return
	to_chat(H, SPAN_NOTICE("You start sifting emery into the hottest part of \the [F]'s flame, a little at a time..."))
	if (!do_after(H, 100, F))
		return
	if (QDELETED(src) || QDELETED(F) || !F.is_open_flame() || loc != H || !use(BOULE_EMERY))
		return
	H.put_in_hands(new /obj/item/ruby_boule(get_turf(H)))
	to_chat(H, SPAN_NOTICE("A pink boule of synthetic ruby grows in the flame."))

/obj/item/ruby_boule
	name = "synthetic ruby boule"
	desc = "A pear-shaped crystal of ruby grown drop by drop in a flame. It is cheap: chisel it into jewel bearings, or grind it into a laser rod on a lapping wheel charged with diamond."
	icon = 'icons/obj/gem_science.dmi'
	icon_state = "ruby_boule"
	w_class = ITEM_SIZE_SMALL
	flammable = FALSE
	value = 4

// A boule makes a whole batch of cheap watch jewels.
/obj/item/ruby_boule/attackby(obj/item/W, mob/user)
	if (is_tool(W, TOOL_CHISEL) && ishuman(user))
		var/mob/living/human/H = user
		if (!is_tool(H.get_inactive_hand(), TOOL_HAMMER))
			to_chat(H, SPAN_WARNING("You need a hammer in your other hand to drill jewel bearings."))
			return
		if (!H.may_do_after || !crafting_node_allowed_or_warn(H, "optics_instruments"))
			return
		to_chat(H, SPAN_NOTICE("You start slicing \the [src] and drilling the slices..."))
		if (!do_after(H, 80, src))
			return
		if (QDELETED(src) || H.get_active_hand() != W || !(loc == H || (isturf(loc) && get_dist(src, H) <= 1)))
			return
		var/obj/item/stack/jewel_bearing/J = new(get_turf(src))
		J.amount = BOULE_BEARINGS
		J.update_icon()
		to_chat(H, SPAN_NOTICE("You drill [BOULE_BEARINGS] jewel bearings from \the [src]."))
		qdel(src)
		return
	..()

/obj/structure/lapping_wheel/proc/make_ruby_rod(obj/item/ruby_boule/B, mob/living/human/H)
	if (!H.may_do_after || !crafting_node_allowed_or_warn(H, "consumer_electronics"))
		return
	if (charges < ROD_CHARGES)
		to_chat(H, SPAN_WARNING("\The [src] needs at least [ROD_CHARGES] charges of diamond grit to grind a rod."))
		return
	to_chat(H, SPAN_NOTICE("You start grinding \the [B] into a rod and polishing its ends flat..."))
	if (!do_after(H, 100, src))
		return
	if (QDELETED(B) || B.loc != H || charges < ROD_CHARGES)
		return
	charges -= ROD_CHARGES
	H.drop_from_inventory(B)
	qdel(B)
	H.put_in_hands(new /obj/item/ruby_rod(get_turf(H)))
	to_chat(H, SPAN_NOTICE("You finish a ruby rod and silver its ends."))

/obj/item/ruby_rod
	name = "ruby rod"
	desc = "A polished rod of synthetic ruby with silvered ends: the heart of a ruby laser. Fit it into a pair of binoculars to make a laser rangefinder."
	icon = 'icons/obj/gem_science.dmi'
	icon_state = "ruby_rod"
	w_class = ITEM_SIZE_TINY
	flammable = FALSE
	value = 20

/obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/ruby_rod) && type == /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars && ishuman(user))
		var/mob/living/human/H = user
		if (!H.may_do_after || !crafting_node_allowed_or_warn(H, "consumer_electronics"))
			return
		to_chat(H, SPAN_NOTICE("You start fitting the ruby rod and a flash lamp into \the [src]..."))
		if (!do_after(H, 60, src))
			return
		if (QDELETED(src) || QDELETED(W) || W.loc != H || !(loc == H || (isturf(loc) && get_dist(src, H) <= 1)))
			return
		var/turf/T = get_turf(src)
		var/was_held = (loc == H)
		H.drop_from_inventory(W)
		qdel(W)
		if (was_held)
			H.drop_from_inventory(src)
		var/obj/item/R = new /obj/item/weapon/attachment/scope/adjustable/binoculars/binoculars/rangefinder(T)
		qdel(src)
		if (was_held)
			H.put_in_hands(R)
		to_chat(H, SPAN_NOTICE("You turn the binoculars into a laser rangefinder."))
		return
	..()

// ---- Gem testing: scratch test, loupe, hydrostatic scale, refractometer ----

// list(species, Mohs hardness, specific gravity, refractive index or 0 when
// over the instrument's range, synthetic) for a stone, or null.
/proc/gem_test_data(atom/A)
	if (istype(A, /obj/item/ruby_boule))
		return list("ruby", 9, 4.0, 1.77, TRUE)
	var/path = A.type
	if (istype(A, /obj/item/stack/ore/gem))
		var/obj/item/stack/ore/gem/R = A
		path = R.cut_type
	else if (istype(A, /obj/item/stack/ore/diamond))
		path = /obj/item/stack/gemstone/diamond
	if (ispath(path, /obj/item/stack/gemstone/diamond))
		return list("diamond", 10, 3.52, 0, FALSE)
	if (ispath(path, /obj/item/stack/gemstone/ruby))
		return list("ruby", 9, 4.0, 1.77, FALSE)
	if (ispath(path, /obj/item/stack/gemstone/sapphire))
		return list("sapphire", 9, 4.0, 1.77, FALSE)
	if (ispath(path, /obj/item/stack/gemstone/topaz))
		return list("topaz", 8, 3.55, 1.62, FALSE)
	if (ispath(path, /obj/item/stack/gemstone/emerald))
		return list("emerald", 7.5, 2.75, 1.58, FALSE)
	if (ispath(path, /obj/item/stack/gemstone/garnet))
		return list("garnet", 7, 3.9, 1.76, FALSE)
	if (ispath(path, /obj/item/stack/gemstone/amethyst))
		return list("amethyst", 7, 2.65, 1.55, FALSE)
	if (ispath(path, /obj/item/stack/gemstone/quartz))
		return list("quartz", 7, 2.65, 1.55, FALSE)
	return null

/obj/item/stack
	var/inclusions_mapped = FALSE // rough stone looked over with a loupe before cutting

/obj/item/gem_tester
	name = "jeweller's loupe"
	desc = "A folding brass lens. Use it on a rough stone to map its inclusions before you cut, so fewer stones split."
	icon = 'icons/obj/gem_science.dmi'
	icon_state = "loupe"
	w_class = ITEM_SIZE_TINY
	slot_flags = SLOT_POCKET
	flammable = FALSE
	value = 6
	var/node = "optics_instruments"

/obj/item/gem_tester/scale
	name = "gem scale"
	desc = "A small brass balance with a cup of water beneath one pan. Weighing a stone in air and in water gives its specific gravity, which names the stone and its weight in carats."
	icon_state = "gem_scale"
	w_class = ITEM_SIZE_SMALL
	slot_flags = 0
	value = 10

/obj/item/gem_tester/refractometer
	name = "gem refractometer"
	desc = "A brass instrument with a glass window and an eyepiece. A cut stone laid on the window shows its refractive index, which names it for certain and shows a stone grown in a flame for what it is."
	icon_state = "refractometer"
	w_class = ITEM_SIZE_SMALL
	slot_flags = 0
	value = 18
	node = "electricity"

/obj/item/gem_tester/proc/test_stone(atom/A, mob/living/human/H, list/data)
	return

/obj/item/gem_tester/test_stone(atom/A, mob/living/human/H, list/data)
	var/obj/item/stack/ore/O = A
	if (!istype(O))
		to_chat(H, SPAN_NOTICE("A loupe is for planning the cut of a rough stone."))
		return
	if (O.inclusions_mapped)
		to_chat(H, SPAN_NOTICE("You have already mapped the inclusions in \the [O]."))
		return
	O.inclusions_mapped = TRUE
	to_chat(H, SPAN_NOTICE("You turn \the [O] under the loupe and mark its inclusions. Cuts planned around them will split half as often."))

/obj/item/gem_tester/scale/test_stone(atom/A, mob/living/human/H, list/data)
	var/obj/item/I = A
	var/obj/item/stack/S = A
	var/stones = istype(S) ? max(1, S.amount) : 1
	to_chat(H, SPAN_NOTICE("Specific gravity [data[3]]: [data[1]]. About [stones * (istype(A, /obj/item/stack/ore) ? 6 : 2)] carats in all, worth about [I.value * stones]."))

/obj/item/gem_tester/refractometer/test_stone(atom/A, mob/living/human/H, list/data)
	if (istype(A, /obj/item/stack/ore))
		to_chat(H, SPAN_NOTICE("A rough stone has no flat face to read. Cut it first."))
		return
	if (!data[4])
		to_chat(H, SPAN_NOTICE("The reading runs past the top of the scale: only diamond bends light that far."))
		return
	to_chat(H, SPAN_NOTICE("Refractive index [data[4]]: [data[1]].[data[5] ? " Curved growth lines show it was grown in a flame: synthetic." : " Natural."]"))

/proc/gem_test_attempt(obj/item/W, atom/A, mob/user)
	if (!ishuman(user))
		return FALSE
	var/mob/living/human/H = user
	var/list/data = gem_test_data(A)
	if (!data)
		return FALSE
	// Scratch test: a cut quartz point scratches only what is softer than it.
	if (istype(W, /obj/item/stack/gemstone/quartz) && W != A)
		if (!crafting_node_allowed_or_warn(H, "regalia"))
			return TRUE
		if (data[2] > 7)
			to_chat(H, SPAN_NOTICE("The quartz point skates off \the [A] without a mark: it is harder than quartz."))
		else
			to_chat(H, SPAN_NOTICE("The quartz point and \the [A] scratch each other alike: it is about as hard as quartz."))
		return TRUE
	if (!istype(W, /obj/item/gem_tester))
		return FALSE
	var/obj/item/gem_tester/T = W
	if (!H.may_do_after || !crafting_node_allowed_or_warn(H, T.node))
		return TRUE
	if (!do_after(H, 20, A))
		return TRUE
	if (QDELETED(A) || QDELETED(T))
		return TRUE
	T.test_stone(A, H, data)
	return TRUE

/obj/item/stack/ore/gem/attackby(obj/item/W, mob/user)
	if (gem_test_attempt(W, src, user))
		return
	..()

/obj/item/stack/ore/diamond/attackby(obj/item/W, mob/user)
	if (gem_test_attempt(W, src, user))
		return
	..()

/obj/item/stack/gemstone/attackby(obj/item/W, mob/user)
	if (gem_test_attempt(W, src, user))
		return
	..()

/obj/item/ruby_boule/attackby(obj/item/W, mob/user)
	if (gem_test_attempt(W, src, user))
		return
	..()

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
#undef READING_STONE_LIGHT
#undef GARNET_PAPER_SHEETS
#undef BOULE_EMERY
#undef BOULE_BEARINGS
#undef ROD_CHARGES
