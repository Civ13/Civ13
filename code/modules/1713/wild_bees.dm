// Wild honeybees and honey hunting (Stone Age, no research).
//
// Wild nests sit in the hollows of living trees in temperate, taiga, jungle
// and savanna lands. They hold a few combs that refill slowly in the warm or
// wet season. Smoke from a smouldering grass bundle or a lit torch calms the
// bees for a short while; robbing a nest without smoke sets the bees on the
// one person who disturbed it (see the sting chase below). Taking the last
// comb drives the colony away until a new swarm moves in.
//
// Comb squeezed into an open container gives honey and a crushed wax lump;
// the lump melted over a flame becomes beeswax, and beeswax dipped onto a
// rope wick makes a beeswax candle.
//
// Cost: nests never process. The flora regrowth worker (flora_regrowth.dm)
// visits the nest registry once a minute with one prob() per nest, and places
// at most one new nest per visit from a few random samples. A sting chase is
// one short timer chain bound to one player, at most one per player.

#define WILD_BEE_NEST_CAP 60 // per map
#define WILD_BEE_MAX_COMB 4
#define WILD_BEE_COMB_MINUTES 45 // average minutes for one comb to refill in season
#define WILD_BEE_RETURN_MINUTES 360 // average minutes for a swarm to settle an empty nest in season
#define WILD_BEE_SITE_ATTEMPTS 6
#define WILD_BEE_SMOKE_TIME (45 SECONDS)
#define WILD_BEE_CHASE_TIME (20 SECONDS)
#define WILD_BEE_CHASE_STEP 15 // deciseconds between sting rolls
#define WILD_BEE_CHASE_RANGE 7 // tiles from the nest before the bees give up

var/global/list/wild_bee_nests = list()

/proc/wild_bee_climates()
	return list("temperate", "taiga", "jungle", "savanna")

// The bees forage and the combs fill in the warm or wet part of the year.
/proc/wild_bee_season_active()
	if (season_is_temperate())
		return season == SEASON_SPRING || season == SEASON_SUMMER
	return season == SEASON_WET

// Live trees whose trunks can hold a nest.
/proc/wild_bee_tree(obj/structure/wild/W)
	if (QDELETED(W) || !W.trunk_center_x)
		return FALSE
	if (istype(W, /obj/structure/wild/tree/live_tree))
		return TRUE
	if (istype(W, /obj/structure/wild/jungle))
		return !(istype(W, /obj/structure/wild/jungle/acacia/dead) || istype(W, /obj/structure/wild/jungle/medpine/dead) || istype(W, /obj/structure/wild/jungle/cherry/dead) || istype(W, /obj/structure/wild/jungle/yucca))
	return FALSE

/////// The nest

/obj/structure/wild_bee_nest
	name = "wild bee nest"
	desc = "Honeybees stream in and out of a hollow in the trunk. Pale combs glint inside."
	icon = 'icons/farming/wild_bees.dmi'
	icon_state = "nest"
	anchored = TRUE
	density = FALSE
	layer = 5.12 // just over the tree it lives in
	var/comb = 2
	var/occupied = TRUE
	var/tmp/smoked_until = 0
	var/tmp/robbing = FALSE

/obj/structure/wild_bee_nest/persistence_runtime_var(key)
	return key == "robbing" || ..()

/obj/structure/wild_bee_nest/New()
	..()
	wild_bee_nests |= src
	update_icon()

/obj/structure/wild_bee_nest/after_load()
	. = ..()
	wild_bee_nests |= src
	update_icon()

/obj/structure/wild_bee_nest/Destroy()
	wild_bee_nests -= src
	return ..()

/obj/structure/wild_bee_nest/Del()
	wild_bee_nests -= src
	..()

/obj/structure/wild_bee_nest/update_icon()
	if (!occupied)
		icon_state = "nest_empty"
		desc = "An old hollow in the trunk, empty but for a scrap of dark comb. Bees may settle here again."
	else if (comb >= 2)
		icon_state = "nest"
		desc = initial(desc)
	else
		icon_state = "nest_low"
		desc = "Honeybees stream in and out of a hollow in the trunk. Most of the comb has been torn out."

