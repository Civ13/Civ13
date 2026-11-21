// Native drug class probe, included by tests/ecology_spawning/run_linux.py, never
// by the game DME. It drives code/modules/reagents/drug_classes.dm.
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 30
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/drugclass_probe/New()
	map = src
/mob/living/human/drugclass_probe/New()
	icon_update = FALSE // no species: skip body overlays when held items change
	return
/mob/living/human/drugclass_probe/New()
	icon_update = FALSE
	bloodstr = new/datum/reagents/metabolism(1000, src, CHEM_BLOOD)
	ingested = new/datum/reagents/metabolism(1000, src, CHEM_INGEST)
	touching = new/datum/reagents/metabolism(1000, src, CHEM_TOUCH)
	reagents = bloodstr
	species = new /datum/species/human
	return
var/drugclass_failures = 0
var/drugclass_runtime_error = FALSE
/proc/drugclass_check(condition, label)
	if (!condition)
		drugclass_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	drugclass_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		new /obj/map_metadata/drugclass_probe
		initialize_chemical_reactions()
		for (var/turf/T in block(locate(1, 1, 1), locate(30, 30, 1)))
			T.ChangeTurf(/turf/floor/grass, FALSE, FALSE)
		drugclass_classes()
		drugclass_dosing()
		drugclass_relief_and_relapse()
		drugclass_mixing()
		drugclass_signs()
	catch(var/exception/e)
		drugclass_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = drugclass_failures, "runtime_error" = drugclass_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/drugclass_reagent(datum/reagents/holder, id, amount)
	holder.add_reagent(id, amount)
	for (var/datum/reagent/R in holder.reagent_list)
		if (R.id == id)
			return R
	return null

/proc/drugclass_classes()
	var/obj/item/weapon/reagent_containers/glass/beaker/B = new(locate(2, 2, 1))
	var/list/expect = list("opium" = "opioid", "morphine" = "opioid", "tramadol" = "opioid", "cocaine" = "stimulant", "crack" = "stimulant", "methamphetamine" = "stimulant", "nicotine" = "nicotine", "thc" = "cannabis", "coffee" = "caffeine", "beer" = "alcohol", "wine" = "alcohol")
	for (var/id in expect)
		var/datum/reagent/R = drugclass_reagent(B.reagents, id, 1)
		drugclass_check(R && drug_reagent_class(R) == expect[id], "[id] is in the [expect[id]] class")
	qdel(B)

// Dosing builds dependence and tolerance; tolerance blunts mood and raises the overdose line.
/proc/drugclass_dosing()
	var/mob/living/human/drugclass_probe/H = new(locate(4, 4, 1))
	var/datum/reagent/opium/O = drugclass_reagent(H.reagents, "opium", 5)
	O.affect_blood(H, null, 0.1)
	drugclass_check(H.addictions["opioid"] > 0, "opium builds opioid dependence")
	drugclass_check(H.drug_tolerance["opioid"] > 0, "opium builds opioid tolerance")
	var/base = O.overdose_limit(H)
	H.drug_tolerance["opioid"] = 100
	drugclass_check(O.overdose_limit(H) == O.overdose * 2, "full tolerance doubles the overdose line")
	drugclass_check(base < O.overdose_limit(H), "tolerance raises the overdose line")
	drugclass_check(H.drug_effect_scale("opioid") < 0.5, "full tolerance blunts the effect")
	var/datum/reagent/nicotine/N = drugclass_reagent(H.reagents, "nicotine", 5)
	N.affect_blood(H, null, 0.1)
	drugclass_check(H.addictions["nicotine"] > 0, "smoking now builds nicotine dependence")
	var/datum/reagent/opium/OD = drugclass_reagent(H.ingested, "opium", 1)
	var/oxy = H.getOxyLoss()
	OD.overdose(H, null)
	drugclass_check(H.getOxyLoss() > oxy, "an opium overdose slows breathing")
	qdel(H)

/proc/drugclass_relief_and_relapse()
	var/mob/living/human/drugclass_probe/H = new(locate(6, 6, 1))
	H.addictions = list("opium" = 50, "cocaine" = 30, "tobacco" = 20)
	H.handle_drugs()
	drugclass_check(H.addictions["opioid"] > 49 && !("opium" in H.addictions), "old opium dependence moves to the opioid class")
	drugclass_check(H.addictions["stimulant"] > 29 && H.addictions["nicotine"] > 19, "old cocaine and tobacco keys move to their classes")
	H.drug_tolerance["opioid"] = 40
	H.addictions["opioid"] = 40
	for (var/i in 1 to 100)
		H.handle_drugs()
	drugclass_check(H.drug_tolerance["opioid"] < 30 && H.addictions["opioid"] > 30, "tolerance fades faster than dependence")
	drugclass_reagent(H.reagents, "morphine", 2)
	drugclass_check(H.drug_class_active("opioid"), "morphine counts as an opioid in the body")
	qdel(H)

/proc/drugclass_mixing()
	var/mob/living/human/drugclass_probe/H = new(locate(8, 8, 1))
	drugclass_reagent(H.reagents, "opium", 2)
	var/oxy = H.getOxyLoss()
	H.drug_mixing()
	drugclass_check(H.getOxyLoss() == oxy, "opium alone does not stop breathing")
	drugclass_reagent(H.ingested, "beer", 5)
	H.drug_mixing()
	drugclass_check(H.getOxyLoss() > oxy, "opium with alcohol slows breathing")
	qdel(H)

/proc/drugclass_signs()
	var/mob/living/human/drugclass_probe/H = new(locate(10, 10, 1))
	var/datum/gender/T = new /datum/gender/male
	drugclass_check(H.drug_examine_text(T) == "", "a sober body shows no signs")
	drugclass_reagent(H.reagents, "opium", 2)
	drugclass_check(findtext(H.drug_examine_text(T), "pinpoint"), "opioids show pinpoint pupils")
	H.reagents.clear_reagents()
	H.addictions["stimulant"] = 70
	drugclass_check(findtext(H.drug_examine_text(T), "shaking"), "withdrawal shows shaking hands")
	qdel(H)
