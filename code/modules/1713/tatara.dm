// Tamahagane: Japanese iron-sand steel (docs/tatara.md).
//
// Iron sand (satetsu) is panned from shallow fresh water or sifted out of
// beach sand. An ordinary bloomery smelts it at two sand per sponge iron.
// Asia, the land of the Yamato coasts, has richer black sand.

/obj/map_metadata/var/iron_sand_rich = FALSE

#define IRON_SAND_PAN_UNITS 3
#define IRON_SAND_SIFT_UNITS 2
#define IRON_SAND_RICH_BONUS 2
#define IRON_SAND_PER_SPONGE 2

/obj/item/stack/ore/iron_sand
	name = "iron sand"
	desc = "Heavy black sand, washed out of river silt and beaches. Iron-rich, but too fine for a fire pit: smelt it in a bloomery or a tatara."
	icon = 'icons/obj/tatara.dmi'
	icon_state = "iron_sand"
	flags = CONDUCT

// Units one finished pan or sieve of iron sand leaves on the tile.
/mob/living/human/proc/iron_sand_yield(panning)
	. = panning ? IRON_SAND_PAN_UNITS : IRON_SAND_SIFT_UNITS
	if (map && map.iron_sand_rich)
		. += IRON_SAND_RICH_BONUS

// The bloomery takes iron sand beside ore; the blast furnace does not.
/obj/structure/furnace/var/iron_sand = 0

/obj/structure/furnace/accept_manual_stack(var/obj/item/I, var/mob/living/human/H)
	if (!istype(I, /obj/item/stack/ore/iron_sand) || type != /obj/structure/furnace)
		return ..()
	iron_sand += I.amount
	to_chat(H, "You pour \the [I] into \the [src].")
	H.remove_from_mob(I)
	visible_message("<span class = 'notice'>[H] pours [I] into \the [name].</span>")
	qdel(I)

/obj/structure/furnace/process()
	if (type == /obj/structure/furnace && iron_sand >= IRON_SAND_PER_SPONGE)
		var/sponge = round(iron_sand / IRON_SAND_PER_SPONGE)
		iron_sand -= sponge * IRON_SAND_PER_SPONGE
		spawn_stack(/obj/item/stack/ore/iron_sponge, src.loc, sponge)
	return ..()

/obj/structure/furnace/empty()
	if (iron_sand > 0)
		spawn_stack(/obj/item/stack/ore/iron_sand, src.loc, iron_sand)
		iron_sand = 0
	..()

#undef IRON_SAND_PAN_UNITS
#undef IRON_SAND_SIFT_UNITS
#undef IRON_SAND_RICH_BONUS
#undef IRON_SAND_PER_SPONGE

//////////////////////////////////////////////////////////////////////////////
// The tatara: a clay box furnace built for one firing. Iron sand and charcoal
// go in by turns, the bellows blow, and after ten minutes the furnace is
// broken open on a bloom of kera and a little pig iron (zuku).

#define TATARA_LIMIT 30 // iron sand and charcoal each
#define TATARA_MIN_SAND 3
#define TATARA_MIN_CHARGES 3 // iron sand added on top of charcoal this often for a full yield
#define TATARA_SAND_PER_KERA 3
#define TATARA_SAND_PER_ZUKU 10
#define TATARA_BURN_TIME 6000 // deciseconds, ten minutes
#define TATARA_TICK 100
#define TATARA_BLAST_TIME 900 // one pump of the bellows keeps the blast this long
#define TATARA_CLAY_BACK 5
#define KERA_TAMAHAGANE_PERCENT 50
#define KERA_WROUGHT_PERCENT 30
#define FOLD_TAMAHAGANE 3
#define FOLD_STEEL 2

/obj/item/stack/ore/kera
	name = "kera"
	desc = "Broken pieces of a tatara bloom: steel, softer iron and slag fused together. Sort it on an anvil."
	icon = 'icons/obj/tatara.dmi'
	icon_state = "kera"
	singular_name = "lump"
	flags = CONDUCT

/obj/item/stack/ore/tamahagane
	name = "tamahagane"
	desc = "The best of the kera: bright, hard steel that breaks with a crystalline face. Fold it on an anvil into steel."
	icon = 'icons/obj/tatara.dmi'
	icon_state = "tamahagane"
	singular_name = "chunk"
	flags = CONDUCT

