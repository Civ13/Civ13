// Original mall raid. Secure home/hub levels remain outside the mission policy.
/area/extraction_mall
	name = "Shopping centre"
	dynamic_lighting = FALSE
	luminosity = TRUE
/area/extraction_mall/parking
	name = "Mall parking and highway"
/area/extraction_mall/retail
	name = "Mall retail floor"
/area/extraction_mall/gallery
	name = "Mall upper gallery"

/obj/map_metadata/extraction_survival/mall
	ID = MAP_EXTRACTION_MALL
	title = "Interchange Mall"
	description = "Recover supplies in an abandoned shopping centre, its parking structure and upper gallery. Vehicles enter and leave through the highway approaches."
	gamemode = "Mall Extraction"
	mission_z(level)
		return level in list(1, 4, 5)
	vehicle_mission_supported()
		return TRUE
	vehicle_entry_allowed(obj/effect/extraction_raid_marker/marker)
		return istype(marker, /obj/effect/extraction_raid_marker/road) && marker.z == 1
	vehicle_exit_allowed(obj/effect/extraction_exit/E)
		return ..() && istype(E, /obj/effect/extraction_exit/highway) && E.z == 1
	round_briefing()
		return "Thirty-minute mall raid: parking below, retail and upper gallery via signed stairs. Cars arrive on highways and can return only at West/East highway evacuation. Rail embankment and service footgate are on foot; drain access also forbids backpacks."
	hub_map_catalog()
		var/list/catalog = ..()
		catalog[MAP_EXTRACTION_MALL] = 0
		return catalog

/datum/job/civilian/extraction_survival/mall
	title = "Mall Raider"
	allowed_maps = list(MAP_EXTRACTION_MALL)

/obj/effect/extraction_raid_marker/road
	name = "Highway vehicle arrival"
/obj/effect/extraction_exit/highway
	name = "Highway evacuation - foot or car"
/obj/effect/extraction_exit/mall_foot
	name = "Pedestrian evacuation - foot only"

/obj/effect/extraction_mall_sign
	name = "Mall directory"
	desc = "Use the signed stairs for parking, retail and upper gallery. Highway exits admit cars; pedestrian exits do not."
	icon = 'icons/obj/decals.dmi'
	icon_state = "securearea"
	anchored = TRUE
	density = FALSE
	opacity = FALSE

/obj/effect/extraction_mall_rubble
	name = "Collapsed masonry and broken shop fittings"
	desc = "War damage and repeated scavenging have scattered fragments across the floor."
	icon = 'icons/obj/structures.dmi'
	icon_state = "debris1"
	anchored = TRUE
	density = FALSE
	opacity = FALSE


// Mall raid fixtures are fixed architecture, not an unjournaled material pool.
// Native table connections and bed/chair material overlays remain unchanged.
// Guard both interactive tool paths and direct damage/deconstruction callbacks.
/obj/structure/table/extraction_mall
	parent_type = /obj/structure/table/wood
	not_movable = TRUE
	not_disassemblable = TRUE
	deconstructable = FALSE
	parts = null
	attackby(obj/item/I, mob/user, params)
		return
	break_to_parts(full_return = FALSE)
		return list()
	table_destroy(destroy_type, mob/user)
		return
	check_cover(obj/item/projectile/P, turf/from)
		// Preserve native unflipped-table cover probability, without damage
		// accumulation or the parent's resource-producing break callback.
		if (!get_step(loc, get_dir(from, loc)) || get_dist(P.starting, loc) <= 1)
			return TRUE
		var/chance = 20
		if (ismob(P.original))
			var/mob/M = P.original
			if (M.lying) chance += 10
		return !prob(chance)
	Flip()
		return
	rotate_left()
		return
	rotate_right()
		return

/obj/structure/table/extraction_mall/shelf
	name = "store shelf"
	icon = 'icons/obj/structures.dmi'
	icon_state = "storeshelf"
	fixedsprite = TRUE
	low = TRUE
	update_icon()
		return

/obj/structure/table/extraction_mall/coatrack
	name = "coat rack"
	icon = 'icons/obj/junk.dmi'
	icon_state = "coatrack"
	fixedsprite = TRUE
	low = TRUE
	update_icon()
		return

/obj/structure/table/extraction_mall/nightstand
	name = "night stand"
	icon = 'icons/obj/structures.dmi'
	icon_state = "nightstand"
	fixedsprite = TRUE
	low = TRUE
	update_icon()
		return

