// ============================================================
// Walking between lands over a shared map edge (docs/americas-regions.md,
// docs/edge-crossings.md)
// ------------------------------------------------------------
// Where one land mass is split over two regions (the Americas at the isthmus,
// Europe and Asia, Asia and the Desert, the Desert and the Jungle),
// the edge of the map is not the end of the land. A map names the neighbour
// beyond an edge in edge_crossings. A player who walks onto dry or wadeable
// ground at that edge is asked once whether to walk on; on "Travel" they leave
// as an ordinary region traveller (region_travel.dm) and come out on the
// matching edge of the neighbour, as far along it as they were here.
//
// Nothing stands on the map for this: the hidden gate below exists only while
// one traveller is asked and sent. A rider takes the mount along: the animal
// goes as a small record with its rider and stands beside them on the far
// side, and so does one animal led by hand. Drivers and anyone dragging
// anything else are told to go on foot. A hand cart or travois pulled by
// hand crosses with its load, and a bicycle is wheeled over by its rider;
// other driven vehicles do not cross yet.
// ============================================================

// How far in from the border an arriving walker is put down, so the first
// step is theirs and the edge does not ask them straight back.
#define REGION_EDGE_ARRIVAL_INSET 3
// The most things a pulled cart may hold on a crossing.
#define REGION_EDGE_CART_ITEMS_MAX 60
// How long a player who said no is left alone.
#define REGION_EDGE_ASK_COOLDOWN 300
// Wading out past the last dry tile of the edge still counts as the crossing.
#define REGION_EDGE_SHORE 4

// "north", "south", "east" or "west" = the region id of the land beyond that
// whole edge, or a list of region id = list(from, to): the stretch of the edge
// that leads there, as fractions of its length counted west to east or south
// to north. One edge may lead to several lands (Asia's west edge: Europe in
// the north, the Desert in the south).
// A map sets this only for a world outside the earth group (fixtures, the Moon's
// colonies); the earth group's links come from world_links (world_links.dm),
// by this world's region id. Read them through region_edge_links().
/obj/map_metadata/var/list/edge_crossings = null
// The level the crossings are walked on: the surface.
/obj/map_metadata/var/edge_crossing_z = 1

/mob/living/human/var/tmp/region_edge_asking = FALSE
/mob/living/human/var/tmp/region_edge_asked_at = 0

/mob/living/human/persistence_runtime_var(key)
	return key == "region_edge_asking" || key == "region_edge_asked_at" || ..()

// "side|id" = the positions of dry ground along that stretch of the border row.
var/global/list/region_edge_spans = list()

// The edges of this world that lead on, or null: the map's own, else this
// region's entry in the world links table.
/proc/region_edge_links()
	if (!map)
		return null
	if (map.edge_crossings)
		return map.edge_crossings
	if (!shard_group || !shard_group.enabled || !istext(shard_group.region))
		return null
	var/list/links = world_links[shard_group.region]
	return length(links) ? links : null

/proc/region_edge_dir(side)
	switch (side)
		if ("north") return NORTH
		if ("south") return SOUTH
		if ("east") return EAST
		if ("west") return WEST
	return 0

/proc/region_edge_opposite(side)
	switch (side)
		if ("north") return "south"
		if ("south") return "north"
		if ("east") return "west"
		if ("west") return "east"
	return null

// Ground a walker can stand on at the edge: no rock, lava or deep water.
/proc/region_edge_ground(turf/T, dry = FALSE)
	if (!istype(T, /turf/floor) || T.density)
		return FALSE
	if (istype(T, /turf/floor/dirt/underground) || istype(T, /turf/floor/lava) || istype(T, /turf/floor/beach/water/deep))
		return FALSE
	if (dry && istype(T, /turf/floor/beach/water))
		return FALSE
	return TRUE

/proc/region_edge_length(side)
	return (side == "north" || side == "south") ? world.maxx : world.maxy

// Position of T along a side: x on the north and south edges, y on the others.
/proc/region_edge_along(side, turf/T)
	return (side == "north" || side == "south") ? T.x : T.y