/obj/structure/tatara
	name = "tatara"
	desc = "A long clay box furnace with a row of tuyere holes along each side. Feed it charcoal and iron sand by turns, light it, and keep the bellows working beside it. It is broken open when the firing is done."
	icon = 'icons/obj/tatara.dmi'
	icon_state = "tatara"
	density = TRUE
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/iron_sand = 0
	var/charcoal = 0
	var/charges = 0 // times iron sand went in on top of fresh charcoal
	var/last_charcoal = FALSE // the last thing loaded was charcoal
	var/burning = FALSE
	var/burnt_out = FALSE
	var/burn_left = 0 // saved, so a load resumes the firing
	var/burn_ticks = 0
	var/blown_ticks = 0
	var/kera_out = 0 // what breaking the burnt-out furnace yields
	var/zuku_out = 0
	var/tmp/burn_epoch = 0
	var/tmp/bellows_until = 0

/obj/structure/tatara/persistence_runtime_var(key)
	return key == "burn_epoch" || key == "bellows_until" || ..()

/obj/structure/tatara/update_icon()
	if (burning)
		icon_state = "tatara_on"
		set_light(3)
	else if (burnt_out)
		icon_state = "tatara_spent"
		set_light(1)
	else if (iron_sand || charcoal)
		icon_state = "tatara_loaded"
		set_light(0)
	else
		icon_state = "tatara"
		set_light(0)

/obj/structure/tatara/examine(mob/user, distance)
	..(user, distance)
	if (burnt_out)
		to_chat(user, SPAN_NOTICE("The firing is over. Break the furnace open with a hammer or pickaxe to get the kera out."))
	else if (burning)
		to_chat(user, SPAN_NOTICE("It roars with heat. About [max(1, round(burn_left / 600))] minute\s left. It holds [iron_sand] iron sand and [charcoal] charcoal, charged [charges] time\s."))
	else
		to_chat(user, SPAN_NOTICE("It holds [iron_sand] of [TATARA_LIMIT] iron sand and [charcoal] of [TATARA_LIMIT] charcoal, charged [charges] time\s. Add charcoal, then iron sand on top, at least [TATARA_MIN_CHARGES] times."))

/obj/structure/tatara/attackby(obj/item/I, mob/living/human/H)
	if (!I || !I.loc || !istype(H))
		return
	if (burnt_out && (is_tool(I, TOOL_HAMMER) || is_tool(I, TOOL_PICKAXE)))
		break_open(H)
		return
	if (isflamesource(I))
		light(H)
		return
	if (istype(I, /obj/item/stack/ore/iron_sand) || istype(I, /obj/item/stack/ore/charcoal))
		charge(I, H)
		return
	return ..()

/obj/structure/tatara/attack_hand(mob/living/human/H)
	if (istype(H) && !burnt_out)
		light(H)

// Charging stays open for the first half of the firing, as the smelters did.
/obj/structure/tatara/proc/charge(obj/item/stack/S, mob/living/human/H)
	if (burnt_out || (burning && burn_left < TATARA_BURN_TIME / 2))
		to_chat(H, SPAN_WARNING("It is too late to charge \the [src] now."))
		return
	var/sand = istype(S, /obj/item/stack/ore/iron_sand)
	var/moved = min(S.amount, TATARA_LIMIT - (sand ? iron_sand : charcoal))
	if (moved <= 0)
		to_chat(H, SPAN_WARNING("\The [src] can take no more [sand ? "iron sand" : "charcoal"]."))
		return
	if (sand)
		iron_sand += moved
		if (last_charcoal)
			charges++
		last_charcoal = FALSE
	else
		charcoal += moved
		last_charcoal = TRUE
	S.use(moved)
	update_icon()
	visible_message(SPAN_NOTICE("[H] charges \the [src] with [moved] [sand ? "iron sand" : "charcoal"]."))