/obj/structure/bed/wood/extraction_mall
	not_movable = TRUE
	not_disassemblable = TRUE
	parts = null
	attackby(obj/item/weapon/W, mob/user)
		return
	dismantle()
		return
	remove_padding()
		return
	add_padding(padding_type)
		return

/obj/structure/bed/fieldbed/extraction_mall
	not_movable = TRUE
	not_disassemblable = TRUE
	parts = null
	attackby(obj/item/weapon/W, mob/user)
		return
	dismantle()
		return
	remove_padding()
		return
	add_padding(padding_type)
		return

/obj/structure/bed/sofa/extraction_mall
	not_movable = TRUE
	not_disassemblable = TRUE
	parts = null
	attackby(obj/item/weapon/W, mob/user)
		return
	dismantle()
		return
	remove_padding()
		return
	add_padding(padding_type)
		return

/obj/structure/bed/chair/extraction_mall
	not_movable = TRUE
	not_disassemblable = TRUE
	parts = null
	attackby(obj/item/weapon/W, mob/user)
		return
	dismantle()
		return
	remove_padding()
		return
	add_padding(padding_type)
		return
	rotate_left()
		return
	rotate_right()
		return

/obj/structure/closet/extraction_mall
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	parts = null
	attackby(obj/item/I, mob/user)
		return

/obj/structure/closet/fridge/extraction_mall
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	parts = null
	attackby(obj/item/I, mob/user)
		return

/obj/structure/oven/extraction_mall
	not_movable = TRUE
	not_disassemblable = TRUE
	parts = null
	attackby(obj/item/I, mob/living/human/H)
		return
	attack_hand(mob/living/human/H)
		return
	fire_loop()
		return
	process()
		return

// Disused plumbing retains each actual native sprite without the sink's
// renewable water / mosquito constructors or its reagent filling handlers.
/obj/structure/extraction_mall_fixture
	anchored = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	parts = null
	attackby(obj/item/I, mob/user)
		return

/obj/structure/sink/extraction_mall
	parent_type = /obj/structure/extraction_mall_fixture
	name = "disused sink"
	desc = "A damaged washbasin. The mall water supply has been disconnected."
	icon = 'icons/obj/watercloset.dmi'
	icon_state = "sink"
	density = FALSE

/obj/structure/toilet/extraction_mall
	parent_type = /obj/structure/extraction_mall_fixture
	name = "disused toilet"
	desc = "A damaged porcelain fixture in the abandoned washroom."
	icon = 'icons/obj/watercloset.dmi'
	icon_state = "toilet00"
	density = FALSE

/obj/covers/generic_wall/extraction_mall
	not_movable = TRUE
	amount = 0
	attackby(obj/item/I, mob/user)
		return
	try_destroy()
		return
	bullet_act(obj/item/projectile/P)
		return
	ex_act(severity)
		return

/obj/structure/extraction_mall_stairs
	name = "Mall stairs"
	desc = "Pedestrian stair core. Click to change floors. Vehicles cannot use this route."
	icon = 'icons/obj/stairs.dmi'
	icon_state = "ladderup"
	anchored = TRUE
	density = FALSE
	opacity = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/destination_z = 4
	proc/traverse(mob/living/human/H)
		var/obj/map_metadata/extraction_survival/mall/M = map
		if (!istype(M) || !M.owned(H) || H.stat != CONSCIOUS || !Adjacent(H) || H.z != z || H.buckled || H.pinned.len || H.restrained()) return FALSE
		var/datum/extraction_session/S = H.extraction_session
		if (S.transitioning || S.profile["state"] != "raid" || M.round_closing || M.game_over || !M.mission_z(z) || !M.mission_z(destination_z)) return FALSE
		// Only the intended bidirectional parking/retail/gallery connections.
		if (!((z == 1 && destination_z == 4) || (z == 4 && destination_z in list(1, 5)) || (z == 5 && destination_z == 4))) return FALSE
		var/turf/T = locate(x, y, destination_z)
		if (!istype(T, /turf/floor) || T.density) return FALSE
		var/obj/structure/extraction_mall_stairs/return_stairs
		for (var/atom/movable/A in T)
			if (A.density || isliving(A)) return FALSE
			if (istype(A, /obj/structure/extraction_mall_stairs)) return_stairs = A
		if (!return_stairs || return_stairs.destination_z != z) return FALSE
		H.forceMove(T)
		return get_turf(H) == T
	attack_hand(mob/user)
		var/mob/living/human/H = user
		if (!istype(H) || !traverse(H)) return
		to_chat(H, "You reach [get_area(H)].")
