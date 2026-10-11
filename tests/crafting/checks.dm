// Compiled with all game definitions, no map or normal world/global-init startup.
// Catalog outputs are inspected as types; only explicit isolated fixture adapters are constructed.
/world
	hub = ""
	hub_password = ""
	maxx = 1
	maxy = 1
	maxz = 1
	turf = /turf
	area = /area

/obj/map_metadata/recipe_ci
	New()
		return

var/list/recipe_ci_errors = list()
var/recipe_ci_count = 0
var/recipe_ci_files = 0

/proc/recipe_ci_fail(context, reason)
	recipe_ci_errors += "[context]: [reason]"

/proc/recipe_ci_positive(value)
	return isnum(value) && value > 0

/proc/recipe_ci_row(list/row, context)
	if (row.len != 13)
		recipe_ci_fail(context, "expected 13 fields, got [row.len]")
		return
	if (!length(row[2]))
		recipe_ci_fail(context, "empty display title")
	var/material_path = text2path(copytext(row[1], 1, length(row[1])))
	if (!ispath(material_path, /material) || row[1] != "[material_path]/")
		recipe_ci_fail(context, "unknown material or missing canonical trailing slash: [row[1]]")
	var/result_path = text2path(row[3])
	if (!ispath(result_path, /obj))
		recipe_ci_fail(context, "output is not an object type: [row[3]]")
	if (!recipe_ci_positive(text2num(row[4])))
		recipe_ci_fail(context, "cost must be positive: [row[4]]")
	for (var/i in list(5,9,10,11))
		var/n = text2num(row[i])
		if (isnull(n) || n < 0)
			recipe_ci_fail(context, "invalid time/research field [i]: [row[i]]")
	for (var/i in list(6,7))
		if (isnull(text2num(row[i])))
			recipe_ci_fail(context, "boolean field [i] must be numeric")
	var/age = text2num(row[12])
	if (isnull(age) || age < 0 || round(age) != age)
		recipe_ci_fail(context, "maximum ordinal age must be a nonnegative integer")
	if (row[13] != "null" && !get_material_by_name(row[13]))
		recipe_ci_fail(context, "unknown supplied material: [row[13]]")