// The turf at position a along a side, depth tiles in from the border.
/proc/region_edge_turf(side, a, depth = 0)
	var/z = map ? map.edge_crossing_z : 1
	switch (side)
		if ("north") return locate(a, world.maxy - depth, z)
		if ("south") return locate(a, 1 + depth, z)
		if ("east") return locate(world.maxx - depth, a, z)
		if ("west") return locate(1 + depth, a, z)
	return null

// The region ids a side leads to.
/proc/region_edge_destinations(side)
	. = list()
	var/list/links = region_edge_links()
	if (!links)
		return
	var/entry = links[side]
	if (istext(entry))
		. += entry
	else if (islist(entry))
		for (var/id in entry)
			if (istext(id))
				. += id

// list(first, last) positions of the stretch of a side that leads to id, or null.
/proc/region_edge_bounds(side, id)
	var/list/links = region_edge_links()
	if (!links || !istext(id))
		return null
	var/length = region_edge_length(side)
	var/entry = links[side]
	if (istext(entry))
		return entry == id ? list(1, length) : null
	if (!islist(entry))
		return null
	var/list/R = entry[id]
	if (!islist(R) || R.len != 2 || !isnum(R[1]) || !isnum(R[2]))
		return null
	var/lo = clamp(round(R[1] * length) + 1, 1, length)
	return list(lo, clamp(round(R[2] * length), lo, length))

// The positions of dry ground along the stretch of a side that leads to id.
/proc/region_edge_dry(side, id)
	var/key = "[side]|[id]"
	if (key in region_edge_spans)
		return region_edge_spans[key]
	var/list/bounds = region_edge_bounds(side, id)
	var/list/dry = list()
	if (bounds)
		for (var/a = bounds[1] to bounds[2])
			if (region_edge_ground(region_edge_turf(side, a), TRUE))
				dry += a
	region_edge_spans[key] = dry.len ? dry : null
	return region_edge_spans[key]

// list(first, last) positions of dry ground on the stretch leading to id, or null.
/proc/region_edge_span(side, id)
	var/list/dry = region_edge_dry(side, id)
	return dry ? list(dry[1], dry[dry.len]) : null

// The region a walker at position a along a side walks on into, or null:
// on the stretch's dry ground, or wading just beside it.
/proc/region_edge_destination(side, a)
	for (var/id in region_edge_destinations(side))
		var/list/bounds = region_edge_bounds(side, id)
		var/list/span = region_edge_span(side, id)
		if (!bounds || !span)
			continue
		if (a >= max(bounds[1], span[1] - REGION_EDGE_SHORE) && a <= min(bounds[2], span[2] + REGION_EDGE_SHORE))
			return id
	return null

// The side whose crossing T lies on, or null.
/proc/region_edge_side(turf/T)
	var/list/links = region_edge_links()
	if (!links || !istype(T) || T.z != map.edge_crossing_z)
		return null
	var/side = null
	if (T.y == 1) side = "south"
	else if (T.y == world.maxy) side = "north"
	else if (T.x == 1) side = "west"
	else if (T.x == world.maxx) side = "east"
	if (!side || !links[side] || !region_edge_ground(T))
		return null
	if (!region_edge_destination(side, region_edge_along(side, T)))
		return null
	return side

// How far along the stretch's dry ground T is, 0 to 1. Counted over dry tiles
// only, so a walker on land comes out on land however the two edges differ.
/proc/region_edge_fraction(side, id, turf/T)
	var/list/dry = region_edge_dry(side, id)
	if (!dry || dry.len < 2)
		return 0.5
	var/a = region_edge_along(side, T)
	var/before = 0
	for (var/d in dry)
		if (d >= a)
			break
		before++
	return round(clamp(before / (dry.len - 1), 0, 1), 0.001)

// ---------------------------------------------------------------- leaving

// The way a walker leaves: a hidden gate that exists only for their crossing.
/obj/structure/region_gate/land_edge
	name = "the way on"
	desc = "The land carries on beyond here."
	invisibility = 101
	icon = null
	// Never part of a save: it lasts only while one walker is asked and sent.
	should_save = FALSE
	var/list/crossing = null
	// The mount that goes with this walker (region_edge_mount_record), if any.
	var/list/mount = null
	// The animal this walker leads (region_edge_led_record), if any.
	var/list/led = null
	// The hand cart or travois this walker pulls, held inside the gate from the
	// moment its load is recorded (travel_extra) until they left or stayed.
	var/obj/structure/closet/crate/cart = null
	var/turf/cart_from = null
	// The bicycle this walker rode up on and got off (region_edge_cross). It is
	// recorded and held the same way as they leave.
	var/obj/structure/vehicle/bicycle/bike = null
	var/turf/bike_from = null
	var/bike_held = FALSE

