// character_view: what a controlled character sees, as an appearance dump in the
// byond-devtools ingame format (appearance trees with overlays and underlays, colour
// matrices, planes and the plane masters a player's HUD builds). byond-devtools renders
// it (dump_render, or `cli.js ingame --dump`); civ13_agent.py does that for the MCP tool.
// Icons from the source tree are named by path; icons made at runtime (human bodies,
// blended overlays) are sent as base64 DMI bytes. The dump is built once and read in
// parts, because a Topic reply holds at most 64 KB.

#define AGENT_VIEW_PART 30000 // characters of dump text per reply
#define AGENT_VIEW_MAX_BYTES 4000000
#define AGENT_VIEW_MAX_RUNTIME_ICONS 48
#define AGENT_VIEW_MAX_ICON_BYTES 120000

var/global/list/agent_view_plane_masters // built once: plane masters as a player's HUD makes them

/datum/agent_character
	var/view_text // the last dump, read in parts
	var/view_id = 0

/datum/agent_view_dump
	var/list/apps = list() // appearance ref -> index
	var/list/app_rows = list()
	var/list/icons = list() // icon key -> index
	var/list/icon_rows = list()
	var/runtime_icons = 0
	var/skipped_icons = 0

/datum/agent_view_dump/proc/icon_index(icon)
	if (!icon)
		return null
	var/named = isfile(icon) && length("[icon]")
	var/key = named ? "file:[icon]" : "ref:\ref[icon]"
	if (icons[key])
		return icons[key]
	var/list/row = list("source" = named ? "[icon]" : null)
	if (!named)
		var/data = runtime_icons < AGENT_VIEW_MAX_RUNTIME_ICONS ? agent_icon_base64(icon) : null
		if (data && length(data) <= AGENT_VIEW_MAX_ICON_BYTES)
			runtime_icons++
			row["base64"] = data
		else
			skipped_icons++
	icon_rows += list(row)
	icons[key] = icon_rows.len
	return icon_rows.len

/datum/agent_view_dump/proc/value(v)
	if (islist(v))
		var/list/L = v
		return L.Copy()
	if (isnull(v) || isnum(v) || istext(v))
		return v
	return "[v]"

// Index of one appearance (an atom's, or an overlay/underlay entry), recorded once.
/datum/agent_view_dump/proc/app_index(source, ref_key)
	if (apps[ref_key])
		return apps[ref_key]
	var/mutable_appearance/M = new(source)
	app_rows += list(null)
	var/n = app_rows.len
	apps[ref_key] = n
	var/list/row = list(
		"icon" = icon_index(M.icon), "icon_state" = "[M.icon_state]", "dir" = M.dir,
		"layer" = M.layer, "plane" = M.plane, "pixel_x" = M.pixel_x, "pixel_y" = M.pixel_y,
		"pixel_w" = M.pixel_w, "pixel_z" = M.pixel_z, "color" = value(M.color), "alpha" = M.alpha,
		"blend_mode" = M.blend_mode, "appearance_flags" = M.appearance_flags, "invisibility" = M.invisibility,
		"filters" = length(M.filters), "maptext" = length(M.maptext) ? 1 : 0)
	var/matrix/T = M.transform
	if (T && (T.a != 1 || T.b != 0 || T.c != 0 || T.d != 0 || T.e != 1 || T.f != 0))
		row["transform"] = list(T.a, T.b, T.c, T.d, T.e, T.f)
	var/list/over = list()
	for (var/o in M.overlays)
		over += app_index(o, ref(o))
	var/list/under = list()
	for (var/u in M.underlays)
		under += app_index(u, ref(u))
	row["overlays"] = over
	row["underlays"] = under
	app_rows[n] = row
	return n

// A runtime icon's DMI bytes as base64: a savefile's text export carries them.
/proc/agent_icon_base64(icon/I)
	var/savefile/S = new
	S["i"] << I
	var/text = S.ExportText("i")
	var/open = findtext(text, "{\"")
	var/close = findlasttext(text, "\"}")
	if (!open || close <= open)
		return null
	return replacetext(replacetext(copytext(text, open + 2, close), "\n", ""), ascii2text(13), "")

