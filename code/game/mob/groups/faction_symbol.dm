// ============================================================
// Faction custom symbols
// ------------------------------------------------------------
// A 32x32 pixel-art editor (NanoUI) for a faction's banner emblem. The
// symbol is first drawn inside the Faction Creation UI (faction_creation.dm,
// which shares this file's grid primitives and canvas assets); afterwards
// the Leader can only MODIFY it, via this file's editor module and its
// "Modify Faction Symbol" Faction verb. 32x32
// is not arbitrary: it's the exact size of the existing "b_[symbol]" states
// in icons/obj/banners.dmi (confirmed by reading the .dmi's own metadata),
// so a saved custom symbol drops into the SAME banner overlay slot with no
// scaling or repositioning -- it coexists with, rather than replaces, the
// original mechanism.
//
// The two starting-point tools:
//   - Stamp one of the 6 existing shapes (reads real pixel data out of the
//     shipped banners.dmi via icon.GetPixel(), confirmed supported by this
//     BYOND build) as an editable starting point.
//   - Bucket-fill, starting from the plain white background.
// Both just seed/mutate the same editable grid -- nothing is locked.
//
// custom_civs[faction][7]/[8] (main/secondary color, already consumed by the
// banner, faction posters and official paper) are re-derived from the
// drawing itself on save, so nothing downstream needs to change.
// ============================================================

// FACTION_SYMBOL_SIZE lives in code/__defines/faction_lang_defines.dm: DM
// macros are include-order-sensitive, and faction_creation.dm (which shares
// these grid primitives) compiles before this file.
var/global/list/faction_symbol_shapes = list("star", "sun", "moon", "cross", "big cross", "saltire")

// ------------------------------------------------------------
// Grid primitives: global procs over a plain flat list (row-major, row 1 =
// visual top) so the same tools serve BOTH the per-faction store below AND
// the pre-faction draft canvas in the Faction Creation UI
// (faction_creation.dm), where no faction exists yet to key a store by.
// ------------------------------------------------------------

/proc/faction_symbol_grid_index(x, y)
	return (y - 1) * FACTION_SYMBOL_SIZE + x

/proc/faction_symbol_new_grid()
	var/list/grid = new/list(FACTION_SYMBOL_SIZE * FACTION_SYMBOL_SIZE)
	for (var/i = 1, i <= grid.len, i++)
		grid[i] = "#FFFFFF"
	return grid

/proc/faction_symbol_grid_is_blank(list/grid)
	for (var/i = 1, i <= grid.len, i++)
		if (grid[i] != "#FFFFFF")
			return FALSE
	return TRUE

// Reads the shipped 32x32 shape art pixel-by-pixel into the grid as an
// editable starting point (a stamp, not a lock). BYOND's icon.GetPixel()
// addresses row 1 as the BOTTOM row; the grid addresses row 1 as the visual
// TOP (matching the UI's top-down rendering), so the y axis is flipped here.
// GetPixel() returns null for fully transparent pixels -- those become plain
// background, so the grid never holds anything but a real color string.
/proc/faction_symbol_stamp_grid(list/grid, shape)
	if (!(shape in faction_symbol_shapes))
		return
	var/icon/source = icon('icons/obj/banners.dmi', "b_[shape]")
	for (var/y = 1, y <= FACTION_SYMBOL_SIZE, y++)
		for (var/x = 1, x <= FACTION_SYMBOL_SIZE, x++)
			var/px = source.GetPixel(x, FACTION_SYMBOL_SIZE - y + 1)
			grid[faction_symbol_grid_index(x, y)] = px ? px : "#FFFFFF"

// 4-connected iterative flood fill from (x,y), replacing every contiguous
// same-colored pixel with new_color. Iterative (own stack), not recursive --
// a 32x32 grid can be up to 1024 cells deep in a pathological case, more
// than comfortably safe for DM's call stack.
/proc/faction_symbol_bucket_fill_grid(list/grid, x, y, new_color)
	if (x < 1 || x > FACTION_SYMBOL_SIZE || y < 1 || y > FACTION_SYMBOL_SIZE)
		return
	var/target = grid[faction_symbol_grid_index(x, y)]
	if (!target || target == new_color)
		return
	var/list/stack = list(list(x, y))
	var/list/visited = list()
	while (stack.len)
		var/list/point = stack[stack.len]
		stack.len--
		var/px = point[1]
		var/py = point[2]
		if (px < 1 || px > FACTION_SYMBOL_SIZE || py < 1 || py > FACTION_SYMBOL_SIZE)
			continue
		var/key = "[px],[py]"
		if (visited[key])
			continue
		visited[key] = TRUE
		if (grid[faction_symbol_grid_index(px, py)] != target)
			continue
		grid[faction_symbol_grid_index(px, py)] = new_color
		stack += list(list(px + 1, py))
		stack += list(list(px - 1, py))
		stack += list(list(px, py + 1))
		stack += list(list(px, py - 1))

