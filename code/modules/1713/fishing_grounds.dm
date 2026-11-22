// Fishing grounds (docs/fishing-grounds.md).
//
// Fish belong to the water. Every 16x16 stretch of water of one kind (salt,
// fresh, jungle river, swamp, flooded bed) is a ground with a capacity and a
// stock. Poles, rods, nets, spears and sharpened sticks all draw from the
// ground under the tile they are used on, and the chance to land a fish falls
// as the ground thins.
//
// Nothing ticks. A ground is made the first time someone fishes it and works
// out its regrowth from the time that passed when it is next asked. A ground
// nobody has fished is full and costs nothing.
//
// Grounds short of fish are saved with the durable world metadata in the map
// field fishing_grounds_state (field version 5), as six values a ground:
// kind, cell x, cell y, z, capacity, stock. The time a server is down does not
// count towards regrowth.
//
// Regrowth depends on what is left: fastest at half stock (one fish in four
// minutes), slow near empty and near full. A ground fished to nothing only
// recovers while a neighbouring ground of its kind still holds fish.

#define FISH_GROUND_SIZE 16
#define FISH_GROUND_STEP (1 MINUTES)
#define FISH_GROUND_MAX_STEPS 600
// Fish a minute that drift in from neighbouring grounds, whatever the stock.
#define FISH_GROUND_SPILL 0.0625
#define FISH_BAIT_USES 3
#define FISH_BAIT_BONUS 30
// A thin ground still gives this share of a tool's chance.
#define FISH_THIN_SHARE 0.25
// The open sea is wide: a line finds fewer fish than its stock suggests.
#define FISH_DEEP_SEA_SHARE 0.6
// A cast net: each of its chances is worse than a line's, but one throw can land several fish.
#define FISH_NET_CHANCE 25
#define FISH_NET_HAUL 3
// A trawl dragged behind a ship: a longer wait, and a bigger haul than any
// other gear. It is what empties a ground.
#define FISH_TRAWL_WAIT 200
#define FISH_TRAWL_CHANCE 35
#define FISH_TRAWL_HAUL 6
// Conditions (fish_condition_factor): what the season, the sky and the river
// do to a cast.
#define FISH_RUN_FACTOR 1.5
#define FISH_RUN_SALMON 85
#define FISH_RUN_REGROWTH 2
#define FISH_RAIN_FACTOR 1.25
#define FISH_STORM_SEA_FACTOR 0.5
#define FISH_STORM_RIVER_FACTOR 0.75
#define FISH_SPATE_FACTOR 0.6
#define FISH_LOW_POOL_FACTOR 1.2
// From a ship (fish_ship_factor): a running engine scares fish; a line towed
// at slow ahead is trolling and fishes better, at full ahead it skips.
#define FISH_ENGINE_FACTOR 0.6
#define FISH_TROLL_SLOW 1.3
#define FISH_TROLL_FULL 0.5
// Chance a watched tile of ankle-deep floodwater strands a fish in a river minute.
#define FISH_STRAND_CHANCE 2
// Under a passing shoal (fish_shoals.dm): the share of the catch that is
// herring, and the chance a landed fish came with the shoal and leaves the
// ground's own stock alone.
#define FISH_SHOAL_HERRING 60
#define FISH_SHOAL_FREE 50

// Fishing water kinds: code/__defines/fishing.dm

// "kind,cell x,cell y,z" -> /datum/fishing_ground
var/global/list/fishing_grounds = list()

/datum/fishing_ground
	var/kind
	var/cx = 0
	var/cy = 0
	var/z = 0
	var/capacity = 1
	var/stock = 1
	var/since = 0

/datum/fishing_ground/New(_kind, _cx, _cy, _z, _capacity)
	..()
	kind = _kind
	cx = _cx
	cy = _cy
	z = _z
	capacity = max(1, _capacity)
	stock = capacity
	since = world.time

/proc/fishing_ground_key(kind, cx, cy, z)
	return "[kind],[cx],[cy],[z]"

// ---- Saving ----

/obj/map_metadata/var/list/fishing_grounds_state = list()

// The list last written to, or read from, the map.
var/global/list/fishing_grounds_published = null

// Writes every ground short of fish to the map, where the durable world save
// picks it up, and forgets the grounds that have filled up again.
/proc/fishing_grounds_publish()
	if (!map)
		return
	var/list/state = list()
	for (var/key in fishing_grounds.Copy())
		var/datum/fishing_ground/G = fishing_grounds[key]
		G.settle()
		if (G.stock >= G.capacity)
			fishing_grounds -= key
			continue
		state += list(G.kind, G.cx, G.cy, G.z, G.capacity, round(G.stock, 0.01))
	fishing_grounds_published = state
	map.fishing_grounds_state = state