/obj/structure/tatara/proc/light(mob/living/human/H)
	if (burning || burnt_out)
		return
	if (iron_sand < TATARA_MIN_SAND || charcoal < TATARA_MIN_SAND)
		to_chat(H, SPAN_WARNING("Charge \the [src] with at least [TATARA_MIN_SAND] charcoal and [TATARA_MIN_SAND] iron sand first."))
		return
	visible_message(SPAN_NOTICE("[H] starts lighting \the [src] through its tuyeres."))
	if (!do_after(H, 50, src) || QDELETED(src) || burning || burnt_out)
		return
	burning = TRUE
	note_field_work(H, "smelting", iron_sand) // natural_science_work.dm
	burn_left = TATARA_BURN_TIME
	burn_ticks = 0
	blown_ticks = 0
	update_icon()
	visible_message(SPAN_NOTICE("\The [src] catches. Flame starts licking out of its open top."))
	start_burn_loop()

/obj/structure/tatara/proc/start_burn_loop()
	addtimer(CALLBACK(src, PROC_REF(burn_tick), ++burn_epoch), TATARA_TICK)

/obj/structure/tatara/proc/burn_tick(epoch)
	if (QDELETED(src) || !burning || epoch != burn_epoch)
		return
	burn_ticks++
	if (world.time < bellows_until)
		blown_ticks++
	burn_left -= TATARA_TICK
	if (burn_left <= 0)
		finish_burn()
		return
	addtimer(CALLBACK(src, PROC_REF(burn_tick), epoch), TATARA_TICK)

// Only sand matched by charcoal smelts. The bellows decide how much becomes
// steel bloom; a poorly charged furnace makes half the kera.
/obj/structure/tatara/proc/kera_yield()
	var/smelted = min(iron_sand, charcoal)
	var/blown = burn_ticks ? blown_ticks / burn_ticks : 0
	var/kera = (smelted / TATARA_SAND_PER_KERA) * (0.5 + 0.5 * blown)
	if (charges < TATARA_MIN_CHARGES)
		kera *= 0.5
	return round(kera)

/obj/structure/tatara/proc/zuku_yield()
	return round(min(iron_sand, charcoal) / TATARA_SAND_PER_ZUKU)

/obj/structure/tatara/proc/finish_burn()
	kera_out = kera_yield()
	zuku_out = zuku_yield()
	burning = FALSE
	burnt_out = TRUE
	burn_left = 0
	iron_sand = 0
	charcoal = 0
	burn_epoch++
	update_icon()
	visible_message(SPAN_NOTICE("\The [src] dies down, its clay walls cracked and glowing. It is ready to be broken open."))

/obj/structure/tatara/proc/break_open(mob/living/human/H)
	visible_message(SPAN_NOTICE("[H] starts breaking \the [src] open."))
	playsound(src, 'sound/effects/pickaxe.ogg', 80, TRUE)
	if (!do_after(H, 50, src) || QDELETED(src) || !burnt_out)
		return
	var/turf/T = get_turf(src)
	if (kera_out > 0)
		spawn_stack(/obj/item/stack/ore/kera, T, kera_out)
	if (zuku_out > 0)
		spawn_stack(/obj/item/stack/ore/iron_pig, T, zuku_out)
	spawn_stack(/obj/item/stack/material/clay, T, TATARA_CLAY_BACK)
	visible_message(SPAN_NOTICE("[H] breaks \the [src] apart and drags out [kera_out] lump\s of kera[zuku_out ? " and [zuku_out] pig iron" : ""]."))
	qdel(src)

/obj/structure/tatara/after_load()
	..()
	burn_epoch = 0
	if (burning)
		if (burn_left <= 0)
			burn_left = TATARA_TICK
		start_burn_loop()
	update_icon()

// Bellows beside a tatara blow into it as they do into a bloomery.
/obj/structure/workshop_machine/bellows/attack_hand(mob/living/human/H)
	var/obj/structure/tatara/F = locate(/obj/structure/tatara) in range(1, src)
	if (!F || !istype(H) || busy || length(furnaces_in_reach()))
		return ..()
	if (!anchored)
		to_chat(H, SPAN_WARNING("Fasten \the [src] down first."))
		return
	busy = TRUE
	icon_state = "bellows_pump"
	visible_message(SPAN_NOTICE("[H] works \the [src]."))
	var/done = do_after(H, 30, src)
	busy = FALSE
	if (QDELETED(src))
		return
	icon_state = "bellows"
	if (!done || !anchored || QDELETED(F))
		return
	F.bellows_until = world.time + TATARA_BLAST_TIME
	to_chat(H, SPAN_NOTICE(F.burning ? "Air roars into \the [F]." : "Air blows through \the [F]. Light it to make use of the blast."))

