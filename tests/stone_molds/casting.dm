// Focused native entry point. No metal contents/capacity/icon states are seeded.
// Only the client numeric prompt is replaced in a temporary production include.
var/list/stone_casting_ci_cases = list()
var/list/stone_casting_ci_sprites = list()

/mob/living/human/handle_ci/stone_casting_ci
	var/transfer_amount = 1
	var/transfer_prompts = 0

/mob/living/human/handle_ci/stone_casting_ci/getStatCoeff(statname)
	return 2

/proc/stone_casting_ci_amount(mob/living/human/handle_ci/stone_casting_ci/H, available)
	if (!istype(H))
		recipe_ci_fail("stone casting", "numeric prompt received another actor")
		return null
	H.transfer_prompts++
	return H.transfer_amount

/proc/stone_casting_ci_expect(condition, label)
	stone_casting_ci_cases += list(list("case" = label, "passed" = !!condition))
	if (!condition)
		recipe_ci_fail("stone casting", label)
	return condition

/proc/stone_casting_ci_heads(turf/T)
	var/count = 0
	for (var/obj/item/weapon/material/part/pickaxe/P in T)
		stone_casting_ci_expect(P.get_material_name() == "copper", "cast output retains copper material")
		count++
	return count

/proc/stone_casting_ci_export(obj/item/weapon/clay/mold/M, shape, surface, state)
	var/filename = "stone-casting-[shape]-[surface]-[state].png"
	var/icon/actual = getFlatIcon(M)
	stone_casting_ci_expect(fcopy(actual, filename), "engine PNG export: [shape]/[surface]/[state]")
	stone_casting_ci_sprites += list(list("file" = filename, "shape" = shape, "surface" = surface, "state" = state, "type" = "[M.type]", "icon_state" = M.icon_state, "color" = M.color, "capacity" = M.capacity, "material" = M.current_material))

