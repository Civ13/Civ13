// Kept bee colonies in fixed-comb hives: log hives, sun-dried clay hives and
// woven skeps (bee farming 2; wild nests are in wild_bees.dm).
//
// Getting bees: in spring (or the wet season) a strong colony, kept or wild,
// casts a swarm that hangs in a cluster nearby for a while. Pull an empty hive
// next to the cluster and click the cluster to shake it in. Swarms are calm
// and do not sting.
//
// A colony grows and stores comb while there are flowers, crops and trees to
// forage in the warm or wet season, and eats its stores through autumn and
// winter or the dry season. With no comb left it dwindles and dies. Combs are
// fixed in these hives, so cutting one out (smoke first, or be stung) also
// kills some brood: honey now costs colony strength.
//
// Cost: hives never process. The flora regrowth worker (flora_regrowth.dm)
// calls kept_hive_cycle() once a minute and it runs every third call: one pass
// over the kept_hives registry with a cached forage count per hive, refreshed
// by one range() scan at most every half hour.

#define KEPT_HIVE_TICK_EVERY 3 // flora cycles (minutes) per colony tick
#define KEPT_HIVE_FORAGE_RANGE 5
#define KEPT_HIVE_FORAGE_FULL 16 // forage points for the best growth
#define KEPT_HIVE_FORAGE_REFRESH (30 MINUTES)
#define KEPT_HIVE_SMOKE_TIME (45 SECONDS)
#define BEE_SWARM_LIFETIME (20 MINUTES)

var/global/list/kept_hives = list()
var/global/kept_hive_cycle_count = 0

/obj/structure/kept_hive
	name = "log hive"
	desc = "A hollowed log with a lid board and a small entrance hole, made to house a colony of bees."
	icon = 'icons/farming/kept_hives.dmi'
	icon_state = "log_hive"
	density = TRUE
	anchored = FALSE
	flammable = TRUE
	var/base_state = "log_hive"
	var/max_combs = 6
	var/occupied = FALSE
	var/strength = 0 // colony size, 0 to 100
	var/combs = 0 // stored combs of honey
	var/tmp/smoked_until = 0
	var/tmp/cutting = FALSE
	var/tmp/forage = 0
	var/tmp/forage_at = -1

/obj/structure/kept_hive/persistence_runtime_var(key)
	return key == "cutting" || key == "forage" || key == "forage_at" || ..()

/obj/structure/kept_hive/clay
	name = "clay hive"
	desc = "A sun-dried clay cylinder laid on a mud bench, with a small entrance in its end cap, made to house a colony of bees."
	icon_state = "clay_hive"
	base_state = "clay_hive"
	max_combs = 8
	flammable = FALSE

/obj/structure/kept_hive/skep
	name = "skep"
	desc = "A dome of coiled, woven straw on a board, made to house a colony of bees."
	icon_state = "skep"
	base_state = "skep"
	max_combs = 5

/obj/structure/kept_hive/New()
	..()
	kept_hives |= src
	update_icon()

/obj/structure/kept_hive/after_load()
	. = ..()
	kept_hives |= src
	update_icon()

/obj/structure/kept_hive/Destroy()
	kept_hives -= src
	return ..()

/obj/structure/kept_hive/Del()
	kept_hives -= src
	..()

/obj/structure/kept_hive/update_icon()
	icon_state = occupied ? "[base_state]_bees" : base_state
	overlays.Cut()
	if (occupied && smoked())
		overlays += image(icon, "hive_smoke")
	// An empty hive can be pulled to a swarm; a lived-in one stays put.
	anchored = occupied

/obj/structure/kept_hive/proc/smoked()
	return world.time < smoked_until

/obj/structure/kept_hive/proc/strength_text()
	switch (strength)
		if (70 to INFINITY)
			return "a strong, busy colony"
		if (35 to 70)
			return "a steady colony"
		else
			return "a weak colony"

/obj/structure/kept_hive/examine(mob/user)
	..()
	if (!occupied)
		to_chat(user, "It is empty. Pull it next to a hanging swarm in spring and click the swarm to shake the bees in.")
		return
	to_chat(user, "It holds [strength_text()].")
	var/skilled = ishuman(user) && user:getStatCoeff("farming") >= 1.3
	if (skilled)
		to_chat(user, "You judge the colony at about [round(strength)]% strength, with [combs] of [max_combs] combs of honey stored.")
	else
		to_chat(user, combs ? "It feels heavy with honey." : "It feels light; there is little honey inside.")
	if (!wild_bee_season_active() && combs <= 1)
		to_chat(user, SPAN_WARNING("The bees have little left to live on until the flowers return."))
	if (smoked())
		to_chat(user, SPAN_NOTICE("Smoke drifts round the entrance; the bees are calm."))

