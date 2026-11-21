// Native probe of code/game/mob/language/drift.dm and daughter.dm,
// included by tests/ecology_spawning/run_linux.py, never by the game DME:
//   python3 tests/ecology_spawning/run_linux.py . tests/language_drift/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 5
	maxy = 5
	maxz = 1
	turf = /turf/floor/plating
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/client/New()
	del(src)
	return
/obj/map_metadata/drift_probe/New()
	map = src
/mob/living/human/drift_tester/New()
	languages = list()
	partial_languages = list()
	return
var/drift_failures = 0
var/drift_runtime_error = FALSE
/proc/drift_check(condition, label)
	if (!condition)
		drift_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	drift_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/drift_speaker(nation, datum/language/L)
	var/mob/living/human/drift_tester/H = new
	H.civilization = nation
	H.default_language = L
	H.languages += L
	H.partial_languages[L.name] = L.difficulty
	living_mob_list += H
	human_mob_list += H
	return H

/proc/drift_hear(mob/living/human/listener, mob/living/human/speaker, datum/language/L, times)
	for (var/i in 1 to times)
		listener.next_language_drift_heard = -1
		listener.language_drift_heard(L, speaker)

/world/New()
	OpenPort("none")
	try
		new /obj/map_metadata/drift_probe
		for (var/T in typesof(/datum/language) - /datum/language - /datum/language/daughter)
			var/datum/language/L = new T
			all_languages[L.name] = L
		symmetrize_language_kinship()
		for (var/lname in all_languages)
			var/datum/language/L = all_languages[lname]
			if (!(L.flags & NONGLOBAL))
				language_keys[lowertext(L.key)] = L
		var/datum/language/latin = all_languages["Latin"]
		var/datum/language/italian = all_languages["Italian"]
		drift_check(latin && italian && !all_languages["a daughter language"], "built-in languages load and the daughter type is not one")
		next_language_drift_tick = world.time + 100000

		var/list/pact = list()
		for (var/i in 1 to 5)
			pact += drift_speaker("Iron Pact", latin)
		var/mob/living/human/A = pact[1]
		var/mob/living/human/B = pact[2]
		var/mob/living/human/outsider = drift_speaker("Sea Folk", latin)
		var/mob/living/human/learner = drift_speaker("Sea Folk", italian)
		var/key = language_community_key("Iron Pact", latin)

		// Drift from heard lines.
		drift_hear(A, B, latin, 12)
		drift_check(language_drift_use[key] == 12 && !language_drift_contact[key], "lines from the same nation count as use")
		drift_hear(A, learner, latin, 5)
		drift_check(!language_drift_contact[key], "a speaker who barely knows the language is no contact")
		A.next_language_drift_heard = -1
		A.language_drift_heard(latin, B)
		A.language_drift_heard(latin, B)
		drift_check(language_drift_use[key] == 13, "one listener counts at most one line per cooldown")
		language_drift_tick()
		drift_check(language_drift(key) == LANGUAGE_DRIFT_GAIN, "an isolated community gains the full step")
		drift_check(!language_drift_use.len && !language_drift_contact.len, "heard lines reset each tick")
		drift_hear(A, B, latin, 5)
		drift_hear(A, outsider, latin, 15)
		language_drift_tick()
		drift_check(language_drift(key) == LANGUAGE_DRIFT_GAIN / 2, "mostly outside contact pulls drift back")
		drift_hear(A, B, latin, 5)
		language_drift_tick()
		drift_check(language_drift(key) == LANGUAGE_DRIFT_GAIN / 2, "a quiet community does not change")
		set_language_drift(key, 0)
		drift_check(!(key in language_drift_table()), "a community back at nothing is forgotten")
		var/mob/living/human/nomad = drift_speaker("none", latin)
		drift_hear(nomad, B, latin, 20)
		drift_check(!language_drift_use.len, "a nationless listener belongs to no community")
		language_drift_use = list()

		// The era check.
		set_language_drift(key, 70)
		map.ordinal_age = 3
		drift_check(language_era_advanced() == 1 && (key in language_lineage_part("pending")), "a drifted community with five natives is ready at the era change")
		drift_check(language_era_advanced() == 0, "a waiting community is not counted twice")
		var/sea_key = language_community_key("Sea Folk", latin)
		set_language_drift(sea_key, 90)
		language_era_advanced()
		drift_check(!(sea_key in language_lineage_part("pending")), "too few natives cannot split")
		drift_check(findtext(jointext(language_drift_report(), "\n"), "waiting for its leader to name it"), "the admin view shows the waiting split")

		// Names.
		drift_check(language_name_problem("Latin") && language_name_problem("latin") && language_name_problem("Ab") && language_name_problem("Rom4n") && !language_name_problem("Vulgar"), "names must be new, 3 to 24 letters")
		drift_check(isnull(split_language(sea_key, "Seaspeak")), "only a waiting community can split")

		// The split.
		var/datum/language/daughter/D = split_language(key, "Vulgar")
		drift_check(istype(D) && all_languages["Vulgar"] == D && D.parent_name == "Latin" && D.root_name == "Latin" && D.nation == "Iron Pact", "naming makes the daughter")
		drift_check(!(key in language_lineage_part("pending")) && !language_drift(key), "the split clears the wait and the drift")
		drift_check(D.key && language_keys[D.key] == D && D.key != latin.key, "the daughter gets its own say key")
		drift_check(D.syllables && D.syllables.len == latin.syllables.len && jointext(D.syllables, "") != jointext(latin.syllables, ""), "the daughter's sounds are changed from its parent's")
		var/all_natives = TRUE
		for (var/mob/living/human/H in pact)
			if (!H.knows_language(D) || !H.knows_language(latin) || H.mother_tongue() != D || H.default_language != D || H.language_score(D) < 99)
				all_natives = FALSE
		drift_check(all_natives, "natives speak the daughter fluently, by default and as mother tongue, and keep the parent")
		drift_check(!outsider.knows_language(D) && outsider.mother_tongue() == latin, "outsiders do not get the daughter")
		drift_check(language_kinship(D, latin) == LANGUAGE_DAUGHTER_KIN && language_kinship(latin, D) == LANGUAGE_DAUGHTER_KIN, "parent and daughter follow each other at the split")
		drift_check(language_kinship(D, italian) == round(language_kinship(latin, italian) * LANGUAGE_DAUGHTER_KIN / 100) && language_kinship(italian, D) == language_kinship(D, italian), "the parent's relatives follow the daughter a little less")
		drift_check(outsider.get_mutual_intelligibility(D) == LANGUAGE_DAUGHTER_KIN, "a parent speaker understands most of the daughter")
		drift_check(language_root(D) == latin && language_same(D, D) && !language_same(D, latin), "daughters are told apart by name")

		// Restored copies.
		var/datum/language/daughter/copy = new
		copy.name = "Vulgar"
		drift_check(canonical_language(copy) == D && A.knows_language(copy), "a restored copy maps to the registered daughter")
		var/datum/language/daughter/stranger = new
		stranger.name = "Nowhere Tongue"
		drift_check(canonical_language(stranger) == stranger && !A.knows_language(stranger), "an unknown daughter is never another daughter")

		// Writing.
		var/mob/living/human/young = drift_speaker("Iron Pact", D)
		young.native_tongue = D.name
		drift_check(paper_knows_written_language(young, "civ13:latin:v1") && !paper_knows_written_language(young, "civ13:italian:v1"), "a daughter writes in its root's script")

		// The cap, and sisters.
		var/list/second = list()
		for (var/i in 1 to 5)
			second += drift_speaker("Hill Clans", latin)
		var/hill_key = language_community_key("Hill Clans", latin)
		set_language_drift(hill_key, 80)
		language_era_advanced()
		var/datum/language/sister = split_language(hill_key, "Highland")
		drift_check(istype(sister) && language_kinship(sister, D) >= LANGUAGE_DAUGHTER_KIN - LANGUAGE_DAUGHTER_KIN_STEP * 2 && language_kinship(sister, D) < LANGUAGE_DAUGHTER_KIN, "a second daughter of the same root is a sister")
		for (var/i in 1 to 5)
			drift_speaker("Marsh Folk", latin)
		var/marsh_key = language_community_key("Marsh Folk", latin)
		set_language_drift(marsh_key, 80)
		language_era_advanced()
		drift_check(!(marsh_key in language_lineage_part("pending")) && language_daughter_count(latin) == LANGUAGE_DAUGHTERS_PER_ROOT, "a root has at most its share of daughters")

		// A daughter that drifts again grows further from its parent.
		var/vulgar_key = language_community_key("Iron Pact", D)
		set_language_drift(vulgar_key, 70)
		language_era_advanced()
		drift_check(language_kinship(D, latin) == LANGUAGE_DAUGHTER_KIN - LANGUAGE_DAUGHTER_KIN_STEP && language_drift(vulgar_key) == 35 && !(vulgar_key in language_lineage_part("pending")), "a drifted daughter loses kinship instead of splitting")

		// The family view in Check Known Languages.
		var/list/families = A.language_family_rows()
		var/list/family = families.len == 1 ? families[1] : null
		var/list/member_names = list()
		if (family)
			for (var/list/member in family["members"])
				member_names += member["name"]
		drift_check(family && family["root"] == "Latin" && ("Vulgar" in member_names) && ("Highland" in member_names), "the family view lists the root and its daughters")
		var/mother_marked = FALSE
		if (family)
			for (var/list/member in family["members"])
				if (member["name"] == "Vulgar" && member["mother"])
					mother_marked = TRUE
		drift_check(mother_marked, "the family view marks the mother tongue")
		drift_check(!length(learner.language_family_rows()), "someone outside the family sees none")

		// Saved records restore the same language.
		var/old_key = D.key
		var/old_sounds = jointext(D.syllables, "|")
		all_languages -= "Vulgar"
		language_keys -= old_key
		ensure_daughter_languages()
		var/datum/language/daughter/R = all_languages["Vulgar"]
		drift_check(istype(R) && R.key == old_key && jointext(R.syllables, "|") == old_sounds && language_kinship(R, latin) == LANGUAGE_DAUGHTER_KIN - LANGUAGE_DAUGHTER_KIN_STEP, "a saved daughter restores with its key, sounds and kinship")

		// Renaming and merging back (daughter_admin.dm).
		var/mob/living/human/hill = second[1]
		var/hill_drift_key = language_community_key("Hill Clans", sister)
		set_language_drift(hill_drift_key, 12)
		hill.language_gain_today = list("lesson:Highland" = 4)
		drift_check(isnull(rename_daughter_language("Highland", "Latin")), "a rename needs a free name")
		drift_check(rename_daughter_language("Highland", "Upland") == 5, "a rename reaches every speaker")
		drift_check(!all_languages["Highland"] && all_languages["Upland"] == sister && sister.name == "Upland", "the language answers to its new name")
		drift_check(hill.partial_languages["Upland"] && isnull(hill.partial_languages["Highland"]) && hill.native_tongue == "Upland" && hill.knows_language(sister) && hill.language_gain_today["lesson:Upland"] == 4, "speakers keep their scores, mother tongue and today's learning")
		drift_check(language_kinship(latin, sister) && !("Highland" in latin.mutual_intelligibility) && language_drift(language_community_key("Hill Clans", sister)) == 12 && islist(language_lineage_part("daughters")["Upland"]), "kinship, drift and the record move to the new name")
		var/sister_key = sister.key
		drift_check(merge_daughter_language("Upland") == 5, "merging back reaches every speaker")
		drift_check(!all_languages["Upland"] && !language_keys[sister_key] && !(("Upland") in language_lineage_part("daughters")) && !("Upland" in latin.mutual_intelligibility), "the merged language is forgotten")
		drift_check(!hill.knows_language(sister) && hill.knows_language(latin) && hill.mother_tongue() == latin && hill.default_language == latin && isnull(hill.native_tongue), "its speakers speak the parent again")
		drift_check(language_daughter_count(latin) == 1 && !language_drift(language_community_key("Hill Clans", sister)), "the split no longer counts")

		// Travel to a land that never heard of it.
		var/list/T = A.region_travel_tongues()
		drift_check(islist(T["daughters"]) && ("Vulgar" in T["daughters"]) && T["native"] == "Vulgar", "a traveller carries the daughter's record")
		drift_check(region_travel_tongues_valid(T), "the record validates where the daughter is known")
		all_languages -= "Vulgar"
		language_keys -= R.key
		var/list/records = language_lineage_part("daughters")
		records -= "Vulgar"
		drift_check(region_travel_tongues_valid(T), "and where it is not")
		var/mob/living/human/arrival = drift_speaker("none", italian)
		drift_check(arrival.region_travel_restore_tongues(T) && arrival.knows_language(all_languages["Vulgar"]) && arrival.mother_tongue() == all_languages["Vulgar"], "the arrival speaks the daughter as their mother tongue")
		var/list/imported = records["Vulgar"]
		drift_check(islist(imported) && imported["imported"] && language_daughter_count(latin) == 0, "an imported daughter is saved but does not count towards the cap")
		var/list/bad = T.Copy()
		var/list/bad_daughters = list("Vulgar" = list("parent" = "Latin", "root" = "Klingon", "nation" = "x", "era" = 1, "kin" = 80))
		bad["daughters"] = bad_daughters
		all_languages -= "Vulgar"
		drift_check(!region_travel_tongues_valid(bad), "a daughter of an unknown root refuses the trip")
	catch(var/exception/e)
		drift_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = drift_failures, "runtime_error" = drift_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