// Applies a client-batched paint stroke ("x,y_x,y_..." as sent by
// faction_symbol.js on mouse-up; '_'-joined because ';' would be eaten as a
// parameter separator by BYOND's href parsing) onto a grid in the given
// color. The cell string is player-controlled input, so every coordinate is
// re-validated here regardless of what the client claims to have painted.
/proc/faction_symbol_apply_stroke(list/grid, cells_string, color)
	if (!cells_string)
		return
	var/list/cells = splittext(cells_string, "_")
	var/applied = 0
	for (var/c in cells)
		if (applied >= FACTION_SYMBOL_SIZE * FACTION_SYMBOL_SIZE)
			break // a legitimate stroke can never exceed the whole canvas
		var/list/xy = splittext(c, ",")
		if (xy.len != 2)
			continue
		var/x = text2num(xy[1])
		var/y = text2num(xy[2])
		if (isnull(x) || isnull(y))
			continue
		x = round(x)
		y = round(y)
		if (x < 1 || x > FACTION_SYMBOL_SIZE || y < 1 || y > FACTION_SYMBOL_SIZE)
			continue
		grid[faction_symbol_grid_index(x, y)] = color
		applied++

// ------------------------------------------------------------
// Undo: a bounded stack of full-grid snapshots, one pushed before every
// mutating action (stroke, single pixel, bucket fill, stamp, clear). Full
// 1024-entry snapshots are deliberate: trivially correct to restore, and at
// FACTION_SYMBOL_UNDO_MAX deep it's small change memory-wise.
// ------------------------------------------------------------

/proc/faction_symbol_push_undo(list/stack, list/grid)
	stack += list(grid.Copy())
	if (stack.len > FACTION_SYMBOL_UNDO_MAX)
		stack.Cut(1, stack.len - FACTION_SYMBOL_UNDO_MAX + 1)

// Returns the popped snapshot, or null if there's nothing to undo.
/proc/faction_symbol_pop_undo(list/stack)
	if (!stack || !stack.len)
		return null
	var/list/grid = stack[stack.len]
	stack.len--
	return grid

// ------------------------------------------------------------
// Per-faction store on map_metadata: thin keyed wrappers over the grid
// primitives above.
// ------------------------------------------------------------

/obj/map_metadata
	var/list/faction_symbol_grid = list()        // faction => flat list of SIZE*SIZE hex strings, row-major top-to-bottom
	var/list/faction_symbol_icon = list()        // faction => finalized /icon (null until first save)
	var/list/faction_symbol_tool = list()        // faction => "paint" or "bucket"
	var/list/faction_symbol_color = list()       // faction => current active paint color
	var/list/faction_symbol_undo = list()        // faction => bounded stack of grid snapshots

/obj/map_metadata/proc/ensure_faction_symbol_undo(faction)
	var/list/stack = faction_symbol_undo[faction]
	if (!stack)
		stack = list()
		faction_symbol_undo[faction] = stack
	return stack

/obj/map_metadata/proc/ensure_faction_symbol_grid(faction)
	var/list/grid = faction_symbol_grid[faction]
	if (!grid)
		grid = faction_symbol_new_grid()
		faction_symbol_grid[faction] = grid
	return grid

/obj/map_metadata/proc/set_faction_symbol_pixel(faction, x, y, color)
	if (x < 1 || x > FACTION_SYMBOL_SIZE || y < 1 || y > FACTION_SYMBOL_SIZE)
		return
	var/list/grid = ensure_faction_symbol_grid(faction)
	grid[faction_symbol_grid_index(x, y)] = color

/obj/map_metadata/proc/stamp_faction_symbol(faction, shape)
	faction_symbol_stamp_grid(ensure_faction_symbol_grid(faction), shape)

// Clears only the DRAFT grid. The baked icon stays active until the next
// Save -- Clear followed by closing the editor (or Undo) must not change
// what banners display. admin_reset_faction_symbol() re-bakes explicitly.
/obj/map_metadata/proc/clear_faction_symbol(faction)
	faction_symbol_grid[faction] = faction_symbol_new_grid()

