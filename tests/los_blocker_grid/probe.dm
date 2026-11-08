// Native parity probe for the line-of-sight blocker grid. Compiled with the
// geometry procs extracted from code/modules/visibility/los_context.dm.
// For indoor scenes (with eye step offsets, moving blockers and fractional
// targets) the grid answer of blocks_target must equal the flat scan over
// every blocker, which index_blockers() leaves authoritative.
/world/New()
	..()
	spawn(1)
		los_grid_probe()

/proc/los_grid_wall(x, y, dense)
	if (x % 7 == 0 && (y % 6) != 3)
		return TRUE
	if (y % 6 == 0 && (x % 7) != 4)
		return TRUE
	return dense && ((x * 31 + y * 17) % 23) == 0

/proc/los_grid_snapshot(ex, ey, fx, fy, rx, ry, dense)
	var/datum/los_snapshot/S = new
	S.eye_x = ex + fx
	S.eye_y = ey + fy
	S.radius_x = rx
	S.radius_y = ry
	for (var/cx = ex - rx - 1, cx <= ex + rx + 1, cx++)
		for (var/cy = ey - ry - 1, cy <= ey + ry + 1, cy++)
			if (los_grid_wall(cx, cy, dense))
				var/datum/los_cell/B = new
				B.tile_x = cx - S.eye_x
				B.tile_y = cy - S.eye_y
				B.cell_x = B.tile_x
				B.cell_y = B.tile_y
				B.owners = 1
				S.blockers += B
	for (var/i = 1 to 4)
		var/datum/los_cell/M = new
		M.tile_x = rand(-rx, rx) - fx
		M.tile_y = rand(-ry, ry) - fy
		M.cell_x = M.tile_x + rand(-16, 16) / 32
		M.cell_y = M.tile_y + rand(-16, 16) / 32
		M.owners = 1
		S.blockers += M
	return S

/proc/los_grid_flat(datum/los_snapshot/S, tx, ty, tile_x, tile_y, opaque)
	for (var/datum/los_cell/B in S.blockers)
		if (los_target_blocked(tx, ty, B.cell_x, B.cell_y, tile_x, tile_y, B.tile_x, B.tile_y, opaque))
			return TRUE
	return FALSE

/proc/los_grid_probe()
	rand_seed(20261108)
	var/queries = 0
	var/mismatches = 0
	var/hits = 0
	var/gridded = 0
	for (var/trial = 1 to 24)
		var/rx = (trial % 4) ? 15 : 7
		var/ry = (trial % 4) ? 11 : 7
		var/fx = (trial % 2) ? 0 : rand(-8, 31) / 32
		var/fy = (trial % 2) ? 0 : rand(-8, 31) / 32
		var/datum/los_snapshot/S = los_grid_snapshot(rand(50, 150), rand(50, 150), fx, fy, rx, ry, trial % 3)
		S.index_blockers()
		if (S.blocker_grid)
			gridded++
		for (var/tx = -rx, tx <= rx, tx++)
			for (var/ty = -ry, ty <= ry, ty++)
				var/ox = (trial % 3) ? 0 : rand(-12, 12) / 32
				var/oy = (trial % 3) ? 0 : rand(-12, 12) / 32
				for (var/opaque = 0, opaque <= 1, opaque++)
					var/expected = los_grid_flat(S, tx - fx + ox, ty - fy + oy, tx - fx, ty - fy, opaque)
					var/actual = S.blocks_target(tx - fx + ox, ty - fy + oy, tx - fx, ty - fy, opaque)
					queries++
					hits += expected
					if (!expected != !actual)
						mismatches++
						if (mismatches <= 5)
							world.log << "MISMATCH trial=[trial] target=[tx - fx + ox],[ty - fy + oy] opaque=[opaque] flat=[expected] grid=[actual]"
	world.log << "LOS_GRID queries=[queries] blocked=[hits] gridded=[gridded] mismatches=[mismatches]"
	world.log << (mismatches || gridded != 24 || hits == 0 || hits == queries ? "LOS_GRID FAIL" : "LOS_GRID PASS")
	shutdown()