/obj/structure/region_gate/land_edge/accepts_arrivals()
	return FALSE

/obj/structure/region_gate/land_edge/travel_extra(mob/living/human/H)
	if (!crossing)
		return null
	. = list("edge" = crossing)
	if (mount)
		.["mount"] = mount
	if (led)
		.["led"] = led
	// The cart is recorded as the traveller leaves, not when they were asked,
	// and taken out of reach at once so its load cannot change after that.
	var/list/load = region_edge_cart_record(H)
	if (islist(load))
		cart = H.pulling
		cart_from = get_turf(cart)
		H.stop_pulling()
		cart.forceMove(src)
		.["cart"] = load
	var/list/ridden = region_edge_bike_record(bike, H)
	if (ridden)
		bike_from = get_turf(bike)
		bike.forceMove(src)
		bike_held = TRUE
		.["bike"] = ridden
	// A carriage is packed whole as its driver leaves (region_edge_carriage.dm).
	var/list/driven = pack_wagon(H)
	if (driven)
		.["wagon"] = driven

// A walker who stayed, or could not leave, gets the cart back where it stood.
/obj/structure/region_gate/land_edge/proc/release_cart()
	if (cart && !QDELETED(cart) && cart.loc == src)
		cart.forceMove(cart_from || get_turf(src))
	cart = null
	if (bike_held && bike && !QDELETED(bike) && bike.loc == src)
		bike.forceMove(bike_from || get_turf(src))
	bike_held = FALSE
	bike = null
	release_wagon()

/obj/structure/region_gate/land_edge/Destroy()
	release_cart()
	return ..()

/obj/structure/region_gate/land_edge/attack_hand(mob/living/human/user)
	return

/obj/structure/region_gate/land_edge/attack_ghost(mob/user)
	return

/obj/structure/region_gate/land_edge/closed_reason()
	. = ..()
	// The shared wording speaks of a trail; there is none here.
	if (. && findtext(., "trail"))
		if (busy || persistence_save_active())
			return "You cannot walk on just now. Try again in a moment."
		return "The land goes on, but nobody can walk on into [destination_name() || "it"] right now."

// A walk across the border takes wounds along (they travel as damage), so
// unlike a trail it does not ask for full health.
/obj/structure/region_gate/land_edge/travel_refusal(mob/living/human/H)
	var/reason = closed_reason()
	if (reason) return reason
	if (H.client ? IsGuestKey(H.client.key) : !agent_travel_account(H)) return "Only players with a BYOND account can travel."
	if (H.buckled || H.driver || H.driver_vehicle) return "You cannot drive across yet. Get down and walk on."
	if ((H.riding || H.riding_mob) && !region_edge_mount_record(H)) return "Your mount cannot make the crossing. Get down and walk on."
	if (H.pulling && !region_edge_led_record(H))
		var/load = region_edge_cart_record(H)
		if (istext(load)) return load
		if (!load) return "You cannot drag that across. Let go and walk on."
	if (H.stat != CONSCIOUS || H.restrained()) return "You can't set off right now."
	if (get_turf(H) != loc && H.loc != src) return "You turned back from the edge of the land."
	return null

// Called after a human's own step. Asks, and sends them on a yes.
/mob/living/human/proc/region_edge_check()
	if (region_edge_asking || !region_edge_links())
		return
	var/turf/T = loc
	if (!isturf(T) || (T.y != 1 && T.x != 1 && T.y != world.maxy && T.x != world.maxx))
		return
	var/side = region_edge_side(T)
	if (!side)
		return
	if (!client && !agent_travel_account(src))
		return
	if (world.time < region_edge_asked_at + REGION_EDGE_ASK_COOLDOWN)
		return
	region_edge_asking = TRUE
	region_edge_asked_at = world.time
	region_edge_cross(side, T)

