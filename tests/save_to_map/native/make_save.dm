// Writes a small synthetic completed generation in the layout saving.dm uses
// (level formats 3, 4 and the format-5 index), for tests/save_to_map/run_native.py.
// Only synthetic data; the stream file of format 5 is written by the helper.
//
// Params: format=3|4|5, generation=<id>. Writes 1.sav and 2.sav (+ parts)
// in the world directory. A 4x3x2 world: z1 is a full level, z2 a sparse
// building level with two saved cells.

/turf/floor/wood
/turf/floor/grass
/turf/wall/iron
/turf/sky/building
/obj/structure/bed/chair
/obj/structure/closet
/obj/structure/vehicleparts/frame
/obj/item/stack/rods
/obj/covers/wood
/obj/roof/wood
/mob/living/human

/world
	sleep_offline = 0

var/list/fixture_entries = list()
var/fixture_next = 1

// One entry: type, fields and direct contents, like BuildVarDirectory.
/proc/fixture_entry(type, list/fields, list/contents)
	var/ref = fixture_next++
	fixture_entries += list(list("ref" = ref, "type" = type, "fields" = fields, "contents" = contents))
	return ref

/proc/fixture_write_entry(savefile/F, list/row, format)
	var/ref = row["ref"]
	F.cd = "/entries/[round((ref - 1) / 512)]/[ref]"
	F["type"] << row["type"]
	var/list/fields = row["fields"]
	for(var/name in fields)
		F[name] << fields[name]
	var/list/contents = row["contents"]
	if(contents && contents.len)
		F["content"] << list(list2params(contents))
	F.cd = "/"

/world/New()
	..()
	var/format = text2num(world.params["format"])
	var/generation = world.params["generation"]
	// z1: full level. Cell (2,2) holds a rotated chair, a mob, a loose item,
	// a vehicle frame and a closet with something inside.
	var/list/grid1 = list()
	for(var/y = 1, y <= 3, y++)
		for(var/x = 1, x <= 4, x++)
			var/list/contents = list()
			var/turf_type = /turf/floor/grass
			var/list/turf_fields = list("icon_state" = "grass[x]")
			if(x == 2 && y == 2)
				turf_type = /turf/floor/wood
				var/inner = fixture_entry(/obj/item/stack/rods, list("amount" = 3), null)
				contents += fixture_entry(/obj/structure/bed/chair, list("dir" = 4, "pixel_x" = 6, "name" = "Secret \[chair\] \"name\""), null)
				contents += fixture_entry(/mob/living/human, list("name" = "Player Name", "ckey" = "privateckey"), null)
				contents += fixture_entry(/obj/item/stack/rods, list("amount" = 5), null)
				contents += fixture_entry(/obj/structure/vehicleparts/frame, list("dir" = 2), null)
				contents += fixture_entry(/obj/structure/closet, list("opened" = 1, "dir" = 99), list(inner))
			if(x == 4 && y == 3)
				turf_type = /turf/wall/iron
				turf_fields = list("health" = 50)
			if(x == 1 && y == 1)
				contents += fixture_entry(/obj/covers/wood, list("dir" = list("kind" = "value", "value" = 8)), null)
			grid1["[x],[y]"] = fixture_entry(turf_type, turf_fields, contents)
	// Reorder: contents were numbered before their turf; that is what the save does too.
	write_level(1, format, generation, grid1, null)
	fixture_entries = list()
	fixture_next = 1
	// z2: sparse building level, two saved cells: a roof and a wood floor.
	var/list/grid2 = list()
	grid2["1,1"] = fixture_entry(/turf/floor/wood, list(), list(fixture_entry(/obj/roof/wood, list(), null)))
	grid2["3,2"] = fixture_entry(/turf/floor/wood, list("dir" = 1), null)
	write_level(2, format, generation, grid2, TRUE)
	del(world)

/proc/write_level(z, format, generation, list/grid, sparse)
	fdel("[z].sav")
	var/savefile/F = new("[z].sav")
	F["/format_version"] << format
	F["/value_format"] << 2
	F["/generation"] << generation
	F["/maxx"] << 4
	F["/maxy"] << 3
	F["/maxz"] << 2
	if(sparse)
		F["/sparse/kind"] << "building"
		F["/sparse/turf"] << /turf/sky/building
		F["/sparse/zone"] << "zone-sky"
		F["/sparse/cells"] << grid.len
	for(var/key in grid)
		var/list/xy = splittext(key, ",")
		var/ref = grid[key]
		F["/map/[z]/[xy[2]]/[xy[1]]"] << ref
		F["/zone_capture/[ref]/index"] << ref
		F["/zone_capture/[ref]/id"] << (sparse ? "zone-house" : (xy[1] == "4" ? "zone-house" : "zone-outside"))
	if(format == 3)
		for(var/list/row in fixture_entries)
			fixture_write_entry(F, row, format)
	else if(format == 4)
		// Two segments split at entry 6, like level_segment_writer.
		var/list/bounds = list(min(6, fixture_entries.len), fixture_entries.len)
		F["/segments/count"] << 2
		F["/segments/entries"] << bounds
		F["/segments/lists"] << list(0, 0)
		for(var/number = 1, number <= 2, number++)
			fdel("[z].part[number].sav")
			var/savefile/S = new("[z].part[number].sav")
			S["/format_version"] << 3
			S["/segment"] << number
			S["/generation"] << generation
			for(var/list/row in fixture_entries)
				var/ref = row["ref"]
				if((number == 1 && ref <= bounds[1]) || (number == 2 && ref > bounds[1]))
					fixture_write_entry(S, row, format)
	else
		F["/stream/file"] << "[z].stream.sav"
		// The helper writes the stream from this listing (run_native.py).
		var/list/rows = list()
		for(var/list/row in fixture_entries)
			var/list/fields = row["fields"]
			var/list/out = list("ref" = row["ref"], "type" = "[row["type"]]", "fields" = list(), "contents" = row["contents"] ? list2params(row["contents"]) : null)
			for(var/name in fields)
				out["fields"][name] = fields[name]
			rows += list(out)
		fdel("[z].stream.json")
		text2file(json_encode(rows), "[z].stream.json")