// A save loaded since the last look brings its own grounds.
/proc/fishing_grounds_sync()
	if (!map || map.fishing_grounds_state == fishing_grounds_published)
		return
	var/list/state = map.fishing_grounds_state
	fishing_grounds_published = state
	fishing_grounds = list()
	if (!islist(state) || state.len % 6)
		return
	var/static/list/kinds = list(FISH_WATER_SALT, FISH_WATER_FRESH, FISH_WATER_JUNGLE, FISH_WATER_SWAMP, FISH_WATER_FLOODED)
	for (var/i = 1, i + 5 <= state.len, i += 6)
		var/kind = state[i]
		var/capacity = state[i + 4]
		var/stock = state[i + 5]
		if (!(kind in kinds) || !isnum(state[i + 1]) || !isnum(state[i + 2]) || !isnum(state[i + 3]) || !isnum(capacity) || !isnum(stock) || capacity < 1)
			continue
		var/datum/fishing_ground/G = new /datum/fishing_ground(kind, state[i + 1], state[i + 2], state[i + 3], capacity)
		G.stock = min(G.capacity, max(0, stock))
		fishing_grounds[fishing_ground_key(kind, G.cx, G.cy, G.z)] = G

// TRUE while a neighbouring ground of the same kind holds a fish. A neighbour
// nobody has fished is full.
/datum/fishing_ground/proc/neighbours_have_fish()
	for (var/dx = -1, dx <= 1, dx++)
		for (var/dy = -1, dy <= 1, dy++)
			if (!dx && !dy)
				continue
			var/datum/fishing_ground/G = fishing_grounds[fishing_ground_key(kind, cx + dx, cy + dy, z)]
			if (!G || G.stock >= 1)
				return TRUE
	return FALSE

// Fish gained in one step at this stock.
/datum/fishing_ground/proc/growth(spill)
	. = max(stock * (1 - stock / capacity) / capacity, spill)
	if (kind == FISH_WATER_FRESH && fish_run_season())
		. *= FISH_RUN_REGROWTH // the run brings fish up from the sea
	// Fouled river water holds fewer fish (river_foul.dm).
	if (kind != FISH_WATER_SALT)
		. *= river_foul_fish_factor(cx * FISH_GROUND_SIZE + FISH_GROUND_SIZE / 2, cy * FISH_GROUND_SIZE + FISH_GROUND_SIZE / 2, z)

// Brings the stock up to now.
/datum/fishing_ground/proc/settle()
	if (stock >= capacity)
		stock = capacity
		since = world.time // a full ground does not bank regrowth
		return
	var/steps = round((world.time - since) / FISH_GROUND_STEP)
	if (steps <= 0)
		return
	if (steps > FISH_GROUND_MAX_STEPS)
		stock = capacity
		since = world.time
		return
	since += steps * FISH_GROUND_STEP
	var/spill = neighbours_have_fish() ? FISH_GROUND_SPILL : 0
	for (var/i = 1, i <= steps, i++)
		stock += growth(spill)
		if (stock >= capacity)
			stock = capacity
			since = world.time
			break

// Whole fish that can be caught now.
/datum/fishing_ground/proc/available()
	settle()
	return round(stock)

// 0 (empty) to 1 (full).
/datum/fishing_ground/proc/fullness()
	settle()
	return stock / capacity

/datum/fishing_ground/proc/take(n = 1)
	if (available() < n)
		return FALSE
	if (stock >= capacity)
		since = world.time
	stock -= n
	fishing_grounds_publish()
	return TRUE

// ---- Water ----

// The kind of fishing water T is, or null when nothing can be caught in it.
/proc/fish_water_kind(turf/T)
	if (!istype(T, /turf/floor/beach/water) || T.density)
		return null
	if (istype(T, /turf/floor/beach/water/ice) || istype(T, /turf/floor/beach/water/deep/saltwater/underwater))
		return null
	if (istype(T, /turf/floor/beach/water/swamp) || istype(T, /turf/floor/beach/water/deep/swamp))
		return FISH_WATER_SWAMP
	if (istype(T, /turf/floor/beach/water/flooded))
		return FISH_WATER_FLOODED
	var/turf/floor/F = T
	if (F.salty)
		return FISH_WATER_SALT
	if (istype(T, /turf/floor/beach/water/jungle) || istype(T, /turf/floor/beach/water/deep/jungle))
		return FISH_WATER_JUNGLE
	return FISH_WATER_FRESH

