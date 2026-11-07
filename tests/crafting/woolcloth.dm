// Isolated production-path checks; character startup/HUD and test output are
// inherited adapters. No live map, client or external service is started.
var/cloth_ci_assertions = 0

/proc/cloth_ci_expect(condition, label)
	cloth_ci_assertions++
	if (!condition) recipe_ci_fail("cloth substitution", label)

/mob/living/human/handle_ci/cloth_ci
	var/medical_skill = 2

/mob/living/human/handle_ci/cloth_ci/getStatCoeff(statname)
	return statname == "medical" ? medical_skill : 2

/proc/cloth_ci_setup()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.name_set_event = new
	GLOB.stat_set_event = new
	populate_material_list()
	map = new /obj/map_metadata/recipe_ci
	map.ordinal_age = 0
	map.resourceresearch = TRUE
	map.chad_mode_plus = TRUE
	build_research_tree()
	for (var/node_id in research_nodes)
		var/list/entry = map.ensure_node_entry("recipe_ci", node_id)
		entry[RNODE_ENTRY_STATUS] = RNODE_DONE

/proc/cloth_ci_load_catalogs()
	for (var/filename in flist("config/crafting/"))
		if (!findtext(filename, "material_recipes_")) continue
		var/faction = replacetext(replacetext(filename, "material_recipes_", ""), ".txt", "")
		craftlist_lists[faction] = list()
		for (var/line in splittext(file2text("config/crafting/[filename]"), "\n"))
			if (!findtext(line, "RECIPE: ") || findtext(line, "//")) continue
			var/list/row = splittext(replacetext(line, "RECIPE: ", ""), ",")
			row[row.len] = replacetext(row[row.len], ascii2text(13), "")
			craftlist_lists[faction] += list(row)

/proc/cloth_ci_catalog()
	cloth_ci_load_catalogs()
	var/material/cloth = get_material_by_name("cloth")
	var/material/wool = get_material_by_name("woolcloth")
	for (var/faction in craftlist_lists)
		cloth.generate_recipes_civs(list(999,999,999), faction, "recipe_ci")
		wool.generate_recipes_civs(list(999,999,999), faction, "recipe_ci")
		var/list/wool_recipes = recipe_ci_flatten(wool.recipes)
		for (var/datum/stack_recipe/R in recipe_ci_flatten(cloth.recipes))
			var/found = FALSE
			for (var/datum/stack_recipe/W in wool_recipes)
				if (R.title == W.title && R.result_type == W.result_type && R.req_amount == W.req_amount && R.time == W.time && R.use_material == W.use_material) found = TRUE
			cloth_ci_expect(found, "[faction] wool can pay [R.title] at original cost")
	// The ordinary cloth bedroll is absent from the wool-only catalog on master.
	var/datum/stack_recipe/bedroll = recipe_ci_food_recipe(/material/woolcloth, /obj/item/weapon/bedroll/cloth, "recipe_ci")
	cloth_ci_expect(bedroll && bedroll.req_amount == 4, "wool offers ordinary four-sheet bedroll")

/proc/cloth_ci_stock()
	var/turf/T = locate(2,1,1)
	var/obj/item/stack/material/woolcloth/W = new(T, 10, FALSE)
	var/obj/item/stack/material/cloth/C = new(T, 4, FALSE)
	cloth_ci_expect(is_cloth_sheet(W) && is_cloth_sheet(C), "both finished textiles match cloth")
	for (var/path in list(/obj/item/stack/material/wool, /obj/item/stack/material/cotton, /obj/item/stack/material/rags, /obj/item/stack/material/leather, /obj/item/stack/material/steel))
		var/obj/item/stack/S = new path(null, 10, FALSE)
		cloth_ci_expect(!is_cloth_sheet(S) && !stack_matches_recipe_material(S, /obj/item/stack/material/cloth), "not cloth: [path]")
		qdel(S)
	cloth_ci_expect(!stack_matches_recipe_material(W, /obj/item/stack/material/steel), "non-cloth requirements unchanged")
	var/obj/item/stack/piece = W.split(3)
	cloth_ci_expect(piece.type == /obj/item/stack/material/woolcloth && piece.amount == 3 && W.amount == 7 && W.get_material_name() == "woolcloth", "split retains wool identity and units")
	cloth_ci_expect(!W.transfer_to(C) && W.amount == 7 && C.amount == 4, "substitution does not merge or convert stacks")
	W.material = get_material_by_name("cotton")
	cloth_ci_expect(!is_cloth_sheet(W), "relabelled wool stack rejected")
	qdel(W)
	qdel(C)
	qdel(piece)

