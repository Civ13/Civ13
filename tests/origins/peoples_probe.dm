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

		// The year.
		var/year = world_calendar_year()
		peoples_check(isnum(year) && year > 0 && year == round(year), "the calendar year is a whole number")
	catch(var/exception/e)
		peoples_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = peoples_failures, "runtime_error" = peoples_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