/proc/agent_view_masters()
	if (!agent_view_plane_masters)
		agent_view_plane_masters = list()
		for (var/t in subtypesof(/obj/screen/plane_master))
			if (t == /obj/screen/plane_master/light_mask && !LIGHTING_COMPOSITION_V2)
				continue
			var/obj/screen/plane_master/P = new t()
			P.backdrop(null)
			agent_view_plane_masters += P
	return agent_view_plane_masters

// The dump for the turfs the character can see within radius; unseen tiles are left out
// (the renderer draws them black, as a player's screen would).
/proc/agent_view_dump(mob/living/M, radius)
	var/turf/here = get_turf(M)
	if (!here)
		agent_fail("invalid_state", "the character is not on the map")
	var/x1 = max(1, here.x - radius), y1 = max(1, here.y - radius)
	var/x2 = min(world.maxx, here.x + radius), y2 = min(world.maxy, here.y + radius)
	var/datum/agent_view_dump/D = new
	var/list/cells = list()
	var/vis = 0
	for (var/turf/T in view(radius, M))
		if (T.z != here.z)
			continue
		var/list/movables = list()
		for (var/atom/movable/A in T)
			if (A.loc != T || A.invisibility > M.see_invisible)
				continue
			movables += list(list(D.app_index(A, ref(A.appearance)), A.step_x, A.step_y, "[A.type]"))
			if (length(A.vis_contents))
				vis++
		if (length(T.vis_contents))
			vis++
		cells += list(list(T.x, T.y, D.app_index(T.loc, ref(T.loc.appearance)), D.app_index(T, ref(T.appearance)), movables, "[T.type]"))
	var/list/masters = list()
	for (var/obj/screen/plane_master/P in agent_view_masters())
		masters += list(list("type" = "[P.type]", "appearance" = D.app_index(P, ref(P.appearance))))
	return list(
		"byond" = "[world.byond_version].[world.byond_build]", "icon_size" = world.icon_size, "map_format" = world.map_format,
		"maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz, "region" = list(x1, y1, x2, y2, here.z),
		"center" = list(here.x, here.y), "see_invisible" = M.see_invisible, "time_of_day" = time_of_day, "profile" = "civ13",
		"world_time" = world.time, "vis_contents" = vis, "plane_masters" = masters, "appearances" = D.app_rows,
		"icons" = D.icon_rows, "cells" = cells, "skipped_icons" = D.skipped_icons,
		"provenance" = list("truthLayer" = "live-character-view", "character" = agent_ref(M)))

/datum/agent_control/proc/act_character_view(datum/agent_identity/A, list/req)
	var/datum/agent_character/C = character_arg(A, req)
	var/part = round(text2num("[req["part"]]") || 1)
	if (part > 1)
		if (text2num("[req["view"]]") != C.view_id || !C.view_text)
			agent_fail("view_gone", "that view was replaced; start again with part 1")
	else
		var/radius = clamp(round(text2num("[req["radius"]]") || 7), 1, 7)
		audit_read(A, "character_view", "[C.body] ([agent_ref(C.body)])")
		C.view_text = json_encode(agent_view_dump(C.body, radius))
		C.view_id++
		if (length(C.view_text) > AGENT_VIEW_MAX_BYTES)
			C.view_text = null
			agent_fail("too_large", "the view is too large; use a smaller radius")
	var/parts = max(1, -round(-length(C.view_text) / AGENT_VIEW_PART))
	if (part < 1 || part > parts)
		agent_fail("bad_request", "part must be from 1 to [parts]")
	var/start = (part - 1) * AGENT_VIEW_PART + 1
	return list("view" = C.view_id, "part" = part, "parts" = parts, "bytes" = length(C.view_text), "text" = copytext(C.view_text, start, start + AGENT_VIEW_PART))

#undef AGENT_VIEW_PART
#undef AGENT_VIEW_MAX_BYTES
#undef AGENT_VIEW_MAX_RUNTIME_ICONS
#undef AGENT_VIEW_MAX_ICON_BYTES
