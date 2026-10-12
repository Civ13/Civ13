// Paid portable installation. The ordinary native engine burns the actual
// saved jerrycan contents; its live cables and callbacks are never serialized.
/obj/item/extraction_generator_kit
	name = "private gasoline generator kit"
	desc = "A gasoline generator and short workshop cable. Install in your private room. Fuel is sold separately."
	icon = 'icons/obj/engines32.dmi'
	icon_state = "gasoline_static"
	w_class = ITEM_SIZE_HUGE
	var/generator_broken = FALSE
	var/tmp/obj/structure/engine/internal/gasoline/extraction_private/engine
	var/tmp/obj/structure/cable/cable
	New()
		..()
		new /obj/item/weapon/reagent_containers/glass/barrel/jerrycan(src)
	proc/tank()
		if (contents.len != 1) return null
		var/obj/item/weapon/reagent_containers/glass/barrel/jerrycan/T = contents[1]
		return istype(T) && T.type == /obj/item/weapon/reagent_containers/glass/barrel/jerrycan && !T.contents.len ? T : null
	proc/access(mob/living/human/H)
		var/obj/map_metadata/extraction_survival/M = map
		var/datum/extraction_session/S = H?.extraction_session
		return istype(M) && M.owned(H) && !S.transitioning && !extraction_secure_stored && !extraction_insurance_token && S.profile["state"] == "home" && S.profile["level"] >= 2 && H.Adjacent(src) && S.house && get_turf(src)?.z == S.house.z && get_dist(get_turf(src), S.house) <= 4 && map.is_node_done(H.civilization, "electricity")
	proc/snapshot_installation()
		if (!tank()) return FALSE
		if (engine)
			if (engine.fueltank != tank() || !cable || engine.loc != loc || !isturf(loc)) return FALSE
			generator_broken = engine.broken
		return TRUE
	proc/install(mob/living/human/H)
		if (!access(H) || engine || !tank()) return FALSE
		var/datum/extraction_session/S = H.extraction_session
		var/turf/site = locate(S.house.x - 3, S.house.y - 4, S.house.z)
		var/turf/wire = locate(S.house.x - 3, S.house.y - 3, S.house.z)
		if (!site || !wire || site.density || wire.density) return FALSE
		for (var/obj/item/extraction_generator_kit/G in site)
			if (G != src) return FALSE
		H.unEquip(src, TRUE)
		forceMove(site)
		anchored = TRUE
		engine = new(site)
		engine.kit = src
		engine.should_save = FALSE
		engine.anchored = TRUE
		engine.broken = generator_broken
		engine.fueltank = tank()
		cable = new(wire)
		cable.should_save = FALSE
		engine.connections |= cable
		cable.connections |= engine
		return TRUE
	attack_hand(mob/living/human/H)
		if (!access(H)) return
		if (!engine && !install(H)) return
		// Native startup, fuel threshold, demand and running loop remain intact.
		engine.attack_hand(H)
	attackby(obj/item/I, mob/living/human/H)
		if (!access(H) || !tank() || !istype(I, /obj/item/weapon/reagent_containers/glass/barrel/jerrycan)) return
		if (engine?.on) return
		var/obj/item/weapon/reagent_containers/glass/barrel/jerrycan/F = I
		if (!F.reagents || !F.reagents.has_reagent("gasoline")) return
		// Reject mixed/unsupported fuel rather than deleting a contaminant.
		for (var/datum/reagent/R in F.reagents.reagent_list)
			if (R.id != "gasoline") return
		var/obj/item/weapon/reagent_containers/glass/barrel/jerrycan/T = tank()
		F.reagents.trans_to(T, min(F.reagents.total_volume, T.reagents.maximum_volume - T.reagents.total_volume))
	Destroy()
		if (engine)
			engine.on = FALSE
			engine.power_off_connections()
			engine.fueltank = null
			qdel(engine)
		if (cable) qdel(cable)
		engine = null
		cable = null
		return ..()
	persistence_runtime_var(key)
		return (key in list("engine", "cable")) || ..(key)

// The kit is the sole account access point for its runtime-only engine.
/obj/structure/engine/internal/gasoline/extraction_private
	var/tmp/obj/item/extraction_generator_kit/kit
	attack_hand(mob/user)
		if (istype(user, /mob/living/human) && kit?.access(user)) return ..()
	attackby(obj/item/I, mob/user)
		return
	remove_fueltank()
		return