// Sits on the trunk of the tree on its tile.
/obj/structure/wild_bee_nest/proc/fit_to_tree(obj/structure/wild/W)
	if (!W)
		return
	// The hollow is drawn in the middle of the frame, up from its foot, so the
	// frame stands on the trunk's base at the trunk's centre.
	pixel_x = W.pixel_x + W.trunk_center_x - 15
	pixel_y = W.pixel_y

/obj/structure/wild_bee_nest/proc/smoked()
	return world.time < smoked_until

/obj/structure/wild_bee_nest/examine(mob/user)
	..()
	if (!occupied)
		return
	if (smoked())
		to_chat(user, SPAN_NOTICE("Smoke drifts through the hollow; the bees are sluggish and calm."))
	else
		to_chat(user, SPAN_WARNING("The bees guard the entrance. Smoke them before reaching in."))
	switch (comb)
		if (0)
			to_chat(user, "There is no comb left to take.")
		if (1)
			to_chat(user, "A single comb is left.")
		else
			to_chat(user, "You can see [comb] combs inside.")

/obj/structure/wild_bee_nest/attackby(obj/item/I, mob/user)
	if (!ishuman(user))
		return ..()
	if (occupied && is_bee_smoke(I))
		smoke_out(user)
		return TRUE
	if (is_tool(I, TOOL_KNIFE) || is_tool(I, TOOL_HATCHET))
		rob(user, TRUE)
		return TRUE
	return ..()

/obj/structure/wild_bee_nest/attack_hand(mob/user)
	if (ishuman(user))
		rob(user, FALSE)
		return TRUE
	return ..()

/obj/structure/wild_bee_nest/proc/smoke_out(mob/living/human/user)
	user.visible_message(SPAN_NOTICE("[user] wafts smoke into \the [src]."), SPAN_NOTICE("You waft smoke into the hollow. The humming drops to a drowsy murmur."))
	smoked_until = world.time + WILD_BEE_SMOKE_TIME

// Reach in and take one comb. A blade or axe opens the hollow faster.
/obj/structure/wild_bee_nest/proc/rob(mob/living/human/user, tooled)
	if (!occupied)
		to_chat(user, SPAN_NOTICE("The hollow is empty; the bees have gone."))
		return
	if (comb <= 0)
		to_chat(user, SPAN_NOTICE("There is no comb left in \the [src]."))
		return
	if (robbing)
		to_chat(user, SPAN_NOTICE("Someone is already reaching into \the [src]."))
		return
	if (!user.Adjacent(src))
		return
	robbing = TRUE
	if (!smoked())
		user.visible_message(SPAN_DANGER("[user] reaches into \the [src] and the bees boil out!"), SPAN_DANGER("You reach into the hollow and the bees boil out at you!"))
		wild_bee_attack(user, src)
	else
		user.visible_message(SPAN_NOTICE("[user] reaches carefully into \the [src]."), SPAN_NOTICE("You reach carefully into the smoky hollow."))
	var/took = do_after(user, tooled ? 50 : 120, src)
	robbing = FALSE
	if (!took || QDELETED(src) || QDELETED(user) || !user.Adjacent(src) || !occupied || comb <= 0)
		return
	comb--
	var/turf/T = get_turf(user)
	new /obj/item/weapon/reagent_containers/food/snacks/honeycomb(T)
	if (prob(25))
		new /obj/item/weapon/reagent_containers/food/snacks/brood_comb(T)
	user.adaptStat("farming", 1)
	if (comb <= 0)
		occupied = FALSE
		user.visible_message(SPAN_NOTICE("[user] tears the last comb from \the [src]. The bees swirl up and leave."), SPAN_NOTICE("You tear out the last comb. The colony swirls up out of the hollow and leaves for good."))
	else
		to_chat(user, SPAN_NOTICE("You pull out a dripping comb."))
	update_icon()

// The tree is felled: the nest falls with it and the colony leaves.
/obj/structure/wild_bee_nest/proc/tree_felled()
	var/turf/T = get_turf(src)
	if (T && occupied)
		for (var/i = 1, i <= comb, i++)
			new /obj/item/weapon/reagent_containers/food/snacks/honeycomb(T)
		visible_message(SPAN_WARNING("The bees' nest falls with the tree and the colony scatters."))
	qdel(src)

