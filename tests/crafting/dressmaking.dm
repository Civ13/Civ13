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

// Fabric sets warmth, padding and tone; dyes follow knowledge.
/proc/dressmaking_ci_fabric_and_dyes(mob/living/human/handle_ci/dress_ci/H, turf/site, datum/save_epoch)
	dressmaking_ci_clear(site)
	dressmaking_ci_expect(tailoring_tint("#ffffff", "#e6dccb") == "#e6dccb" && tailoring_tint("#808080", "#ffffff") == "#808080", "fabric tone multiplies dyes")
	dressmaking_ci_expect(tailoring_dye_node("#A8342C") == "classical_dress" && tailoring_dye_node("#ffffff") == "weaving" && tailoring_dye_node("#123456") == "textile_mills", "every colour has a dye tier")
	dressmaking_ci_expect(!tailoring_known_dyes(H), "textile mills dye any colour")
	var/old_persistence = map.persistence
	map.persistence = FALSE
	var/list/mills = map.ensure_node_entry("recipe_ci", "textile_mills")
	var/list/fine = map.ensure_node_entry("recipe_ci", "fine_garments")
	mills[RNODE_ENTRY_STATUS] = RNODE_LOCKED
	var/list/dyes = tailoring_known_dyes(H)
	dressmaking_ci_expect(dyes && dyes["undyed"] == "#ffffff" && dyes["madder red"] && dyes["kermes crimson"] && !("#123456" in dyes), "known dye tiers without textile mills")
	dressmaking_ci_expect(tailoring_design_allowed(H, "made_shirt", null, "#ffffff|#a8342c|#b01c30") && !tailoring_design_allowed(H, "made_shirt", null, "#ffffff|#123456") && tailoring_missing_node(H, "made_shirt", null, "#ffffff|#123456") == "textile_mills", "a mixed colour needs textile mills")
	fine[RNODE_ENTRY_STATUS] = RNODE_LOCKED
	dressmaking_ci_expect(!tailoring_design_allowed(H, "made_shirt", null, "#b01c30") && tailoring_missing_node(H, "made_shirt", null, "#b01c30") == "fine_garments", "a costly dye needs fine garments")
	var/obj/item/tailoring_project/dress_ci/dyed = new(H)
	H.r_hand = dyed
	dyed.design_body = "made_shirt"
	dyed.design_colors = "#123456"
	dyed.fabric = 8
	dressmaking_ci_expect(!dyed.cut_fabric(H, site, save_epoch) && dyed.stage == 0, "an unknown dye cannot be cut")
	fine[RNODE_ENTRY_STATUS] = RNODE_DONE
	mills[RNODE_ENTRY_STATUS] = RNODE_DONE
	map.persistence = old_persistence
	// A wool shirt with long sleeves and trousers: warmer, padded, toned, covered.
	dyed.fabric_kind = "woolcloth"
	dyed.design_colors = "#ffffff|#ffffff|#ffffff|#ffffff"
	dyed.design_pieces = "Plain|Long|Plain|Trousers"
	dressmaking_ci_expect(dyed.cut_fabric(H, site, save_epoch), "a wool design cuts")
	var/obj/item/stack/material/woolcloth/spare = locate() in site
	dressmaking_ci_expect(spare && spare.amount == 3 && !(locate(/obj/item/stack/material/cloth) in site), "spare wool comes back as wool")
	if (spare)
		qdel(spare)
	dressmaking_ci_expect(dyed.sew_garment(H, site, save_epoch), "a wool design sews")
	var/obj/item/clothing/under/tailored/wool = locate() in site
	if (!wool)
		dressmaking_ci_expect(FALSE, "wool shirt exists")
		return
	var/list/layers = wool.worn_design_layers()
	var/image/main = layers[1]
	dressmaking_ci_expect(wool.design_fabric == "woolcloth" && wool.min_cold_protection_temperature == 225 && wool.armor["melee"] == 5 && wool.armor["arrow"] == 5 && main.color == "#e6dccb", "wool is warmer, padded and darker")
	dressmaking_ci_expect(wool.body_parts_covered == (UPPER_TORSO|LOWER_TORSO|LEGS|ARMS) && wool.cold_protection == wool.body_parts_covered, "sleeves and trousers add coverage")
	// Linen keeps the ordinary stats and exact dyes.
	var/obj/item/clothing/suit/storage/jacket/tailored/linen = new(site)
	linen.design_body = "made_cloak"
	linen.design_colors = "#a8342c"
	linen.design_pieces = "Hood"
	linen.design_fabric = "cloth"
	linen.tailoring_refresh()
	var/list/cloak_layers = linen.worn_design_layers()
	var/image/cloak = cloak_layers[1]
	dressmaking_ci_expect(linen.min_cold_protection_temperature == 225 && linen.armor["melee"] == 0 && cloak.color == "#a8342c" && (linen.body_parts_covered & HEAD), "a linen cloak with a hood")
	// Fabric survives a save.
	var/savefile/F = new("dressmaking-fabric.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, wool, 1)
	map_storage.clear_bookkeeping()
	var/obj/item/clothing/loaded = map_storage.Load_Entry(F, ref, starting_loc = site)
	if (loaded)
		loaded.after_load()
	dressmaking_ci_expect(loaded && loaded.design_fabric == "woolcloth" && loaded.min_cold_protection_temperature == 225 && loaded.armor["melee"] == 5, "wool round trip keeps its stats")
	qdel(loaded)
	dressmaking_ci_clear(site)
	tailoring_named_items = list()

// Mix-and-match pieces: every variant draws, costs and validates; unknown
// pieces are refused; research gates pieces; patterns and saves keep them.
/proc/dressmaking_ci_pieces(mob/living/human/handle_ci/dress_ci/H, turf/site, datum/save_epoch)
	dressmaking_ci_clear(site)
	var/list/C = tailoring_bodies()
	var/modular = 0
	for (var/body_id in C)
		var/list/body = C[body_id]
		var/list/options = body["options"]
		if (!options)
			continue
		modular++
		dressmaking_ci_expect(body["art"] == "tailoring", "pieced body uses the shared template art [body_id]")
		var/option_index = 0
		for (var/option in options)
			option_index++
			var/list/variants = options[option]
			for (var/variant in variants)
				var/state = variants[variant]
				var/pieces = tailoring_set_piece(body_id, null, option, variant)
				var/list/chosen = tailoring_pieces(body_id, pieces)
				dressmaking_ci_expect(chosen[option] == variant && tailoring_design_valid(body_id, "#ffffff", pieces), "variant selectable [body_id]/[option]/[variant]")
				var/list/colors = list()
				for (var/i = 1, i <= length(tailoring_piece_labels(body)), i++)
					colors += rgb(10 * i, 10 * i, 10 * i)
				var/list/layers = tailoring_layers(body_id, jointext(colors, "|"), TRUE, pieces)
				var/found = FALSE
				for (var/image/I in layers)
					if (state && I.icon_state == state && I.color == colors[1 + length(body["panels"]) + option_index])
						found = TRUE
				dressmaking_ci_expect(!state || found, "variant drawn in its own colour [body_id]/[option]/[variant]")
				var/list/info = state ? tailoring_piece_info[state] : null
				var/list/defaults = tailoring_pieces(body_id, null)
				var/list/default_variants = options[option]
				var/list/default_info = default_variants[defaults[option]] ? tailoring_piece_info[default_variants[defaults[option]]] : null
				var/expected = tailoring_design_cost(body_id, null) - (default_info ? default_info[2] : 0) + (info ? info[2] : 0)
				dressmaking_ci_expect(tailoring_design_cost(body_id, pieces) == expected && expected <= 8, "variant fabric cost [body_id]/[option]/[variant]")
	dressmaking_ci_expect(modular >= 6, "six pieced bodies")
	dressmaking_ci_expect(!tailoring_design_valid("made_shirt", "#ffffff", "Wings"), "unknown variant rejected")
	dressmaking_ci_expect(!tailoring_design_valid("made_cloak", "#ffffff", "None|None|None|None"), "extra piece choices rejected")
	dressmaking_ci_expect(!tailoring_design_valid("toga", "#ffffff", "Long"), "a body without pieces takes no choices")
	dressmaking_ci_expect(tailoring_set_piece("made_shirt", "Plain|Long", "Sleeves", "Wings") == "Plain|Long", "unknown variant not set")
	dressmaking_ci_expect(tailoring_pieces_text(tailoring_pieces("made_shirt", "Plain|Long|V neck")) == "Plain|Long|V neck|Trousers|None", "missing choices take defaults")
	// Research gates single pieces, and names the missing knowledge.
	var/old_persistence = map.persistence
	map.persistence = FALSE
	var/list/entry = map.ensure_node_entry("recipe_ci", "fine_garments")
	entry[RNODE_ENTRY_STATUS] = RNODE_LOCKED
	dressmaking_ci_expect(tailoring_design_allowed(H, "made_shirt", "Plain|Long|V neck") && !tailoring_design_allowed(H, "made_shirt", "Plain|Long|High collar") && tailoring_missing_node(H, "made_shirt", "Plain|Long|High collar") == "fine_garments", "an unknown piece blocks the design")
	var/obj/item/tailoring_project/dress_ci/gated = new(H)
	H.r_hand = gated
	gated.design_body = "made_shirt"
	gated.design_colors = "#ffffff"
	gated.design_pieces = "Plain|Long|High collar"
	gated.fabric = 8
	dressmaking_ci_expect(!gated.cut_fabric(H, site, save_epoch) && gated.stage == 0, "an unknown piece cannot be cut")
	entry[RNODE_ENTRY_STATUS] = RNODE_DONE
	map.persistence = old_persistence
	// Cut and sew a full design; the cost includes its pieces.
	gated.design_colors = "#aa0000|#00aa00|#0000aa|#aaaa00|#00aaaa|#aa00aa"
	gated.design_pieces = "Checks|Long|High collar|Breeches|Sash"
	var/cost = tailoring_design_cost("made_shirt", gated.design_pieces)
	dressmaking_ci_expect(cost == 4 && gated.body_cost() == 4, "pieces add fabric")
	dressmaking_ci_expect(gated.cut_fabric(H, site, save_epoch) && gated.fabric == 4, "a pieced design cuts")
	var/obj/item/stack/material/cloth/spare = locate() in site
	if (spare)
		qdel(spare)
	dressmaking_ci_expect(gated.sew_garment(H, site, save_epoch), "a pieced design sews")
	var/obj/item/clothing/under/tailored/shirt = locate() in site
	dressmaking_ci_expect(shirt && shirt.design_pieces == "Checks|Long|High collar|Breeches|Sash" && shirt.overlays.len == 6 && shirt.icon == 'icons/obj/clothing/tailoring.dmi' && shirt.icon_override == 'icons/mob/tailoring.dmi', "the garment keeps its pieces and template art")
	if (!shirt)
		return
	// A pattern traced from the garment carries the pieces to a new project.
	var/obj/item/weapon/paper/sheet = new(H)
	H.r_hand = sheet
	shirt.attackby(sheet, H)
	var/obj/item/sewing_pattern/pattern = locate() in site
	dressmaking_ci_expect(pattern && pattern.design_pieces == shirt.design_pieces, "a pattern records the pieces")
	if (pattern)
		var/obj/item/tailoring_project/dress_ci/copy = new(site)
		dressmaking_ci_expect(copy.load_pattern(H, pattern) && copy.design_pieces == shirt.design_pieces && copy.body_cost() == 4, "a pattern loads the pieces")
	// The pieces survive a save round trip and rebuild once.
	var/savefile/F = new("dressmaking-pieces.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, shirt, 1)
	map_storage.clear_bookkeeping()
	var/obj/item/clothing/loaded = map_storage.Load_Entry(F, ref, starting_loc = site)
	if (loaded)
		loaded.after_load()
		loaded.after_load()
	dressmaking_ci_expect(loaded && loaded.design_pieces == shirt.design_pieces && loaded.overlays.len == 6 && length(loaded.worn_design_layers()) == 6, "pieced garment round trip rebuilds once")
	qdel(loaded)
	dressmaking_ci_clear(site)
	tailoring_named_items = list()

// Sewing patterns, design names, the staff registry and the name block list.
// Headwear: the head slot sews its own garment type, veils hide hair, and a
// saved cap rebuilds its layers.
/proc/dressmaking_ci_headwear(mob/living/human/handle_ci/dress_ci/H, turf/site, datum/save_epoch)
	dressmaking_ci_clear(site)
	var/list/heads = list()
	for (var/body_id in tailoring_bodies())
		var/list/body = tailoring_body(body_id)
		if (body["slot"] == "head")
			heads += body_id
	dressmaking_ci_expect(heads.len >= 10 && tailoring_garment_type(tailoring_body("beret")) == /obj/item/clothing/head/tailored, "headwear bodies sew tailored headwear")
	dressmaking_ci_expect(tailoring_slot_name(tailoring_body("beret")) == "headwear" && tailoring_slot_name(tailoring_body("poncho")) == "overclothes" && tailoring_slot_name(tailoring_body("toga")) == "clothing", "garment menu names each slot")
	var/obj/item/clothing/head/tailored/veil = new(site)
	veil.design_body = "hijab"
	veil.design_colors = "#3e5a86"
	veil.design_fabric = "cloth"
	veil.tailoring_refresh()
	dressmaking_ci_expect((veil.flags_inv & BLOCKHAIR) && veil.name == "veil" && veil.icon == 'icons/obj/clothing/hats.dmi' && veil.item_state == "hijab", "a veil hides the hair")
	veil.design_body = "beret"
	veil.tailoring_refresh()
	dressmaking_ci_expect(!(veil.flags_inv & BLOCKHAIR) && veil.name == "beret", "a beret leaves the hair visible")
	qdel(veil)
	var/obj/item/clothing/head/tailored/cap = new(site)
	cap.design_body = "peaked_cap"
	cap.design_colors = "#232f58|#b01c30|#e0b030"
	cap.design_fabric = "woolcloth"
	cap.tailoring_refresh()
	var/expected = length(cap.worn_design_layers())
	dressmaking_ci_expect(expected == 3 && cap.overlays.len == 3 && cap.armor["melee"] == 5, "a peaked cap draws body, band and badge")
	var/savefile/F = new("dressmaking-headwear.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, cap, 1)
	map_storage.clear_bookkeeping()
	var/obj/item/clothing/head/tailored/loaded = map_storage.Load_Entry(F, ref, starting_loc = site)
	if (loaded)
		loaded.after_load()
		loaded.after_load()
	dressmaking_ci_expect(loaded && loaded.design_body == "peaked_cap" && loaded.design_colors == "#232f58|#b01c30|#e0b030" && loaded.overlays.len == expected && loaded.name == "peaked cap", "headwear round trip rebuilds its layers once")
	qdel(cap); qdel(loaded)
	// Mix-and-match hats: four crowns sharing bands, brims, flaps and decorations.
	var/list/crowns = list("made_round_hat", "made_pointed_hat", "made_soft_hat", "made_tall_hat")
	for (var/crown in crowns)
		var/list/crown_body = tailoring_body(crown)
		var/full = "Stripes|Fur trim|Wide brim|Ear flaps|Plume"
		dressmaking_ci_expect(crown_body && crown_body["slot"] == "head" && length(tailoring_piece_labels(crown_body)) == 6 && tailoring_design_valid(crown, "#232f58|#ffffff|#6e4c30|#232f58|#232f58|#b01c30", full), "[crown] takes five coloured pieces")
		dressmaking_ci_expect(length(tailoring_layers(crown, null, TRUE, full)) == 6 && length(tailoring_layers(crown, null, FALSE, null)) == 1 && tailoring_design_cost(crown, full) == crown_body["cost"] + 2, "[crown] draws each chosen piece and charges for brim and flaps")
	dressmaking_ci_expect(!tailoring_design_valid("made_round_hat", "#ffffff", "Stripes|Band|Top hat brim") && tailoring_pieces_text(tailoring_pieces("made_round_hat", null)) == "Plain|None|None|None|None", "unknown hat pieces are refused and a new hat starts plain")
	var/obj/item/clothing/head/tailored/hat = new(site)
	hat.design_body = "made_soft_hat"
	hat.design_colors = "#232f58|#ffffff|#e0b030|#232f58|#ffffff|#b01c30"
	hat.design_pieces = "Plain|Band|Cocked brim|None|Feather"
	hat.design_fabric = "woolcloth"
	hat.design_name = "Sunday hat"
	hat.tailoring_refresh()
	dressmaking_ci_expect(hat.name == "Sunday hat" && hat.icon == 'icons/obj/clothing/tailoring.dmi' && hat.icon_override == 'icons/mob/tailoring.dmi' && hat.item_state == "tl_hat_soft" && hat.overlays.len == 4 && length(hat.worn_design_layers()) == 4 && (hat.body_parts_covered & HEAD) && !(hat.flags_inv & BLOCKHAIR), "a soft hat with band, cocked brim and feather draws four layers on the tailoring art")
	var/savefile/hat_file = new("dressmaking-made-hat.sav")
	hat_file["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/hat_ref = map_storage.BuildVarDirectory(hat_file, hat, 1)
	map_storage.clear_bookkeeping()
	var/obj/item/clothing/head/tailored/loaded_hat = map_storage.Load_Entry(hat_file, hat_ref, starting_loc = site)
	if (loaded_hat)
		loaded_hat.after_load()
	dressmaking_ci_expect(loaded_hat && loaded_hat.design_pieces == "Plain|Band|Cocked brim|None|Feather" && loaded_hat.overlays.len == 4 && loaded_hat.name == "Sunday hat" && loaded_hat.icon_override == 'icons/mob/tailoring.dmi', "a pieced hat round trip keeps its pieces")
	tailoring_named_items -= hat
	tailoring_named_items -= loaded_hat
	qdel(hat); qdel(loaded_hat)
	dressmaking_ci_clear(site)

// Gloves, footwear and belts: leather projects, looks only, function unchanged.
/proc/dressmaking_ci_accessories(mob/living/human/handle_ci/dress_ci/H, turf/site, datum/save_epoch)
	dressmaking_ci_clear(site)
	dressmaking_ci_expect(tailoring_garment_type(tailoring_body("made_gloves")) == /obj/item/clothing/gloves/thick/leather/tailored && tailoring_garment_type(tailoring_body("made_shoes")) == /obj/item/clothing/shoes/tailored && tailoring_garment_type(tailoring_body("made_tall_boots")) == /obj/item/clothing/shoes/leatherboots/tailored && tailoring_garment_type(tailoring_body("made_sash")) == /obj/item/clothing/pouch_belt/tailored, "accessory bodies sew the matching item")
	dressmaking_ci_expect(tailoring_slot_name(tailoring_body("made_gloves")) == "gloves" && tailoring_slot_name(tailoring_body("made_boots")) == "footwear" && tailoring_slot_name(tailoring_body("made_belt")) == "belt", "garment menu names the accessory slots")
	dressmaking_ci_expect(tailoring_body_fits("made_boots", "leather") && !tailoring_body_fits("made_boots", "cloth") && tailoring_body_fits("made_gloves", "woolcloth") && !tailoring_body_fits("made_gloves", "cloth") && tailoring_body_fits("made_sash", "cloth") && !tailoring_body_fits("made_sash", "leather") && !tailoring_body_fits("toga", "leather") && tailoring_body_fits("toga", null), "each body is made of its own materials")
	dressmaking_ci_expect(tailoring_default_body("leather") == "made_gloves" && tailoring_default_body("cloth") == "loincloth" && tailoring_body_fabric_names("made_gloves") == "leather or wool", "a material starts on a garment it can make")
	var/list/leather_bodies = tailoring_known_bodies(H, "leather")
	var/list/cloth_bodies = tailoring_known_bodies(H, "cloth")
	var/leather_only = TRUE
	for (var/label in leather_bodies)
		if (!tailoring_body_fits(leather_bodies[label], "leather"))
			leather_only = FALSE
	dressmaking_ci_expect(leather_bodies.len == 7 && leather_only && !("toga (clothing, 3 fabric)" in leather_bodies) && ("toga (clothing, 3 fabric)" in cloth_bodies) && ("waist sash (belt, 1 fabric)" in cloth_bodies), "the garment list follows the project's material")
	// A leather sheet pays for a leather project, which starts on gloves.
	var/datum/stack_recipe/R = recipe_ci_food_recipe(/material/leather, /obj/item/tailoring_project, H.civilization)
	dressmaking_ci_expect(R && R.req_amount == 1, "one-sheet leather recipe")
	if (R)
		R.time = 0
		var/obj/item/stack/material/leather/hide = new(H, 4, FALSE)
		var/obj/item/weapon/flint/blocker = new(H)
		H.r_hand = hide
		H.l_hand = blocker
		hide.produce_recipe(R, 1, H)
		// Skip projects an earlier check consumed and left queued for deletion.
		var/obj/item/tailoring_project/paid = null
		for (var/obj/item/tailoring_project/made in site)
			if (!made.gcDestroyed)
				paid = made
		dressmaking_ci_expect(paid && paid.fabric_kind == "leather" && hide.amount == 3, "a leather project is made of leather")
		if (paid)
			paid.fit_fabric()
			dressmaking_ci_expect(paid.design_body == "made_gloves" && paid.design_pieces == "None|Plain|Plain", "a leather project starts on plain gloves")
			paid.attackby(hide, H)
			dressmaking_ci_expect(paid.fabric == 2 && hide.amount == 2, "leather tops up a leather project")
			var/obj/item/stack/material/cloth/linen = new(site, 2, FALSE)
			paid.attackby(linen, H)
			dressmaking_ci_expect(paid.fabric == 2 && linen.amount == 2, "cloth is refused by a leather project")
			qdel(linen)
			dressmaking_ci_expect(!paid.load_design(H, "toga", "#ffffff", null, null, null, null) && paid.design_body == "made_gloves", "a clothing design is refused by a leather project")
			dressmaking_ci_expect(paid.load_design(H, "made_boots", "#6e4c30|#2a2826|#ffffff|#d6c050|#ffffff", "Thick|Plain|Buckled|Fur", null, null, null) && paid.design_body == "made_boots" && paid.body_cost() == 3, "a boot design loads onto a leather project")
			qdel(paid)
		H.remove_from_mob(hide); qdel(hide)
		H.remove_from_mob(blocker); qdel(blocker)
	var/obj/item/tailoring_project/dress_ci/linen_project = new(H)
	H.r_hand = linen_project
	dressmaking_ci_expect(!linen_project.load_design(H, "made_boots", "#ffffff", null, null, null, null) && linen_project.design_body == "long_tunic", "a boot design is refused by a cloth project")
	linen_project.design_body = "made_boots"
	linen_project.fabric = 8
	dressmaking_ci_expect(!linen_project.cut_fabric(H, site, save_epoch) && linen_project.stage == 0, "boots cannot be cut from cloth")
	linen_project.fit_fabric()
	dressmaking_ci_expect(linen_project.design_body == "loincloth", "a design the material cannot make falls back to one it can")
	H.remove_from_mob(linen_project); qdel(linen_project)
	// Boots: the design is drawn, the protection and grip are a leather boot's.
	var/obj/item/clothing/shoes/leatherboots/plain_boots = new(site)
	var/obj/item/clothing/shoes/leatherboots/tailored/boots = new(site)
	boots.design_body = "made_tall_boots"
	boots.design_colors = "#6e4c30|#2a2826|#ffffff|#d6c050|#d8ccb0"
	boots.design_pieces = "Thick|Plain|Buckled|Fur"
	boots.design_fabric = "leather"
	boots.tailoring_refresh()
	dressmaking_ci_expect(boots.name == "tall boots" && boots.icon == 'icons/obj/clothing/tailoring.dmi' && boots.icon_override == 'icons/mob/tailoring.dmi' && boots.icon_state == "tl_boots_tall" && boots.overlays.len == 4 && length(boots.worn_design_layers()) == 4, "tall boots with sole, buckle and fur cuff draw four layers")
	dressmaking_ci_expect(boots.armor["melee"] == plain_boots.armor["melee"] && boots.armor["arrow"] == plain_boots.armor["arrow"] && boots.min_cold_protection_temperature == plain_boots.min_cold_protection_temperature && boots.body_parts_covered == plain_boots.body_parts_covered && boots.mud_mult == plain_boots.mud_mult && boots.waterproof_feet == plain_boots.waterproof_feet && (boots.item_flags & NOSLIP) && (boots.slot_flags & SLOT_FEET), "tailored boots protect and grip like plain leather boots")
	var/list/tan = tailoring_layers("made_tall_boots", "#ffffff", FALSE, null, "leather")
	var/image/tan_body = tan[1]
	dressmaking_ci_expect(tan_body.color == "#cfa97c", "undyed leather shows its own tan")
	var/savefile/F = new("dressmaking-boots.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, boots, 1)
	map_storage.clear_bookkeeping()
	var/obj/item/clothing/shoes/leatherboots/tailored/loaded_boots = map_storage.Load_Entry(F, ref, starting_loc = site)
	if (loaded_boots)
		loaded_boots.after_load()
		loaded_boots.after_load()
	dressmaking_ci_expect(loaded_boots && loaded_boots.design_body == "made_tall_boots" && loaded_boots.design_pieces == "Thick|Plain|Buckled|Fur" && loaded_boots.design_fabric == "leather" && loaded_boots.overlays.len == 4 && loaded_boots.name == "tall boots", "boots round trip rebuilds their layers once")
	qdel(plain_boots); qdel(boots); qdel(loaded_boots)
	// Gloves: wool or leather, the same thick gloves either way.
	var/obj/item/clothing/gloves/thick/leather/plain_gloves = new(site)
	var/obj/item/clothing/gloves/thick/leather/tailored/gloves = new(site)
	gloves.design_body = "made_long_gloves"
	gloves.design_colors = "#a8342c|#d6c050|#ffffff|#2a2826"
	gloves.design_pieces = "Banded|Plain|Capped"
	gloves.design_fabric = "woolcloth"
	gloves.tailoring_refresh()
	dressmaking_ci_expect(gloves.name == "long gloves" && gloves.overlays.len == 3 && gloves.icon_state == "tl_gloves_long" && gloves.body_parts_covered == plain_gloves.body_parts_covered && gloves.min_cold_protection_temperature == plain_gloves.min_cold_protection_temperature && gloves.cold_protection == plain_gloves.cold_protection && (gloves.slot_flags & SLOT_GLOVES), "long wool gloves keep a thick glove's protection")
	qdel(plain_gloves); qdel(gloves)
	// Belts: the same attachment points as a plain leather belt.
	var/obj/item/clothing/pouch_belt/tailored/belt = new(site)
	belt.design_body = "made_wide_belt"
	belt.design_colors = "#2a2826|#e0b030|#e0b030|#2a2826"
	belt.design_pieces = "Studded|Plate|Hanging"
	belt.design_fabric = "leather"
	belt.tailoring_refresh()
	var/obj/item/clothing/accessory/storage/belt_pouch/pouch = new(site)
	var/obj/item/clothing/accessory/medal/medal = new(site)
	dressmaking_ci_expect(belt.name == "wide belt" && belt.overlays.len == 4 && belt.icon_override == 'icons/mob/tailoring.dmi' && (belt.slot_flags & SLOT_BELT) && belt.can_attach_accessory(pouch) && !belt.can_attach_accessory(medal) && tailoring_design_cost("made_wide_belt", "Studded|Plate|Hanging") == 3, "a tailored belt hangs what a plain belt hangs")
	var/obj/item/clothing/pouch_belt/tailored/sash = new(site)
	sash.design_body = "made_sash"
	sash.design_colors = "#a8342c|#d6c050|#ffffff"
	sash.design_pieces = "Striped|Fringed"
	sash.design_fabric = "cloth"
	sash.tailoring_refresh()
	dressmaking_ci_expect(sash.name == "waist sash" && sash.overlays.len == 3 && sash.can_attach_accessory(pouch), "a waist sash is a belt of cloth")
	var/code = tailoring_design_code("made_wide_belt", belt.design_colors, belt.design_pieces, "Parade belt")
	var/list/parsed = tailoring_parse_design_code(code)
	dressmaking_ci_expect(code == "C13CLOTH/1/made_wide_belt/2a2826.e0b030.e0b030.2a2826/2.3.2/Parade_belt" && parsed && parsed["body"] == "made_wide_belt" && parsed["pieces"] == "Studded|Plate|Hanging", "a belt design travels as a design code")
	qdel(pouch); qdel(medal); qdel(belt); qdel(sash)
	dressmaking_ci_clear(site)

// Writes in its own proc so the savefile closes before it is read back.
// Restyling a finished bag: looks only, one sheet a job, the bag in hand.
/proc/dressmaking_ci_bag_styles(mob/living/human/handle_ci/dress_ci/H, turf/site, datum/save_epoch)
	dressmaking_ci_clear(site)
	var/obj/item/weapon/storage/backpack/bag = new(H)
	var/obj/item/weapon/storage/backpack/satchel/black/other = new(site)
	var/obj/item/clothing/accessory/storage/webbing/bandolier = new(site)
	var/list/kind = bag_style_kind(bag)
	var/list/strap_kind = bag_style_kind(bandolier)
	dressmaking_ci_expect(kind && kind[1] == "backpack" && length(kind[2]) == 3 && strap_kind && length(strap_kind[2]) == 2 && !bag_style_kind(other) && !bag_style_kind(H) && !bag_style_kind(null), "only the listed bags are restyled, never their subtypes")
	var/obj_states = icon_states('icons/obj/clothing/bag_styles.dmi')
	var/mob_states = icon_states('icons/mob/bag_styles.dmi')
	var/art = TRUE
	for (var/path in bag_style_kinds)
		var/list/row = bag_style_kinds[path]
		if (!ispath(text2path(path), /obj/item))
			art = FALSE
		for (var/zone in row[2])
			if (!("[row[1]]_[lowertext(zone)]" in obj_states) || !("[row[1]]_[lowertext(zone)]" in mob_states))
				art = FALSE
	dressmaking_ci_expect(art, "every restyled bag has loose and worn art for each part")
	var/list/blank = bag_style_colors(bag, null)
	dressmaking_ci_expect(blank.len == 3 && !blank[1] && !blank[3] && !bag_style_text(blank) && bag_style_text(list("#3e5a86", null, "#d6c050")) == "#3e5a86|-|#d6c050", "an unstyled bag stores nothing")
	var/list/parsed = bag_style_colors(bag, "#3E5A86|-|javascript")
	dressmaking_ci_expect(parsed[1] == "#3e5a86" && !parsed[2] && !parsed[3], "malformed colours are dropped")
	var/obj/item/tailoring_project/dress_ci/P = new(H)
	P.fabric = 2
	H.l_hand = P
	H.r_hand = bag
	var/space = bag.max_storage_space
	var/old_type = bag.type
	var/old_name = bag.name
	var/obj/item/weapon/flint/kept = new(bag)
	P.wait_mode = "cancel"
	dressmaking_ci_expect(!P.sew_bag_style(H, site, save_epoch, bag, list("#3e5a86", null, "#d6c050")) && !bag.bag_style && P.fabric == 2, "an interrupted restyling costs nothing")
	P.wait_mode = "complete"
	dressmaking_ci_expect(!P.sew_bag_style(H, site, save_epoch, bag, list("#3e5a86", "bad", null)) && !P.sew_bag_style(H, site, save_epoch, bag, list("#3e5a86")) && !P.sew_bag_style(H, site, save_epoch, other, list("#3e5a86", null, null)) && !bag.bag_style && P.fabric == 2, "bad colours, wrong parts and unlisted bags are refused")
	H.r_hand = null
	bag.forceMove(site)
	dressmaking_ci_expect(!P.sew_bag_style(H, site, save_epoch, bag, list("#3e5a86", null, null)) && P.fabric == 2, "the bag must be in the tailor's other hand")
	bag.forceMove(H)
	H.r_hand = bag
	P.stage = 1
	dressmaking_ci_expect(!P.sew_bag_style(H, site, save_epoch, bag, list("#3e5a86", null, null)) && P.fabric == 2, "cut pieces cannot restyle")
	P.stage = 0
	dressmaking_ci_expect(P.sew_bag_style(H, site, save_epoch, bag, list("#3e5a86", null, "#d6c050")) && bag.bag_style == "#3e5a86|-|#d6c050" && P.fabric == 1 && !P.gcDestroyed, "restyling takes one sheet")
	dressmaking_ci_expect(bag.type == old_type && bag.name == old_name && bag.max_storage_space == space && kept.loc == bag && length(bag.bag_style_overlays) == 2 && length(bag_style_layers(bag, TRUE)) == 2, "a restyled bag is the same bag with the same storage")
	dressmaking_ci_expect(!P.sew_bag_style(H, site, save_epoch, bag, list("#3e5a86", null, "#d6c050")) && P.fabric == 1, "the same look again costs nothing")
	var/before = length(bag.overlays)
	bag.after_load()
	dressmaking_ci_expect(length(bag.overlays) == before && length(bag.bag_style_overlays) == 2, "a loaded bag draws its style once")
	dressmaking_ci_expect(findtext(bag_style_describe(bag), "woad blue fabric") && findtext(bag_style_describe(bag), "weld yellow trim") && !bag_style_describe(other), "examining names the dyes")
	// Undoing every part clears the style; the last sheet uses the project up.
	dressmaking_ci_expect(P.sew_bag_style(H, site, save_epoch, bag, list(null, null, null)) && !bag.bag_style && !bag.bag_style_overlays && P.gcDestroyed && H.l_hand != P, "the last sheet uses up the project and a bag can go back to plain")
	qdel(kept)
	// A bandolier keeps its dyes on the clothes it is attached to.
	var/obj/item/tailoring_project/dress_ci/Q = new(H)
	Q.fabric = 3
	H.l_hand = Q
	bag.forceMove(site)
	bandolier.forceMove(H)
	H.r_hand = bandolier
	var/image/plain = bandolier.get_mob_overlay()
	dressmaking_ci_expect(!length(plain.overlays), "a plain bandolier draws nothing extra")
	dressmaking_ci_expect(Q.sew_bag_style(H, site, save_epoch, bandolier, list("#a8342c", "#e0b030")) && bandolier.bag_style == "#a8342c|#e0b030" && Q.fabric == 2, "a bandolier is restyled the same way")
	var/image/worn = bandolier.get_mob_overlay()
	var/image/inv = bandolier.get_inv_overlay()
	dressmaking_ci_expect(length(worn.overlays) == 2 && length(inv.overlays) == 2 && bandolier.slots == initial(bandolier.slots) && bandolier.hold, "a restyled bandolier keeps its pouches and shows its dyes when attached")
	// Dyes follow the tailor's knowledge, as on a garment.
	dressmaking_ci_expect(bag_style_allowed(H, list("#3e5a86", null)) == !!(crafting_node_allowed(H, "classical_dress") || crafting_node_allowed(H, "textile_mills")), "dyes follow knowledge")
	H.l_hand = null
	H.r_hand = null
	qdel(Q)
	qdel(bandolier)
	qdel(bag)
	qdel(other)
	dressmaking_ci_clear(site)

/proc/dressmaking_ci_retains_top_overlays(obj/item/clothing/G, list/top_layers)
	if (length(G.overlays) != length(G.tailoring_overlays) + length(top_layers))
		return FALSE
	var/design_count = length(G.tailoring_overlays)
	for (var/i in 1 to length(top_layers))
		if (G.overlays[design_count + i] != top_layers[i])
			return FALSE
	return TRUE

// Minor alterations: a few re-dyed or swapped parts, never a new garment.
/proc/dressmaking_ci_alterations(mob/living/human/handle_ci/dress_ci/H, turf/site, datum/save_epoch)
	dressmaking_ci_clear(site)
	var/obj/item/clothing/under/tailored/G = new(H)
	G.design_body = "made_tunic"
	G.design_colors = "#ffffff"
	G.design_pieces = tailoring_pieces_text(tailoring_pieces("made_tunic", null))
	G.design_fabric = "cloth"
	G.design_name = "Sunday best"
	G.design_maker = "Ada"
	G.tailoring_refresh()
	var/obj/item/clothing/accessory/A = new(G)
	A.has_suit = G
	G.accessories += A
	var/first_top_layer = length(G.overlays) + 1
	G.overlays += A.get_inv_overlay()
	G.blood_DNA = list("fixture" = "O+")
	G.generate_blood_overlay()
	G.overlays += G.blood_overlay
	var/image/tag_art = image(G.icon, icon_state = G.icon_state)
	tag_art.alpha = 95
	G.overlays += tag_art
	var/list/top_layers = G.overlays.Copy(first_top_layer)
	dressmaking_ci_expect(length(top_layers) == 3, "the alteration fixture has three distinct top overlays")
	var/plain = G.design_pieces
	var/striped = tailoring_set_piece("made_tunic", plain, "Pattern", "Stripes")
	var/sleeved = tailoring_set_piece("made_tunic", plain, "Sleeves", "Long")
	var/busy = tailoring_set_piece("made_tunic", striped, "Neckline", "V neck")
	dressmaking_ci_expect(striped != plain && sleeved != plain && busy != striped, "the alteration fixture's pieces exist")
	dressmaking_ci_expect(tailoring_alteration_changes("made_tunic", "#ffffff", plain, "#3e5a86", plain) == 1 && tailoring_alteration_changes("made_tunic", "#ffffff", plain, "#3e5a86", busy) == 3 && !tailoring_alteration_changes("made_tunic", "#ffffff", plain, "#FFFFFF", plain), "each re-dyed or swapped part counts once")
	dressmaking_ci_expect(!tailoring_alteration_problem(H, G, "#3e5a86", striped) && findtext(tailoring_alteration_problem(H, G, "#3e5a86", busy), "more than a minor alteration") && findtext(tailoring_alteration_problem(H, G, "#ffffff", sleeved), "more fabric") && findtext(tailoring_alteration_problem(H, G, "#ffffff", plain), "Nothing") && tailoring_alteration_problem(H, G, "red", plain) && tailoring_alteration_problem(H, H, "#3e5a86", plain), "only small, fabric-free changes are alterations")
	var/obj/item/tailoring_project/dress_ci/P = new(H)
	P.fabric = 2
	H.l_hand = P
	H.r_hand = G
	var/covered = G.body_parts_covered
	var/old_type = G.type
	P.wait_mode = "cancel"
	dressmaking_ci_expect(!P.sew_alteration(H, site, save_epoch, G, "#3e5a86", striped) && G.design_colors == "#ffffff" && P.fabric == 2, "an interrupted alteration costs nothing")
	P.wait_mode = "complete"
	dressmaking_ci_expect(!P.sew_alteration(H, site, save_epoch, G, "#3e5a86", busy) && !P.sew_alteration(H, site, save_epoch, G, "#ffffff", sleeved) && G.design_pieces == plain && P.fabric == 2, "a redesign is refused")
	P.fabric_kind = "leather"
	dressmaking_ci_expect(!P.alteration_material_fits(G) && !P.sew_alteration(H, site, save_epoch, G, "#3e5a86", striped) && P.fabric == 2, "the project must be the garment's material")
	P.fabric_kind = "cloth"
	H.r_hand = null
	G.forceMove(site)
	dressmaking_ci_expect(!P.sew_alteration(H, site, save_epoch, G, "#3e5a86", striped) && P.fabric == 2, "the garment must be in the tailor's other hand")
	G.forceMove(H)
	H.r_hand = G
	dressmaking_ci_expect(P.sew_alteration(H, site, save_epoch, G, "#3e5a86", striped) && P.fabric == 1 && G.design_pieces == striped && copytext(G.design_colors, 1, 8) == "#3e5a86", "an alteration takes one sheet")
	dressmaking_ci_expect(G.type == old_type && G.design_body == "made_tunic" && G.name == "Sunday best" && G.design_maker == "Ada" && G.design_fabric == "cloth" && G.body_parts_covered == covered && length(G.tailoring_overlays) == length(tailoring_layers("made_tunic", G.design_colors, FALSE, striped, "cloth")), "an altered garment keeps its body, name, designer and cover")
	dressmaking_ci_expect(!P.sew_alteration(H, site, save_epoch, G, G.design_colors, striped) && P.fabric == 1, "no change costs nothing")
	dressmaking_ci_expect(dressmaking_ci_retains_top_overlays(G, top_layers), "alteration keeps accessory, stain and unrelated art above the design in order")
	dressmaking_ci_expect(P.sew_alteration(H, site, save_epoch, G, "#ffffff", striped) && P.fabric == 0, "a second alteration uses the remaining sheet")
	dressmaking_ci_expect(dressmaking_ci_retains_top_overlays(G, top_layers), "second alteration replaces the design exactly once without rearranging the other art")
	H.l_hand = null
	H.r_hand = null
	qdel(P)
	qdel(G)
	// Leather boots take a leather project; the boots stay boots.
	var/obj/item/clothing/shoes/leatherboots/tailored/B = new(H)
	B.design_body = "made_boots"
	B.design_colors = "#ffffff"
	B.design_pieces = tailoring_pieces_text(tailoring_pieces("made_boots", null))
	B.design_fabric = "leather"
	B.tailoring_refresh()
	var/obj/item/tailoring_project/dress_ci/L = new(H)
	L.fabric_kind = "leather"
	L.fabric = 1
	H.l_hand = L
	H.r_hand = B
	var/laced = tailoring_set_piece("made_boots", B.design_pieces, "Fastening", "Laced")
	dressmaking_ci_expect(L.sew_alteration(H, site, save_epoch, B, "#6e4c30", laced) && B.design_pieces == laced && B.type == /obj/item/clothing/shoes/leatherboots/tailored && L.gcDestroyed && H.l_hand != L, "boots are altered from leather and the last sheet uses up the project")
	H.l_hand = null
	H.r_hand = null
	qdel(B)
	dressmaking_ci_clear(site)

/proc/dressmaking_ci_write_book(path, list/designs)
	var/savefile/S = new(path)
	S["designs"] << designs

// Pattern book: per-account designs saved beside the player notes.
/proc/dressmaking_ci_book(mob/living/human/handle_ci/dress_ci/H, turf/site, datum/save_epoch)
	dressmaking_ci_clear(site)
	var/key = "dresscibook"
	var/path = tailoring_book_path(key)
	dressmaking_ci_expect(path == "data/player_saves/d/dresscibook/tailoring_patterns.sav" && !tailoring_book_path(""), "books live in the account's player save folder")
	if (fexists(path))
		fdel(path)
	tailoring_books = list()
	dressmaking_ci_expect(islist(tailoring_book(key)) && !length(tailoring_book(key)), "a new account starts with an empty book")
	var/list/first = tailoring_book_add(key, "laced_dress", "#FFFFFF|#bb4455|#223344", null, "Tom & Jerry", "Ann Smith", "dressci")
	dressmaking_ci_expect(islist(first) && first["colors"] == "#ffffff|#bb4455|#223344" && first["name"] == "Tom &amp; Jerry" && fexists(path), "a design is noted and written to disk")
	dressmaking_ci_expect(tailoring_book_add(key, "laced_dress", "#ffffff|#bb4455|#223344", null, "Tom &amp; Jerry", "Ann Smith", "dressci") == "duplicate", "the same design is not noted twice")
	dressmaking_ci_expect(!tailoring_book_add(key, "no_such_body", "#ffffff", null, null, null, null) && !tailoring_book_add(key, "laced_dress", "not a colour", null, null, null, null), "invalid designs are refused")
	var/shirt_pieces = tailoring_pieces_text(tailoring_pieces("made_shirt", null))
	var/list/shirt = tailoring_book_add(key, "made_shirt", jointext(tailoring_colors("made_shirt", null), "|"), shirt_pieces, null, "Ann Smith", "dressci")
	dressmaking_ci_expect(islist(shirt) && shirt["pieces"] == shirt_pieces, "piece choices are kept")
	for (var/i = 3, i <= 20, i++)
		tailoring_book_add(key, "long_tunic", rgb(i, i, i), null, null, null, null)
	dressmaking_ci_expect(length(tailoring_book(key)) == 20 && tailoring_book_add(key, "long_tunic", "#123456", null, null, null, null) == "full", "a book holds 20 designs")
	// Reading the book back from disk.
	tailoring_books = list()
	var/list/reread = tailoring_book(key)
	dressmaking_ci_expect(length(reread) == 20 && tailoring_book_same(reread[1], first) && reread[2]["pieces"] == shirt_pieces, "the book reads back from disk unchanged")
	dressmaking_ci_expect(tailoring_book_label(reread[1]) == "Tom &amp; Jerry (laced dress)" && tailoring_book_label(reread[3]) == "long tunic", "entries are listed by name and garment")
	dressmaking_ci_expect(tailoring_book_remove(key, reread[3]) && !tailoring_book_remove(key, list("body" = "long_tunic")), "a design can be struck from the book")
	tailoring_books = list()
	dressmaking_ci_expect(length(tailoring_book(key)) == 19, "removal is written to disk")
	// Entries that no longer match the catalogue are dropped on reading.
	fdel(path)
	dressmaking_ci_write_book(path, list(list("body" = "gone_body", "colors" = "#ffffff"), "junk", list("body" = "long_tunic", "colors" = "#334455")))
	tailoring_books = list()
	var/list/cleaned = tailoring_book(key)
	dressmaking_ci_expect(length(cleaned) == 1 && cleaned[1]["colors"] == "#334455", "stale entries are dropped")
	// Loading a book entry onto a project uses the same checks as a pattern.
	var/obj/item/tailoring_project/dress_ci/target = new(site)
	dressmaking_ci_expect(target.load_design(H, first["body"], first["colors"], first["pieces"], first["name"], first["maker"], first["author"], "design") && target.design_body == "laced_dress" && target.design_name == "Tom &amp; Jerry" && target.design_maker == "Ann Smith" && (target in tailoring_named_items), "a book design loads onto an uncut project")
	tailoring_name_block_list = list("dressci")
	dressmaking_ci_expect(tailoring_book_label(first) == "laced dress" && target.load_design(H, first["body"], first["colors"], first["pieces"], first["name"], first["maker"], first["author"], "design") && !target.design_name && !(target in tailoring_named_items), "a blocked author's name is not copied")
	tailoring_name_block_list = list()
	target.stage = 1
	dressmaking_ci_expect(!target.load_design(H, "long_tunic", "#ffffff", null, null, null, null, "design") && target.design_body == "laced_dress", "a cut project keeps its design")
	qdel(target)
	fdel(path)
	tailoring_books = list()
	dressmaking_ci_clear(site)

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
		dressmaking_ci_expect(paid && paid.fabric_kind == (material_path == /material/cloth ? "cloth" : "woolcloth"), "project is made of the paying fabric [material_path]")
		if (paid)
			paid.attackby(stock, H)
			dressmaking_ci_expect(paid.fabric == 2 && stock.amount == 4, "a held sheet adds fabric for [material_path]")
			var/other_type = material_path == /material/cloth ? /obj/item/stack/material/woolcloth : /obj/item/stack/material/cloth
			var/obj/item/stack/other = new other_type(site, 3, FALSE)
			paid.attackby(other, H)
			dressmaking_ci_expect(paid.fabric == 2 && other.amount == 3, "another fabric is refused [material_path]")
			qdel(other)
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
		var/list/options = body["options"]
		for (var/option in options)
			var/list/variants = options[option]
			dressmaking_ci_expect(variants.len >= 2 && (!tailoring_piece_node(variants[variants[1]]) || tailoring_piece_node(variants[variants[1]]) == body["node"]), "first variant needs only the body's knowledge [body_id]/[option]")
			for (var/variant in variants)
				if (variants[variant])
					states |= variants[variant]
		var/default_pieces = 0
		for (var/state in tailoring_piece_states(body_id, null))
			if (state)
				default_pieces++
		var/cost = tailoring_design_cost(body_id, null)
		dressmaking_ci_expect(cost >= 1 && cost <= 8, "default design fits one project [body_id]")
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
		var/list/body_fabrics = body["fabrics"]
		P.fabric_kind = body_fabrics ? body_fabrics[1] : "cloth"
		var/list/made_of = tailoring_fabric(P.fabric_kind)
		P.fabric = cost - 1
		dressmaking_ci_expect(!P.cut_fabric(H, site, save_epoch) && P.stage == 0, "too little fabric cannot cut [body_id]")
		P.fabric = 8
		dressmaking_ci_expect(!P.sew_garment(H, site, save_epoch) && P.stage == 0, "uncut fabric cannot sew [body_id]")
		dressmaking_ci_expect(P.cut_fabric(H, site, save_epoch) && P.stage == 1 && P.fabric == cost, "cut locks design and keeps the cost [body_id]")
		var/obj/item/stack/material/spare = locate(made_of["stack"]) in site
		dressmaking_ci_expect(cost == 8 ? !spare : (spare && spare.amount == 8 - cost), "spare sheets set aside [body_id]")
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
			dressmaking_ci_expect(G.overlays.len == worn.len && worn.len == labels.len - length(options) + default_pieces + (fixed ? fixed.len : 0), "item and worn layer counts agree [body_id]")
			if (body["slot"] == "under")
				dressmaking_ci_expect(G.item_state_slots[slot_w_uniform_str] == body["base"], "worn base tracks chosen body [body_id]")
			else
				dressmaking_ci_expect(G.item_state == body["base"] && G.icon_state == (body["item_base"] ? body["item_base"] : body["base"]), "worn base tracks chosen body [body_id]")
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
	dressmaking_ci_pieces(H, site, save_epoch)
	dressmaking_ci_fabric_and_dyes(H, site, save_epoch)
	dressmaking_ci_patterns(H, site, save_epoch)
	dressmaking_ci_book(H, site, save_epoch)
	dressmaking_ci_headwear(H, site, save_epoch)
	dressmaking_ci_accessories(H, site, save_epoch)
	dressmaking_ci_bag_styles(H, site, save_epoch)
	dressmaking_ci_alterations(H, site, save_epoch)
	qdel(H)
	dressmaking_ci_clear(site)
	map_storage.clear_bookkeeping()