/proc/stone_casting_ci_body()
	populate_material_list()
	map = new /obj/map_metadata/recipe_ci
	map.ordinal_age = 0
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.name_set_event = new
	GLOB.stat_set_event = new
	var/turf/T = locate(2,1,1)
	var/mob/living/human/handle_ci/stone_casting_ci/H = new(T)
	H.original_job_title = "Blacksmith"
	H.a_intent = I_HELP
	var/obj/structure/furnace/kiln/stone/K = new(T)
	var/obj/structure/anvil/stone/A = new(T)
	var/obj/item/weapon/clay/mold/claypot/fired/V = new(T)
	var/obj/item/stack/ore/copper/ore = new(T, 25, FALSE)
	V.attackby(ore, H)
	if (!stone_casting_ci_expect(ore.amount == 5 && V.contents_materials["copper"] == 20 && V.capacity == 0, "actual pot loading debits twenty ore and respects vessel capacity"))
		return
	K.attackby(V, H)
	stone_casting_ci_expect(V.loc == K, "actual kiln admission retains vessel")
	K.process()
	if (!stone_casting_ci_expect(V.loc == T && V.capacity == 20 && V.current_material == "copper" && !V.contents_materials.len, "actual kiln processing converts charged ore to copper"))
		return
	var/obj/item/weapon/clay/mold/claypot/fired/G = new(T)
	var/obj/item/stack/ore/gold/gold_ore = new(T, 6, FALSE)
	G.attackby(gold_ore, H)
	stone_casting_ci_expect(QDELETED(gold_ore), "actual loading consumes exhausted gold ore stack")
	K.attackby(G, H)
	K.process()
	if (!stone_casting_ci_expect(G.capacity == 6 && G.current_material == "gold", "actual kiln processing produces separate gold charge"))
		return
	var/obj/item/weapon/clay/mold/pickaxe/fired/sandstone/M = new(T)
	M.attackby(V, H)
	stone_casting_ci_expect(M.capacity == 1 && M.current_material == "copper" && V.capacity == 19 && V.current_material == "copper", "production pour moves one copper with matching debit")
	var/prompts_before = H.transfer_prompts
	M.attackby(G, H)
	stone_casting_ci_expect(M.capacity == 1 && M.current_material == "copper" && G.capacity == 6 && G.current_material == "gold" && H.transfer_prompts == prompts_before, "mixed-metal pour rejects before prompting despite free mold space")
	H.transfer_amount = 0
	M.attackby(V, H)
	stone_casting_ci_expect(M.capacity == 1 && V.capacity == 19, "zero transfer preserves source and target")
	H.transfer_amount = 999
	M.attackby(V, H)
	stone_casting_ci_expect(M.capacity == 3 && M.current_material == "copper" && V.capacity == 17 && V.current_material == "copper", "oversized request clamps to two free units and preserves metal")
	prompts_before = H.transfer_prompts
	M.attackby(V, H)
	stone_casting_ci_expect(M.capacity == 3 && V.capacity == 17 && H.transfer_prompts == prompts_before, "full mold refuses further transfer")
	for (var/iteration = 1, iteration <= 2, iteration++)
		A.attackby(M, H)
		stone_casting_ci_expect(stone_casting_ci_heads(T) == iteration && M.capacity == 0 && isnull(M.current_material) && M.icon_state == "pickaxe_mold_empty" && M.stone_mold && !QDELETED(M) && !A.in_use, "actual anvil creates one copper head and preserves reusable empty mold: [iteration]")
		if (iteration == 1)
			H.transfer_amount = 3
			M.attackby(V, H)
			stone_casting_ci_expect(M.capacity == 3 && V.capacity == 14, "same mold refills from remaining production copper")
	var/obj/item/weapon/clay/mold/pickaxe/fired/sandstone/gold_mold = new(T)
	H.transfer_amount = 3
	gold_mold.attackby(G, H)
	A.attackby(gold_mold, H)
	stone_casting_ci_expect(gold_mold.capacity == 3 && gold_mold.current_material == "gold" && G.capacity == 3 && G.current_material == "gold" && stone_casting_ci_heads(T) == 2 && !A.in_use, "stone anvil rejects gold without consuming metal or producing a head")
	// Export actual empty/filled stone and clay appearances for all eight shapes.
	// Both materials are filled and emptied through the same production pour proc.
	var/list/shapes = list("ingot" = /obj/item/weapon/clay/mold/fired, "axehead" = /obj/item/weapon/clay/mold/axehead/fired, "sword" = /obj/item/weapon/clay/mold/sword/fired, "knife" = /obj/item/weapon/clay/mold/knife/fired, "spearhead" = /obj/item/weapon/clay/mold/spearhead/fired, "pickaxe" = /obj/item/weapon/clay/mold/pickaxe/fired, "shovel" = /obj/item/weapon/clay/mold/shovel/fired, "arrowhead" = /obj/item/weapon/clay/mold/arrowhead/fired)
	H.transfer_amount = 1
	for (var/shape in shapes)
		var/clay_type = shapes[shape]
		var/stone_type = text2path("[clay_type]/sandstone")
		var/obj/item/weapon/clay/mold/stone = new stone_type(T)
		var/obj/item/weapon/clay/mold/clay = new clay_type(T)
		stone_casting_ci_export(stone, shape, "stone", "empty")
		stone_casting_ci_export(clay, shape, "clay", "empty")
		stone.attackby(V, H)
		clay.attackby(V, H)
		stone_casting_ci_expect(stone.capacity == 1 && clay.capacity == 1 && stone.current_material == "copper" && clay.current_material == "copper" && V.capacity == 12, "actual pours fill sprite pair: [shape]")
		stone_casting_ci_export(stone, shape, "stone", "full")
		stone_casting_ci_export(clay, shape, "clay", "full")
		V.attackby(stone, H)
		V.attackby(clay, H)
		stone_casting_ci_expect(stone.capacity == 0 && clay.capacity == 0 && isnull(stone.current_material) && isnull(clay.current_material) && V.capacity == 14 && V.current_material == "copper", "sprite charges returned by real pouring without loss: [shape]")
	stone_casting_ci_expect(ore.amount + V.capacity + 3 * stone_casting_ci_heads(T) == 25, "all copper conserved across ore, vessel and two cast outputs")
	stone_casting_ci_expect(G.capacity + gold_mold.capacity == 6, "all gold preserved after rejected casting")

/proc/run_stone_casting_checks()
	stone_casting_ci_body()
	text2file(json_encode(list("cases" = stone_casting_ci_cases, "sprites" = stone_casting_ci_sprites, "limits" = "Headless getFlatIcon/MapColors output; no connected client, scene lighting, fuel cycle or save/load")), "stone-casting-checks.json")
	var/report = "Focused actual ore/pour/anvil path and engine sprite checks.\n"
	for (var/error in recipe_ci_errors)
		report += "FAIL [error]\n"
	report += recipe_ci_errors.len ? "FAIL\n" : "PASS\n"
	text2file(report, "recipe-checks.txt")
	del(world)