// A rider carried onto the edge by what they ride (a bicycle) is asked too.
/mob/living/human/proc/region_edge_ride()
	if (region_edge_links())
		region_edge_check()

// Asks and waits on its own; the step that led here is not held up.
/mob/living/human/proc/region_edge_cross(side, turf/T)
	set waitfor = FALSE
	var/id = region_edge_destination(side, region_edge_along(side, T))
	if (!id)
		region_edge_asking = FALSE
		return
	var/obj/structure/region_gate/land_edge/gate = new(T)
	gate.destination = id
	gate.crossing = list(side, region_edge_fraction(side, id, T), id)
	// The mount is recorded now and leaves only if its rider did.
	var/mob/living/simple_animal/steed = riding_mob
	gate.mount = region_edge_mount_record(src)
	var/took_mount = gate.mount && istype(steed)
	// So is an animal led by hand.
	var/mob/living/simple_animal/beast = pulling
	gate.led = region_edge_led_record(src)
	var/took_led = gate.led && istype(beast)
	// A bicycle is wheeled over: its rider gets off here and it goes along.
	var/obj/structure/vehicle/bicycle/ridden = driver_vehicle
	if (istype(ridden) && buckled == ridden && region_edge_bike_ok(ridden.type))
		ridden.unbuckle_mob()
		if (!buckled && !driver_vehicle)
			gate.bike = ridden
			to_chat(src, SPAN_NOTICE("You get off \the [ridden] to wheel it on."))
	gate.travel(src)
	// travel() returns once they left, said no or were refused.
	if (took_mount && QDELETED(src) && !QDELETED(steed))
		log_game("Region travel: the mount [steed.name] ([steed.type]) crossed the edge with its rider.")
		qdel(steed)
	if (took_led && QDELETED(src) && !QDELETED(beast))
		log_game("Region travel: the led animal [beast.name] ([beast.type]) crossed the edge with its keeper.")
		qdel(beast)
	// The cart went with them: it and its load are gone from here.
	if (QDELETED(src) && gate.cart && !QDELETED(gate.cart))
		log_game("Region travel: the cart [gate.cart.name] ([gate.cart.type]) crossed the edge with its puller.")
		for (var/atom/movable/M in gate.cart)
			qdel(M)
		qdel(gate.cart)
		gate.cart = null
	if (QDELETED(src) && gate.bike_held && gate.bike && !QDELETED(gate.bike))
		log_game("Region travel: the bicycle [gate.bike.name] ([gate.bike.type]) crossed the edge with its rider.")
		qdel(gate.bike)
		gate.bike = null
		gate.bike_held = FALSE
	if (!QDELETED(gate))
		qdel(gate)
	if (!QDELETED(src))
		region_edge_asking = FALSE
		region_edge_asked_at = world.time

// ---------------------------------------------------------------- mounts

// A mount crosses by type, name and health: an animal that can be ridden and
// keeps no other state. Anything else stays and its rider walks.
/proc/region_edge_mount_ok(path)
	var/mob/living/simple_animal/A = path
	return ispath(path, /mob/living/simple_animal) && initial(A.can_ride)

// list(type, name, health) for the animal H rides, or null when it cannot cross.
/proc/region_edge_mount_record(mob/living/human/H)
	var/mob/living/simple_animal/A = H.riding_mob
	if (!istype(A) || QDELETED(A) || A.rider != H || A.stat == DEAD || !region_edge_mount_ok(A.type) || A.wild || A.pulledby)
		return null
	// Saddlebags and the like would be lost; an animal carrying anything walks with nobody.
	for (var/atom/movable/M in A)
		return null
	var/label = (istext(A.name) && length(A.name) <= 40 && !findtext(A.name, "<") && !findtext(A.name, "\"")) ? A.name : initial(A.name)
	return list("[A.type]", label, clamp(round(A.health), 1, A.maxHealth))

