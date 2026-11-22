// Native probe of code/game/mob/living/carbon/human/peoples.dm and
// code/modules/admin/verbs/peoples_admin.dm, included by
// tests/ecology_spawning/run_linux.py, never by the game DME:
//   python3 tests/ecology_spawning/run_linux.py . tests/origins/peoples_probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 5
	maxy = 5
	maxz = 2
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
/obj/map_metadata/peoples_probe/New()
	map = src
	ID = MAP_NOMADS_GAIA
	title = "Nomads (Gaia)"
/mob/living/human/peoples_tester/New()
	languages = list()
	partial_languages = list()
	return
var/peoples_failures = 0
var/peoples_runtime_error = FALSE
/proc/peoples_check(condition, label)
	if (!condition)
		peoples_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	peoples_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/peoples_person(origin, land = "Gaia")
	var/mob/living/human/peoples_tester/H = new
	H.origin_id = origin
	H.origin_land = land
	H.stat = CONSCIOUS
	living_mob_list += H
	human_mob_list += H
	return H

/world/New()
	OpenPort("none")
	try
		new /obj/map_metadata/peoples_probe
		for (var/T in typesof(/datum/language) - /datum/language - /datum/language/daughter)
			var/datum/language/L = new T
			all_languages[L.name] = L

		// Names.
		peoples_check(people_name_problem("Latins") && people_name_problem("Hearthlanders") && people_name_problem("Ab"), "taken and short names are refused")
		peoples_check(people_name_problem("White Folk") && people_name_problem("Black-Hand Clan") && people_name_problem("Germans") && people_name_problem("Ukrainians") && people_name_problem("Sandniggers"), "real-world peoples, races and slurs are refused")
		peoples_check(!people_name_problem("Saltmarsh Kin") && !people_name_problem("Spice Traders") && !people_name_problem("Abode Folk"), "names of this world are free")
		peoples_check(language_name_problem("Germanish") && !language_name_problem("Saltspeak"), "new languages take the same blocklist")

		// Gaia's own roots.
		var/datum/origin/hearth = origin_by_id("hearthlanders")
		peoples_check(hearth && hearth.language == "Latin" && origin_root(hearth) == hearth, "Gaia roots are peoples of their own")
		var/mob/living/human/old_gaian = peoples_person("latins", "Gaia")
		var/mob/living/human/european = peoples_person("latins", "Europe")
		peoples_check(old_gaian.settle_people_record() && old_gaian.origin_id == "hearthlanders", "a Gaia-born Latin becomes a Hearthlander")
		peoples_check(!european.settle_people_record() && european.origin_id == "latins", "a Latin of Europe stays a Latin")
		peoples_check(!old_gaian.settle_people_record(), "settling twice changes nothing")

		// A formed people.
		var/datum/origin/salt = found_people("Saltmarsh Kin", list("hearthlanders"), "Latin", "Gaia", "Iron Pact")
		peoples_check(istype(salt) && salt.world_record && salt.root_id == "hearthlanders" && salt.name_style == "roman" && islist(salt.parents) && salt.parents[1] == "hearthlanders", "a formed people is recorded with its root and parents")
		peoples_check(origin_by_id(salt.id) == salt && (salt.id in people_records()), "it is found by id like a root")
		peoples_check(people_name_problem("Saltmarsh Kin"), "its name is taken now")
		var/datum/origin/deep = found_people("Deepmarsh Kin", list(salt.id), "Latin", "Gaia")
		peoples_check(istype(deep) && origin_root(deep) == hearth, "a people formed from a formed people keeps the first root")
		var/mob/living/human/member = peoples_person(salt.id, "Gaia")
		peoples_check(member.mother_tongue() == all_languages["Latin"] && findtext(member.origin_summary(), "Saltmarsh Kin"), "members speak its tongue and their notes name it")
		peoples_check(people_members(salt.id) == 1, "living members are counted")

		// Travel.
		member.languages += all_languages["Latin"]
		member.partial_languages["Latin"] = all_languages["Latin"].difficulty
		var/list/T = member.region_travel_tongues()
		peoples_check(islist(T["peoples"]) && (salt.id in T["peoples"]) && T["origin"] == salt.id, "a traveller carries their people's record")
		peoples_check(region_travel_tongues_valid(T), "the record validates where the people is known")
		var/list/records = people_records()
		var/list/saved = records[salt.id]
		records -= salt.id
		world_peoples_cache -= salt.id
		peoples_check(region_travel_tongues_valid(T), "and where it is not")
		var/mob/living/human/arrival = peoples_person(null, null)
		peoples_check(arrival.region_travel_restore_tongues(T) && arrival.origin_id == salt.id && origin_by_id(salt.id), "the arrival keeps their people")
		var/list/imported = records[salt.id]
		peoples_check(islist(imported) && imported["imported"], "an arriving people is recorded as imported")
		records[salt.id] = saved
		world_peoples_cache -= salt.id
		var/list/bad = T.Copy()
		bad["peoples"] = list("p_bad" = list("name" = "Badfolk", "root" = "klingons", "language" = "Latin"))
		bad["origin"] = "p_bad"
		peoples_check(!region_travel_tongues_valid(bad), "a people of an unknown root refuses the trip")

		// Admin rename and merge.
		peoples_check(rename_world_people(salt.id, "Zulu Kin") && !rename_world_people(salt.id, "Reedmarsh Kin") && origin_by_id(salt.id).name == "Reedmarsh Kin", "renaming takes only a name of this world")
		peoples_check(isnull(merge_world_people(salt.id)), "a people others grew from cannot be merged first")
		peoples_check(merge_world_people(deep.id) == 0 && !origin_by_id(deep.id), "merging forgets the people")
		peoples_check(merge_world_people(salt.id) == 2 && member.origin_id == "hearthlanders" && arrival.origin_id == "hearthlanders", "merging back moves members to the parent")
		var/mob/living/human/away = peoples_person(salt.id, "Gaia")
		peoples_check(away.settle_people_record() && away.origin_id == "hearthlanders", "someone away during the merge follows at login")
		peoples_check(findtext(jointext(world_peoples_report(), "\n"), "No peoples"), "the admin report lists what is left")

		// Born into a community.
		for (var/mob/living/human/H in human_mob_list.Copy())
			human_mob_list -= H
			living_mob_list -= H
		var/turf/here = locate(3, 3, 1)
		var/datum/origin/marsh = found_people("Fenreach Kin", list("hearthlanders"), "Latin", "Gaia")
		peoples_check(!community_peoples(here).len, "nobody around is the wild")
		var/list/townsfolk = list()
		for (var/i in 1 to 2)
			var/mob/living/human/H = peoples_person(marsh.id)
			H.loc = locate(i, 1, 1)
			townsfolk += H
		var/mob/living/human/stranger = peoples_person("fjordfolk")
		stranger.loc = locate(5, 5, 1)
		var/mob/living/human/dead = peoples_person("fjordfolk")
		dead.loc = here
		dead.stat = DEAD
		var/mob/living/human/nowhere = peoples_person("fjordfolk")
		peoples_check(nowhere.loc == null, "a character nowhere is not counted")
		var/list/community = community_peoples(here)
		peoples_check(community.len == 2 && community[1] == marsh.id && community[marsh.id] == 2 && community["fjordfolk"] == 1, "a community counts the living around, most common first")
		var/list/choices = community_people_choices(community)
		peoples_check(choices[1] == "Fenreach Kin" && choices.len == 2, "the newcomer picks among the peoples living there")
		var/mob/living/human/newcomer = peoples_person(null, null)
		newcomer.loc = here
		peoples_check(community_peoples(here, newcomer).len == 2, "the newcomer does not count themselves")
		peoples_check(newcomer.choose_origin("tundra") && newcomer.origin_id == marsh.id && newcomer.origin_land == "Gaia", "a newcomer without a keyboard joins the most common people there")
		var/mob/living/human/wild = peoples_person(null, null)
		wild.loc = locate(5, 1, 2)
		peoples_check(wild.loc && wild.choose_origin("tundra") && wild.origin_id == "fjordfolk", "one born in the wild takes the birthplace root")
		var/mob/living/human/returner = peoples_person(null, null)
		returner.loc = here
		returner.legacy_people = "fjordfolk"
		peoples_check(returner.choose_origin("temperate") && returner.origin_id == "fjordfolk" && isnull(returner.legacy_people), "a returning character keeps their last people if it lives there")
		var/mob/living/human/returner2 = peoples_person(null, null)
		returner2.loc = here
		returner2.legacy_people = "zulu"
		peoples_check(returner2.choose_origin("temperate") && returner2.origin_id == marsh.id, "but not a people that does not live there")
		var/mob/living/human/agent = peoples_person(null, null)
		agent.loc = here
		agent.origin_wish = "fjordfolk"
		peoples_check(agent.choose_origin("temperate") && agent.origin_id == "fjordfolk", "an agent may ask for a people living there")

		// Splits after long isolation.
		for (var/mob/living/human/H in human_mob_list.Copy())
			human_mob_list -= H
			living_mob_list -= H
		var/list/pact = list()
		for (var/i in 1 to 5)
			var/mob/living/human/H = peoples_person("hearthlanders")
			H.civilization = "Iron Pact"
			pact += H
		var/mob/living/human/pact_fjord = peoples_person("fjordfolk")
		pact_fjord.civilization = "Iron Pact"
		var/pact_key = people_community_key("Iron Pact", "hearthlanders")
		var/list/active = language_lineage_part("people_active")
		var/list/contact = language_lineage_part("people_contact")
		var/list/isolation = language_lineage_part("people_isolation")
		var/list/pending = language_lineage_part("people_pending")
		var/start_year = 1000
		peoples_check(!people_year_check(start_year) && language_lineage_part("people_year")["year"] == start_year, "the first tick only marks the year")
		peoples_check(!people_year_check(start_year + 1) && !isolation[pact_key], "a year nobody played adds nothing")
		var/year = start_year + 1
		for (var/i in 1 to 10)
			active[pact_key] = TRUE
			people_year_check(++year)
		peoples_check(isolation[pact_key] == 10, "each played year without contact adds a year apart")
		active[pact_key] = TRUE
		contact["Iron Pact"] = TRUE
		people_year_check(++year)
		peoples_check(isolation[pact_key] == 5 && !contact.len && !active.len, "a year with contact halves it and the flags reset")
		var/mob/living/human/neighbour = peoples_person("fjordfolk")
		neighbour.civilization = "Sea League"
		var/mob/living/human/S = pact[1]
		neighbour.client = null
		S.people_heard(neighbour)
		peoples_check(!language_lineage_part("people_heard")["Iron Pact"], "speech from a body nobody plays is not contact")
		isolation[pact_key] = PEOPLE_SPLIT_YEARS - 1
		active[pact_key] = TRUE
		peoples_check(!people_year_check(++year) || (pact_key in pending), "the split comes at the year it reaches the limit")
		peoples_check((pact_key in pending), "a nation apart long enough is ready to split")
		peoples_check(findtext(jointext(people_isolation_report(), "\n"), "waiting for its leader"), "the admin report shows the waiting split")
		var/fen_key = people_community_key("Fen Kin", "hearthlanders")
		isolation[fen_key] = PEOPLE_SPLIT_YEARS + 5
		people_split_check(year)
		peoples_check(!(fen_key in pending), "a nation with too few members does not split")
		peoples_check(isnull(split_people(pact_key, "Germans")) && (pact_key in pending), "a blocked name does not split")

		// Name suggestions.
		var/mob/living/human/elder = pact[2]
		elder.real_name = "Aldric Stone"
		elder.age = 70
		peoples_check(people_pending_tongue(pact_key) == "Latin", "suggestions come from the tongue the people will speak")
		var/list/offered = people_name_suggestions(pact_key)
		var/all_free = offered.len >= 3
		for (var/word in offered)
			if (people_name_problem(word) || length(word) < 4 || length(word) > 12)
				all_free = FALSE
		peoples_check(all_free, "three suggestions, each a name that passes the name check")
		var/list/meanings = list()
		for (var/word in offered)
			meanings += offered[word]
		peoples_check(("the children of Aldric" in meanings) && ("the people of the homeland" in meanings), "suggestions carry a place, a trait and an elder")
		var/list/again = people_name_suggestions(pact_key)
		peoples_check(jointext(again, ",") == jointext(offered, ","), "the same meanings give the same words")
		var/list/others = people_name_suggestions(pact_key, 1)
		peoples_check(others.len && jointext(others, ",") != jointext(offered, ","), "asking again gives other words")
		peoples_check(people_word_letters("'Ana-x") == "anax" && isnull(people_word("No Such Tongue", "the free")), "words use plain letters of a real tongue")
		var/first_word = offered[1]
		var/datum/origin/iron = split_people(pact_key, first_word, offered[first_word])
		peoples_check(istype(iron) && iron.nation == "Iron Pact" && iron.parents[1] == "hearthlanders" && iron.language == "Latin", "naming makes the new people")
		peoples_check(iron.meaning == offered[first_word] && findtext(jointext(world_peoples_report(), "\n"), iron.meaning), "the chosen meaning is kept and shown to admins")
		peoples_check(!rename_world_people(iron.id, "Ironvale Folk") && isnull(world_people(iron.id).meaning), "an admin rename drops the old meaning")
		var/moved = 0
		for (var/mob/living/human/H in pact)
			if (H.origin_id == iron.id)
				moved++
		peoples_check(moved == 5 && pact_fjord.origin_id == "fjordfolk" && neighbour.origin_id == "fjordfolk", "only the nation's members of that people join it")
		peoples_check(!(pact_key in pending) && !(pact_key in isolation), "the split clears the wait and the years")

		// Blending.
		for (var/mob/living/human/H in human_mob_list.Copy())
			human_mob_list -= H
			living_mob_list -= H
		var/list/league = list()
		for (var/i in 1 to 3)
			var/mob/living/human/H = peoples_person("fjordfolk")
			H.civilization = "Sea League"
			H.loc = locate(1, 1, 1)
			league += H
		for (var/i in 1 to 2)
			var/mob/living/human/H = peoples_person("isleborn")
			H.civilization = "Sea League"
			H.loc = locate(2, 1, 1)
			league += H
		var/blend_key = people_blend_key("Sea League", "isleborn", "fjordfolk")
		peoples_check(blend_key == people_blend_key("Sea League", "fjordfolk", "isleborn") && people_blend_pair(people_community_parts(blend_key)[2]).len == 2, "a blend key does not depend on order")
		var/list/blend_table = language_lineage_part("people_blend")
		var/list/b_active = list(people_community_key("Sea League", "fjordfolk") = TRUE)
		for (var/i in 1 to PEOPLE_BLEND_YEARS - 1)
			people_blend_year(b_active, 2000 + i)
		peoples_check(blend_table[blend_key] == PEOPLE_BLEND_YEARS - 1 && !(blend_key in pending), "a mixed nation counts years together")
		people_blend_year(b_active, 2100)
		peoples_check((blend_key in pending) && people_pending_label(blend_key) == "Fjordfolk and Isleborn", "after enough years the blend waits for a name")
		var/list/pending_league = people_pending_for("Sea League")
		peoples_check(pending_league.len == 1, "the leader sees one waiting people")
		var/datum/origin/tide = blend_people(blend_key, "Tidewater Folk")
		peoples_check(istype(tide) && tide.parents.len == 2 && tide.parents[1] == "fjordfolk" && tide.language == "Old Norse" && tide.nation == "Sea League", "the blend has both parents and the larger group's tongue")
		var/still = 0
		for (var/mob/living/human/H in league)
			if (H.origin_id == "fjordfolk" || H.origin_id == "isleborn")
				still++
		peoples_check(still == 5, "nobody's own people changes")
		people_blend_year(b_active, 2101)
		peoples_check(!(blend_key in pending), "a nation does not blend the same two peoples twice")
		var/mob/living/human/baby = peoples_person(null, null)
		baby.loc = locate(1, 2, 1)
		peoples_check(community_blend_people(get_turf(baby), baby) == tide, "the blend belongs to the nation living there")
		peoples_check(baby.choose_origin("temperate") && baby.origin_id == tide.id, "a newcomer among them is born into the blend")
		var/mob/living/human/solo = league[5]
		solo.civilization = "Lone Isle"
		var/list/lone = list(people_community_key("Lone Isle", "isleborn") = TRUE)
		people_blend_year(lone, 2102)
		peoples_check(!length(people_pending_for("Lone Isle")), "a nation too small never blends")

		// Belonging.
		var/mob/living/human/guest = peoples_person("hearthlanders")
		guest.loc = locate(1, 1, 1)
		for (var/i in 1 to PEOPLE_RAISED_YEARS)
			guest.people_played_year = TRUE
			people_belong_year()
		peoples_check(guest.raised_among("fjordfolk") && !guest.raised_among("isleborn") && guest.origin_id == "hearthlanders", "living among a people for years raises a character among them, birth people kept")
		var/mob/living/human/idle = peoples_person("hearthlanders")
		idle.loc = locate(1, 1, 1)
		for (var/i in 1 to PEOPLE_RAISED_YEARS)
			people_belong_year()
		peoples_check(!idle.raised_among("fjordfolk"), "years not played do not count")

		// The year.
		var/now_year = world_calendar_year()
		peoples_check(isnum(now_year) && now_year > 0 && now_year == round(now_year), "the calendar year is a whole number")
	catch(var/exception/e)
		peoples_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = peoples_failures, "runtime_error" = peoples_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