/proc/fish_water_deep(turf/T)
	return istype(T, /turf/floor/beach/water/deep)

// Fish a full ground of this water holds. The coastal shelf is the richest
// water; the open ocean and still, stale water the poorest.
/proc/fish_water_capacity(turf/T, kind)
	switch (kind)
		if (FISH_WATER_SWAMP)
			return 3
		if (FISH_WATER_FLOODED)
			return 2
		if (FISH_WATER_SALT)
			return fish_water_deep(T) ? 6 : 12
	return fish_water_deep(T) ? 10 : 6

// The ground T lies in, made when create is set. A ground takes the capacity
// of the best water anyone has fished in it.
/proc/fishing_ground_at(turf/T, create = TRUE)
	var/kind = fish_water_kind(T)
	if (!kind)
		return null
	var/capacity = fish_water_capacity(T, kind)
	var/datum/fishing_ground/G = fishing_ground_cell(T, kind, capacity, create)
	if (G && capacity > G.capacity)
		G.settle()
		G.stock += capacity - G.capacity
		G.capacity = capacity
	return G

// What a person can judge of the fish in this water, or null for no water.
/proc/fish_ground_reading(turf/T)
	if (!fish_water_kind(T))
		return null
	var/datum/fishing_ground/G = fishing_ground_at(T, FALSE)
	var/full = G ? G.fullness() : 1
	if (fish_shoal_at(T))
		return "The water flickers with silver: a great shoal is passing through."
	if (G && G.available() < 1)
		return "Nothing stirs in the water. This stretch is fished out for now."
	if (full >= 0.75)
		return "The water is alive with fish."
	if (full >= 0.4)
		return "Fish move below the surface."
	return "A few shapes move below. This stretch has been fished hard."

/turf/floor/beach/water/examine(mob/user)
	..()
	if (ishuman(user) && get_dist(user, src) <= 2)
		var/reading = fish_ground_reading(src)
		if (reading)
			to_chat(user, reading)
			var/conditions = fish_condition_reading(src, fish_water_kind(src))
			if (conditions)
				to_chat(user, conditions)

// ---- Conditions ----

// Autumn: salmon run up the rivers.
/proc/fish_run_season()
	return season == SEASON_FALL

// What the season, the weather overhead and the state of the river do to a
// tool's chance in this water. run: the salmon run is on. sky: WEATHER_NONE,
// WEATHER_WET or WEATHER_EXTREME. stage: the river's stage in levels above
// normal (0 away from a charted river).
/proc/fish_condition_factor(kind, deep, run, sky, stage)
	. = 1
	var/river = kind == FISH_WATER_FRESH || kind == FISH_WATER_JUNGLE
	if (run && kind == FISH_WATER_FRESH)
		. *= FISH_RUN_FACTOR
	if (sky == WEATHER_WET)
		. *= FISH_RAIN_FACTOR // fish rise to feed in the rain
	else if (sky == WEATHER_EXTREME)
		. *= kind == FISH_WATER_SALT ? FISH_STORM_SEA_FACTOR : FISH_STORM_RIVER_FACTOR
	if (river)
		if (stage >= 1)
			. *= FISH_SPATE_FACTOR // a river in spate runs brown and fast
		else if (stage <= -1 && deep)
			. *= FISH_LOW_POOL_FACTOR // at low water the fish crowd into the pools

/proc/fish_condition_factor_at(turf/T, kind)
	return fish_condition_factor(kind, fish_water_deep(T), fish_run_season(), weather_at(T), river_stage_at(T)) * fish_shoal_factor(T)

// A line for the water's examine text, or null when nothing is out of the ordinary.
/proc/fish_condition_reading(turf/T, kind)
	var/river = kind == FISH_WATER_FRESH || kind == FISH_WATER_JUNGLE
	var/stage = river_stage_at(T)
	if (river && stage >= 1)
		return "The river is running high and brown; fish will be hard to find in it."
	var/sky = weather_at(T)
	if (sky == WEATHER_EXTREME)
		return kind == FISH_WATER_SALT ? "The sea is too rough for good fishing." : "The storm is churning the water."
	if (kind == FISH_WATER_FRESH && fish_run_season())
		return "The salmon are running."
	if (sky == WEATHER_WET)
		return "Fish are rising to the rain."
	if (river && stage <= -1 && fish_water_deep(T))
		return "The river is low, and the fish have gathered in the deep pools."
	return null