//////////////////////////////////////////////////////////////////////////////
// Sorting kera and folding tamahagane on an anvil

/obj/structure/anvil/attackby(obj/item/P as obj, mob/user as mob)
	if (!istype(P, /obj/item/stack/ore/kera) && !istype(P, /obj/item/stack/ore/tamahagane))
		return ..()
	var/mob/living/human/H = user
	if (!istype(H) || in_use)
		return
	if (H.getStatCoeff("crafting") < 1.2)
		to_chat(H, "This anvil requires an effective Crafting coefficient of at least 1.20x.")
		return
	if (!("iron" in accepted_materials))
		to_chat(H, SPAN_WARNING("You can't use this material on this anvil."))
		return
	if (!crafting_node_allowed_or_warn(H, "tatara_smelting"))
		return
	var/obj/item/stack/S = P
	var/kera = istype(S, /obj/item/stack/ore/kera)
	if (!kera && S.amount < FOLD_TAMAHAGANE)
		to_chat(H, SPAN_WARNING("Fold at least [FOLD_TAMAHAGANE] chunks of tamahagane together."))
		return
	var/initial_amount = S.amount
	var/batches = kera ? initial_amount : round(initial_amount / FOLD_TAMAHAGANE)
	to_chat(H, kera ? "You begin breaking and sorting the kera..." : "You begin folding the tamahagane...")
	icon_state = "[base_icon]_anvil_use"
	in_use = TRUE
	update_icon()
	playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
	var/done = do_after(H, 15 * (kera ? initial_amount : batches * FOLD_TAMAHAGANE), src)
	in_use = FALSE
	update_icon()
	if (!done || QDELETED(S) || S.amount != initial_amount)
		return
	if (kera)
		var/tama = round(initial_amount * KERA_TAMAHAGANE_PERCENT / 100)
		var/wrought = round(initial_amount * KERA_WROUGHT_PERCENT / 100)
		S.use(initial_amount)
		if (tama > 0)
			spawn_stack(/obj/item/stack/ore/tamahagane, loc, tama)
		if (wrought > 0)
			spawn_stack(/obj/item/stack/material/iron, loc, wrought)
		to_chat(H, SPAN_NOTICE("You sort out [tama] chunk\s of tamahagane and [wrought] bar\s of soft iron; the rest is slag."))
	else
		S.use(batches * FOLD_TAMAHAGANE)
		spawn_stack(/obj/item/stack/material/steel, loc, batches * FOLD_STEEL)
		to_chat(H, SPAN_NOTICE("You heat, fold and weld the tamahagane over and over into [batches * FOLD_STEEL] sheet\s of steel."))

#undef TATARA_LIMIT
#undef TATARA_MIN_SAND
#undef TATARA_MIN_CHARGES
#undef TATARA_SAND_PER_KERA
#undef TATARA_SAND_PER_ZUKU
#undef TATARA_BURN_TIME
#undef TATARA_TICK
#undef TATARA_BLAST_TIME
#undef TATARA_CLAY_BACK
#undef KERA_TAMAHAGANE_PERCENT
#undef KERA_WROUGHT_PERCENT
#undef FOLD_TAMAHAGANE
#undef FOLD_STEEL

//////////////////////////////////////////////////////////////////////////////
// Washing for iron sand (kanna-nagashi). Running water carries light grains
// away and leaves the heavy black sand behind: a wooden channel by a river
// washes hillside soil, and ordinary sand washed in a channel or a pan gives
// up a little of its iron sand.

#define KANNA_WASH_UNITS 2 // iron sand from one load of soil
#define KANNA_STOCK 20 // soil loads one channel tile gives before it rests
#define KANNA_REGROW 600 // deciseconds per load coming back (20 minutes for all)
#define KANNA_WASH_TIME 300
#define SAND_PER_WASH 5 // ordinary sand washed down to one iron sand
#define SAND_WASH_TIME 50 // per batch of SAND_PER_WASH

// "x,y,z" -> /datum/resource_stock, so a rebuilt channel does not refill.
var/global/list/kanna_channel_stock = list()

