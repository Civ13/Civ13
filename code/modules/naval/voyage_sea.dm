// ============================================================
// The sea going by on a voyage (docs/ship-voyage.md)
// ------------------------------------------------------------
// On a voyage she lies off the coast at anchor: the world chart carries her,
// not the map. Her crew should still see her sail, so for as long as the
// voyage lasts every tile of open water round her is drawn, for them only,
// streaming past her from bow to stern at a steady pace.
//
// Appearance only: each water tile gets an override image of itself that
// slides one tile sternwards and snaps back, over and over. Every water tile
// of a kind looks the same and shares one animation loop, so the snap back
// is a whole tile and cannot be seen. Nothing moves, nothing is saved, and a
// click on the water still finds the real tile.
// ============================================================

#define VOYAGE_SEA_RANGE 24     // Tiles of water drawn past her on every side.
#define VOYAGE_SEA_TILE_TIME 12 // Deciseconds the water takes to go one tile by.

/obj/structure/hull_tiller
	var/tmp/datum/voyage_sea/voyage_sea = null

/datum/voyage_sea
	should_save = FALSE
	var/obj/structure/hull_tiller/tiller
	var/heading = 0
	var/list/images = list()   // One override image per water tile round her.
	var/list/watchers = list() // Clients that see them.

/datum/voyage_sea/New(obj/structure/hull_tiller/T)
	..()
	tiller = T

/datum/voyage_sea/Destroy()
	clear()
	tiller = null
	return ..()

// The water tiles round her, as drawn. A tile under her hull is hers, not the sea's.
/datum/voyage_sea/proc/build()
	clear_images()
	var/datum/craft_body/built/B = tiller && tiller.body()
	if (!istype(B) || !B.placed())
		return
	heading = B.heading()
	var/list/box = B.box(B.offsets)
	var/x1 = max(1, B.px + box[1] - VOYAGE_SEA_RANGE)
	var/y1 = max(1, B.py + box[2] - VOYAGE_SEA_RANGE)
	var/x2 = min(world.maxx, B.px + box[3] + VOYAGE_SEA_RANGE)
	var/y2 = min(world.maxy, B.py + box[4] + VOYAGE_SEA_RANGE)
	var/shift_x = (heading == EAST ? -1 : (heading == WEST ? 1 : 0)) * world.icon_size
	var/shift_y = (heading == NORTH ? -1 : (heading == SOUTH ? 1 : 0)) * world.icon_size
	// The tiles under her (and any other floor) are drawn as the open water
	// round her: their own water is hidden under the planks, but the water
	// sliding sternwards out from under her stern must come from somewhere.
	var/turf/sample = null
	var/list/open = list()
	var/list/under = list()
	for (var/turf/T in block(locate(x1, y1, B.z), locate(x2, y2, B.z)))
		if (!is_liquid_water(T))
			continue
		if (T.iscovered() || B.contains(T))
			under[T] = TRUE
		else
			open += T
			if (!sample)
				sample = T
	if (!sample)
		return
	for (var/turf/T in open + under)
		var/image/I = image(loc = T)
		I.appearance = under[T] ? sample.appearance : T.appearance
		I.loc = T
		I.override = TRUE
		I.mouse_opacity = 0
		images += I
		voyage_sea_flow(I, shift_x, shift_y)

// Slides I one tile sternwards and back, forever.
/proc/voyage_sea_flow(image/I, shift_x, shift_y)
	animate(I, pixel_x = shift_x, pixel_y = shift_y, time = VOYAGE_SEA_TILE_TIME, loop = -1)
	animate(pixel_x = 0, pixel_y = 0, time = 0)

// Shows the stream to whoever of her crew can see it now, and to nobody else.
/datum/voyage_sea/proc/refresh(list/crew)
	var/datum/craft_body/built/B = tiller && tiller.body()
	if (!istype(B) || !B.placed())
		clear()
		return
	if (!images.len || heading != B.heading())
		for (var/client/C in watchers)
			C.images -= images
		watchers.Cut()
		build()
	var/list/now = list()
	for (var/mob/M in crew)
		if (M.client)
			now[M.client] = TRUE
	for (var/client/C in watchers.Copy())
		if (!now[C])
			C.images -= images
			watchers -= C
	for (var/client/C in now)
		if (!(C in watchers))
			C.images += images
			watchers += C

/datum/voyage_sea/proc/clear_images()
	for (var/client/C in watchers)
		C.images -= images
	images.Cut()

/datum/voyage_sea/proc/clear()
	clear_images()
	watchers.Cut()

// Everyone aboard, awake or not, who has a client: they all see her sail.
/obj/structure/hull_tiller/proc/voyage_sea_viewers()
	. = list()
	var/datum/craft_body/built/B = body()
	if (!B)
		return
	for (var/mob/M in B.aboard())
		if (M.client)
			. += M

/obj/structure/hull_tiller/proc/voyage_sea_show()
	if (!voyage)
		voyage_sea_stop()
		return
	if (!voyage_sea)
		voyage_sea = new(src)
	voyage_sea.refresh(voyage_sea_viewers())

/obj/structure/hull_tiller/proc/voyage_sea_stop()
	if (voyage_sea)
		qdel(voyage_sea)
		voyage_sea = null

/obj/structure/hull_tiller/Destroy()
	voyage_sea_stop()
	return ..()

#undef VOYAGE_SEA_RANGE
