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