/obj/structure/wild/Destroy()
	if (trunk_center_x && wild_bee_nests.len && !persistence_active_operation && !persistence_save_in_progress)
		var/turf/T = get_turf(src)
		if (T)
			for (var/obj/structure/wild_bee_nest/N in T)
				N.tree_felled()
	return ..()

/////// Smoke

/proc/is_bee_smoke(obj/item/I)
	if (istype(I, /obj/item/weapon/smoke_bundle))
		var/obj/item/weapon/smoke_bundle/B = I
		return B.lit
	if (istype(I, /obj/item/bee_smoker))
		var/obj/item/bee_smoker/S = I
		return S.lit
	return istype(I, /obj/item/flashlight/torch) && isflamesource(I)

// A tied bundle of green grass and leaves. Lit from a flame it smoulders for a
// few minutes, giving off the thick smoke that calms bees.
/obj/item/weapon/smoke_bundle
	name = "smoke bundle"
	desc = "A tied bundle of green grass and leaves. Lit from a fire, it smoulders with thick smoke that calms bees."
	icon = 'icons/farming/wild_bees.dmi'
	icon_state = "smoke_bundle"
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	var/tmp/lit = FALSE
	var/tmp/burn_generation = 0

/obj/item/weapon/smoke_bundle/persistence_runtime_var(key)
	return key == "lit" || key == "burn_generation" || ..()

/obj/item/weapon/smoke_bundle/attackby(obj/item/W, mob/user)
	if (!lit && isflamesource(W))
		light(user, W)
		return TRUE
	return ..()

/obj/item/weapon/smoke_bundle/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (!lit && A != src && isflamesource(A))
		light(user, A)
		return TRUE
	return ..()

/obj/item/weapon/smoke_bundle/proc/light(mob/user, atom/source)
	if (lit)
		return
	lit = TRUE
	icon_state = "smoke_bundle_lit"
	name = "smouldering smoke bundle"
	if (user)
		user.visible_message(SPAN_NOTICE("[user] lights \the [src] from \the [source]; it smoulders with thick grey smoke."), SPAN_NOTICE("You light the bundle. It smoulders with thick grey smoke."))
	burn_generation++
	addtimer(CALLBACK(src, PROC_REF(burn_timeout), burn_generation), 3 MINUTES)

/obj/item/weapon/smoke_bundle/proc/burn_timeout(generation)
	if (!QDELETED(src) && lit && generation == burn_generation)
		burn_out()

/obj/item/weapon/smoke_bundle/proc/burn_out()
	var/mob/M = loc
	if (istype(M))
		to_chat(M, SPAN_NOTICE("\The [src] smoulders down to ash."))
		M.drop_from_inventory(src)
	qdel(src)

/////// The sting chase

/mob/living/human
	var/tmp/bee_chase_until = 0
	var/tmp/bee_stings = 0 // swelling from recent stings, wears off over time
	var/tmp/bee_stings_at = 0
	var/tmp/bee_reaction_at = -1

/mob/living/human/persistence_runtime_var(key)
	return key == "bee_chase_until" || key == "bee_stings" || key == "bee_stings_at" || key == "bee_reaction_at" || ..()

/obj/effect/bee_swarm
	name = "angry bees"
	desc = "A furious cloud of stinging bees."
	icon = 'icons/farming/wild_bees.dmi'
	icon_state = "bee_swarm"
	anchored = TRUE
	mouse_opacity = FALSE
	layer = MOB_LAYER + 0.2
	should_save = FALSE

// Bees chase the one person who disturbed them; nobody else is stung.
/proc/wild_bee_attack(mob/living/human/H, atom/origin, duration = WILD_BEE_CHASE_TIME)
	if (!istype(H) || H.stat == DEAD)
		return FALSE
	var/already = world.time < H.bee_chase_until
	H.bee_chase_until = max(H.bee_chase_until, world.time + duration)
	if (already)
		return TRUE
	var/obj/effect/bee_swarm/S = new(get_turf(H))
	H.bee_chase_step(get_turf(origin), S)
	return TRUE

