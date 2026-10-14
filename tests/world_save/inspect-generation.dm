// Full production types and validator, with startup disabled by the packet builder.
/world/OpenPort(port)
	if(port) return FALSE
	return ..(0)

/world/New()
	world.OpenPort(0)
	spawn(0)
		var/list/report = list("validated" = FALSE, "humans" = list())
		try
			map = new /obj/map_metadata
			map.ID = "NOMADS_GAIA"
			if(!map_storage.validate_world_save())
				throw EXCEPTION("Production validation rejected: [map_storage.last_error]")
			report["validated"] = TRUE
			var/list/humans = report["humans"]
			for(var/z = 1, z <= world.maxz, z++)
				var/savefile/F = new("map_saves/[z].sav")
				var/list/entries = generation_entries(F)
				var/list/parents = list()
				for(var/ref in entries)
					var/contents = F["[entry_path(F, ref)]/content"]
					for(var/child in params2list(contents))
						if(parents["[child]"])
							throw EXCEPTION("Multiple saved containment parents for [child]")
						parents["[child]"] = "[ref]"
					TICK_CHECK
				var/list/coordinates = list()
				for(var/y = 1, y <= world.maxy, y++)
					for(var/x = 1, x <= world.maxx, x++)
						var/ref = F["/map/[z]/[y]/[x]"]
						coordinates["[ref]"] = list(x, y, z)
						TICK_CHECK
				for(var/ref in entries)
					var/type = F["[entry_path(F, ref)]/type"]
					if(!ispath(type, /mob/living/human)) continue
					var/root = "[ref]"
					var/list/seen = list()
					while(parents[root])
						if(seen[root]) throw EXCEPTION("Cyclic saved containment")
						seen[root] = TRUE
						root = parents[root]
					var/list/row = list("z" = z, "entry" = "[ref]", "position" = coordinates[root])
					row["snapshot"] = generation_snapshot(F, ref, list())
					humans += list(row)
		catch(var/exception/e)
			report["error"] = "[e] on [e.file]:[e.line]"
		if(!text2file(json_encode(report), "generation-inspection.json"))
			world.log << "FAIL: inspection output write failed"
		else
			world.log << (report["error"] ? "FAIL: generation inspection" : "PASS: generation inspection")
		shutdown()

/proc/generation_entries(savefile/F)
	F.cd = "/entries"
	var/list/entries = F.dir.Copy()
	if(F["/format_version"] == 2)
		var/list/shards = entries
		entries = list()
		for(var/shard in shards)
			F.cd = "/entries/[shard]"
			entries += F.dir.Copy()
	return entries

/proc/generation_snapshot(savefile/F, ref, list/visited, depth = 0)
	if(depth > 32 || visited.len > 10000)
		throw EXCEPTION("Saved body snapshot exceeds inspection bound")
	if(visited["[ref]"]) return list("alias_entry" = "[ref]")
	visited["[ref]"] = TRUE
	F.cd = entry_path(F, ref)
	var/list/fields = F.dir.Copy()
	var/list/result = list("entry" = "[ref]", "fields" = list(), "contents" = list())
	var/list/values = result["fields"]
	for(var/field in fields)
		if(field == "content") continue
		values[field] = F["[entry_path(F, ref)]/[field]"]
	var/list/children = result["contents"]
	var/content = F["[entry_path(F, ref)]/content"]
	for(var/child in params2list(content))
		children += list(generation_snapshot(F, child, visited, depth + 1))
		TICK_CHECK
	return result