/obj/structure/kanna_channel
	name = "washing channel"
	desc = "A kanna-nagashi channel: a plank trough with riffles, set by shallow fresh water. Wash hillside soil through it with an empty hand, or pour ordinary sand into it, and the heavy black iron sand settles behind the riffles."
	icon = 'icons/obj/tatara.dmi'
	icon_state = "kanna_channel"
	density = FALSE
	anchored = TRUE
	not_movable = TRUE
	var/tmp/washing = FALSE

/obj/structure/kanna_channel/proc/water_beside()
	var/turf/T = get_turf(src)
	return T && T.panning_water()

/obj/structure/kanna_channel/proc/stock()
	var/key = "[x],[y],[z]"
	var/datum/resource_stock/S = kanna_channel_stock[key]
	if (!S)
		S = new /datum/resource_stock(KANNA_STOCK, KANNA_REGROW)
		kanna_channel_stock[key] = S
	return S

/obj/structure/kanna_channel/examine(mob/user, distance)
	..(user, distance)
	if (!water_beside())
		to_chat(user, SPAN_WARNING("It is dry: it needs shallow fresh water right beside it."))
	else
		var/datum/resource_stock/S = stock()
		to_chat(user, SPAN_NOTICE("The hillside here has [S.available()] of [KANNA_STOCK] loads of soil worth washing."))

/obj/structure/kanna_channel/proc/start_washing(mob/living/human/H)
	if (washing)
		to_chat(H, SPAN_WARNING("Someone is already washing in \the [src]."))
		return FALSE
	if (!water_beside())
		to_chat(H, SPAN_WARNING("\The [src] needs shallow fresh water right beside it."))
		return FALSE
	washing = TRUE
	icon_state = "kanna_channel_working"
	return TRUE

/obj/structure/kanna_channel/proc/stop_washing()
	washing = FALSE
	if (!QDELETED(src))
		icon_state = "kanna_channel"

/obj/structure/kanna_channel/attack_hand(mob/living/human/H)
	if (!istype(H) || !start_washing(H))
		return
	var/datum/resource_stock/S = stock()
	if (S.available() < 1)
		stop_washing()
		to_chat(H, SPAN_WARNING("The soil around here is washed out. Give it time to weather."))
		return
	visible_message(SPAN_NOTICE("[H] starts washing soil down \the [src]."))
	var/done = do_after(H, KANNA_WASH_TIME, src)
	stop_washing()
	if (!done || QDELETED(src) || !water_beside() || !S.take(1))
		return
	var/units = KANNA_WASH_UNITS + (map && map.iron_sand_rich ? 2 : 0)
	spawn_stack(/obj/item/stack/ore/iron_sand, get_turf(src), units)
	to_chat(H, SPAN_NOTICE("The muddy water runs off and leaves [units] iron sand behind the riffles."))

/obj/structure/kanna_channel/attackby(obj/item/I, mob/living/human/H)
	if (istype(I, /obj/item/stack/ore/glass) && istype(H))
		if (start_washing(H))
			wash_sand(I, H, src)
			stop_washing()
		return
	if (is_tool(I, TOOL_HAMMER) && istype(H))
		visible_message(SPAN_NOTICE("[H] starts taking \the [src] apart."))
		if (do_after(H, 40, src) && !QDELETED(src))
			spawn_stack(/obj/item/stack/material/wood, get_turf(src), 3)
			qdel(src)
		return
	return ..()

// Washes the held sand in batches; TRUE when any iron sand came out.
/proc/wash_sand(obj/item/stack/S, mob/living/human/H, atom/where)
	var/batches = round(S.amount / SAND_PER_WASH)
	if (batches < 1)
		to_chat(H, SPAN_WARNING("Wash at least [SAND_PER_WASH] sand at a time."))
		return FALSE
	var/initial_amount = S.amount
	to_chat(H, SPAN_NOTICE("You start washing the sand, letting the water carry the light grains away."))
	if (!do_after(H, SAND_WASH_TIME * batches, where) || QDELETED(S) || S.amount != initial_amount)
		return FALSE
	var/units = batches * (map && map.iron_sand_rich ? 2 : 1)
	S.use(batches * SAND_PER_WASH)
	spawn_stack(/obj/item/stack/ore/iron_sand, get_turf(H), units)
	to_chat(H, SPAN_NOTICE("[batches * SAND_PER_WASH] sand washes down to [units] iron sand."))
	return TRUE

