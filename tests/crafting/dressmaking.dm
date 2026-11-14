// Tailoring: recipe payment, fabric top-up, every catalogue body's art, cut
// and sew transitions, saved fields and appearance. Only the wait is replaced
// to inject interruption/late-mutation cases; the shared handle_ci actor
// disables physiology/HUD. Output auto-equipping is refused by this fixture,
// so output remains on the floor; source hand cleanup still uses the
// production inventory transaction.
/mob/living/human/handle_ci/dress_ci/put_in_any_hand_if_possible(obj/item/W, del_on_fail = FALSE, disable_warning = TRUE, redraw_mob = TRUE, prioritize_active_hand = FALSE)
	return FALSE

/mob/living/human/handle_ci/dress_ci/tailoring_trace_wait(obj/item/source)
	return TRUE

/obj/item/tailoring_project/dress_ci
	var/wait_mode = "complete"

/obj/item/tailoring_project/dress_ci/wait_for_tailoring(mob/living/human/user, delay)
	switch (wait_mode)
		if ("cancel")
			return FALSE
		if ("drop")
			user.transfer_held_item_to(src, get_turf(user))
		if ("save")
			persistence_admission_identity = new /datum
		if ("incapacitate")
			user.stat = UNCONSCIOUS
	return TRUE

/proc/dressmaking_ci_expect(condition, label)
	if (!condition)
		recipe_ci_fail("tailoring", label)

/proc/dressmaking_ci_clear(turf/site)
	for (var/obj/item/I in site)
		qdel(I)