// The same record for the one animal H leads by hand: any living animal that
// is not wild (it would arrive tame), carries nothing and that nobody rides. It crosses as a new one of its kind
// with its name and health, like a mount.
/proc/region_edge_led_record(mob/living/human/H)
	var/mob/living/simple_animal/A = H.pulling
	if (!istype(A) || QDELETED(A) || A.pulledby != H || A.stat == DEAD || A.wild || A.rider || A == H.riding_mob || !isturf(A.loc) || get_dist(A, H) > 2)
		return null
	for (var/atom/movable/M in A)
		return null
	var/label = (istext(A.name) && length(A.name) <= 40 && !findtext(A.name, "<") && !findtext(A.name, "\"")) ? A.name : initial(A.name)
	var/list/record = list("[A.type]", label, clamp(round(A.health), 1, A.maxHealth))
	return region_edge_mount_valid(record, TRUE) ? record : null

/proc/region_edge_mount_valid(list/M, led = FALSE)
	if (!islist(M) || M.len != 3 || !istext(M[1]) || !istext(M[2]) || !length(M[2]) || length(M[2]) > 40 || findtext(M[2], "<") || !isnum(M[3]))
		return FALSE
	var/mob/living/simple_animal/path = text2path(M[1])
	if (led ? !ispath(path, /mob/living/simple_animal) : !region_edge_mount_ok(path))
		return FALSE
	return M[3] >= 1 && M[3] <= initial(path.maxHealth) && M[3] == round(M[3])

// Builds the recorded mount beside its rider. The rider gets back on themselves.
/proc/region_edge_mount_build(list/M, turf/T, led = FALSE)
	if (!region_edge_mount_valid(M, led) || !istype(T))
		return null
	var/path = text2path(M[1])
	var/mob/living/simple_animal/A = new path(T)
	A.name = M[2]
	A.health = M[3]
	return A

// ---------------------------------------------------------------- carts

// A hand cart or a travois pulled by hand crosses with what is shut inside it,
// by the same kinds a traveller's own things use (region_travel_gear.dm).
/proc/region_edge_cart_ok(path)
	return ispath(path, /obj/structure/closet/crate/cart) || ispath(path, /obj/structure/closet/crate/travois)

// list(type, list(list(kind, amount), ...)) for the cart H pulls, a sentence
// when its load cannot cross, or null when H pulls no cart.
/proc/region_edge_cart_record(mob/living/human/H)
	var/obj/structure/closet/crate/C = H.pulling
	if (!istype(C) || QDELETED(C) || !region_edge_cart_ok(C.type) || C.pulledby != H || !isturf(C.loc) || get_dist(C, H) > 2)
		return null
	var/list/held = list()
	var/list/blockers = list()
	for (var/atom/movable/M in C)
		if (region_travel_ignorable(M))
			continue
		var/list/entry = istype(M, /obj/item) ? region_travel_worn_entry(M) : null
		if (entry)
			held += list(entry)
		else
			blockers += M.name
	if (blockers.len)
		return "\The [C] cannot cross with [english_list(blockers)] in it. Unload that first."
	if (held.len > REGION_EDGE_CART_ITEMS_MAX)
		return "\The [C] holds too much to cross. Unload some of it first."
	var/list/record = list("[C.type]", held)
	return region_edge_cart_valid(record) ? record : "\The [C] cannot make the crossing. Let go and walk on."

/proc/region_edge_cart_valid(list/R)
	if (!islist(R) || R.len != 2 || !istext(R[1]) || !region_edge_cart_ok(text2path(R[1])))
		return FALSE
	var/list/held = R[2]
	if (!islist(held) || held.len > REGION_EDGE_CART_ITEMS_MAX)
		return FALSE
	for (var/entry in held)
		var/list/E = entry
		if (!islist(E) || E.len != 2 || !region_travel_worn_valid(E[1], E[2]))
			return FALSE
	return TRUE

// Builds the recorded cart at T, shut, holding exactly what travelled.
/proc/region_edge_cart_build(list/R, turf/T)
	if (!region_edge_cart_valid(R) || !istype(T))
		return null
	var/path = text2path(R[1])
	var/obj/structure/closet/crate/C = new path(T)
	// A shut crate takes in what lies on its tile; that is not part of the load.
	for (var/atom/movable/M in C)
		M.forceMove(T)
	for (var/list/E in R[2])
		var/obj/item/I = region_travel_make_worn(E[1], E[2], T)
		if (I)
			I.forceMove(C)
	C.update_capacity(length(C.contents))
	C.update_icon()
	return C

