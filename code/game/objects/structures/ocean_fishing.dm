// Open-water fishing (#3051). Cast a fishing pole, rod or net over the side of a
// boat into deep saltwater; no fish hotspot is needed. Each 8x8 stretch of ocean
// holds a few fish that come back over time, so a crew has to keep moving.
// Raw meat or raw fish hooked onto the line makes a bite far likelier.

#define OCEAN_FISH_CHUNK 8
#define OCEAN_FISH_MAX 3
#define OCEAN_FISH_REGEN (10 MINUTES)
#define OCEAN_BAIT_USES 3

// "chunk x,chunk y,z" -> list(fish left, time the next fish started coming back)
var/global/list/ocean_fish_stock = list()

/proc/ocean_fish_key(turf/T)
	return "[round(T.x / OCEAN_FISH_CHUNK)],[round(T.y / OCEAN_FISH_CHUNK)],[T.z]"

/proc/ocean_fish_available(turf/T)
	if (!T)
		return 0
	var/key = ocean_fish_key(T)
	var/list/entry = ocean_fish_stock[key]
	if (!entry)
		entry = list(OCEAN_FISH_MAX, world.time)
		ocean_fish_stock[key] = entry
	if (entry[1] < OCEAN_FISH_MAX)
		var/regained = round((world.time - entry[2]) / OCEAN_FISH_REGEN)
		if (regained > 0)
			entry[1] = min(OCEAN_FISH_MAX, entry[1] + regained)
			entry[2] += regained * OCEAN_FISH_REGEN
	if (entry[1] >= OCEAN_FISH_MAX)
		entry[2] = world.time // a full stretch does not bank regrowth
	return entry[1]

/proc/ocean_fish_take(turf/T)
	if (ocean_fish_available(T) <= 0)
		return FALSE
	var/list/entry = ocean_fish_stock[ocean_fish_key(T)]
	entry[1]--
	return TRUE

// Bait
/obj/item/weapon/fishing/var/bait_uses = 0

/obj/item/weapon/fishing/proc/is_bait(obj/item/I)
	return istype(I, /obj/item/weapon/reagent_containers/food/snacks/meat) || istype(I, /obj/item/weapon/reagent_containers/food/snacks/rawfish)

/obj/item/weapon/fishing/attackby(obj/item/W as obj, mob/user as mob)
	if (!is_bait(W))
		return ..()
	if (bait_uses > 0)
		to_chat(user, SPAN_WARNING("\The [src] is already baited."))
		return
	var/bait_name = W.name
	user.drop_from_inventory(W)
	qdel(W)
	bait_uses = OCEAN_BAIT_USES
	to_chat(user, SPAN_NOTICE("You cut up \the [bait_name] and bait \the [src]. It's good for [OCEAN_BAIT_USES] casts."))

/obj/item/weapon/fishing/examine(mob/user, var/distance = -1)
	..()
	if (bait_uses > 0)
		to_chat(user, SPAN_NOTICE("It is baited for [bait_uses] more cast\s."))

// Boats
/mob/living/human/var/tmp/ocean_fishing = FALSE

/mob/living/human/proc/on_boat_deck()
	if (driver_vehicle)
		return TRUE
	var/turf/T = get_turf(src)
	if (!istype(T, /turf/floor/beach/water))
		return FALSE
	return (locate(/obj/structure/vehicleparts/frame) in T) || (locate(/obj/structure/vehicleparts/axis) in T)

/turf/floor/beach/water/deep/saltwater/attackby(obj/item/C as obj, mob/user as mob)
	if (istype(C, /obj/item/weapon/fishing) && ishuman(user) && !istype(src, /turf/floor/beach/water/deep/saltwater/underwater))
		cast_ocean_line(C, user)
		return
	..()

/turf/floor/beach/water/deep/saltwater/proc/cast_ocean_line(obj/item/weapon/fishing/F, mob/living/human/H)
	if (H.ocean_fishing)
		to_chat(H, SPAN_WARNING("You are already fishing."))
		return
	if (!H.on_boat_deck())
		to_chat(H, SPAN_WARNING("You need to be on a boat to fish the open sea."))
		return
	if (iscovered() || (locate(/obj/structure/vehicleparts/frame) in src) || (locate(/obj/structure/vehicleparts/axis) in src))
		to_chat(H, SPAN_WARNING("Cast over the side, into open water."))
		return
	if (ocean_fish_available(src) <= 0)
		to_chat(H, SPAN_WARNING("This stretch of sea seems fished out. Try further along."))
		return
	var/baited = F.bait_uses > 0
	H.ocean_fishing = TRUE
	H.visible_message(SPAN_NOTICE("[H] casts \the [F] over the side."), SPAN_NOTICE("You cast \the [F] over the side[baited ? " with bait on the line" : ""]."))
	var/modern = istype(F, /obj/item/weapon/fishing/modern)
	var/done = do_after(H, modern ? 120 : 150, src)
	H.ocean_fishing = FALSE
	if (!done || F.loc != H || !H.on_boat_deck() || !Adjacent(H))
		return
	if (baited && F.bait_uses > 0)
		F.bait_uses--
	var/chance = (modern ? 25 : 15) + (baited ? 30 : 0)
	if (!prob(chance))
		to_chat(H, "Nothing bites...")
		return
	if (!ocean_fish_take(src)) // someone else on deck took the last fish during the wait
		to_chat(H, "Whatever was biting got away.")
		return
	var/catch_path = /obj/item/weapon/reagent_containers/food/snacks/rawfish
	if (prob(55))
		catch_path = /obj/item/weapon/reagent_containers/food/snacks/rawfish/cod
	else if (baited && prob(20))
		catch_path = /obj/item/weapon/reagent_containers/food/snacks/pink_squid
	var/obj/item/caught = new catch_path(get_turf(H))
	H.put_in_hands(caught)
	to_chat(H, SPAN_NOTICE("You reel in \a [caught]!"))
	H.adaptStat("dexterity", 1)

#undef OCEAN_FISH_CHUNK
#undef OCEAN_FISH_MAX
#undef OCEAN_FISH_REGEN
#undef OCEAN_BAIT_USES