// ---- The catch ----

// What comes up. baited: bait on the line. towed: a line trolled from a ship.
// shoal: a shoal is passing (fish_shoals.dm).
/proc/fish_catch_type(turf/T, kind, baited, towed = FALSE, shoal = FALSE)
	switch (kind)
		if (FISH_WATER_SALT)
			var/deep = fish_water_deep(T)
			// Tuna hunt in open water and only take something that moves or smells.
			if (deep && ((towed && prob(25)) || (baited && !towed && prob(12))))
				return /obj/item/weapon/reagent_containers/food/snacks/rawfish/tuna
			if (shoal && prob(FISH_SHOAL_HERRING))
				return /obj/item/weapon/reagent_containers/food/snacks/rawfish/herring
			if (deep)
				if (prob(55))
					return /obj/item/weapon/reagent_containers/food/snacks/rawfish/cod
				if (baited && prob(20))
					return /obj/item/weapon/reagent_containers/food/snacks/pink_squid
				return /obj/item/weapon/reagent_containers/food/snacks/rawfish
			if (prob(35))
				return /obj/item/weapon/reagent_containers/food/snacks/rawfish/herring
			if (prob(30))
				return /obj/item/weapon/reagent_containers/food/snacks/rawfish/cod
			return /obj/item/weapon/reagent_containers/food/snacks/rawfish
		if (FISH_WATER_FRESH)
			if (prob(fish_run_season() ? FISH_RUN_SALMON : 50))
				return /obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon
			if (fish_water_deep(T) && prob(40))
				return /obj/item/weapon/reagent_containers/food/snacks/rawfish/catfish
			if (prob(50))
				return /obj/item/weapon/reagent_containers/food/snacks/rawfish/trout
		if (FISH_WATER_JUNGLE)
			if (prob(35))
				return /obj/item/weapon/reagent_containers/food/snacks/rawfish/catfish
			if (prob(50))
				return /obj/item/weapon/reagent_containers/food/snacks/rawfish/salmon
		if (FISH_WATER_SWAMP)
			if (prob(40))
				return /obj/item/weapon/reagent_containers/food/snacks/rawfish/catfish
	return /obj/item/weapon/reagent_containers/food/snacks/rawfish

// ---- Tools ----

// How W fishes: list(wait, chance at a full ground, TRUE for a spear, fish a
// cast can land), or null when it is no fishing tool. A line or a spear takes
// one fish at a time; a cast net can come up with several.
/proc/fishing_tool_profile(obj/item/W)
	if (istype(W, /obj/item/weapon/fishing/trawl))
		return list(FISH_TRAWL_WAIT, FISH_TRAWL_CHANCE, FALSE, FISH_TRAWL_HAUL)
	if (istype(W, /obj/item/weapon/fishing/net))
		return list(150, FISH_NET_CHANCE, FALSE, FISH_NET_HAUL)
	if (istype(W, /obj/item/weapon/fishing/modern))
		return list(120, 40, FALSE, 1)
	if (istype(W, /obj/item/weapon/fishing))
		return list(150, 30, FALSE, 1)
	if (spear_fishing_tool(W))
		return list(spear_fishing_delay(), spear_fishing_chance(), TRUE, 1)
	if (istype(W, /obj/item/weapon/branch))
		var/obj/item/weapon/branch/B = W
		if (B.sharpened)
			return list(120, 20, TRUE, 1)
	return null

// A trawl: a bag of net held open by two boards and dragged behind a ship
// that is making way (fish_troll). Industrial: recipe in
// config/crafting/material_recipes_global.txt, research node rail_steam.
/obj/item/weapon/fishing/trawl
	name = "trawl net"
	desc = "A long bag of tarred net with cork floats and two heavy boards to hold its mouth open. Shoot it from a ship that is under way, at slow or half ahead, and it comes up with whatever was in its path."
	icon = 'icons/obj/fishing_gear.dmi'
	icon_state = "trawl_net"
	w_class = ITEM_SIZE_LARGE
	slot_flags = null
	force = WEAPON_FORCE_WEAK
	throwforce = WEAPON_FORCE_WEAK
	attack_verb = list("slapped")

// Bait: raw meat or raw fish cut onto a line.
/obj/item/weapon/fishing/var/bait_uses = 0

