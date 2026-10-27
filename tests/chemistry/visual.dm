// Local evidence adapter. Real beakers/holders/process_reactions; game startup
// and the usual lobby Login are disabled by the visual runner only.
var/global/list/chemistry_visual_beakers = list()
var/global/chemistry_visual_processed = FALSE
var/global/chemistry_visual_product = "polyethylene"

/proc/chemistry_prepare_visual()
	world.name = "Civ13 LOCAL chemistry fixture"
	var/datum/chemical_reaction/polyethylene/recipe = new
	for(var/i in 1 to 3)
		var/turf/T = locate(19+i, 20, 1)
		T = T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
		var/obj/item/weapon/reagent_containers/glass/beaker/large/beaker = new(T)
		beaker.name = list("A: ethylene + all catalysts", "B: ethylene, missing borontrifluoride", "C: propylene + all catalysts")[i]
		beaker.reagents.add_reagent(i == 3 ? "propylene" : "ethylene", i == 1 ? 4 : 2, safety = TRUE)
		for(var/id in recipe.catalysts)
			if(i == 2 && id == "borontrifluoride")
				continue
			beaker.reagents.add_reagent(id, recipe.catalysts[id], safety = TRUE)
		chemistry_visual_beakers += beaker
	text2file("READY: visual fixture; use Inspect chemistry then Run chemistry", "visual_ready.txt")
	spawn(9000)
		del(world) // Maximum 15 minute task-owned visual session.

/client/verb/inspect_chemistry()
	set category = "Local Verification"
	set name = "Inspect chemistry"
	screen.Cut()
	mob.loc = locate(21, 19, 1)
	mob.sight = SEE_TURFS | SEE_OBJS | SEE_MOBS | SEE_SELF
	mob.see_in_dark = 8
	eye = mob.loc
	src << browse(null, "window=playersetup")
	var/report = "<html><body><h2>LOCAL isolated chemistry fixture</h2><p>Commit: [world.params["tested_commit"]]</p><p>BYOND [world.byond_version].[world.byond_build]; map [world.maxx] x [world.maxy] x [world.maxz].</p><p>Real beakers and production process_reactions. Game startup/lobby disabled; no crafting-menu clicks. State: [chemistry_visual_processed ? "AFTER processing" : "BEFORE processing"].</p>"
	for(var/obj/item/weapon/reagent_containers/glass/beaker/large/beaker in chemistry_visual_beakers)
		report += "<h3>[beaker.name]</h3><p>"
		for(var/datum/reagent/reagent in beaker.reagents.reagent_list)
			report += "[reagent.name] ([reagent.id]): [reagent.volume]u<br>"
		report += "[chemistry_visual_product]: [beaker.reagents.get_reagent_amount(chemistry_visual_product)]u</p>"
	report += "<p>Native Local Verification verb: Run chemistry processes all three holders once.</p></body></html>"
	src << browse(report, "window=chemistry;size=760x800")

/client/verb/run_chemistry()
	set category = "Local Verification"
	set name = "Run chemistry"
	chemistry_run_visual()
	inspect_chemistry()

/proc/chemistry_run_visual()
	if(chemistry_visual_product == "gasoline")
		fuel_run_visual()
		return
	if(!chemistry_visual_processed)
		for(var/obj/item/weapon/reagent_containers/glass/beaker/large/beaker in chemistry_visual_beakers)
			beaker.reagents.process_reactions()
		var/obj/item/weapon/reagent_containers/glass/beaker/large/positive = chemistry_visual_beakers[1]
		var/obj/item/weapon/reagent_containers/glass/beaker/large/missing = chemistry_visual_beakers[2]
		var/obj/item/weapon/reagent_containers/glass/beaker/large/wrong = chemistry_visual_beakers[3]
		chemistry_assert(positive.reagents.get_reagent_amount("polyethylene") == 50, "Visual positive yield")
		chemistry_assert(missing.reagents.get_reagent_amount("polyethylene") == 0, "Visual missing catalyst")
		chemistry_assert(wrong.reagents.get_reagent_amount("polyethylene") == 0, "Visual wrong feedstock")
		chemistry_visual_processed = TRUE
		text2file("PASS: real beaker process_reactions - A=50 polyethylene, B=0, C=0", "visual_result.txt")

/mob/new_player/proc/chemistry_fixture_login()
	my_client = client
	spawn(40)
		if(client)
			client.inspect_chemistry()