/obj/map_metadata/proc/bucket_fill_faction_symbol(faction, x, y, new_color)
	faction_symbol_bucket_fill_grid(ensure_faction_symbol_grid(faction), x, y, new_color)

// Bakes the faction's grid into a real PNG via rust_g (the same primitive
// already used by the -- currently non-functional -- painting canvas
// feature) and loads it back as the faction's active /icon. Returns TRUE on
// success.
/obj/map_metadata/proc/bake_faction_symbol_png(faction)
	// text2file() into a not-yet-existing directory creates the missing
	// parent folders as a side effect (standard, reliable DM file I/O
	// behaviour) -- do this first so rust_g always has somewhere to write,
	// since its own directory-creation behaviour isn't something we can
	// verify from here (compiled native library, no source to check).
	if (!fexists("data/faction_symbols"))
		text2file("", "data/faction_symbols/.keep")
	var/list/grid = ensure_faction_symbol_grid(faction)
	var/list/data = list()
	for (var/i = 1, i <= grid.len, i++)
		data += grid[i]
	var/png_filename = "data/faction_symbols/[ckey(faction)].png"
	var/result = rustg_dmi_create_png(png_filename, "[FACTION_SYMBOL_SIZE]", "[FACTION_SYMBOL_SIZE]", data.Join(""))
	if (result)
		log_debug("faction_symbol: rustg_dmi_create_png failed for [faction]: [result]")
		return FALSE
	faction_symbol_icon[faction] = new/icon(png_filename)
	return TRUE

// Player-facing save: bake the PNG, then re-derive the faction's two display
// colors from the drawing.
/obj/map_metadata/proc/finalize_faction_symbol(faction)
	if (!bake_faction_symbol_png(faction))
		return FALSE
	apply_faction_symbol_colors(faction)
	return TRUE

/obj/map_metadata/proc/get_faction_symbol_icon(faction)
	return faction_symbol_icon[faction]

// Admin moderation action: blanks the grid AND bakes+saves a genuinely blank
// white icon as the faction's active custom symbol (rather than just
// clearing it back to null, which would fall through to re-displaying
// whatever fixed shape they originally picked at creation -- not what an
// admin wiping an offending drawing wants). The faction's colors are left
// alone; only the symbol art itself is reset.
/obj/map_metadata/proc/admin_reset_faction_symbol(faction)
	clear_faction_symbol(faction)
	return bake_faction_symbol_png(faction)

// ------------------------------------------------------------
// Color extraction: pick the two colors that best represent the drawing,
// biased toward genuinely DIFFERENT colors (not two near-identical shades of
// the same hue) unless the drawing itself only really uses one hue family.
// ------------------------------------------------------------

/proc/hex2rgb_list(hex)
	if (copytext(hex, 1, 2) == "#")
		hex = copytext(hex, 2)
	return list(hex2num(copytext(hex, 1, 3)), hex2num(copytext(hex, 3, 5)), hex2num(copytext(hex, 5, 7)))

// Hue in degrees (0-360). Avoids DM's % operator on negative operands
// (sign behaviour there isn't worth relying on) by adjusting with plain ifs.
/proc/hex2hue(hex)
	var/list/c = hex2rgb_list(hex)
	var/r = c[1] / 255
	var/g = c[2] / 255
	var/b = c[3] / 255
	var/cmax = max(r, g, b)
	var/cmin = min(r, g, b)
	var/delta = cmax - cmin
	if (delta == 0)
		return 0 // grayscale: hue is undefined, treat as 0 (red bucket)
	var/hue
	if (cmax == r)
		hue = 60 * ((g - b) / delta)
	else if (cmax == g)
		hue = 60 * (((b - r) / delta) + 2)
	else
		hue = 60 * (((r - g) / delta) + 4)
	if (hue < 0)
		hue += 360
	if (hue >= 360)
		hue -= 360
	return hue

// Shifts a color toward white (factor > 0) or black (factor < 0).
/proc/shift_color_lightness(hex, factor)
	var/list/c = hex2rgb_list(hex)
	var/r = c[1]
	var/g = c[2]
	var/b = c[3]
	if (factor >= 0)
		r += (255 - r) * factor
		g += (255 - g) * factor
		b += (255 - b) * factor
	else
		r += r * factor
		g += g * factor
		b += b * factor
	return rgb(clamp(round(r), 0, 255), clamp(round(g), 0, 255), clamp(round(b), 0, 255))