// Sewing patterns, design names, the staff registry and the name block list.
/proc/dressmaking_ci_patterns(mob/living/human/handle_ci/dress_ci/H, turf/site, datum/save_epoch)
	dressmaking_ci_clear(site)
	dressmaking_ci_expect(tailoring_clean_name("  Sunday <b>best</b>  ") == "Sunday  b best /b", "names lose markup and edge spaces")
	dressmaking_ci_expect(!tailoring_clean_name("x") && !tailoring_clean_name("   ") && !tailoring_clean_name(5), "too short or non-text names rejected")
	dressmaking_ci_expect(length(tailoring_clean_name("abcdefghijklmnopqrstuvwxyzabcdefghijklmnop")) == 32, "names cap at 32 letters")
	tailoring_named_items = list()
	var/obj/item/tailoring_project/dress_ci/source = new(site)
	source.design_body = "laced_dress"
	source.design_colors = "#ffffff|#bb4455|#223344"
	source.design_name = "Sunday best"
	source.claim_design(H)
	tailoring_register(source)
	dressmaking_ci_expect(source.design_author == H.ckey && source.design_maker == H.real_name && (source in tailoring_named_items), "a named design records its maker and is listed for staff")
	// Tracing needs a blank sheet held in hand and consumes it.
	var/obj/item/weapon/paper/written = new(H)
	written.info = "a letter"
	H.r_hand = written
	source.attackby(written, H)
	dressmaking_ci_expect(!(locate(/obj/item/sewing_pattern) in site) && written.loc == H, "written paper cannot be traced on")
	H.remove_from_mob(written); qdel(written)
	var/obj/item/weapon/paper/parchment/sheet = new(H)
	H.r_hand = sheet
	source.attackby(sheet, H)
	var/obj/item/sewing_pattern/pattern = locate() in site
	dressmaking_ci_expect(pattern && QDELETED(sheet) && !H.r_hand, "tracing consumes the held sheet")
	if (!pattern)
		return
	dressmaking_ci_expect(pattern.design_body == "laced_dress" && pattern.design_colors == source.design_colors && pattern.design_name == "Sunday best" && pattern.design_author == H.ckey && pattern.color == "#e8d8b0" && pattern.name == "sewing pattern (Sunday best)", "a parchment pattern keeps the design, name and maker")
	dressmaking_ci_expect(pattern in tailoring_named_items, "a named pattern is listed for staff")
	// Copying a pattern onto plain paper.
	var/obj/item/weapon/paper/copy_sheet = new(H)
	H.r_hand = copy_sheet
	pattern.attackby(copy_sheet, H)
	var/count = 0
	for (var/obj/item/sewing_pattern/found in site)
		count++
	dressmaking_ci_expect(count == 2 && QDELETED(copy_sheet), "a pattern copies onto a blank sheet")
	// An undesigned project has nothing to trace.
	var/obj/item/tailoring_project/dress_ci/blank = new(site)
	blank.design_body = null
	var/obj/item/weapon/paper/unused = new(H)
	H.r_hand = unused
	blank.attackby(unused, H)
	dressmaking_ci_expect(!QDELETED(unused) && unused.loc == H, "an undesigned project keeps the sheet")
	H.remove_from_mob(unused); qdel(unused)
	// Loading a pattern onto an uncut project, then sewing it.
	var/obj/item/tailoring_project/dress_ci/target = new(H)
	H.r_hand = target
	dressmaking_ci_expect(target.load_pattern(H, pattern) && target.design_body == "laced_dress" && target.design_colors == pattern.design_colors && target.design_name == "Sunday best" && target.design_author == H.ckey, "a pattern loads onto an uncut project")
	target.fabric = 8
	dressmaking_ci_expect(target.cut_fabric(H, site, save_epoch) && target.sew_garment(H, site, save_epoch), "a loaded pattern cuts and sews")
	var/obj/item/clothing/under/tailored/sewn = locate() in site
	dressmaking_ci_expect(sewn && sewn.name == "Sunday best" && sewn.design_maker == H.real_name && (sewn in tailoring_named_items), "the garment carries the design name and is listed")
	var/obj/item/stack/material/cloth/spare = locate() in site
	if (spare)
		qdel(spare)
	// A cut project refuses a new pattern.
	var/obj/item/tailoring_project/dress_ci/cut = new(site)
	cut.stage = 1
	cut.design_body = "toga"
	cut.design_colors = "#ffffff"
	dressmaking_ci_expect(!cut.load_pattern(H, pattern) && cut.design_body == "toga", "a cut project keeps its design")
	// Research gates the pattern's garment.
	var/obj/item/sewing_pattern/modern = new(site)
	modern.set_design("tracksuit", "#112233|#445566|#778899", null, "Someone", "someone", FALSE)
	var/list/entry = map.ensure_node_entry("recipe_ci", "synthetics")
	var/old_persistence = map.persistence
	map.persistence = FALSE
	entry[RNODE_ENTRY_STATUS] = RNODE_LOCKED
	var/obj/item/tailoring_project/dress_ci/unknown = new(site)
	dressmaking_ci_expect(!unknown.load_pattern(H, modern) && unknown.design_body == "long_tunic", "an unknown garment's pattern cannot be loaded")
	entry[RNODE_ENTRY_STATUS] = RNODE_DONE
	map.persistence = old_persistence
	dressmaking_ci_expect(unknown.load_pattern(H, modern) && unknown.design_body == "tracksuit" && !(unknown in tailoring_named_items), "an unnamed pattern loads once known and is not listed")
	// Blocked accounts lose names copied from their patterns.
	var/list/saved_blocks = tailoring_name_block_list
	tailoring_name_block_list = list(ckey(H.ckey ? H.ckey : "dressci"))
	pattern.design_author = H.ckey ? H.ckey : "dressci"
	var/obj/item/tailoring_project/dress_ci/blocked = new(site)
	dressmaking_ci_expect(blocked.load_pattern(H, pattern) && !blocked.design_name, "a blocked account's design name is dropped on copy")
	tailoring_name_block_list = saved_blocks
	pattern.design_author = H.ckey
	// Staff renames and clears update names and the registry.
	tailoring_apply_name(sewn, "Plain dress")
	dressmaking_ci_expect(sewn.name == "Plain dress" && (sewn in tailoring_named_items), "staff rename shows on the garment")
	tailoring_apply_name(sewn, null)
	dressmaking_ci_expect(sewn.name == "laced dress" && !(sewn in tailoring_named_items), "staff clear restores the garment name")
	tailoring_apply_name(pattern, null)
	dressmaking_ci_expect(pattern.name == "sewing pattern (laced dress)" && !(pattern in tailoring_named_items), "staff clear renames the pattern")
	// Patterns survive a save round trip and re-register.
	tailoring_apply_name(pattern, "Sunday best")
	var/savefile/F = new("dressmaking-pattern.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, pattern, 1)
	map_storage.clear_bookkeeping()
	tailoring_named_items = list()
	var/obj/item/sewing_pattern/loaded = map_storage.Load_Entry(F, ref, starting_loc = site)
	if (loaded)
		loaded.after_load()
	dressmaking_ci_expect(loaded && loaded.design_body == "laced_dress" && loaded.design_colors == pattern.design_colors && loaded.design_name == "Sunday best" && loaded.design_author == H.ckey && loaded.color == "#e8d8b0" && loaded.name == "sewing pattern (Sunday best)" && (loaded in tailoring_named_items), "pattern round trip keeps the design and re-registers")
	qdel(loaded)
	dressmaking_ci_expect(!(loaded in tailoring_named_items), "deleted patterns leave the registry")
	H.remove_from_mob(target)
	dressmaking_ci_clear(site)
	tailoring_named_items = list()

/proc/recipe_ci_dressmaking()
	cloth_ci_setup()
	cloth_ci_load_catalogs()
	var/turf/site = locate(3,2,1)
	var/mob/living/human/handle_ci/dress_ci/H = new(site)
	H.civilization = "recipe_ci"
	var/datum/save_epoch = persistence_admission_identity
	// Wool uses the existing cloth substitution, with no second duplicate recipe.
	for (var/material_path in list(/material/cloth, /material/woolcloth))
		var/datum/stack_recipe/R = recipe_ci_food_recipe(material_path, /obj/item/tailoring_project, H.civilization)
		dressmaking_ci_expect(R && R.req_amount == 1, "one-sheet recipe available for [material_path]")
		if (!R)
			continue
		R.time = 0
		var/stock_path = material_path == /material/cloth ? /obj/item/stack/material/cloth : /obj/item/stack/material/woolcloth
		var/obj/item/stack/stock = new stock_path(H, 6, FALSE)
		var/obj/item/weapon/flint/blocker = new(H)
		H.r_hand = stock
		H.l_hand = blocker
		stock.produce_recipe(R, 1, H)
		var/obj/item/tailoring_project/paid = locate() in site
		dressmaking_ci_expect(paid && paid.fabric == 1 && stock.amount == 5, "project pays one sheet of [material_path]")
		if (paid)
			paid.attackby(stock, H)
			dressmaking_ci_expect(paid.fabric == 2 && stock.amount == 4, "a held sheet adds fabric for [material_path]")
			paid.fabric = 8
			paid.attackby(stock, H)
			dressmaking_ci_expect(paid.fabric == 8 && stock.amount == 4, "a full project refuses more fabric for [material_path]")
			qdel(paid)
		H.remove_from_mob(stock); qdel(stock)
		H.remove_from_mob(blocker); qdel(blocker)
	for (var/value in list("#123456", "#aBcDeF", "#000000", "#FFFFFF"))
		dressmaking_ci_expect(tailoring_color_valid(value), "opaque RGB accepted [value]")
	for (var/value in list("", "#123", "#00000000", "#GG0000", "red", 0))
		dressmaking_ci_expect(!tailoring_color_valid(value), "invalid/transparent color rejected [value]")
	dressmaking_ci_expect(!tailoring_design_valid("toga", "#ffffff|#000000"), "a toga has one colour only")
	dressmaking_ci_expect(!tailoring_design_valid("toga", "red"), "malformed colours rejected")
	dressmaking_ci_expect(!tailoring_design_valid("no_such_body", "#ffffff"), "unknown body rejected")
	var/list/C = tailoring_bodies()
	dressmaking_ci_expect(C.len >= 30, "catalogue lists every existing customizable garment")
	for (var/body_id in C)
		var/list/body = C[body_id]
		var/list/labels = tailoring_piece_labels(body)
		dressmaking_ci_expect(labels.len <= 6, "at most six coloured layers [body_id]")
		dressmaking_ci_expect(get_research_node(body["node"]), "known research node [body_id]")
		dressmaking_ci_expect(body["cost"] >= 1 && body["cost"] <= 8, "fabric cost fits one project [body_id]")
		var/list/states = list(body["base"])
		var/list/panels = body["panels"]
		for (var/label in panels)
			states += panels[label]
		var/list/fixed = body["fixed"]
		if (fixed)
			states += fixed
		var/worn_art = tailoring_art(body, TRUE)
		var/item_art = tailoring_art(body, FALSE)
		for (var/state in states)
			dressmaking_ci_expect(state in icon_states(worn_art), "worn art [body_id]/[state]")
			if (state != body["base"] || !body["item_base"])
				dressmaking_ci_expect(state in icon_states(item_art), "item art [body_id]/[state]")
		if (body["item_base"])
			dressmaking_ci_expect(body["item_base"] in icon_states(item_art), "item base art [body_id]")
		// Full cut and sew of every body, with a distinct colour per piece.
		var/list/colors = list()
		for (var/i = 1, i <= labels.len, i++)
			colors += rgb(20 * i, 200 - 20 * i, 100)
		var/obj/item/tailoring_project/dress_ci/P = new(H)
		H.r_hand = P
		P.design_body = body_id
		P.design_colors = jointext(colors, "|")
		P.fabric = body["cost"] - 1
		dressmaking_ci_expect(!P.cut_fabric(H, site, save_epoch) && P.stage == 0, "too little fabric cannot cut [body_id]")
		P.fabric = 8
		dressmaking_ci_expect(!P.sew_garment(H, site, save_epoch) && P.stage == 0, "uncut fabric cannot sew [body_id]")
		dressmaking_ci_expect(P.cut_fabric(H, site, save_epoch) && P.stage == 1 && P.fabric == body["cost"], "cut locks design and keeps the cost [body_id]")
		var/obj/item/stack/material/cloth/spare = locate() in site
		dressmaking_ci_expect(body["cost"] == 8 ? !spare : (spare && spare.amount == 8 - body["cost"]), "spare sheets set aside [body_id]")
		if (spare)
			qdel(spare)
		dressmaking_ci_expect(!P.cut_fabric(H, site, save_epoch), "cannot cut twice [body_id]")
		dressmaking_ci_expect(P.sew_garment(H, site, save_epoch), "cut project sews [body_id]")
		var/garment_type = tailoring_garment_type(body)
		var/obj/item/clothing/G = locate(garment_type) in site
		dressmaking_ci_expect(!H.r_hand && !H.l_hand, "consumed project clears hand [body_id]")
		dressmaking_ci_expect(istype(G) && G.design_body == body_id && G.design_colors == jointext(colors, "|") && G.name == body["name"], "one wearable keeps the chosen design [body_id]")
		if (istype(G))
			var/list/worn = G.worn_design_layers()
			dressmaking_ci_expect(G.overlays.len == worn.len && worn.len == labels.len + (fixed ? fixed.len : 0), "item and worn layer counts agree [body_id]")
			if (body["slot"] == "under")
				dressmaking_ci_expect(G.item_state_slots[slot_w_uniform_str] == body["base"], "worn base tracks chosen body [body_id]")
			else
				dressmaking_ci_expect(G.icon_state == body["base"], "worn suit base tracks chosen body [body_id]")
			G.tailoring_refresh()
			dressmaking_ci_expect(G.overlays.len == worn.len, "refresh does not accumulate layers [body_id]")
		dressmaking_ci_clear(site)
	for (var/mode in list("cancel", "drop", "save", "incapacitate"))
		for (var/initial_stage in list(0, 1))
			var/obj/item/tailoring_project/dress_ci/P = new(H)
			H.r_hand = P
			P.design_body = "toga"
			P.fabric = 3
			P.stage = initial_stage
			P.wait_mode = mode
			var/result = initial_stage == 0 ? P.cut_fabric(H, site, save_epoch) : P.sew_garment(H, site, save_epoch)
			dressmaking_ci_expect(!result && P.stage == initial_stage && P.loc, "[mode] preserves paid project at stage [initial_stage]")
			H.stat = CONSCIOUS
			persistence_admission_identity = save_epoch
			H.remove_from_mob(P); qdel(P)
	// Interrupted work is durable, but an open menu lock is not.
	var/obj/item/tailoring_project/P = new(site)
	P.stage = 1
	P.design_body = "buttoned_dress"
	P.design_colors = "#ffffff|#bb4455|#334455"
	P.fabric = 4
	P.tailoring_busy = TRUE
	dressmaking_ci_expect(!("tailoring_busy" in P.get_saved_vars()), "busy lock is runtime-only")
	var/savefile/F = new("dressmaking-project.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, P, 1)
	map_storage.clear_bookkeeping()
	var/obj/item/tailoring_project/restored = map_storage.Load_Entry(F, ref, starting_loc = site)
	if (restored) restored.after_load()
	dressmaking_ci_expect(restored && restored.stage == 1 && restored.design_body == "buttoned_dress" && restored.design_colors == "#ffffff|#bb4455|#334455" && restored.fabric == 4 && !restored.tailoring_busy, "cut project round trip retains design without lock")
	qdel(P); qdel(restored)
	// Item appearance rebuild retains decoration and blood without duplication.
	for (var/garment_type in list(/obj/item/clothing/under/tailored, /obj/item/clothing/suit/storage/jacket/tailored))
		var/obj/item/clothing/D = new garment_type(site)
		var/body_id = garment_type == /obj/item/clothing/under/tailored ? "laced_dress" : "colonial_coat"
		D.design_body = body_id
		D.design_colors = "#bb4455|#223344|#556677"
		D.tailoring_refresh()
		var/expected = length(D.worn_design_layers())
		var/obj/item/clothing/accessory/A = new(D)
		A.has_suit = D
		D.accessories += A
		D.overlays += A.get_inv_overlay()
		D.blood_DNA = list("fixture" = "O+")
		D.generate_blood_overlay()
		D.overlays += D.blood_overlay
		F = new("dressmaking-[body_id].sav")
		F["/format_version"] << 2
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		ref = map_storage.BuildVarDirectory(F, D, 1)
		map_storage.clear_bookkeeping()
		var/obj/item/clothing/loaded = map_storage.Load_Entry(F, ref, starting_loc = site)
		if (loaded)
			loaded.after_load()
			loaded.after_load()
		dressmaking_ci_expect(loaded && loaded.design_body == body_id && loaded.design_colors == "#bb4455|#223344|#556677" && loaded.overlays.len == expected + 2 && loaded.accessories.len == 1 && loaded.blood_DNA.len == 1, "[body_id] round trip rebuilds layers, accessory and blood once")
		qdel(D); qdel(loaded)
	// A dress sewn before tailoring restores as the matching tailored body.
	var/obj/item/clothing/under/tailored_dress/old = new(site)
	old.dress_cut = "Laced"
	old.primary_color = "#BB4455"
	old.secondary_color = "#223344"
	old.after_load()
	dressmaking_ci_expect(old.design_body == "laced_dress" && old.design_colors == "#ffffff|#bb4455|#223344" && old.overlays.len == 4, "old laced dress restores as tailoring")
	qdel(old)
	var/obj/item/dressmaking_project/old_project = new(site)
	old_project.dress_cut = "Layered"
	old_project.primary_color = "#112233"
	old_project.stage = 1
	old_project.after_load()
	dressmaking_ci_expect(old_project.design_body == "layered_dress" && old_project.fabric == 4 && old_project.stage == 1, "old dress project restores as tailoring")
	qdel(old_project)
	dressmaking_ci_patterns(H, site, save_epoch)
	qdel(H)
	dressmaking_ci_clear(site)
	map_storage.clear_bookkeeping()