/obj/item/weapon/fishing/proc/is_bait(obj/item/I)
	return istype(I, /obj/item/weapon/reagent_containers/food/snacks/meat) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/rawfish)

/obj/item/weapon/fishing/attackby(obj/item/W as obj, mob/user as mob)
	if (!is_bait(W))
		return ..()
	if (istype(src, /obj/item/weapon/fishing/net) || istype(src, /obj/item/weapon/fishing/trawl))
		to_chat(user, SPAN_WARNING("A net takes whatever swims into it. Bait is for a line."))
		return
	if (bait_uses > 0)
		to_chat(user, SPAN_WARNING("\The [src] is already baited."))
		return
	var/bait_name = W.name
	user.drop_from_inventory(W)
	qdel(W)
	bait_uses = FISH_BAIT_USES
	to_chat(user, SPAN_NOTICE("You cut up \the [bait_name] and bait \the [src]. It's good for [FISH_BAIT_USES] casts."))

/obj/item/weapon/fishing/examine(mob/user, var/distance = -1)
	..()
	if (bait_uses > 0)
		to_chat(user, SPAN_NOTICE("It is baited for [bait_uses] more cast\s."))

// A tool's chance on this ground before the water and the weather have their
// say: bait added, then scaled by how full the ground is.
/proc/fish_tool_chance(list/profile, baited, datum/fishing_ground/G)
	return (profile[2] + (baited ? FISH_BAIT_BONUS : 0)) * (FISH_THIN_SHARE + (1 - FISH_THIN_SHARE) * G.fullness())

// ---- Fishing ----

/mob/living/human/var/tmp/ocean_fishing = FALSE

/mob/living/human/proc/on_boat_deck()
	if (istype(driver_vehicle, /obj/structure/vehicle/boat) || istype(driver_vehicle, /obj/structure/vehicle/raft))
		return TRUE
	var/turf/T = get_turf(src)
	if (!istype(T, /turf/floor/beach/water))
		return FALSE
	return (locate(/obj/structure/vehicleparts/frame) in T) || (locate(/obj/structure/vehicleparts/axis) in T)

// Somewhere to stand over deep water: a deck, a bridge or a pier.
/mob/living/human/proc/fishing_footing()
	var/turf/T = get_turf(src)
	if (!fish_water_deep(T))
		return TRUE
	return on_boat_deck() || T.iscovered()

/turf/floor/beach/water/attackby(obj/item/C as obj, mob/user as mob)
	if (ishuman(user) && fishing_tool_profile(C))
		fish_cast(C, user)
		return
	..()

// An axe, pick or chisel on ice cuts a fishing hole (ice_fishing.dm), or on
// harm intent breaks the tile open (ice_breaking.dm).
/turf/floor/beach/water/ice/attackby(obj/item/C as obj, mob/user as mob)
	if (ishuman(user) && ice_hole_tool_delay(C))
		ice_hole_cut(src, C, user)
		return
	// A crowbar cannot cut a hole, but it breaks the ice (ice_breaking.dm).
	if (ishuman(user) && ice_break_tool_delay(C))
		ice_break(src, C, user)
		return
	..()

