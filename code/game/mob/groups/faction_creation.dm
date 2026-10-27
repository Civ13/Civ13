// ============================================================
// Faction Creation UI
// ------------------------------------------------------------
// One window for the whole founding flow -- naming the faction AND drawing
// its banner symbol -- replacing the old chain of separate popup dialogs
// (name input, shape list, two color pickers). Opened by the Create Faction
// verb (factions.dm). Everything here is a per-instance DRAFT: nothing
// touches map_metadata until the player actually presses Found, so closing
// the window simply discards the attempt.
//
// The faction's two display colors (custom_civs[7]/[8]) are no longer picked
// explicitly: they're derived from the drawing on founding, by the exact
// same rule the post-creation Modify Faction Symbol editor applies on save
// (see apply_faction_symbol_colors() in faction_symbol.dm) -- one consistent
// answer to "where do a faction's colors come from". A blank canvas founds
// with the classic black-on-white defaults and the fixed-shape banner
// fallback, same as the old dialog flow's defaults.
// ============================================================

#define FACTION_MOTTO_MAX_CHARS 80
#define FACTION_FLAVOUR_MAX_WORDS 120
#define FACTION_NAME_MAX_CHARS 40

// Motto (one line, next to the name) and flavour text (short description,
// under the name) as shown in the Faction List (see faction_list() in
// factions.dm). Stored already html-encoded -- they go straight into
// browser HTML read by everyone on the server.
/obj/map_metadata
	var/list/faction_motto = list()
	var/list/faction_flavour = list()

/datum/nano_module/faction_creation
	name = "Faction Creation"
	var/mob/living/human/owner
	var/draft_name = ""
	var/draft_motto = ""
	var/draft_flavour = ""
	var/list/draft_grid
	// Last stamped shape. Becomes custom_civs[6], which stays the banner
	// fallback (and is read by other symbol consumers, e.g. flags) whenever
	// no baked custom icon exists.
	var/draft_shape = "star"
	var/tool = "paint"
	var/paint_color = "#000000"
	var/list/undo_stack = list()

/datum/nano_module/faction_creation/New(var/location, var/mob/living/human/H)
	..(location)
	owner = H
	draft_grid = faction_symbol_new_grid()

/datum/nano_module/faction_creation/ui_interact(mob/user, ui_key = "main", var/datum/nanoui/ui = null, var/force_open = TRUE)
	if (!map)
		return
	var/list/data = host.initial_data()
	data["name"] = draft_name
	data["motto"] = draft_motto
	data["flavour"] = draft_flavour
	data["grid"] = draft_grid.Copy()
	data["tool"] = tool
	data["color"] = paint_color

	ui = GLOB.nanomanager.try_update_ui(user, src, ui_key, ui, data, force_open)
	if (!ui)
		// Reuses the symbol editor's canvas stylesheet and cell-binding
		// script wholesale -- same grid markup, same behavior.
		ui = new(user, src, ui_key, "faction_creation.tmpl", name, 620, 900)
		// "basic" layout: no stock SS13 NanoUI chrome around the parchment
		// (see the research bench UI for the same choice).
		ui.set_layout_key("basic")
		ui.add_stylesheet("civ13_theme.css")
		ui.add_stylesheet("faction_symbol.css")
		ui.add_script("faction_symbol.js")
		ui.set_initial_data(data)
		ui.open()

