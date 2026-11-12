// Production recipe payment, state transitions, saved fields and appearance.
// Only the wait is replaced to inject interruption/late-mutation cases; the
// shared handle_ci actor disables physiology/HUD. Output auto-equipping is
// refused by this fixture, so output remains on the floor; source hand cleanup
// still uses the production inventory transaction.
/mob/living/human/handle_ci/dress_ci/put_in_any_hand_if_possible(obj/item/W, del_on_fail = FALSE, disable_warning = TRUE, redraw_mob = TRUE, prioritize_active_hand = FALSE)
	return FALSE

/obj/item/dressmaking_project/dress_ci
	var/wait_mode = "complete"

/obj/item/dressmaking_project/dress_ci/wait_for_dressmaking(mob/living/human/user, delay)
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
		recipe_ci_fail("dressmaking", label)

/proc/recipe_ci_dressmaking()
	cloth_ci_setup()
	cloth_ci_load_catalogs()
	var/turf/site = locate(3,2,1)
	var/mob/living/human/handle_ci/dress_ci/H = new(site)
	H.civilization = "recipe_ci"
	var/datum/save_epoch = persistence_admission_identity
	// Wool uses the existing cloth substitution, with no second duplicate recipe.
	for (var/material_path in list(/material/cloth, /material/woolcloth))
		var/datum/stack_recipe/R = recipe_ci_food_recipe(material_path, /obj/item/dressmaking_project, H.civilization)
		dressmaking_ci_expect(R && R.req_amount == 4, "four-sheet recipe available for [material_path]")
		if (!R)
			continue
		R.time = 0
		var/stock_path = material_path == /material/cloth ? /obj/item/stack/material/cloth : /obj/item/stack/material/woolcloth
		var/obj/item/stack/stock = new stock_path(H, 6, FALSE)
		var/obj/item/weapon/flint/blocker = new(H)
		H.r_hand = stock
		H.l_hand = blocker
		stock.produce_recipe(R, 1, H)
		var/obj/item/dressmaking_project/paid = locate() in site
		dressmaking_ci_expect(paid && stock.amount == 2, "project pays four sheets of [material_path]")
		qdel(paid)
		H.remove_from_mob(stock); qdel(stock)
		H.remove_from_mob(blocker); qdel(blocker)
	for (var/value in list("#123456", "#aBcDeF", "#000000", "#FFFFFF"))
		dressmaking_ci_expect(dressmaking_color_valid(value), "opaque RGB accepted [value]")
	for (var/value in list("", "#123", "#00000000", "#GG0000", "red", 0))
		dressmaking_ci_expect(!dressmaking_color_valid(value), "invalid/transparent color rejected [value]")
	for (var/cut in list("Layered", "Buttoned", "Laced"))
		var/list/design = dressmaking_cut(cut)
		var/list/panels = design["panels"]
		for (var/art in list('icons/obj/clothing/uniforms.dmi', 'icons/mob/uniform.dmi'))
			dressmaking_ci_expect(design["base"] in icon_states(art), "existing base art [cut]")
			for (var/panel in panels)
				dressmaking_ci_expect(panels[panel] in icon_states(art), "existing panel art [cut]/[panel]")
		var/obj/item/dressmaking_project/dress_ci/P = new(H)
		H.r_hand = P
		P.dress_cut = cut
		P.primary_color = "#CC6644"
		P.secondary_color = "#4466CC"
		P.accent_color = "#44CC66"
		dressmaking_ci_expect(!P.sew_dress(H, site, save_epoch) && P.stage == 0, "uncut fabric cannot sew [cut]")
		dressmaking_ci_expect(P.cut_fabric(H, site, save_epoch) && P.stage == 1, "cut locks design [cut]")
		dressmaking_ci_expect(!P.cut_fabric(H, site, save_epoch), "cannot cut twice [cut]")
		dressmaking_ci_expect(P.sew_dress(H, site, save_epoch), "cut project sews [cut]")
		var/obj/item/clothing/under/tailored_dress/D = locate() in site
		dressmaking_ci_expect(!H.r_hand && !H.l_hand, "consumed project clears hand [cut]")
		dressmaking_ci_expect(istype(D) && D.dress_cut == cut && D.primary_color == "#CC6644" && D.secondary_color == "#4466CC" && D.accent_color == "#44CC66", "one wearable retains chosen panels [cut]")
		if (istype(D))
			var/list/worn = D.worn_design_layers()
			dressmaking_ci_expect(D.overlays.len == worn.len && worn.len == panels.len + !!design["fixed"], "item and worn layer counts agree [cut]")
			dressmaking_ci_expect(D.item_state_slots[slot_w_uniform_str] == design["base"], "worn base tracks chosen cut [cut]")
			D.refresh_design()
			dressmaking_ci_expect(D.overlays.len == worn.len, "refresh does not accumulate layers [cut]")
			qdel(D)
	for (var/mode in list("cancel", "drop", "save", "incapacitate"))
		for (var/initial_stage in list(0, 1))
			var/obj/item/dressmaking_project/dress_ci/P = new(H)
			H.r_hand = P
			P.stage = initial_stage
			P.wait_mode = mode
			var/result = initial_stage == 0 ? P.cut_fabric(H, site, save_epoch) : P.sew_dress(H, site, save_epoch)
			dressmaking_ci_expect(!result && P.stage == initial_stage && P.loc, "[mode] preserves paid project at stage [initial_stage]")
			H.stat = CONSCIOUS
			persistence_admission_identity = save_epoch
			H.remove_from_mob(P); qdel(P)
	// Interrupted work is durable, but an open menu lock is not.
	var/obj/item/dressmaking_project/P = new(site)
	P.stage = 1
	P.dress_cut = "Buttoned"
	P.primary_color = "#BB4455"
	P.dressmaking_busy = TRUE
	dressmaking_ci_expect(!("dressmaking_busy" in P.get_saved_vars()), "busy lock is runtime-only")
	var/savefile/F = new("dressmaking-project.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, P, 1)
	map_storage.clear_bookkeeping()
	var/obj/item/dressmaking_project/restored = map_storage.Load_Entry(F, ref, starting_loc = site)
	if (restored) restored.after_load()
	dressmaking_ci_expect(restored && restored.stage == 1 && restored.dress_cut == "Buttoned" && restored.primary_color == "#BB4455" && !restored.dressmaking_busy, "cut project round trip retains design without lock")
	qdel(P); qdel(restored)
	// Item appearance rebuild retains decoration and blood without duplication.
	var/obj/item/clothing/under/tailored_dress/D = new(site)
	D.dress_cut = "Laced"
	D.primary_color = "#BB4455"
	D.refresh_design()
	var/obj/item/clothing/accessory/A = new(D)
	A.has_suit = D
	D.accessories += A
	D.overlays += A.get_inv_overlay()
	D.blood_DNA = list("fixture" = "O+")
	D.generate_blood_overlay()
	D.overlays += D.blood_overlay
	F = new("dressmaking-dress.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	ref = map_storage.BuildVarDirectory(F, D, 1)
	map_storage.clear_bookkeeping()
	var/obj/item/clothing/under/tailored_dress/loaded = map_storage.Load_Entry(F, ref, starting_loc = site)
	if (loaded)
		loaded.after_load()
		loaded.after_load()
	dressmaking_ci_expect(loaded && loaded.dress_cut == "Laced" && loaded.primary_color == "#BB4455" && loaded.overlays.len == 5 && loaded.accessories.len == 1 && loaded.blood_DNA.len == 1, "dress round trip rebuilds three panels, accessory and blood once")
	qdel(D); qdel(loaded); qdel(H)
	map_storage.clear_bookkeeping()