// A wooden bowl pans ordinary sand the same way beside shallow fresh water.
/obj/item/kitchen/wood_bowl/attackby(obj/item/I, mob/living/human/H)
	if (!istype(I, /obj/item/stack/ore/glass) || !istype(H))
		return ..()
	var/turf/T = get_turf(H)
	if (!T || !T.panning_water())
		to_chat(H, SPAN_WARNING("Stand beside shallow fresh water to wash sand."))
		return
	if (map && map.ordinal_age < 1)
		to_chat(H, SPAN_WARNING("You see nothing worth keeping in the sand."))
		return
	wash_sand(I, H, H)

#undef KANNA_WASH_UNITS
#undef KANNA_STOCK
#undef KANNA_REGROW
#undef KANNA_WASH_TIME
#undef SAND_PER_WASH
#undef SAND_WASH_TIME

//////////////////////////////////////////////////////////////////////////////
// Japanese blades: clay hardening (tsuchioki and yaki-ire). A steel blade
// forged beside a watered quench tub, with clay to hand, is coated thin at
// the edge and thick at the spine before the quench: the edge comes out
// harder than plain quenching makes it, with a hamon line along it.

#define CLAY_HARDENED_QUALITY 1.35

/obj/item/weapon/material/var/hamon = FALSE

/obj/item/weapon/material/sword/tachi
	name = "tachi"
	desc = "The older Japanese cavalry sword: long and deeply curved, worn edge down slung from the belt."
	icon_state = "tachi"
	item_state = "tachi"
	block_chance = 25
	force_divisor = 0.8
	thrown_force_divisor = 0.5
	slot_flags = SLOT_BELT | SLOT_BACK
	value = 60
	cooldownw = 7

/proc/is_japanese_blade(obj/item/weapon/material/W)
	return istype(W, /obj/item/weapon/material/sword/katana) || istype(W, /obj/item/weapon/material/sword/wakazashi) \
		|| istype(W, /obj/item/weapon/material/sword/tachi) || istype(W, /obj/item/weapon/material/kitchen/utensil/knife/tanto) \
		|| istype(W, /obj/item/weapon/material/naginata) || istype(W, /obj/item/weapon/material/spear/naginata)

/obj/item/weapon/material/examine(mob/user)
	..()
	if (hamon)
		to_chat(user, SPAN_NOTICE("A misty hamon line runs along its clay-hardened edge."))

// Clay in the smith's other hand, or on the anvil's tile.
/obj/structure/anvil/proc/hardening_clay(mob/living/human/H)
	var/obj/item/stack/material/clay/C = H.get_inactive_hand()
	if (istype(C) && C.amount > 0)
		return C
	for (var/obj/item/stack/material/clay/S in get_turf(src))
		if (S.amount > 0)
			return S
	return null

/obj/structure/anvil/proc/clay_harden(obj/item/weapon/material/W, mob/living/human/H)
	if (!is_japanese_blade(W) || W.get_material_name() != "steel" || W.crafting_quality >= CLAY_HARDENED_QUALITY)
		return FALSE
	if (!crafting_node_allowed(H, "japanese_swordsmithing"))
		return FALSE
	var/obj/structure/quench_tub/Q = quench_tub()
	var/obj/item/stack/material/clay/C = hardening_clay(H)
	if (!Q || !C || !Q.station_take_water(null))
		return FALSE
	C.use(1)
	W.crafting_quality = CLAY_HARDENED_QUALITY
	W.hamon = TRUE
	W.update_force()
	playsound(Q, 'sound/effects/watersplash.ogg', 30, TRUE)
	to_chat(H, SPAN_NOTICE("You coat \the [W] in clay, thin at the edge and thick at the spine, and quench it. A hamon line blooms along the edge."))
	return TRUE

/obj/structure/anvil/forge_stack_recipe(obj/item/P, mob/user, mob/living/human/H, choice, material_index, material_name, picked = null)
	if (material_name != "steel" || !istype(H))
		return ..()
	var/turf/T = get_turf(src)
	var/list/before = list()
	for (var/obj/item/weapon/material/W in T)
		before += W
	. = ..()
	if (!T)
		return
	for (var/obj/item/weapon/material/W in T)
		if (!(W in before))
			clay_harden(W, H)

#undef CLAY_HARDENED_QUALITY