/datum/nano_module/faction_creation/Topic(href, href_list)
	if (!istype(owner) || owner.stat)
		return
	if (!map || !map.allows_custom_factions())
		return
	if (owner.civilization != "none")
		to_chat(owner, SPAN_WARNING("You are already in a faction."))
		return

	if (href_list["set_name"])
		var/newname = input(owner, "Choose a name for the faction:", "Faction Creation", draft_name) as text|null
		if (newname && newname != "")
			// The name becomes an assoc key everywhere (custom_civs,
			// mob.civilization) AND raw HTML in the faction list, so strip
			// markup outright (encode=FALSE) rather than html-encode --
			// entities in a key would haunt every later comparison.
			newname = sanitize(newname, FACTION_NAME_MAX_CHARS + 1, FALSE)
			if (!newname || newname == "")
				to_chat(owner, SPAN_WARNING("That name contains nothing usable. Choose another name."))
			// Warned here for immediate feedback, but re-checked in
			// found_faction() -- another faction can claim the name while
			// this window sits open.
			else if (map.faction_name_taken(newname))
				to_chat(owner, SPAN_WARNING("That faction already exists. Choose another name."))
			else
				draft_name = newname
	else if (href_list["set_motto"])
		var/raw = input(owner, "Motto ([FACTION_MOTTO_MAX_CHARS] characters max; leave empty for none):", "Faction Creation", draft_motto) as text|null
		if (!isnull(raw))
			// The character limit applies to what was TYPED -- enforce it
			// before sanitize()'s html-encoding inflates e.g. "&" to "&amp;".
			if (length(raw) > FACTION_MOTTO_MAX_CHARS)
				raw = copytext(raw, 1, FACTION_MOTTO_MAX_CHARS + 1)
				to_chat(owner, SPAN_WARNING("Your motto was over [FACTION_MOTTO_MAX_CHARS] characters and has been trimmed."))
			draft_motto = sanitize(raw, 0)
	else if (href_list["set_flavour"])
		var/raw = input(owner, "Flavour text ([FACTION_FLAVOUR_MAX_WORDS] words max; leave empty for none):", "Faction Creation", draft_flavour) as message|null
		if (!isnull(raw))
			// Word-count limit, so trim at a word boundary. Newlines get
			// flattened to spaces by sanitize() anyway (it's shown as one
			// paragraph in the Faction List), so flatten first and count.
			var/list/words = list()
			for (var/w in splittext(replacetext(raw, "\n", " "), " "))
				if (length(w))
					words += w
			if (words.len > FACTION_FLAVOUR_MAX_WORDS)
				words.Cut(FACTION_FLAVOUR_MAX_WORDS + 1)
				to_chat(owner, SPAN_WARNING("Your flavour text was over [FACTION_FLAVOUR_MAX_WORDS] words and has been trimmed."))
			draft_flavour = sanitize(jointext(words, " "), 0)
	else if (href_list["set_tool"])
		tool = href_list["set_tool"]
	else if (href_list["pick_color"])
		var/newcolor = input(owner, "Choose the active paint color:", "Faction Creation", paint_color) as color
		if (newcolor)
			paint_color = newcolor
	else if (href_list["paint"])
		var/x = text2num(href_list["x"])
		var/y = text2num(href_list["y"])
		faction_symbol_push_undo(undo_stack, draft_grid)
		if (tool == "bucket")
			faction_symbol_bucket_fill_grid(draft_grid, x, y, paint_color)
		else if (x >= 1 && x <= FACTION_SYMBOL_SIZE && y >= 1 && y <= FACTION_SYMBOL_SIZE)
			draft_grid[faction_symbol_grid_index(x, y)] = paint_color
	else if (href_list["stroke"])
		// A whole client-side brush drag, batched into one action -- and, via
		// stroke_continue on follow-up chunks of the same drag, ONE undo step.
		if (!href_list["stroke_continue"])
			faction_symbol_push_undo(undo_stack, draft_grid)
		faction_symbol_apply_stroke(draft_grid, href_list["cells"], paint_color)
	else if (href_list["stamp"])
		var/choice = WWinput(owner, "Stamp which shape onto the canvas? This OVERWRITES the current drawing.", "Faction Creation", "Cancel", list("Cancel") + faction_symbol_shapes)
		if (choice && choice != "Cancel")
			faction_symbol_push_undo(undo_stack, draft_grid)
			faction_symbol_stamp_grid(draft_grid, choice)
			draft_shape = choice
	else if (href_list["clear"])
		faction_symbol_push_undo(undo_stack, draft_grid)
		draft_grid = faction_symbol_new_grid()
	else if (href_list["undo"])
		var/list/restored = faction_symbol_pop_undo(undo_stack)
		if (restored)
			draft_grid = restored
		else
			to_chat(owner, SPAN_WARNING("Nothing left to undo."))
	else if (href_list["found"])
		if (found_faction())
			return // window already closed; nothing left to update
	GLOB.nanomanager.update_uis(src)

// The moment of founding: everything the old create_faction_pr() dialog
// chain did, performed atomically from the draft. Returns TRUE on success
// (and closes the window); FALSE leaves the draft open to fix and retry.
/datum/nano_module/faction_creation/proc/found_faction()
	// Re-sanitize before the name becomes a permanent assoc key and raw HTML
	// everywhere -- set_name already sanitized, but this is the last gate.
	draft_name = sanitize(draft_name, FACTION_NAME_MAX_CHARS + 1, FALSE)
	if (!draft_name || draft_name == "" || draft_name == "none")
		to_chat(owner, SPAN_WARNING("Choose a name for the faction first."))
		return FALSE
	if (map.faction_name_taken(draft_name))
		to_chat(owner, SPAN_WARNING("That faction already exists. Choose another name."))
		return FALSE

	var/newname = draft_name
	owner.civilization = newname
	owner.leader = TRUE
	owner.faction_perms = list(1,1,1,1)
	map.custom_faction_nr += newname
											//ind						mil					med			leader money	symbol	main color	backcolor, sales tax, business tax
	var/newnamev = list("[newname]" = list(map.default_research,map.default_research,map.default_research,owner,0,draft_shape,"#000000","#FFFFFF",10,10))
	map.custom_civs += newnamev
	// Research tree: freeze this faction's main-tree baseline era at the
	// moment they're founded (see is_node_done in research_faction.dm) --
	// it must not keep growing later just because the world's era
	// advances due to OTHER factions' achievements.
	map.faction_baseline_era[newname] = map.ordinal_age
	if (draft_motto != "")
		map.faction_motto[newname] = draft_motto
	if (draft_flavour != "")
		map.faction_flavour[newname] = draft_flavour

	// The draft drawing becomes the faction's real symbol. A blank canvas
	// skips the bake: baking an all-white icon would plaster a white square
	// over the banner instead of falling back to the fixed shape.
	map.faction_symbol_grid[newname] = draft_grid.Copy()
	if (!faction_symbol_grid_is_blank(draft_grid))
		map.finalize_faction_symbol(newname)

	owner.make_commander()
	owner.make_title_changer()
	owner.grant_faction_symbol_editor()
	to_chat(owner, "<big>You are now the leader of the <b>[newname]</b> faction.</big>")
	GLOB.nanomanager.close_user_uis(owner, src)
	return TRUE