/proc/cloth_ci_projects()
	var/turf/T = locate(2,1,1)
	var/mob/living/human/handle_ci/cloth_ci/H = new(T)
	H.civilization = "recipe_ci"
	var/obj/structure/region_gate/railway_station/office = new(T)
	office.party = "cloth_ci"
	var/obj/item/stack/material/woolcloth/W = new(H, 25, FALSE)
	H.l_hand = W
	office.attackby(W, H)
	cloth_ci_expect(office.delivered["cloth"] == 25 && !W.loc, "office credits paid wool under existing cloth key")
	var/obj/item/stack/material/cloth/C = new(H, 20, FALSE)
	H.l_hand = C
	office.attackby(C, H)
	cloth_ci_expect(office.delivered["cloth"] == 40 && C.amount == 5, "office combines textiles and returns excess")
	office.attackby(C, H)
	cloth_ci_expect(office.delivered["cloth"] == 40 && C.amount == 5, "office full ledger cannot double debit")
	var/obj/item/stack/material/wool/raw = new(H, 10, FALSE)
	H.l_hand = raw
	office.attackby(raw, H)
	cloth_ci_expect(office.delivered["cloth"] == 40 && raw.amount == 10, "office rejects raw wool")
	var/savefile/F = new("cloth-office.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, office, 1)
	map_storage.clear_bookkeeping()
	var/obj/structure/region_gate/railway_station/restored = map_storage.Load_Entry(F, ref, starting_loc = T)
	if (restored) restored.after_load()
	cloth_ci_expect(restored && restored.delivered["cloth"] == 40 && isnull(restored.remaining()["cloth"]), "existing saved cloth ledger needs no migration")
	qdel(restored)
	qdel(office)
	qdel(C)
	qdel(raw)
	qdel(H)

/proc/cloth_ci_armor()
	var/turf/T = locate(2,1,1)
	var/mob/living/human/handle_ci/cloth_ci/H = new(T)
	H.civilization = "recipe_ci"
	var/obj/structure/component_workbench/armor/bench = new(T)
	var/obj/item/stack/material/woolcloth/W = new(H, 5, FALSE)
	H.l_hand = W
	cloth_ci_expect(bench.insert(W, H), "armor stages wool in canonical cloth slot")
	var/obj/item/stack/material/cloth/C = new(H, 4, FALSE)
	H.l_hand = C
	cloth_ci_expect(!bench.insert(C, H) && C.loc == H, "armor cannot fill one requirement twice")
	var/obj/item/stack/material/leather/L = new(H, 3, FALSE)
	H.l_hand = L
	cloth_ci_expect(bench.insert(L, H), "armor still requires leather separately")
	var/list/staged = bench.staged_inputs("Armor carrier")
	var/list/amounts = list()
	for (var/obj/item/stack/S in staged) amounts[S] = S.amount
	bench.busy = TRUE
	bench.assembler = H
	var/datum/epoch = persistence_admission_identity
	persistence_admission_identity = new /datum
	cloth_ci_expect(!bench.commit_armor(H, "Armor carrier", staged, amounts, T, epoch) && W.amount == 5 && L.amount == 3, "armor crossed save admission consumes nothing")
	var/obj/item/result = bench.commit_armor(H, "Armor carrier", staged, amounts, T, persistence_admission_identity)
	cloth_ci_expect(istype(result, /obj/item/armor_component/carrier) && W.amount == 1 && L.amount == 1, "armor pays exact wool and leather before output")
	qdel(bench)
	qdel(C)
	qdel(W)
	qdel(L)
	qdel(H)

/proc/cloth_ci_crafting()
	var/turf/T = locate(2,1,1)
	var/mob/living/human/handle_ci/cloth_ci/H = new(T)
	H.civilization = "recipe_ci"
	var/obj/item/stack/material/woolcloth/W = new(H, 12, FALSE)
	H.r_hand = W
	var/obj/item/weapon/flint/tool = new(H)
	H.l_hand = tool
	var/datum/stack_recipe/R = recipe_ci_food_recipe(/material/woolcloth, /obj/item/weapon/bedroll/cloth, H.civilization)
	if (R)
		R.time = 0
		W.produce_recipe(R, 1, H)
		cloth_ci_expect(W.amount == 8 && (locate(/obj/item/weapon/bedroll/cloth) in T), "wool constructs ordinary bedroll and pays four")
		W.amount = 3
		W.produce_recipe(R, 1, H)
		cloth_ci_expect(W.amount == 3, "short primary wool pays nothing")
	qdel(W)
	qdel(tool)
	H.l_hand = null
	H.r_hand = null
	shelf_ci_clear()
	// Paintings have a separate three-sheet requirement per batch. Bind mixed
	// hand stacks with the primary wood on the player's tile, like normal craft.
	var/obj/item/stack/material/wood/wood = new(T, 20, FALSE)
	var/obj/item/stack/material/cloth/C = new(H, 2, FALSE)
	W = new(H, 7, FALSE)
	H.l_hand = C
	H.r_hand = W
	R = new("stormy sea", /obj/item/stack/recipe_ci_output, 2, 1, 10)
	var/datum/cloth_recipe_payment/P = new(wood, H, R, 2, 3)
	cloth_ci_expect(P.valid() && P.secondary[C] == 2 && P.secondary[W] == 4, "batch plans six mixed cloth sheets")
	W.amount = 3
	cloth_ci_expect(!P.valid() && wood.amount == 20 && C.amount == 2, "late shortage is atomic")
	W.amount = 7
	var/datum/epoch = persistence_admission_identity
	persistence_admission_identity = new /datum
	cloth_ci_expect(!P.valid(), "crossed persistence admission cancels retained cloth")
	persistence_admission_identity = epoch
	W.forceMove(T)
	cloth_ci_expect(!P.valid(), "moved hand ingredient is not reselected")
	W.forceMove(H)
	H.r_hand = W
	wood.produce_recipe(R, 2, H)
	var/obj/item/stack/recipe_ci_output/result = locate() in T
	cloth_ci_expect(wood.amount == 16 && !C.loc && W.amount == 3 && result && result.amount == 2, "batch commits primary and six mixed sheets before output")
	qdel(wood)
	qdel(W)
	qdel(H)
	shelf_ci_clear()


/proc/cloth_ci_workshops()
	var/turf/T = locate(2,1,1)
	var/mob/living/human/handle_ci/cloth_ci/H = new(T)
	H.civilization = "recipe_ci"
	for (var/path in list(/obj/structure/car_workshop, /obj/structure/car_workshop/rover_bay))
		var/obj/structure/car_workshop/bench = new path(T)
		var/obj/item/stack/material/woolcloth/W = new(H, 7, FALSE)
		H.l_hand = W
		bench.attackby(W, H)
		var/obj/item/stack/material/cloth/C = new(H, 3, FALSE)
		H.l_hand = C
		bench.attackby(C, H)
		cloth_ci_expect(bench.stock["cloth"] == 10 && bench.stock["woolcloth"] == 7, "workshop mixed paid stock [path]")
		var/savefile/F = new("cloth-workshop.sav")
		F["/format_version"] << 2
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		var/ref = map_storage.BuildVarDirectory(F, bench, 1)
		map_storage.clear_bookkeeping()
		var/obj/structure/car_workshop/restored = map_storage.Load_Entry(F, ref, starting_loc = T)
		if (restored) restored.after_load()
		cloth_ci_expect(restored && restored.stock["cloth"] == 10 && restored.stock["woolcloth"] == 7, "workshop saved textile provenance [path]")
		qdel(bench)
		if (restored) restored.unload()
		var/cloth_total = 0
		var/wool_total = 0
		for (var/obj/item/stack/material/S in T)
			if (S.type == /obj/item/stack/material/cloth) cloth_total += S.amount
			if (S.type == /obj/item/stack/material/woolcloth) wool_total += S.amount
		cloth_ci_expect(cloth_total == 3 && wool_total == 7, "workshop refunds actual textile kinds [path]")
		qdel(restored)
		shelf_ci_clear()
	var/obj/structure/car_workshop/legacy = new(T)
	legacy.stock["cloth"] = 4
	legacy.unload()
	var/obj/item/stack/material/cloth/ordinary = locate() in T
	cloth_ci_expect(ordinary && ordinary.amount == 4 && !(locate(/obj/item/stack/material/woolcloth) in T), "old workshop ledger refunds ordinary cloth")
	qdel(legacy)
	shelf_ci_clear()
	var/datum/extraction_equipment_codec/codec = new
	var/obj/item/stack/material/woolcloth/original = new(H, 4, FALSE)
	var/list/record = codec.encode(original)
	cloth_ci_expect(record && codec.validate(record), "private workshop codec admits exact wool type")
	var/obj/item/stack/material/woolcloth/decoded = codec.decode(record, T)
	cloth_ci_expect(decoded && decoded.type == original.type && decoded.get_material_name() == "woolcloth" && decoded.amount == 4, "private workshop restore preserves wool identity and units")
	qdel(original)
	qdel(decoded)
	qdel(H)

// Execute the actual production wait, then invalidate the exact retained input.
/datum/cloth_ci_interrupt
	var/obj/item/stack/ingredient
	// Do not merge with stacks left on the other fixture tile.
	var/obj/destination
	proc/change()
		sleep(1)
		ingredient.forceMove(destination)

/proc/cloth_ci_supplements()
	var/turf/T = locate(2,1,1)
	var/mob/living/human/handle_ci/cloth_ci/H = new(T)
	H.civilization = "recipe_ci"
	for (var/title in list("doge hat", "doge outfit", "fiendish headdress", "purple arabic turban helmet", "emirate turban", "plague doctor mask"))
		var/path = /obj/item/stack/material/gold
		var/cost = 1
		if (title == "fiendish headdress")
			path = /obj/item/stack/material/bone
			cost = 2
		else if (findtext(title, "turban"))
			path = /obj/item/stack/material/iron
			cost = 3
		else if (title == "plague doctor mask")
			path = /obj/item/stack/medical/advanced/herbs
			cost = 2
		var/obj/item/stack/material/woolcloth/W = new(H, 20, FALSE)
		H.r_hand = W
		var/obj/item/stack/extra = new path(H, 10, FALSE)
		H.l_hand = extra
		var/datum/stack_recipe/R = new(title, /obj/item/stack/recipe_ci_output, 4, 1, 10)
		W.produce_recipe(R, 2, H)
		cloth_ci_expect(W.amount == 12 && extra.amount == 10 - cost * 2, "batched cloth supplemental payment [title]")
		shelf_ci_clear()
		var/datum/cloth_ci_interrupt/interruption = new
		interruption.ingredient = extra
		interruption.destination = new /obj(locate(1,1,1))
		R.time = 40 // Skill adapters divide this to five ticks.
		var/datum/callback/change = CALLBACK(interruption, TYPE_PROC_REF(/datum/cloth_ci_interrupt, change))
		change.InvokeAsync()
		W.produce_recipe(R, 1, H)
		cloth_ci_expect(W.amount == 12 && extra.amount == 10 - cost * 2 && !(locate(/obj/item/stack/recipe_ci_output) in T), "late moved supplemental stock pays nothing [title]")
		qdel(W)
		qdel(extra)
		qdel(interruption.destination)
	qdel(H)
	shelf_ci_clear()


/proc/cloth_ci_medical_gate()
	var/turf/T = locate(2,1,1)
	var/mob/living/human/handle_ci/cloth_ci/H = new(T)
	H.civilization = "recipe_ci"
	for (var/title in list("plague doctor mask", "plague doctor suit", "plague doctor hat"))
		var/obj/item/stack/material/woolcloth/W = new(H, 8, FALSE)
		H.r_hand = W
		var/obj/item/stack/medical/advanced/herbs/herbs
		if (title == "plague doctor mask")
			herbs = new(H, 2, FALSE)
			H.l_hand = herbs
		else
			H.l_hand = new /obj/item/weapon/flint(H)
		var/datum/stack_recipe/R = new(title, /obj/item/stack/recipe_ci_output, 4, 1, 10)
		H.medical_skill = 0
		W.produce_recipe(R, 1, H)
		cloth_ci_expect(W.amount == 8 && (!herbs || herbs.amount == 2) && !(locate(/obj/item/stack/recipe_ci_output) in T), "medical skill gate retained [title]")
		H.medical_skill = 2
		W.produce_recipe(R, 1, H)
		cloth_ci_expect(W.amount == 4 && (!herbs || !herbs.loc) && (locate(/obj/item/stack/recipe_ci_output) in T), "only mask requires herbs [title]")
		if (H.l_hand) qdel(H.l_hand)
		qdel(W)
		shelf_ci_clear()
	qdel(H)

/proc/cloth_ci_helmets()
	var/turf/T = locate(2,1,1)
	var/mob/living/human/handle_ci/cloth_ci/H = new(T)
	for (var/base in list(/obj/item/clothing/head/helmet/medieval/nomads/templar, /obj/item/clothing/head/helmet/medieval/baltic))
		var/obj/item/helmet = new base(T)
		var/obj/item/stack/material/woolcloth/W = new(H, 2, FALSE)
		H.l_hand = W
		helmet.attackby(W,H)
		cloth_ci_expect(helmet.loc == T && W.amount == 2, "helmet refuses fewer than three cloth sheets [base]")
		W.amount = 4
		helmet.attackby(W,H)
		var/result_type = base == /obj/item/clothing/head/helmet/medieval/baltic ? /obj/item/clothing/head/helmet/medieval/baltic_priest : /obj/item/clothing/head/helmet/medieval/priest
		cloth_ci_expect(!helmet.loc && W.amount == 1 && (locate(result_type) in T), "helmet wool priest conversion [base]")
		qdel(W)
		shelf_ci_clear()
		helmet = new base(T)
		var/metal_type = base == /obj/item/clothing/head/helmet/medieval/baltic ? /obj/item/stack/material/silver : /obj/item/stack/material/gold
		var/obj/item/stack/metal = new metal_type(H, 15, FALSE)
		H.l_hand = metal
		helmet.attackby(metal,H)
		result_type = base == /obj/item/clothing/head/helmet/medieval/baltic ? /obj/item/clothing/head/helmet/medieval/grandmaster : /obj/item/clothing/head/helmet/medieval/crusaderking
		cloth_ci_expect(!helmet.loc && metal.amount == (metal_type == /obj/item/stack/material/silver ? 10 : 5) && (locate(result_type) in T), "helmet existing metal conversion retained [base]")
		qdel(metal)
		shelf_ci_clear()
	qdel(H)

/proc/recipe_ci_cloth_substitution()
	map.ordinal_age = 0
	cloth_ci_catalog()
	cloth_ci_stock()
	cloth_ci_projects()
	cloth_ci_armor()
	cloth_ci_workshops()
	cloth_ci_crafting()
	cloth_ci_supplements()
	cloth_ci_medical_gate()
	cloth_ci_helmets()
/proc/run_cloth_checks()
	cloth_ci_setup()
	recipe_ci_cloth_substitution()
	var/report = "Checked [cloth_ci_assertions] cloth substitution assertions.\n"
	for (var/error in recipe_ci_errors) report += "FAIL [error]\n"
	report += recipe_ci_errors.len ? "FAIL\n" : "PASS\n"
	text2file(report, "recipe-checks.txt")
	del(world)