/obj/structure/kept_hive/attackby(obj/item/I, mob/user)
	if (!ishuman(user))
		return ..()
	if (occupied && is_bee_smoke(I))
		user.visible_message(SPAN_NOTICE("[user] puffs smoke into \the [src]."), SPAN_NOTICE("You puff smoke in at the entrance. The humming drops to a drowsy murmur."))
		smoked_until = world.time + KEPT_HIVE_SMOKE_TIME
		update_icon()
		addtimer(CALLBACK(src, PROC_REF(update_icon)), KEPT_HIVE_SMOKE_TIME + 1)
		return TRUE
	if (occupied && is_tool(I, TOOL_KNIFE))
		cut_comb(user, TRUE)
		return TRUE
	return ..()

/obj/structure/kept_hive/attack_hand(mob/user)
	if (occupied && ishuman(user))
		cut_comb(user, FALSE)
		return TRUE
	return ..()

// Fixed comb has to be cut out, and the brood in it dies with it.
/obj/structure/kept_hive/proc/cut_comb(mob/living/human/user, knife)
	if (combs <= 0)
		to_chat(user, SPAN_NOTICE("There is no honey comb in \the [src] to cut."))
		return
	if (cutting)
		to_chat(user, SPAN_NOTICE("Someone is already working at \the [src]."))
		return
	if (!user.Adjacent(src))
		return
	cutting = TRUE
	if (!smoked())
		user.visible_message(SPAN_DANGER("[user] opens \the [src] and the bees pour out!"), SPAN_DANGER("You open the hive and the bees pour out at you!"))
		wild_bee_attack(user, src)
	else
		user.visible_message(SPAN_NOTICE("[user] opens \the [src] and starts cutting out a comb."), SPAN_NOTICE("You open the smoky hive and start cutting out a comb."))
	var/done = do_after(user, knife ? 60 : 150, src)
	cutting = FALSE
	if (!done || QDELETED(src) || QDELETED(user) || !user.Adjacent(src) || !occupied || combs <= 0)
		return
	combs--
	strength = max(strength - 8, 1)
	var/turf/T = get_turf(user)
	new /obj/item/weapon/reagent_containers/food/snacks/honeycomb(T)
	if (prob(25))
		new /obj/item/weapon/reagent_containers/food/snacks/brood_comb(T)
	user.adaptStat("farming", 1)
	to_chat(user, SPAN_NOTICE("You cut out a heavy comb of honey[strength < 35 ? ". The colony looks thin now" : ""]."))
	update_icon()

/obj/structure/kept_hive/proc/settle(colony_strength)
	occupied = TRUE
	strength = clamp(colony_strength, 10, 100)
	combs = 0
	forage_at = -1
	update_icon()

/obj/structure/kept_hive/proc/die_out()
	occupied = FALSE
	strength = 0
	combs = 0
	update_icon()
	visible_message(SPAN_WARNING("The last bees in \the [src] have died."))

// Flowering and fruiting things within reach: crops, wild plants and trees.
/obj/structure/kept_hive/proc/refresh_forage()
	forage = bee_forage_points(src)
	forage_at = world.time

// Shared with frame hives (beekeeping.dm).
/proc/bee_forage_points(atom/A)
	var/points = 0
	for (var/obj/structure/O in range(KEPT_HIVE_FORAGE_RANGE, A))
		if (istype(O, /obj/structure/farming/plant))
			var/obj/structure/farming/plant/P = O
			if (P.stage <= P.readyStageMax)
				points += 1
		else if (istype(O, /obj/structure/wild/tree) || istype(O, /obj/structure/wild/jungle) || istype(O, /obj/structure/wild/bush))
			points += 0.5
		if (points >= KEPT_HIVE_FORAGE_FULL)
			break
	return min(points, KEPT_HIVE_FORAGE_FULL)

/proc/bee_forage_full()
	return KEPT_HIVE_FORAGE_FULL

/obj/structure/kept_hive/proc/colony_tick(active, swarm_season)
	if (!occupied)
		return
	if (active)
		if (forage_at < 0 || world.time - forage_at > KEPT_HIVE_FORAGE_REFRESH)
			refresh_forage()
		var/f = forage / KEPT_HIVE_FORAGE_FULL
		if (f < 0.1)
			strength = max(strength - 1, 1)
		else
			strength = min(strength + 4 * f, 100)
		if (combs < max_combs && prob(strength * f * 0.5))
			combs++
		if (swarm_season && strength >= 80 && prob(8))
			cast_swarm(src, 40)
			strength -= 40
	else if (prob(strength * 0.1))
		if (combs > 0)
			combs--
		else
			strength -= 15
			if (strength <= 0)
				die_out()
				return
	update_icon()

/////// Swarms