// Re-derives custom_civs[faction][7]/[8] (main/secondary color -- the SAME
// fields the banner, faction posters and official paper already read) from
// the saved grid. Buckets by hue (15-degree buckets) so near-identical exact
// shades of one color count as the same color for this purpose, takes the
// heaviest bucket as primary, then the heaviest OTHER bucket that's at least
// ~40 degrees of hue away as secondary. If nothing is far enough away (the
// drawing is genuinely one hue family), falls back to a lighter shade of
// that same hue instead of forcing an unrelated color.
/obj/map_metadata/proc/apply_faction_symbol_colors(faction)
	var/list/grid = ensure_faction_symbol_grid(faction)
	var/list/freq = list()
	for (var/i = 1, i <= grid.len, i++)
		var/c = uppertext(grid[i])
		if (c == "#FFFFFF")
			continue // ignore the blank background so an empty drawing doesn't skew this
		freq[c] = (freq[c] ? freq[c] : 0) + 1
	if (!freq.len)
		return // nothing but background was drawn -- leave existing colors alone

	// Bucket keys are STRINGS: a numeric key on a DM list is a positional
	// index, so list[15] on an empty list runtimes instead of associating.
	var/list/bucket_weight = list()
	var/list/bucket_color = list()
	var/list/bucket_color_count = list()
	for (var/c in freq)
		var/hue = round(hex2hue(c) / 15) * 15
		if (hue >= 360) // fold the wrap-around bucket so red isn't split in two
			hue = 0
		var/hkey = "[hue]"
		bucket_weight[hkey] = (bucket_weight[hkey] ? bucket_weight[hkey] : 0) + freq[c]
		if (!bucket_color_count[hkey] || freq[c] > bucket_color_count[hkey])
			bucket_color_count[hkey] = freq[c]
			bucket_color[hkey] = c

	var/best_hue = -1
	var/best_weight = 0
	for (var/h in bucket_weight)
		if (bucket_weight[h] > best_weight)
			best_weight = bucket_weight[h]
			best_hue = text2num(h)
	var/primary_color = bucket_color["[best_hue]"]

	var/second_hue = -1
	var/second_weight = 0
	for (var/h in bucket_weight)
		var/nh = text2num(h)
		if (nh == best_hue)
			continue
		var/diff = abs(nh - best_hue)
		if (diff > 180)
			diff = 360 - diff
		if (diff < 40)
			continue // too close to primary to read as a genuinely different color
		if (bucket_weight[h] > second_weight)
			second_weight = bucket_weight[h]
			second_hue = nh

	var/secondary_color = (second_hue >= 0) ? bucket_color["[second_hue]"] : shift_color_lightness(primary_color, 0.4)

	var/list/civ_data = custom_civs[faction]
	if (civ_data && civ_data.len >= 8)
		civ_data[7] = primary_color
		civ_data[8] = secondary_color

// ------------------------------------------------------------
// Editor UI (Leader-only; see design_faction_symbol() below). Uses the
// existing /datum/nano_module pattern (see appearance_changer.dm) rather
// than a physical structure: created fresh per verb call, all real state
// lives on map_metadata so re-opening or auto-refreshing always reflects the
// current saved grid, no separate per-instance state to lose track of.
// ------------------------------------------------------------

/datum/nano_module/faction_symbol_editor
	name = "Faction Symbol Editor"
	var/mob/living/human/owner
	var/faction

/datum/nano_module/faction_symbol_editor/New(var/location, var/mob/living/human/H)
	..(location)
	owner = H
	faction = H.civilization

/datum/nano_module/faction_symbol_editor/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE)
	if (!map || !faction || faction == "none")
		return
	var/list/data = host.initial_data()

	var/list/grid = map.ensure_faction_symbol_grid(faction)
	data["grid"] = grid.Copy()
	var/tool = map.faction_symbol_tool[faction]
	data["tool"] = tool ? tool : "paint"
	var/color = map.faction_symbol_color[faction]
	data["color"] = color ? color : "#000000"
	data["shapes"] = faction_symbol_shapes
	data["has_saved_icon"] = map.get_faction_symbol_icon(faction) ? TRUE : FALSE

	ui = GLOB.nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		ui = new(user, src, ui_key, "faction_symbol.tmpl", name, 620, 760)
		// "basic" layout: no stock SS13 NanoUI chrome around the parchment
		// (see the research bench UI for the same choice).
		ui.set_layout_key("basic")
		ui.add_stylesheet("civ13_theme.css")
		ui.add_stylesheet("faction_symbol.css")
		ui.add_script("faction_symbol.js")
		ui.set_initial_data(data)
		ui.open()

