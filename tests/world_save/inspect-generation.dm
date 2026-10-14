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
					F.cd = map_storage.entry_path(F, ref)
					if(!("content" in F.dir)) continue
					var/contents = F["[map_storage.entry_path(F, ref)]/content"]
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
					var/type = F["[map_storage.entry_path(F, ref)]/type"]
					if(!ispath(type, /mob/living/human)) continue
					var/root = "[ref]"
					var/list/seen = list()
					while(parents[root])
						if(seen[root]) throw EXCEPTION("Cyclic saved containment")
						seen[root] = TRUE
						root = parents[root]
					var/list/row = list("z" = z, "entry" = "[ref]", "position" = coordinates[root])
					row["snapshot"] = generation_snapshot(F, ref, list())
					row["serialized_snapshot"] = json_encode(row["snapshot"])
					humans += list(row)
#ifdef WORLD_SAVE_PLAYER_MIGRATION
			generation_migrate_player(humans)
			report["ownership_migrated"] = TRUE
#endif
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
	F.cd = map_storage.entry_path(F, ref)
	var/list/fields = F.dir.Copy()
	var/list/result = list("entry" = "[ref]", "fields" = list(), "contents" = list())
	var/list/values = result["fields"]
	for(var/field in fields)
		if(field == "content") continue
		values[field] = F["[map_storage.entry_path(F, ref)]/[field]"]
	var/list/children = result["contents"]
	if("content" in fields)
		var/content = F["[map_storage.entry_path(F, ref)]/content"]
		for(var/child in params2list(content))
			children += list(generation_snapshot(F, child, visited, depth + 1))
			TICK_CHECK
	return result

#ifdef WORLD_SAVE_PLAYER_MIGRATION
/proc/generation_migrate_player(list/humans)
	var/list/manifest = json_decode(file2text("migration-manifest.json"))
	var/account = manifest["account"]
	if(manifest["schema"] != 1 || !istext(account) || !length(account) || ckey(account) != account || persistence_guest_account(account))
		throw EXCEPTION("Invalid migration account or manifest")
	var/list/selected
	for(var/list/row in humans)
		var/list/snapshot = row["snapshot"]
		var/list/fields = snapshot["fields"]
		if("persistence_owner_ckey" in fields)
			throw EXCEPTION("Migration requires an unowned legacy generation")
		if(row["z"] == manifest["z"] && row["entry"] == manifest["entry"])
			if(selected) throw EXCEPTION("Ambiguous migration entry")
			selected = row
	if(!selected || selected["serialized_snapshot"] != manifest["serialized_snapshot"])
		throw EXCEPTION("Migration body fingerprint differs from reviewed generation")
	var/list/selected_snapshot = selected["snapshot"]
	var/list/selected_fields = selected_snapshot["fields"]
	var/list/audit = selected_fields["lastKnownCkey"]
	if(!islist(audit) || audit["kind"] != "value" || audit["value"] != account)
		throw EXCEPTION("Migration account audit differs from authenticated observation")
	var/z = selected["z"]
	var/ref = selected["entry"]
	var/savefile/F = new("map_saves/[z].sav")
	if(F["/format_version"] != 2) throw EXCEPTION("Migration requires typed version 2")
	F["[map_storage.entry_path(F, ref)]/persistence_owner_ckey"] << list("kind" = "value", "value" = account)
	F = null
	if(!map_storage.validate_world_save())
		throw EXCEPTION("Derived migration failed production validation")
#endif