/proc/recipe_ci_flatten(list/recipes)
	var/list/result = list()
	for (var/entry in recipes)
		if (istype(entry, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/group = entry
			result += recipe_ci_flatten(group.recipes)
		else
			result += entry
	return result

/proc/run_recipe_checks()
	populate_material_list()
	map = new /obj/map_metadata/recipe_ci
	map.ordinal_age = 0
	map.resourceresearch = TRUE
	map.chad_mode_plus = TRUE
	build_research_tree()
	for (var/node_id in research_nodes)
		var/list/entry = map.ensure_node_entry("recipe_ci", node_id)
		entry[RNODE_ENTRY_STATUS] = RNODE_DONE
	for (var/filename in flist("config/crafting/"))
		if (!findtext(filename, "material_recipes_"))
			continue
		recipe_ci_files++
		var/file_rows = 0
		var/faction = replacetext(replacetext(filename, "material_recipes_", ""), ".txt", "")
		craftlist_lists[faction] = list()
		var/line_number = 0
		for (var/line in splittext(file2text("config/crafting/[filename]"), "\n"))
			line_number++
			// Same active-line rule as setup_everything; comments are intentionally disabled.
			if (!findtext(line, "RECIPE: ") || findtext(line, "//"))
				continue
			var/list/row = splittext(replacetext(line, "RECIPE: ", ""), ",")
			// file2list() strips CR through dd_file2list; normalize Windows input here.
			row[row.len] = replacetext(row[row.len], ascii2text(13), "")
			var/context = "[filename]:[line_number] ([row.len >= 2 ? row[2] : "unnamed"])"
			var/before = recipe_ci_errors.len
			recipe_ci_row(row, context)
			recipe_ci_count++
			file_rows++
			if (recipe_ci_errors.len != before)
				continue
			// Exercise actual production registration at requirements satisfied and age 0.
			craftlist_lists[faction] = list(row)
			var/material_path = text2path(copytext(row[1], 1, length(row[1])))
			var/material/M = new material_path
			map.ordinal_age = ispath(text2path(row[3]), /obj/item/weapon/gun_mount) ? 6 : (ispath(text2path(row[3]), /obj/item/blackpowder_part/stock) ? 3 : 0)
			M.generate_recipes_civs(list(text2num(row[9]), text2num(row[10]), text2num(row[11])), faction, "recipe_ci")
			map.ordinal_age = 0
			var/found = FALSE
			for (var/datum/stack_recipe/R in recipe_ci_flatten(M.recipes))
				if (R.title == row[2] && R.result_type == text2path(row[3]) && R.req_amount == text2num(row[4]))
					found = TRUE
			if (!found)
				recipe_ci_fail(context, "not registered with requirements and special modes enabled")
		if (!file_rows)
			recipe_ci_fail(filename, "no active recipes were enumerated")
	if (!recipe_ci_files || !anvil_recipes.len)
		recipe_ci_fail("catalog", "material files or anvil registry missing")
	for (var/title in anvil_recipes)
		var/list/row = anvil_recipes[title]
		recipe_ci_count++
		var/context = "anvil: [title]"
		if (row.len != 9)
			recipe_ci_fail(context, "expected 9 fields")
			continue
		if (title != row[1])
			recipe_ci_fail(context, "menu title does not match lookup key")
		if (!ispath(row[9], /obj/item))
			recipe_ci_fail(context, "invalid output item")
		if (row[3] < 0 || row[4] > 8 || row[3] > row[4])
			recipe_ci_fail(context, "empty or invalid age window")
		var/alternatives = 0
		for (var/i = 5 to 8)
			if (!isnum(row[i]) || row[i] < 0)
				recipe_ci_fail(context, "invalid material cost in field [i]")
			if (row[i] > 0)
				alternatives++
		if (!alternatives)
			recipe_ci_fail(context, "no material branch can offer this recipe")
	recipe_ci_food_bootstrap()
	recipe_ci_craft_fixture()
	// Negative fixtures must prove errors, without suppressing real catalog failures.
	var/list/catalog_errors = recipe_ci_errors.Copy()
	recipe_ci_errors = list()
	var/list/valid = list("/material/steel/","fixture","/obj/item/stack/material/steel","0.5","0","0","1","group","0","0","0","8","steel")
	recipe_ci_row(valid, "valid inherited output and conditional recipe")
	if (recipe_ci_errors.len)
		catalog_errors += "self-test: valid fixture rejected"
	for (var/i in list(1,2,3,4,5,6,7,9,10,11,12,13))
		var/list/broken = valid.Copy()
		broken[i] = (i in list(4,5,9,10,11,12)) ? "-1" : ""
		recipe_ci_errors = list()
		recipe_ci_row(broken, "negative field [i]")
		if (!recipe_ci_errors.len)
			catalog_errors += "self-test: broken field [i] accepted"
	recipe_ci_errors = list()
	recipe_ci_row(list("malformed"), "negative missing fields")
	if (!recipe_ci_errors.len)
		catalog_errors += "self-test: malformed row accepted"
	recipe_ci_errors = catalog_errors
	var/report = "Checked [recipe_ci_count] material/anvil rows; production material registration, food bootstrap research/material gates, actual crafting fixture and 13 negative fixtures.\n"
	for (var/error in recipe_ci_errors)
		report += "FAIL [error]\n"
	report += recipe_ci_errors.len ? "FAIL\n" : "PASS\n"
	text2file(report, "recipe-checks.txt")
	del(world)










// Actual production produce_recipe/use/can_use calls, with isolated constructors
// and fingerprint/religion adapters. This proves the generic mechanism only.
/mob/living/human/recipe_ci
	New()
		return
	religion_check()
		return "none"

/obj/item/stack/recipe_ci_input
	amount = 10
	max_amount = 10
	New()
		return

/obj/item/stack/recipe_ci_output
	max_amount = 10
	New()
		return
	update_icon()
		return
	add_fingerprint(mob/living/M, ignoregloves = FALSE)
		return

/proc/recipe_ci_craft_fixture()
	var/turf/T = locate(1,1,1)
	var/mob/living/human/recipe_ci/H = new(T)
	var/obj/item/stack/recipe_ci_input/S = new(T)
	var/datum/stack_recipe/R = new("CI fixture", /obj/item/stack/recipe_ci_output, 2, 3, 9)
	S.produce_recipe(R, 1, H)
	var/obj/item/stack/recipe_ci_output/O = locate() in T
	if (!O || O.amount != 3 || S.amount != 8)
		recipe_ci_fail("craft fixture", "satisfied inputs did not consume 2 and produce 3")
	R.req_amount = 20
	S.produce_recipe(R, 1, H)
	var/outputs = 0
	for (var/obj/item/stack/recipe_ci_output/item in T)
		outputs++
	if (outputs != 1 || S.amount != 8)
		recipe_ci_fail("craft fixture", "insufficient inputs were accepted")
	R.req_amount = 2
	R.one_per_turf = TRUE
	S.produce_recipe(R, 1, H)
	if (S.amount != 8)
		recipe_ci_fail("craft fixture", "occupied turf was accepted")

// Check the food route with an unresearched Stone Age faction, separately from
// the catalog's all-nodes-DONE fixture. This does not simulate resource gathering.
/proc/recipe_ci_food_recipe(material_path, result_path, faction)
	var/material/M = new material_path
	M.generate_recipes_civs(list(0,0,0), "global", faction)
	for (var/datum/stack_recipe/R in recipe_ci_flatten(M.recipes))
		if (R.result_type == result_path)
			return R
	return null

/proc/recipe_ci_food_expect(condition, reason)
	if (!condition)
		recipe_ci_fail("food bootstrap", reason)

/proc/recipe_ci_food_bootstrap()
	// Reload every real global row; the catalog loop above tests one row at a time.
	craftlist_lists["global"] = list()
	for (var/line in file2list("config/crafting/material_recipes_global.txt", "\n"))
		if (findtext(line, "RECIPE: ") && !findtext(line, "//"))
			craftlist_lists["global"] += list(splittext(replacetext(line, "RECIPE: ", ""), ","))
	map.ordinal_age = 0
	map.resourceresearch = FALSE
	map.chad_mode_plus = FALSE
	var/faction = "food_bootstrap_ci"
	map.faction_baseline_era[faction] = 0
	var/datum/stack_recipe/R = recipe_ci_food_recipe(/material/wood, /obj/item/weapon/material/kitchen/utensil/knife/wood, faction)
	recipe_ci_food_expect(R && R.req_amount == 2, "raw logs offer the two-log wooden knife")
	R = recipe_ci_food_recipe(/material/stone, /obj/item/weapon/material/hatchet/tribal, faction)
	recipe_ci_food_expect(R && R.req_amount == 2, "Stone Age offers the two-stone hatchet")
	R = recipe_ci_food_recipe(/material/wood/soft, /obj/structure/research_bench, faction)
	recipe_ci_food_expect(R && R.req_amount == 8, "eight planks offer the starter research bench")
	recipe_ci_food_expect(!recipe_ci_food_recipe(/material/wood/soft, /obj/item/weapon/plough, faction), "plough stays locked before Basic Agriculture")
	var/datum/research_node/N = get_research_node("basic_agriculture")
	recipe_ci_food_expect(N && N.cost_ticks == 95 && N.min_bench_tier == 0 && !N.prereqs.len, "Basic Agriculture has a reachable starter-bench contract")
	var/obj/structure/research_bench/B = new(locate(1,1,1))
	B.faction = faction
	recipe_ci_food_expect(B.can_assign_node("basic_agriculture"), "tier-zero bench can select Basic Agriculture")
	recipe_ci_food_expect(!map.add_research_ticks(faction, "irrigation", 165) && !map.get_node_entry(faction, "irrigation"), "irrigation rejects study before its prerequisite")
	// Feed earned-tick accounting directly. No connected researcher or scheduler
	// is simulated, and no DONE status is written by this fixture.
	recipe_ci_food_expect(!map.add_research_ticks(faction, "basic_agriculture", 94), "94 study ticks do not finish Basic Agriculture")
	recipe_ci_food_expect(!recipe_ci_food_recipe(/material/wood/soft, /obj/item/weapon/plough, faction), "incomplete study keeps the plough locked")
	recipe_ci_food_expect(map.add_research_ticks(faction, "basic_agriculture", 1), "the 95th study tick completes Basic Agriculture")
	R = recipe_ci_food_recipe(/material/wood/soft, /obj/item/weapon/plough, faction)
	recipe_ci_food_expect(R && R.req_amount == 4, "completed study offers the four-plank plough")
	recipe_ci_food_expect(!recipe_ci_food_recipe(/material/wood, /obj/item/weapon/plough, faction), "raw logs do not substitute for planks")
	recipe_ci_food_expect(!B.can_assign_node("irrigation"), "starter bench cannot select tier-one irrigation")
	B.tier = 1
	recipe_ci_food_expect(B.can_assign_node("irrigation"), "tier-one bench can select irrigation after Basic Agriculture")
	map.ordinal_age = 8
	recipe_ci_food_expect(!map.is_node_done(faction, "irrigation") && !map.is_node_done(null, "irrigation"), "Modern era does not grant specialist irrigation")
	map.ordinal_age = 1
	recipe_ci_food_expect(map.is_node_done(null, "basic_agriculture"), "Bronze factionless baseline grants Basic Agriculture")
	var/new_faction = "food_bootstrap_frozen_ci"
	map.faction_baseline_era[new_faction] = 0
	recipe_ci_food_expect(!map.is_node_done(new_faction, "basic_agriculture"), "world era advancement does not grant an established Stone Age faction the plough")
	map.ordinal_age = 0
	qdel(B)
