// Native probe: birth charts (code/game/mob/living/carbon/human/birth_charts.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/character_traits/birth_chart_probe.dm
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
/obj/map_metadata/bc_probe/New()
	return
/mob/living/human/bc_probe/New()
	return
/mob/living/human/bc_probe/update_icons()
	return

var/bc_failures = 0
var/bc_runtime_error = FALSE
/proc/bc_check(condition, label)
	if (!condition)
		bc_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	bc_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/bc_probe
		birth_chart_checks()
	catch(var/exception/e)
		bc_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = bc_failures, "runtime_error" = bc_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/bc_human(gender = MALE, age = 22)
	var/mob/living/human/bc_probe/H = new(locate(1, 1, 1))
	H.stat = CONSCIOUS
	H.gender = gender
	H.age = age
	return H

/proc/birth_chart_checks()
	// The catalog: twelve signs, each +10/+5/+5 and -10/-5/-5, zero sum.
	bc_check(birth_chart_signs.len == 12, "twelve signs")
	var/list/totals = list()
	for (var/sign_id in birth_chart_signs)
		var/list/offsets = birth_chart_signs[sign_id]["stats"]
		var/sum = 0
		var/list/sizes = list()
		var/known = TRUE
		for (var/statname in offsets)
			sum += offsets[statname]
			sizes += offsets[statname]
			totals[statname] = (totals[statname] || 0) + offsets[statname]
			if (!(statname in birth_chart_stats))
				known = FALSE
		bc_check(sum == 0, "[sign_id] nets to zero")
		bc_check(offsets.len == 6 && (10 in sizes) && (-10 in sizes), "[sign_id] has three strengths and three weaknesses")
		bc_check(known, "[sign_id] only uses chart stats")
		bc_check(istext(birth_chart_summary(sign_id)), "[sign_id] has a summary")
	var/worst = 0
	for (var/statname in totals)
		worst = max(worst, abs(totals[statname]))
	bc_check(worst <= 10, "no stat favoured by more than 10 points across all signs")
	bc_check(!("magic" in birth_chart_stats) && !("machinegun" in birth_chart_stats), "hidden and machinegun stats are never charted")

	// Applying a named sign sets the lean, keeps the sign and leaves other stats alone.
	var/mob/living/human/O = bc_human()
	O.stats["machinegun"] = list(137, 137)
	bc_check(O.apply_birth_chart("owl") == "owl" && O.birth_chart == "owl", "named sign is kept")
	bc_check(O.stats["philosophy"][1] >= 105 && O.stats["philosophy"][1] <= 116, "owl: philosophy about 110")
	bc_check(O.stats["strength"][1] >= 85 && O.stats["strength"][1] <= 96, "owl: strength about 90")
	bc_check(O.stats["machinegun"][1] == 137, "unlisted stats untouched")
	bc_check(O.stats["philosophy"][1] == O.stats["philosophy"][2], "current and max match")

	// Unknown or missing signs roll a real one; all results stay in range.
	var/in_range = TRUE
	var/list/seen = list()
	for (var/i in 1 to 300)
		var/mob/living/human/R = bc_human(pick(MALE, FEMALE), rand(16, 70))
		var/sign = R.apply_birth_chart(i % 2 ? null : "not a sign")
		seen[sign] = TRUE
		for (var/statname in birth_chart_stats)
			var/value = R.stats[statname][1]
			if (value < BIRTH_CHART_STAT_MIN || value > BIRTH_CHART_STAT_MAX)
				in_range = FALSE
		qdel(R)
	bc_check(in_range, "starting stats stay within the clamp")
	bc_check(seen.len == 12, "every sign can be rolled")

	// A character from before charts gets a sign without any stat change.
	var/mob/living/human/L = bc_human()
	L.stats["crafting"] = list(173, 180)
	L.ensure_birth_chart()
	bc_check(birth_chart_valid(L.birth_chart), "legacy character gets a sign")
	bc_check(L.stats["crafting"][1] == 173 && L.stats["crafting"][2] == 180, "legacy stats unchanged")
	var/kept = L.birth_chart
	L.ensure_birth_chart()
	bc_check(L.birth_chart == kept, "a sign is never rerolled")

	// A sign chosen in Character Setup is used once at spawn; a roll otherwise.
	var/mob/living/human/W = bc_human()
	W.birth_chart_wish = "anvil"
	bc_check(W.apply_birth_chart() == "anvil" && W.birth_chart_wish == null, "chosen sign is used and consumed")
	var/mob/living/human/X = bc_human()
	X.birth_chart_wish = "not a sign"
	bc_check(birth_chart_valid(X.apply_birth_chart()), "a bad chosen sign rolls instead")

	// Choosing fails closed without a verified client.
	bc_check(!birth_chart_choice_allowed(null, "owl"), "no client: no choice")
	var/datum/preferences/P = new
	bc_check(P.birth_chart == "random", "preference defaults to the stars")
	P.setup_birth_chart("owl", null)
	bc_check(P.birth_chart == "random" && findtext(P.setup_notice, "Verify"), "unverified choice refused with a reason")
	P.birth_chart = "owl"
	P.setup_birth_chart("random", null)
	bc_check(P.birth_chart == "random", "anyone may go back to the stars")
	P.setup_birth_chart("not a sign", null)
	bc_check(P.birth_chart == "random", "unknown signs ignored")
	var/list/D = P.birth_chart_setup_data(null)
	bc_check(D["choice"] == "random" && D["verified"] == 0 && length(D["signs"]) == 12, "setup data lists all twelve signs")

	// The calling: +10 stat trains 5% faster, -10 stat 5% slower, never on top of a trait.
	var/mob/living/human/C = bc_human()
	C.traits = list()
	C.traits_dirty = TRUE
	C.birth_chart = "owl"
	bc_check(C.trait_skill_gain_mult("philosophy") == BIRTH_CHART_CALLING_FAST, "owl: philosophy trains faster")
	bc_check(C.trait_skill_gain_mult("strength") == BIRTH_CHART_CALLING_SLOW, "owl: strength trains slower")
	bc_check(C.trait_skill_gain_mult("medical") == 1, "owl: +5 stats train as usual")
	C.traits = list("Quick Learner")
	C.traits_dirty = TRUE
	bc_check(C.trait_skill_gain_mult("philosophy") == 1.15, "Quick Learner replaces the calling, never stacks")
	var/mob/living/human/G = bc_human()
	G.birth_chart = "hearth"
	G.traits = list("Green Thumb")
	G.traits_dirty = TRUE
	bc_check(G.trait_skill_gain_mult("farming") == PLAYSTYLE_FAST_SKILL, "Green Thumb farming: trait only")
	bc_check(G.trait_skill_gain_mult("hunting") == PLAYSTYLE_SLOW_SKILL, "Green Thumb hunting: trait only")
	G.birth_chart = "owl"
	bc_check(G.trait_skill_gain_mult("philosophy") == BIRTH_CHART_CALLING_FAST, "calling still applies where the trait is silent")
	var/mob/living/human/N = bc_human()
	N.traits = list()
	N.traits_dirty = TRUE
	bc_check(N.trait_skill_gain_mult("philosophy") == 1, "no sign: no calling")