// ---------------------------------------------------------------- bicycles

// A pedal bicycle or running bike crosses by type, frame material and health.
// The pedal airship flies and does not.
/proc/region_edge_bike_ok(path)
	return ispath(path, /obj/structure/vehicle/bicycle) && !ispath(path, /obj/structure/vehicle/bicycle/airship)

// list(type, frame material, health) for the bicycle B standing by H with
// nobody on it, or null.
/proc/region_edge_bike_record(obj/structure/vehicle/bicycle/B, mob/living/human/H)
	if (!istype(B) || QDELETED(B) || !region_edge_bike_ok(B.type) || !isturf(B.loc) || get_dist(B, H) > 1 || B.driver || B.buckled_mob || length(B.ontop))
		return null
	var/list/record = list("[B.type]", B.frame_material, clamp(round(B.health), 1, initial(B.health)))
	return region_edge_bike_valid(record) ? record : null

/proc/region_edge_bike_valid(list/R)
	if (!islist(R) || R.len != 3 || !istext(R[1]) || !istext(R[2]) || !isnum(R[3]))
		return FALSE
	var/obj/structure/vehicle/bicycle/path = text2path(R[1])
	if (!region_edge_bike_ok(path) || !get_material_by_name(R[2]))
		return FALSE
	return R[3] >= 1 && R[3] <= initial(path.health) && R[3] == round(R[3])

/proc/region_edge_bike_build(list/R, turf/T)
	if (!region_edge_bike_valid(R) || !istype(T))
		return null
	var/path = text2path(R[1])
	var/obj/structure/vehicle/bicycle/B = new path(T, R[2])
	B.health = R[3]
	return B

// ---------------------------------------------------------------- arriving

/proc/region_edge_payload_ok(list/P)
	var/list/E = P["edge"]
	if (isnull(E))
		return isnull(P["mount"]) && isnull(P["led"]) && isnull(P["cart"]) && isnull(P["bike"]) && isnull(P["wagon"])
	if (!isnull(P["cart"]) && !region_edge_cart_valid(P["cart"]))
		return FALSE
	if (!isnull(P["bike"]) && !region_edge_bike_valid(P["bike"]))
		return FALSE
	if (!isnull(P["wagon"]) && !region_edge_wagon_valid(P["wagon"]))
		return FALSE
	if (!isnull(P["mount"]) && !region_edge_mount_valid(P["mount"]))
		return FALSE
	if (!isnull(P["led"]) && !region_edge_mount_valid(P["led"], TRUE))
		return FALSE
	return islist(E) && E.len == 3 && !!region_edge_dir(E[1]) && isnum(E[2]) && E[2] >= 0 && E[2] <= 1 && istext(E[3])

// Where a walker who crossed an edge comes out: the matching place on the
// facing edge here, a few steps in. Null when this land has no such edge.
/proc/region_edge_arrival_turf(list/P, incoming)
	if (!islist(P) || !islist(P["edge"]) || !region_edge_links())
		return null
	var/list/E = P["edge"]
	// Turned back at the far side: they stand where they left.
	var/side = incoming ? region_edge_opposite(E[1]) : E[1]
	var/id = incoming ? P["from"] : E[3]
	if (!side || !istext(id))
		return null
	var/list/dry = region_edge_dry(side, id)
	if (!dry)
		return null
	var/at = dry[clamp(round(E[2] * (dry.len - 1)) + 1, 1, dry.len)]
	// The nearest free dry ground to that spot, working inland and outward.
	for (var/depth = REGION_EDGE_ARRIVAL_INSET, depth <= REGION_EDGE_ARRIVAL_INSET + 12, depth++)
		for (var/off = 0, off <= 12, off++)
			for (var/sign in list(1, -1))
				if (!off && sign < 0)
					continue
				var/turf/T = region_edge_turf(side, at + off * sign, depth)
				if (region_edge_arrival_free(T))
					return T
	// Nothing near: the closest other dry stretch of the same edge.
	var/list/order = dry.Copy()
	while (order.len)
		var/best = 1
		for (var/i = 2 to order.len)
			if (abs(order[i] - at) < abs(order[best] - at))
				best = i
		var/a = order[best]
		order.Cut(best, best + 1)
		for (var/depth = REGION_EDGE_ARRIVAL_INSET, depth <= REGION_EDGE_ARRIVAL_INSET + 12, depth++)
			var/turf/T = region_edge_turf(side, a, depth)
			if (region_edge_arrival_free(T))
				return T
	return null

