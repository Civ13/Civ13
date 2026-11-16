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
