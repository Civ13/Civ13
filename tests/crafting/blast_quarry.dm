/proc/recipe_ci_blast_quarry()
	var/turf/site = locate(2, 1, 1)
	if (!site)
		recipe_ci_fail("blast quarry", "test site missing")
		return
	var/turf/wall_site = site.ChangeTurf(/turf/floor/dirt/underground)
	if (!wall_site?.quarry_blast_eligible())
		recipe_ci_fail("blast quarry", "solid rock must be eligible")
		return
	wall_site.mining_in_progress = TRUE
	if (wall_site.quarry_blast_eligible())
		recipe_ci_fail("blast quarry", "already-working rock accepted")
	wall_site.mining_in_progress = FALSE
	wall_site.mining_proc(null, TRUE)
	site = locate(2, 1, 1)
	var/obj/structure/quarry_cluster/Q = locate() in site
	if (!Q || site.quarry_blast_eligible() || site.density || Q.stone_left < 12)
		recipe_ci_fail("blast quarry", "blast did not replace a wall with finite stock")
		return
	site.mining_proc(null, TRUE)
	var/cluster_count = 0
	for (var/obj/structure/quarry_cluster/unused in site)
		cluster_count++
	if (cluster_count != 1)
		recipe_ci_fail("blast quarry", "open floor was mined again")
	for (var/obj/item/stack/S in site)
		qdel(S)
	for (var/n in 1 to 12)
		new /obj/item/stack/material/wood(site, 1, FALSE)
	var/original = Q.stone_left
	if (Q.quarry_take_load() || Q.stone_left != original)
		recipe_ci_fail("blast quarry", "full output was not lossless")
	for (var/obj/item/stack/S in site)
		qdel(S)
	if (!Q.quarry_take_load() || Q.stone_left != original - 5)
		recipe_ci_fail("blast quarry", "one load should cost five units from the deposit")
	var/savefile/F = new("blast-quarry.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, Q, 1)
	map_storage.clear_bookkeeping()
	var/obj/structure/quarry_cluster/restored = map_storage.Load_Entry(F, ref, starting_loc = site)
	if (!restored || restored.stone_left != Q.stone_left || restored.stone_type != Q.stone_type)
		recipe_ci_fail("blast quarry", "disk round-trip refilled or changed the remaining stock")
	qdel(restored)
	for (var/i in 1 to 12)
		if (QDELETED(Q) || !Q.quarry_take_load())
			break
	if (!QDELETED(Q))
		recipe_ci_fail("blast quarry", "finished stock did not disappear")
		qdel(Q)
	for (var/obj/item/stack/S in site)
		qdel(S)
