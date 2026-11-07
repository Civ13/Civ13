// ============================================================
// Cable risers and bus tie switches
// ------------------------------------------------------------
// A cable grid is one level: cables join neighbours with range(1), and
// rebuild_supply() skips any link to another z. A cable riser carries power
// between levels. Secure one on a tile with cable, and another at the same x
// and y on the level above or below (multiz_level_above/below, so a dug
// cave or an added building level counts as the adjacent level). Every
// cable on the two tiles then joins one grid, through each cable's runtime
// riser_links list (cables.dm). Like a plain connector, a riser also joins
// every cable on its own tile.
//
// Nothing cross-level is saved: riser_links and the pairing are runtime
// state, rebuilt from positions when a riser is secured or loaded.
//
// A bus tie switch is a connector that can be opened and closed by hand:
// closed, it joins every cable on its tile; open, it joins none. Two runs
// that meet on its tile can be split or tied together.
// ============================================================

/obj/item/connector/riser
	name = "cable riser"
	desc = "A conduit that carries power between levels. Secure it on a cable, and secure another riser at the same spot on the level above or below: every cable on both tiles joins one grid."
	color = "#c0a060"

/obj/item/connector/riser/proc/riser_partners()
	var/list/partners = list()
	if (!anchored || !isturf(loc))
		return partners
	for (var/level in list(multiz_level_above(z), multiz_level_below(z)))
		if (!level || level == z)
			continue
		var/turf/T = locate(x, y, level)
		if (!T)
			continue
		for (var/obj/item/connector/riser/R in T)
			if (R != src && R.anchored && !QDELETED(R))
				partners |= R
	return partners

/obj/item/connector/riser/connect_cables()
	..()
	if (!anchored || !isturf(loc) || QDELETED(src))
		return
	var/joined = FALSE
	for (var/obj/item/connector/riser/R in riser_partners())
		for (var/obj/structure/cable/A in turflist)
			for (var/obj/structure/cable/B in R.turflist)
				if (QDELETED(A) || QDELETED(B) || A.loc != loc || B.loc != R.loc)
					continue
				if (!A.riser_links)
					A.riser_links = list()
				if (!B.riser_links)
					B.riser_links = list()
				A.riser_links |= B
				B.riser_links |= A
				joined = TRUE
	if (joined && turflist.len)
		var/obj/structure/cable/root = turflist[1]
		root.rebuild_supply()

// Cut only the links that pass through this tile: cables here to cables on
// the same x and y of another level.
/obj/item/connector/riser/disconnect_cables()
	var/list/touched = list()
	for (var/obj/structure/cable/A in turflist)
		if (!A.riser_links)
			continue
		for (var/obj/structure/cable/B in A.riser_links.Copy())
			if (B.x == A.x && B.y == A.y)
				A.riser_links -= B
				if (B.riser_links)
					B.riser_links -= A
				touched |= B
		if (!A.riser_links.len)
			A.riser_links = null
	..()
	for (var/obj/structure/cable/B in touched)
		if (B.riser_links && !B.riser_links.len)
			B.riser_links = null
		if (!QDELETED(B))
			B.rebuild_supply()

/obj/item/connector/riser/after_load()
	..()
	if (anchored && isturf(loc))
		connect_cables()

/obj/item/connector/riser/examine(mob/user)
	. = ..()
	if (!anchored)
		return
	var/list/partners = riser_partners()
	if (partners.len)
		to_chat(user, "<span class='notice'>It is joined to [partners.len == 1 ? "a riser" : "[partners.len] risers"] on the next level.</span>")
	else
		to_chat(user, "<span class='warning'>No secured riser at this spot on the level above or below.</span>")

// ---------------------------------------------------------------- bus tie

/obj/item/connector/bus_tie
	name = "bus tie switch"
	desc = "A heavy switch that joins every cable on its tile when closed and none when open. Secure it where two runs meet, then use it to tie or split them."
	color = "#a04040"
	var/closed = TRUE

/obj/item/connector/bus_tie/connect_cables()
	if (!closed)
		disconnect_cables()
		return
	..()

/obj/item/connector/bus_tie/attack_hand(mob/user)
	if (!anchored)
		return ..()
	var/mob/living/human/H = user
	if (!istype(H) || H.stat != CONSCIOUS || !H.can_use_hands() || get_dist(H, src) > 1 || H.z != z)
		return
	closed = !closed
	playsound(loc, 'sound/items/Ratchet.ogg', 50, TRUE)
	to_chat(H, "<span class='notice'>You [closed ? "close" : "open"] \the [src].</span>")
	connect_cables()

/obj/item/connector/bus_tie/examine(mob/user)
	. = ..()
	to_chat(user, "It is [closed ? "closed: the cables here are tied together" : "open: the cables here are split"].")