// One step of the chase: the swarm keeps up with its target and may sting,
// until time runs out or the target gets away.
/mob/living/human/proc/bee_chase_step(turf/home, obj/effect/bee_swarm/S)
	if (QDELETED(S))
		bee_chase_until = 0
		return
	var/turf/T = get_turf(src)
	var/ended = stat == DEAD || world.time >= bee_chase_until
	if (!ended && (!T || !home || T.z != home.z || get_dist(T, home) > WILD_BEE_CHASE_RANGE))
		to_chat(src, SPAN_NOTICE("The bees fall back toward their nest."))
		ended = TRUE
	if (!ended && is_open_water(T))
		to_chat(src, SPAN_NOTICE("You duck into the water and the bees lose you."))
		ended = TRUE
	if (ended)
		bee_chase_until = 0
		qdel(S)
		return
	S.forceMove(T)
	if (prob(bee_sting_chance(src)))
		bee_sting()
	addtimer(CALLBACK(src, PROC_REF(bee_chase_step), home, S), WILD_BEE_CHASE_STEP)

// Clothing over the head, face, body and hands keeps most stings off.
/proc/bee_sting_chance(mob/living/human/H)
	var/chance = 70
	var/veil = istype(H.head, /obj/item/clothing/head/bee_veil)
	var/suit = istype(H.wear_suit, /obj/item/clothing/suit/beekeeper_suit)
	if (veil)
		chance -= 30
	else if (H.head)
		chance -= 15
	if (H.wear_mask)
		chance -= 10
	if (suit)
		chance -= 30
	else if (H.wear_suit)
		chance -= 15
	else if (H.w_uniform)
		chance -= 5
	if (H.gloves)
		chance -= 10
	// Veil and suit together leave almost nowhere to sting.
	return max(chance, (veil && suit) ? 2 : 10)

// One sting. Stings hurt and swell, and many at once can knock someone down,
// but never kill; an allergic reaction is worse but still not lethal.
/mob/living/human/proc/bee_sting()
	if (stat == DEAD)
		return
	bee_sting_decay()
	bee_stings++
	bee_stings_at = world.time
	var/zone = pick("head", "l_arm", "r_arm", "chest", "l_hand", "r_hand")
	var/allergic = find_trait("Bee Sting Allergy")
	var/resistant = find_trait("Sting Resistant")
	var/pain = allergic ? 12 : (resistant ? 2 : 6)
	adjustHalLoss(pain)
	if (health > 60)
		apply_damage(resistant ? 0.2 : 0.5, BRUTE, zone)
	to_chat(src, SPAN_DANGER("A bee stings your [parse_zone(zone)]!"))
	if (allergic)
		bee_allergic_reaction()
	else if (!resistant && bee_stings >= 8 && world.time >= bee_reaction_at)
		bee_reaction_at = world.time + 30 SECONDS
		visible_message(SPAN_DANGER("[src] staggers and falls under the stings!"), SPAN_DANGER("The stings swell and burn; your legs give way!"))
		Weaken(3)

// Stings swell for a few minutes, then go down.
/mob/living/human/proc/bee_sting_decay()
	if (bee_stings && world.time - bee_stings_at > 5 MINUTES)
		bee_stings = 0

/mob/living/human/proc/bee_allergic_reaction()
	eye_blurry = max(eye_blurry, 5)
	if (bee_stings < 2 || world.time < bee_reaction_at)
		to_chat(src, SPAN_WARNING("The sting swells fast and your skin starts to itch all over."))
		return
	bee_reaction_at = world.time + 45 SECONDS
	visible_message(SPAN_DANGER("[src]'s face swells and they gasp for air!"), SPAN_DANGER("Your throat tightens and your face swells. You can barely breathe!"))
	Weaken(6)
	stuttering = max(stuttering, 20)
	adjustHalLoss(25)
	// A bad reaction leaves you choking and helpless, but never kills.
	var/room = 40 - getOxyLoss()
	if (room > 0)
		adjustOxyLoss(min(15, room))

/////// Comb, wax and candles