/proc/region_edge_arrival_free(turf/T)
	if (!region_edge_ground(T, TRUE))
		return FALSE
	for (var/atom/movable/M in T)
		if (M.density && !istype(M, /atom/movable/lighting_overlay))
			return FALSE
	return TRUE

/proc/region_edge_arrived(mob/living/human/H, list/P, incoming)
	if (!istype(H) || !islist(P) || !islist(P["edge"]))
		return
	// Faces inland, so the next step leads on and not straight back.
	var/side = incoming ? region_edge_opposite(P["edge"][1]) : P["edge"][1]
	H.dir = turn(region_edge_dir(side), 180)
	// The mount they rode stands beside them, here or back where they were turned away.
	if (islist(P["mount"]))
		var/mob/living/simple_animal/A = region_edge_mount_build(P["mount"], get_turf(H))
		if (A)
			A.dir = H.dir
			to_chat(H, SPAN_NOTICE("\The [A] came across with you."))
	// So does the animal they led.
	if (islist(P["led"]))
		var/mob/living/simple_animal/L = region_edge_mount_build(P["led"], get_turf(H), TRUE)
		if (L)
			L.dir = H.dir
			to_chat(H, SPAN_NOTICE("\The [L] followed you across."))
	// And the cart they pulled, with its load.
	if (islist(P["cart"]))
		var/turf/behind = get_step(H, turn(H.dir, 180))
		var/obj/structure/closet/crate/C = region_edge_cart_build(P["cart"], (behind && region_edge_ground(behind, TRUE)) ? behind : get_turf(H))
		if (C)
			to_chat(H, SPAN_NOTICE("You hauled \the [C] across."))
	// And the bicycle they wheeled over.
	if (islist(P["bike"]))
		var/obj/structure/vehicle/bicycle/B = region_edge_bike_build(P["bike"], get_turf(H))
		if (B)
			to_chat(H, SPAN_NOTICE("You wheeled \the [B] across."))
	// And the carriage they drove, with its team and crates.
	region_edge_wagon_arrived(H, P, side)

// A departure replayed after a reload: the save still holds the mount that left.
/proc/region_edge_replayed(mob/living/human/H, list/P)
	if (!istype(H) || !islist(P))
		return
	var/list/gone = list()
	for (var/key in list("mount", "led"))
		var/list/M = P[key]
		if (!region_edge_mount_valid(M, key == "led"))
			continue
		var/path = text2path(M[1])
		for (var/mob/living/simple_animal/A in range(2, H))
			if (A.type == path && A.name == M[2] && !(A in gone) && (key == "led" || !A.rider))
				log_game("Region travel: replayed the crossing of the [key == "led" ? "led animal" : "mount"] [A.name]; it leaves again.")
				gone += A
				break
	for (var/mob/living/simple_animal/A in gone)
		qdel(A)
	region_edge_wagon_replayed(H, P)
	if (region_edge_bike_valid(P["bike"]))
		var/bike_path = text2path(P["bike"][1])
		for (var/obj/structure/vehicle/bicycle/B in range(2, H))
			if (B.type == bike_path && (!B.driver || B.driver == H))
				log_game("Region travel: replayed the crossing of the bicycle [B.name]; it leaves again.")
				qdel(B)
				break
	// The cart that left stands near them in the older save, load and all.
	if (region_edge_cart_valid(P["cart"]))
		var/path = text2path(P["cart"][1])
		for (var/obj/structure/closet/crate/C in range(2, H))
			if (C.type == path)
				log_game("Region travel: replayed the crossing of the cart [C.name]; it leaves again.")
				for (var/atom/movable/M in C)
					qdel(M)
				qdel(C)
				break

#undef REGION_EDGE_CART_ITEMS_MAX
#undef REGION_EDGE_ARRIVAL_INSET
#undef REGION_EDGE_ASK_COOLDOWN
#undef REGION_EDGE_SHORE