/obj/structure/bee_swarm_cluster
	name = "hanging swarm"
	desc = "A great humming beard of bees hangs here, resting while their scouts look for a new home. Swarming bees are calm. Pull an empty hive next to it and click the swarm to shake it in."
	icon = 'icons/farming/kept_hives.dmi'
	icon_state = "swarm_cluster"
	anchored = TRUE
	density = FALSE
	layer = 5.12
	should_save = FALSE
	var/colony_strength = 40
	var/tmp/shaking = FALSE

/obj/structure/bee_swarm_cluster/New(loc, colony = 40)
	..(loc)
	colony_strength = colony
	addtimer(CALLBACK(src, PROC_REF(fly_off)), BEE_SWARM_LIFETIME)

/obj/structure/bee_swarm_cluster/proc/fly_off()
	if (QDELETED(src))
		return
	visible_message(SPAN_NOTICE("The swarm lifts off in a roaring cloud and flies away."))
	qdel(src)

/obj/structure/bee_swarm_cluster/attack_hand(mob/user)
	if (!ishuman(user))
		return ..()
	if (shaking)
		return TRUE
	var/obj/structure/H = bee_swarm_home_near(src)
	if (!H)
		to_chat(user, SPAN_NOTICE("You need an empty hive right next to the swarm to shake it into."))
		return TRUE
	shaking = TRUE
	user.visible_message(SPAN_NOTICE("[user] starts brushing the swarm down into \the [H]."), SPAN_NOTICE("You brush and shake the swarm down into \the [H]..."))
	var/done = do_after(user, 50, src)
	shaking = FALSE
	if (!done || QDELETED(src) || QDELETED(H) || get_dist(H, src) > 1 || bee_swarm_home_near(src) != H)
		return TRUE
	H:settle(colony_strength)
	user.visible_message(SPAN_NOTICE("The bees march into \the [H] and settle."), SPAN_NOTICE("The bees march into \the [H], fanning their wings. They have a new home."))
	qdel(src)
	return TRUE

// An empty nucleus box can catch the swarm to carry it to a frame hive.
/obj/structure/bee_swarm_cluster/attackby(obj/item/I, mob/user)
	if (!istype(I, /obj/item/nucleus_box) || !ishuman(user))
		return ..()
	var/obj/item/nucleus_box/B = I
	if (B.full)
		to_chat(user, SPAN_NOTICE("\The [B] already has bees in it."))
		return TRUE
	if (shaking)
		return TRUE
	shaking = TRUE
	user.visible_message(SPAN_NOTICE("[user] holds \the [B] under the swarm and gives the branch a sharp knock."), SPAN_NOTICE("You hold \the [B] under the swarm and knock the branch..."))
	var/done = do_after(user, 40, src)
	shaking = FALSE
	if (!done || QDELETED(src) || QDELETED(B) || B.full)
		return TRUE
	B.fill(colony_strength)
	to_chat(user, SPAN_NOTICE("The swarm drops into \the [B] in a humming mass. Close it up and carry it to an empty frame hive."))
	qdel(src)
	return TRUE

// Hang a swarm on an open tile near the colony, or nowhere when boxed in.
/proc/cast_swarm(atom/origin, colony)
	var/turf/home = get_turf(origin)
	if (!home)
		return null
	var/list/sites = list()
	for (var/turf/T in range(2, home))
		if (T == home || T.density || !ecology_outdoor_climate(T))
			continue
		if (locate(/obj/structure/bee_swarm_cluster) in T)
			continue
		sites += T
	if (!sites.len)
		return null
	return new /obj/structure/bee_swarm_cluster(pick(sites), colony)

/////// The colony tick (driven by flora_regrowth's worker)

/proc/kept_hive_cycle()
	kept_hive_cycle_count++
	// Wild nests swarm too, so the first kept colonies have somewhere to come from.
	if (pollen_season())
		for (var/obj/structure/wild_bee_nest/N in wild_bee_nests)
			if (N.occupied && N.comb >= 3 && prob(1))
				cast_swarm(N, 35)
	if (kept_hive_cycle_count % KEPT_HIVE_TICK_EVERY)
		return 0
	var/active = wild_bee_season_active()
	var/swarm_season = pollen_season()
	var/ticked = 0
	for (var/obj/structure/kept_hive/H in kept_hives.Copy())
		if (QDELETED(H))
			kept_hives -= H
			continue
		if (!isturf(H.loc))
			continue
		H.colony_tick(active, swarm_season)
		ticked++
	for (var/obj/structure/beehive/F in frame_hives.Copy())
		if (QDELETED(F))
			frame_hives -= F
			continue
		if (!isturf(F.loc))
			continue
		F.colony_tick(active, swarm_season)
		ticked++
	return ticked

#undef KEPT_HIVE_TICK_EVERY
#undef KEPT_HIVE_FORAGE_RANGE
#undef KEPT_HIVE_FORAGE_FULL
#undef KEPT_HIVE_FORAGE_REFRESH
#undef KEPT_HIVE_SMOKE_TIME
#undef BEE_SWARM_LIFETIME