/turf/floor/beach/water/proc/fish_cast(obj/item/W, mob/living/human/H)
	var/list/profile = fishing_tool_profile(W)
	if (!profile)
		return
	if (H.ocean_fishing)
		to_chat(H, SPAN_WARNING("You are already fishing."))
		return
	if (istype(src, /turf/floor/beach/water/ice))
		to_chat(H, SPAN_WARNING("The water is frozen over. Cut a hole with an axe, a pick or a chisel and fish through that."))
		return
	var/datum/craft/ship = craft_at(get_turf(H))
	if (ship && fish_craft_step(ship))
		fish_troll(W, H, ship, profile) // the water slides past: tow a line instead
		return
	if (istype(W, /obj/item/weapon/fishing/trawl))
		to_chat(H, SPAN_WARNING("A trawl has to be dragged. Shoot it from a ship that is under way."))
		return
	var/kind = fish_water_kind(src)
	if (!kind)
		to_chat(H, SPAN_WARNING("There is nothing to catch here."))
		return
	var/spear = profile[3]
	var/deep = fish_water_deep(src)
	if (spear && deep)
		to_chat(H, SPAN_WARNING("The water is too deep to spear fish here. Try the shallows."))
		return
	if (iscovered() || (locate(/obj/structure/vehicleparts/frame) in src) || (locate(/obj/structure/vehicleparts/axis) in src))
		to_chat(H, SPAN_WARNING("[spear ? "Strike" : "Cast"] into open water."))
		return
	if (!H.fishing_footing())
		to_chat(H, SPAN_WARNING("You need a deck, a bridge or the bank under you to fish."))
		return
	var/datum/fishing_ground/G = fishing_ground_at(src)
	if (G.available() < 1 && !fish_shoal_at(src))
		to_chat(H, SPAN_WARNING("Nothing stirs here. This stretch seems fished out; try further along."))
		return
	var/obj/item/weapon/fishing/line = istype(W, /obj/item/weapon/fishing) ? W : null
	var/baited = line && line.bait_uses > 0
	var/noisy = ship && fish_craft_engines(ship)
	if (noisy)
		to_chat(H, SPAN_WARNING("The engine's thump carries through the hull. The fish will be wary."))
	H.ocean_fishing = TRUE
	if (spear)
		H.visible_message("[H] stands ready to spear a fish.")
	else
		H.visible_message(SPAN_NOTICE("[H] casts \the [W] into the water."), SPAN_NOTICE("You cast \the [W] into the water[baited ? " with bait on the line" : ""]."))
		H.body_motion_throw(src, BODY_MOTION_FULL)
	var/done = do_after(H, profile[1], src)
	H.ocean_fishing = FALSE
	if (!done || QDELETED(W) || W.loc != H || !Adjacent(H) || !H.fishing_footing())
		return
	if (baited && line.bait_uses > 0)
		line.bait_uses--
	var/chance = fish_tool_chance(profile, baited, G)
	if (deep && kind == FISH_WATER_SALT)
		chance *= FISH_DEEP_SEA_SHARE
	chance = min(95, chance * fish_condition_factor_at(src, kind))
	if (noisy)
		chance *= fish_ship_factor(TRUE, VESSEL_SPEED_STOP)
	fish_land(H, src, G, kind, chance, profile[4], baited, spear)

// The roll and the landing, for a cast and for a towed line. Returns the
// number of fish landed.
/proc/fish_land(mob/living/human/H, turf/water, datum/fishing_ground/G, kind, chance, hauls, baited, spear, towed = FALSE)
	var/list/landed = list()
	var/escaped = FALSE
	var/shoal = fish_shoal_at(water)
	for (var/haul = 1 to hauls)
		if (!prob(round(chance)))
			continue
		// Under a shoal some of the fish came with it and cost the ground nothing.
		if (!(shoal && prob(FISH_SHOAL_FREE)) && !G.take(1)) // the ground ran out, or someone else took the last fish during the wait
			escaped = TRUE
			continue
		var/catch_path = fish_catch_type(water, kind, baited, towed, shoal)
		var/obj/item/fish = new catch_path(get_turf(H))
		river_mercury_taint_catch(fish, water) // amalgam.dm
		landed += fish
	if (!H)
		return landed.len
	if (!landed.len)
		if (escaped)
			to_chat(H, "Whatever was there got away.")
		else if (spear)
			to_chat(H, "The fish dart away from your strike.")
		else
			to_chat(H, hauls > 1 ? "The net comes up empty..." : "Nothing bites...")
		return 0
	var/obj/item/caught = landed[1]
	H.put_in_hands(caught)
	if (landed.len > 1)
		to_chat(H, SPAN_NOTICE("You haul in [landed.len] fish!"))
	else
		to_chat(H, SPAN_NOTICE(spear ? "You spear \a [caught]!" : "You land \a [caught]!"))
	if (!spear)
		H.adaptStat("dexterity", 1)
	return landed.len

// ---- From a ship ----

// TRUE while an engine standing aboard is running.
/proc/fish_craft_engines(datum/craft/C)
	for (var/datum/craft_drive/fitted/engine/D in C.drives)
		if (D.ready())
			return TRUE
	return FALSE

// Her telegraph step while she is making way, VESSEL_SPEED_STOP otherwise. A
// turf-built vessel keeps her own telegraph (naval/vessel.dm).
/proc/fish_craft_step(datum/craft/C)
	var/datum/craft_body/template/B = C.body
	if (istype(B) && B.vessel)
		return B.vessel.anchored ? VESSEL_SPEED_STOP : max(VESSEL_SPEED_STOP, B.vessel.speed)
	return C.anchored ? VESSEL_SPEED_STOP : max(VESSEL_SPEED_STOP, C.speed)