/obj/item/weapon/reagent_containers/food/snacks/brood_comb
	name = "brood comb"
	desc = "A piece of comb packed with bee larvae. Rich and fatty, and eaten raw or roasted since the Stone Age."
	icon = 'icons/farming/wild_bees.dmi'
	icon_state = "brood_comb"
	filling_color = "#efe2b5"
	w_class = ITEM_SIZE_TINY
	non_vegetarian = TRUE
	rots = TRUE
	New()
		..()
		reagents.add_reagent("protein", 3)
		reagents.add_reagent("honey", 2)
		bitesize = 2

// Squeeze a comb into an open bowl, pot or bucket: honey runs out and a lump
// of crushed wax is left in your hand.
/obj/item/weapon/reagent_containers/food/snacks/honeycomb/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (istype(A, /obj/item/weapon/reagent_containers/glass) && user && user.Adjacent(A))
		var/obj/item/weapon/reagent_containers/glass/G = A
		if (!G.is_open_container())
			to_chat(user, SPAN_NOTICE("\The [G] is closed."))
			return TRUE
		var/honey = reagents ? reagents.get_reagent_amount("honey") : 0
		if (honey <= 0)
			to_chat(user, SPAN_NOTICE("There is no honey left in \the [src]."))
			return TRUE
		if (G.reagents.get_free_space() < honey)
			to_chat(user, SPAN_NOTICE("There is not enough room in \the [G]."))
			return TRUE
		user.visible_message(SPAN_NOTICE("[user] squeezes \the [src] over \the [G]."), SPAN_NOTICE("You squeeze \the [src] and honey runs into \the [G]."))
		if (!do_after(user, 30, G) || QDELETED(src) || QDELETED(G))
			return TRUE
		honey = reagents.get_reagent_amount("honey")
		if (honey <= 0 || G.reagents.get_free_space() < honey)
			return TRUE
		reagents.trans_id_to(G, "honey", honey)
		var/obj/item/weapon/crushed_comb/W = new(get_turf(user))
		user.drop_from_inventory(src)
		qdel(src)
		user.put_in_hands(W)
		return TRUE
	return ..()

/obj/item/weapon/crushed_comb
	name = "crushed comb"
	desc = "Squeezed-out comb, sticky with the last of the honey. Melt it over a flame to render beeswax."
	icon = 'icons/farming/wild_bees.dmi'
	icon_state = "crushed_comb"
	w_class = ITEM_SIZE_TINY

/obj/item/weapon/crushed_comb/attackby(obj/item/W, mob/user)
	if (isflamesource(W))
		render(user, W)
		return TRUE
	return ..()

/obj/item/weapon/crushed_comb/resolve_attackby(atom/A, mob/user, icon_x, icon_y)
	if (A != src && isflamesource(A))
		render(user, A)
		return TRUE
	return ..()

/obj/item/weapon/crushed_comb/proc/render(mob/user, atom/source)
	to_chat(user, SPAN_NOTICE("You hold \the [src] over \the [source] and let the wax melt and run together..."))
	if (!do_after(user, 40, source) || QDELETED(src) || !isflamesource(source))
		return
	var/obj/item/weapon/beeswax/B = new(get_turf(user))
	user.drop_from_inventory(src)
	qdel(src)
	user.put_in_hands(B)
	to_chat(user, SPAN_NOTICE("The wax cools into a golden cake of beeswax."))

/obj/item/weapon/beeswax
	name = "beeswax"
	desc = "A golden cake of rendered beeswax. Dip a rope wick into it to make a candle, or melt it with pitch for sealing wax."
	icon = 'icons/farming/wild_bees.dmi'
	icon_state = "beeswax"
	w_class = ITEM_SIZE_TINY
	flammable = TRUE

/obj/item/weapon/beeswax/attackby(obj/item/W, mob/user)
	if (treatable_cloth(W) && ishuman(user) && user.a_intent != I_HARM)
		return cloth_wax(W, src, user)
	if (istype(W, /obj/item/weapon/reagent_containers/glass) && W.reagents && W.reagents.get_reagent_amount("pitch") > 0)
		return make_sealing_wax(W, user)
	if (istype(W, /obj/item/stack/material/rope))
		var/obj/item/stack/material/rope/R = W
		user.visible_message(SPAN_NOTICE("[user] dips a wick into \the [src], shaping a candle."), SPAN_NOTICE("You warm \the [src] and dip a rope wick into it again and again, shaping a candle."))
		if (!do_after(user, 40, src) || QDELETED(src) || QDELETED(R) || R.amount < 1)
			return TRUE
		R.use(1)
		var/turf/T = get_turf(src)
		var/mob/M = loc
		if (istype(M))
			M.drop_from_inventory(src)
		qdel(src)
		new /obj/item/weapon/flame/candle/beeswax(T)
		return TRUE
	return ..()

