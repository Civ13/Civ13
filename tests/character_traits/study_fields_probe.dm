// Native probe: fields of study, Autistic and ADHD change the numbers they promise.
// Run: python3 tests/ecology_spawning/run_linux.py . tests/character_traits/study_fields_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/ps_probe/New()
	return
/mob/living/human/ps_probe/New()
	return
/mob/living/human/ps_probe/update_icons()
	return

var/ps_failures = 0
var/ps_runtime_error = FALSE
/proc/ps_check(condition, label)
	if (!condition)
		ps_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	ps_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/ps_probe
		sf_checks()
	catch(var/exception/e)
		ps_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = ps_failures, "runtime_error" = ps_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/ps_human(x, y, trait = null)
	var/mob/living/human/ps_probe/H = new(locate(x, y, 1))
	H.stat = CONSCIOUS
	H.traits = trait ? list(trait) : list()
	H.traits_dirty = TRUE
	H.scholarship = list("engineering" = 20, "medicine" = 20, "mathematics" = 20, "military" = 20)
	return H

/proc/sf_near(a, b)
	return abs(a - b) < 0.001

/proc/sf_checks()
	if (!research_nodes || !research_nodes.len)
		build_research_tree()
	var/eng = null
	var/med = null
	for (var/node_id in research_nodes)
		if (!eng && node_discipline(node_id) == "engineering")
			eng = node_id
		if (!med && node_discipline(node_id) == "medicine")
			med = node_id
	ps_check(eng && med, "found an Engineering and a Medicine node")
	var/mob/living/human/plain = ps_human(1, 1)
	var/mob/living/human/P = ps_human(10, 10, "Physician")
	ps_check(P.study_field() == "medicine" && !plain.study_field(), "a Physician focuses on Medicine, nobody else does")
	ps_check(sf_near(P.scholar_research_rate(med), plain.scholar_research_rate(med) * 1.4), "Physician researches Medicine x1.4")
	ps_check(sf_near(P.scholar_research_rate(eng), plain.scholar_research_rate(eng) * 0.9), "Physician researches Engineering x0.9")
	ps_check(P.study_field_research_mult("mathematics") == 1 && P.study_field_gain_mult("mathematics") == 1 && P.study_field_study_mult("mathematics") == 1, "Basic Mathematics is never touched")
	ps_check(P.scholar_study_time(2, med) == plain.scholar_study_time(2, med), "reading in the focus costs nothing extra")
	ps_check(P.scholar_study_time(2, eng) == round(plain.scholar_study_time(2, eng) * 1.15), "reading outside the focus takes 15% longer")
	// Gains: the discipline's own share is scaled, the maths share is not.
	plain.scholarship = list(); P.scholarship = list()
	plain.gain_scholarship(med, 1); P.gain_scholarship(med, 1)
	ps_check(sf_near(P.scholar_level("medicine"), plain.scholar_level("medicine") * 1.25) && sf_near(P.scholar_level("mathematics"), plain.scholar_level("mathematics")), "focus gain x1.25, maths share unchanged")
	plain.scholarship = list(); P.scholarship = list()
	plain.gain_scholarship(eng, 1); P.gain_scholarship(eng, 1)
	ps_check(sf_near(P.scholar_level("engineering"), plain.scholar_level("engineering") * 0.75), "off-focus gain x0.75")
	var/mob/living/human/E = ps_human(5, 5, "Engineer")
	ps_check(sf_near(E.study_field_research_mult("engineering"), 1.1) && sf_near(E.study_field_research_mult("medicine"), 0.9), "Engineer x1.1 in Engineering only")
	// Picking in play: the lock starts, and Tinkerer keeps Engineer off the list.
	E.traits = list("Tinkerer"); E.traits_dirty = TRUE
	ps_check(!("Engineer" in E.study_field_choices()) && ("Physician" in E.study_field_choices()), "Tinkerer can't become an Engineer")
	E.set_study_field("Physician")
	ps_check(E.find_trait("Physician") && E.find_trait("Tinkerer") && E.study_field_wait_text(), "picking a field keeps other traits and starts the wait")
	E.set_study_field("Strategist")
	ps_check(!E.find_trait("Physician") && E.study_field() == "military", "a new field replaces the old one")
	E.set_study_field(null)
	ps_check(!E.study_field(), "a field can be dropped")
	// Autistic.
	var/mob/living/human/A = ps_human(3, 3, "Autistic")
	A.study_interest = "medicine"
	ps_check(A.scholar_study_time(2, med) == round(plain.scholar_study_time(2, med) * 0.8), "special interest reads 20% faster")
	A.last_study_discipline = "medicine"
	ps_check(A.scholar_study_time(2, eng) == round(plain.scholar_study_time(2, eng) * 1.35), "switching discipline costs 35% once")
	A.last_study_discipline = "engineering"
	ps_check(A.scholar_study_time(2, eng) == plain.scholar_study_time(2, eng), "staying in a discipline costs nothing")
	A.traits += "Engineer"; A.traits_dirty = TRUE
	ps_check(A.special_interest() == "engineering", "a field of study becomes the special interest")
	// ADHD.
	ps_check(sf_near(adhd_reading_time(780, 0), 600), "first minute of reading x1.3")
	ps_check(sf_near(adhd_reading_time(1980, 0), 1800), "normal pace to three minutes")
	ps_check(sf_near(adhd_reading_time(2780, 0), 2800), "reading x0.8 after three minutes")
	ps_check(sf_near(adhd_reading_time(100, 2000), 125), "a long sitting stays slow")
	var/mob/living/human/D = ps_human(7, 7, "ADHD")
	ps_check(plain.adhd_begin_reading(1000) == 1000, "no trait reads at the base pace")
	ps_check(D.adhd_begin_reading(780) == 600, "ADHD starts a sitting in a burst")
	ps_check(sf_near(D.adhd_bench_mult(), 1.2) && plain.adhd_bench_mult() == 1, "a fresh bench session runs x1.2")
	D.adhd_bench_start = world.time - 13000
	D.adhd_bench_last = world.time
	ps_check(sf_near(D.adhd_bench_mult(), 0.9), "a long bench session runs x0.9")
	// Trait table: one field only, Tinkerer and Engineer exclude each other.
	ps_check(get_trait_selection_error(list("Engineer", "Physician")) && get_trait_selection_error(list("Engineer", "Tinkerer")) && !get_trait_selection_error(list("Physician", "Autistic", "ADHD", "Recluse Scholar")), "trait choices validate")
	// Trades (trade_traits.dm).
	var/mob/living/human/M = ps_human(12, 12, "Mechanic")
	ps_check(M.trade() == "mechanic" && !plain.trade(), "a Mechanic has the mechanic trade")
	ps_check(trade_time(M, 200, "mechanic") == 120 && trade_time(plain, 200, "mechanic") == 200, "a Mechanic's vehicle work takes 40% less time")
	ps_check(trade_time(M, 200, "smith") == 220 && trade_time(M, 200, null) == 200, "other trades take 10% longer, untagged work is unchanged")
	M.set_trade("Carpenter")
	ps_check(M.trade() == "carpenter" && M.trade_wait_text(), "a new trade replaces the old one and starts the wait")
	M.traits += "Physician"; M.traits_dirty = TRUE
	ps_check(M.trade() == "carpenter" && M.study_field() == "medicine", "a trade and a field of study can be held together")
	var/obj/item/stack/material/wood/wood = new(locate(2, 2, 1))
	var/obj/item/stack/material/leather/leather = new(locate(2, 2, 1))
	var/obj/item/stack/material/iron/iron = new(locate(2, 2, 1))
	ps_check(wood.stack_trade() == "carpenter" && leather.stack_trade() == "tailor" && !iron.stack_trade(), "stack crafting is classed by material")
	ps_check(get_trait_selection_error(list("Mechanic", "Smith")) && !get_trait_selection_error(list("Mechanic", "Physician", "Autistic")), "one trade only, alongside a field")