// What the ship does to a line's chance. engine: one is running aboard.
// step: her telegraph step while she is under way, VESSEL_SPEED_STOP otherwise.
/proc/fish_ship_factor(engine, step)
	. = 1
	if (engine)
		. *= FISH_ENGINE_FACTOR
	switch (step)
		if (VESSEL_SPEED_SLOW)
			. *= FISH_TROLL_SLOW
		if (VESSEL_SPEED_FULL)
			. *= FISH_TROLL_FULL

// Open fishing water within two tiles of the fisher that is not under the ship.
/proc/fish_water_beside(mob/living/human/H, datum/craft/ship)
	for (var/turf/T in orange(2, H))
		if (!fish_water_kind(T) || T.iscovered())
			continue
		if ((locate(/obj/structure/vehicleparts/frame) in T) || (locate(/obj/structure/vehicleparts/axis) in T))
			continue
		if (ship && ship.body && ship.body.contains(T))
			continue
		return T
	return null

// Trolling: a line towed from a ship under way. The fisher stays aboard for
// the wait; the fish come out of whatever ground she is over when it ends.
/proc/fish_troll(obj/item/W, mob/living/human/H, datum/craft/ship, list/profile)
	if (profile[3])
		to_chat(H, SPAN_WARNING("You cannot spear fish from a ship under way."))
		return
	var/trawl = istype(W, /obj/item/weapon/fishing/trawl)
	if (profile[4] > 1 && !trawl)
		to_chat(H, SPAN_WARNING("A cast net fouls under way. Stop the ship, or tow a line."))
		return
	if (trawl && fish_craft_step(ship) >= VESSEL_SPEED_FULL)
		to_chat(H, SPAN_WARNING("She is going too fast: the trawl would tear away. Ring slow or half ahead."))
		return
	if (!fish_water_beside(H, ship))
		to_chat(H, SPAN_WARNING("Stand by the rail, where the line can reach open water."))
		return
	var/obj/item/weapon/fishing/line = W
	var/baited = istype(line) && line.bait_uses > 0
	// A trawl works deep and wide; the engine that drags it does not spoil it.
	var/noisy = !trawl && fish_craft_engines(ship)
	H.ocean_fishing = TRUE
	if (trawl)
		H.visible_message(SPAN_NOTICE("[H] shoots \the [W] over the stern."), SPAN_NOTICE("You shoot the trawl over the stern and pay out the warp."))
	else
		H.visible_message(SPAN_NOTICE("[H] lets \the [W] run out astern."), SPAN_NOTICE("You let the line run out astern[baited ? " with bait on it" : ""].[noisy ? " The engine will keep the fish wary." : ""]"))
	var/done = do_after(H, profile[1], W, can_move = TRUE)
	H.ocean_fishing = FALSE
	if (!done || QDELETED(W) || W.loc != H || craft_at(get_turf(H)) != ship)
		return
	if (baited && line.bait_uses > 0)
		line.bait_uses--
	var/turf/water = fish_water_beside(H, ship)
	var/datum/fishing_ground/G = water && fishing_ground_at(water)
	if (!G || (G.available() < 1 && !fish_shoal_at(water)))
		to_chat(H, trawl ? "The trawl comes up empty. These waters are fished out; sail on." : "Nothing follows the lure. These waters seem fished out; sail on.")
		return
	var/kind = G.kind
	var/chance = fish_tool_chance(profile, baited, G)
	if (kind == FISH_WATER_SALT && fish_water_deep(water))
		chance *= FISH_DEEP_SEA_SHARE
	if (trawl)
		// Any speed she can be dragged at fishes the same, and tuna outrun a trawl.
		chance = min(95, chance * fish_condition_factor_at(water, kind))
		fish_land(H, water, G, kind, chance, profile[4], FALSE, FALSE)
		return
	chance = min(95, chance * fish_condition_factor_at(water, kind) * fish_ship_factor(noisy, fish_craft_step(ship)))
	fish_land(H, water, G, kind, chance, 1, baited, FALSE, TRUE)