/datum/nano_module/faction_symbol_editor/Topic(href, href_list)
	if (!istype(owner) || owner.stat)
		return
	if (!map || !faction || faction == "none" || owner.civilization != faction)
		return
	if (!map.is_faction_leader(owner, faction))
		to_chat(owner, SPAN_WARNING("Only your faction's Leader may redesign its symbol."))
		return

	if (href_list["set_tool"])
		map.faction_symbol_tool[faction] = href_list["set_tool"]
	else if (href_list["pick_color"])
		var/newcolor = input(owner, "Choose the active paint color:", "Faction Symbol", map.faction_symbol_color[faction] || "#000000") as color
		if (newcolor)
			map.faction_symbol_color[faction] = newcolor
	else if (href_list["paint"])
		var/x = text2num(href_list["x"])
		var/y = text2num(href_list["y"])
		var/tool = map.faction_symbol_tool[faction]
		var/color = map.faction_symbol_color[faction] || "#000000"
		faction_symbol_push_undo(map.ensure_faction_symbol_undo(faction), map.ensure_faction_symbol_grid(faction))
		if (tool == "bucket")
			map.bucket_fill_faction_symbol(faction, x, y, color)
		else
			map.set_faction_symbol_pixel(faction, x, y, color)
	else if (href_list["stroke"])
		// A whole client-side brush drag, batched into one action -- and, via
		// stroke_continue on follow-up chunks of the same drag, ONE undo step.
		var/color = map.faction_symbol_color[faction] || "#000000"
		if (!href_list["stroke_continue"])
			faction_symbol_push_undo(map.ensure_faction_symbol_undo(faction), map.ensure_faction_symbol_grid(faction))
		faction_symbol_apply_stroke(map.ensure_faction_symbol_grid(faction), href_list["cells"], color)
	else if (href_list["stamp"])
		var/choice = WWinput(owner, "Stamp which shape onto the canvas? This OVERWRITES the current drawing.", "Faction Symbol", "Cancel", list("Cancel") + faction_symbol_shapes)
		if (choice && choice != "Cancel")
			faction_symbol_push_undo(map.ensure_faction_symbol_undo(faction), map.ensure_faction_symbol_grid(faction))
			map.stamp_faction_symbol(faction, choice)
	else if (href_list["clear"])
		faction_symbol_push_undo(map.ensure_faction_symbol_undo(faction), map.ensure_faction_symbol_grid(faction))
		map.clear_faction_symbol(faction)
	else if (href_list["undo"])
		var/list/restored = faction_symbol_pop_undo(map.ensure_faction_symbol_undo(faction))
		if (restored)
			map.faction_symbol_grid[faction] = restored
		else
			to_chat(owner, SPAN_WARNING("Nothing left to undo."))
	else if (href_list["save"])
		if (map.finalize_faction_symbol(faction))
			to_chat(owner, SPAN_NOTICE("Your faction's new symbol is saved. It'll appear on any banner you build from now on."))
		else
			to_chat(owner, SPAN_WARNING("Something went wrong saving the symbol. Try again."))
	GLOB.nanomanager.update_uis(src)

// The symbol is MADE exactly once, on the canvas embedded in the Faction
// Creation UI (faction_creation.dm). This verb is the only way back in
// afterwards -- a leader-only "modify what exists" action, granted/revoked
// alongside the other leader verbs at every point where custom-faction
// leadership changes hands.
/mob/living/human/proc/design_faction_symbol()
	set name = "Modify Faction Symbol"
	set category = "Faction"
	set desc = "Modify your faction's symbol. Changes appear on banners once saved."

	if (!civilization || civilization == "none")
		to_chat(src, SPAN_WARNING("You are not part of any faction."))
		return
	if (!map || !map.is_faction_leader(src, civilization))
		to_chat(src, SPAN_WARNING("Only the Leader of your faction may modify its symbol."))
		return
	var/datum/nano_module/faction_symbol_editor/editor = new(src, src)
	editor.ui_interact(src)

// Paired grant/revoke helpers, mirroring make_commander()/remove_commander()
// in officer.dm. The verb also re-checks is_faction_leader() itself, so a
// stale grant is harmless -- these just keep the Faction panel honest.
/mob/living/human/proc/grant_faction_symbol_editor()
	verbs += /mob/living/human/proc/design_faction_symbol

/mob/living/human/proc/remove_faction_symbol_editor()
	verbs -= /mob/living/human/proc/design_faction_symbol