// Burns longer and cleaner than tallow or lard.
/obj/item/weapon/flame/candle/beeswax
	name = "beeswax candle"
	desc = "A golden dipped candle of beeswax. It burns long and clean, with a faint smell of honey."
	icon = 'icons/farming/wild_bees.dmi'
	icon_state = "candle1_beeswax"
	item_state = "candle1"
	wax = 1400

/obj/item/weapon/flame/candle/beeswax/on_runtime_spawn()
	..()
	wax = rand(1300, 1450)

/obj/item/weapon/flame/candle/beeswax/update_icon()
	var/i = candle_wax_stage()
	icon_state = "candle[i][lit ? "_lit" : ""]_beeswax"

/obj/item/weapon/flame/candle/beeswax/candle_wax_stage()
	if (wax > 1100)
		return 1
	if (wax > 600)
		return 2
	return 3

/obj/item/weapon/flame/candle/beeswax/create_candle_remains()
	new /obj/item/trash/candle/beeswax(loc)

/obj/item/trash/candle/beeswax
	name = "beeswax candle stub"
	icon = 'icons/farming/wild_bees.dmi'
	icon_state = "candle4_beeswax"

/////// Nest upkeep and new nests (driven by flora_regrowth's worker)

/proc/wild_bee_nest_target(datum/flora_regrowth/F)
	if (!F)
		return 0
	return clamp(round(F.plant_target / 5), 0, WILD_BEE_NEST_CAP)

// One pass a minute: combs refill and empty hollows are settled again in
// season, and at most one new nest is placed on an unwatched tree.
/proc/wild_bee_cycle(datum/flora_regrowth/F)
	if (!wild_bee_season_active())
		return 0
	var/comb_chance = 100 / WILD_BEE_COMB_MINUTES
	var/return_chance = 100 / WILD_BEE_RETURN_MINUTES
	for (var/obj/structure/wild_bee_nest/N in wild_bee_nests.Copy())
		if (QDELETED(N) || !isturf(N.loc))
			wild_bee_nests -= N
			continue
		if (N.occupied)
			if (N.comb < WILD_BEE_MAX_COMB && prob(comb_chance))
				N.comb++
				N.update_icon()
		else if (prob(return_chance))
			N.occupied = TRUE
			N.comb = 1
			N.update_icon()
	if (wild_bee_nests.len >= wild_bee_nest_target(F))
		return 0
	for (var/i = 1, i <= WILD_BEE_SITE_ATTEMPTS, i++)
		var/turf/T = locate(rand(1, world.maxx), rand(1, world.maxy), rand(1, multiz_top_z()))
		if (wild_bee_place_nest(T))
			return 1
	return 0

/proc/wild_bee_place_nest(turf/T)
	if (!T || !(ecology_outdoor_climate(T) in wild_bee_climates()))
		return null
	if (locate(/obj/structure/wild_bee_nest) in T)
		return null
	var/obj/structure/wild/tree = null
	for (var/obj/structure/wild/W in T)
		if (wild_bee_tree(W))
			tree = W
			break
	if (!tree)
		return null
	if (ecology_visible_to_players(T) || flora_near_settlement(T))
		return null
	var/obj/structure/wild_bee_nest/N = new(T)
	N.fit_to_tree(tree)
	return N

#undef WILD_BEE_NEST_CAP
#undef WILD_BEE_MAX_COMB
#undef WILD_BEE_COMB_MINUTES
#undef WILD_BEE_RETURN_MINUTES
#undef WILD_BEE_SITE_ATTEMPTS
#undef WILD_BEE_SMOKE_TIME
#undef WILD_BEE_CHASE_TIME
#undef WILD_BEE_CHASE_STEP
#undef WILD_BEE_CHASE_RANGE