// What a sonar set makes of the fish in the water at T (the surface over a
// submerged boat), or null where there is no fishing water.
/proc/fish_finder_line(turf/T)
	if (!T || !fish_water_kind(T))
		return null
	var/datum/fishing_ground/G = fishing_ground_at(T, FALSE)
	var/full = G ? G.fullness() : 1
	var/here = full >= 0.75 ? "thick shoals" : (full >= 0.4 ? "scattered shoals" : ((G && G.available() < 1) ? "no fish" : "a few fish"))
	. = "Fish overhead: [here]."
	var/shoal = fish_shoal_finder_line(T)
	if (shoal)
		. += " [shoal]"
	if (full >= 0.75)
		return
	// The fullest neighbouring stretch, if it beats this one.
	var/best = full
	var/best_dir = 0
	for (var/d in alldirs)
		var/turf/N = locate(T.x + ((d & EAST) ? FISH_GROUND_SIZE : ((d & WEST) ? -FISH_GROUND_SIZE : 0)), T.y + ((d & NORTH) ? FISH_GROUND_SIZE : ((d & SOUTH) ? -FISH_GROUND_SIZE : 0)), T.z)
		if (!N || fish_water_kind(N) != fish_water_kind(T))
			continue
		var/datum/fishing_ground/NG = fishing_ground_at(N, FALSE)
		var/there = NG ? NG.fullness() : 1
		if (there > best + 0.2)
			best = there
			best_dir = d
	if (best_dir)
		. += " Stronger returns to the [dir2text(best_dir)]."

// ---- Set gear ----

// One fish for gear left standing in the water at T (a weir, a cage): the type
// caught, or null when this stretch has none to give. It comes out of the same
// ground a line fishes.
/proc/fish_ground_trap_catch(turf/T)
	var/datum/fishing_ground/G = fishing_ground_at(T)
	if (!G || !G.take(1))
		return null
	return fish_catch_type(T, G.kind, FALSE)

// ---- Flood strandings ----

// Look up one kind of ground for a tile, including floodwater or ice.
// An existing ground's capacity is left to the caller.
/proc/fishing_ground_cell(turf/T, kind, capacity, create = TRUE)
	fishing_grounds_sync()
	var/cx = round(T.x / FISH_GROUND_SIZE)
	var/cy = round(T.y / FISH_GROUND_SIZE)
	var/key = fishing_ground_key(kind, cx, cy, T.z)
	var/datum/fishing_ground/G = fishing_grounds[key]
	if (!G && create)
		G = new /datum/fishing_ground(kind, cx, cy, T.z, capacity)
		fishing_grounds[key] = G
	return G

// A river over its banks carries fish out onto the land, and the shallows at
// the flood's edge leave them flapping. Asked by the flood's own item pass
// (flood_effects.dm): once a river minute for a tile somebody can see, so
// unwatched land costs nothing. The fish come out of a small flooded-ground
// stock for the stretch, so a flood plain gives a few fish, not a harvest.
// Returns the fish, or null.
/proc/fish_flood_stranding(turf/T, band, chance = FISH_STRAND_CHANCE)
	if (band != FLOOD_BAND_ANKLE || !istype(T, /turf/floor) || istype(T, /turf/floor/beach/water) || T.density)
		return null
	if (!prob(chance))
		return null
	var/area/A = get_area(T)
	if (!A || A.location != AREA_OUTSIDE)
		return null
	if (locate(/obj/item/weapon/reagent_containers/food/snacks/rawfish) in T)
		return null
	var/datum/fishing_ground/G = fishing_ground_cell(T, FISH_WATER_FLOODED, 2)
	if (!G.take(1))
		return null
	var/obj/item/weapon/reagent_containers/food/snacks/rawfish/F = new(T)
	F.visible_message(SPAN_NOTICE("A fish flaps in the shallows the flood has left."))
	return F

#undef FISH_GROUND_STEP
#undef FISH_GROUND_MAX_STEPS
#undef FISH_GROUND_SPILL
#undef FISH_BAIT_USES
#undef FISH_BAIT_BONUS
#undef FISH_THIN_SHARE
#undef FISH_DEEP_SEA_SHARE
#undef FISH_NET_CHANCE
#undef FISH_NET_HAUL
#undef FISH_TRAWL_WAIT
#undef FISH_TRAWL_CHANCE
#undef FISH_TRAWL_HAUL
#undef FISH_RUN_FACTOR
#undef FISH_RUN_SALMON
#undef FISH_RUN_REGROWTH
#undef FISH_RAIN_FACTOR
#undef FISH_STORM_SEA_FACTOR
#undef FISH_STORM_RIVER_FACTOR
#undef FISH_SPATE_FACTOR
#undef FISH_LOW_POOL_FACTOR
#undef FISH_STRAND_CHANCE
#undef FISH_SHOAL_HERRING
#undef FISH_SHOAL_FREE
#undef FISH_ENGINE_FACTOR
#undef FISH_TROLL_SLOW
#undef FISH_TROLL_FULL
