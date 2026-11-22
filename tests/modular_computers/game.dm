// Modular computer fixture (code/modules/1713/computers/modular/): research
// gates, module slots and capabilities, the Files program, diskettes, the
// printer, part removal and a native save round trip.
var/mc_failures = 0
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 12
	maxz = 2
	turf = /turf
	visibility = 0
/world/OpenPort(port)
	return port == "none" ? ..() : FALSE
/obj/map_metadata/mc_fixture/New()
	return
/mob/living/human/mc_fixture/New()
	species = new /datum/species/human
	body_build = new /datum/body_build
	bloodstr = new /datum/reagents/metabolism(1000, src, CHEM_BLOOD)
	ingested = new /datum/reagents/metabolism(1000, src, CHEM_INGEST)
	touching = new /datum/reagents/metabolism(1000, src, CHEM_TOUCH)
	reagents = bloodstr
	vessel = new /datum/reagents(1000, src)
/proc/mc_check(condition, label)
	if (!condition)
		mc_failures++
	world.log << "[condition ? "PASS" : "FAIL:"] [label]"
/world/Error(exception/e)
	mc_failures++
	world.log << "runtime error: [e] [e.file]:[e.line]"
/proc/mc_act(obj/structure/modular_computer/C, action, value = null, list/fields = null)
	var/list/params = list("value" = value)
	if (fields)
		params += fields
	return C.computer_action(action, params, null)
/world/New()
	OpenPort("none")
	generate_gameid()
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	movementMachine = new
	map = new /obj/map_metadata/mc_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.ordinal_age = 7
	try
		build_research_tree()
		var/datum/research_node/node = get_research_node("electronic_computing")
		var/datum/research_node/digital = get_research_node("digital_computing")
		mc_check(node && node.era_tier == 7 && ("automation" in node.prereqs) && ("electricity" in node.prereqs), "Electronic Computing is a 1969 node after Automation and Electricity")
		mc_check(digital && ("electronic_computing" in digital.prereqs), "Digital Computing now follows Electronic Computing")
		mc_check(get_recipe_node_req("/obj/structure/modular_computer") == "electronic_computing" && get_recipe_node_req("/obj/item/computer_module/printer") == "electronic_computing", "1969 parts need Electronic Computing")
		mc_check(get_recipe_node_req("/obj/item/computer_module/storage/hard_drive") == "digital_computing" && get_recipe_node_req("/obj/item/computer_module/storage/solid_state") == "consumer_electronics", "later drives need later research")
		mc_check(isnull(computer_os_defs) && isnull(computer_program_defs), "definitions are not built at startup")
		var/datum/computer_os/os = computer_os_def("unga_cli")
		mc_check(os && os.shell == "cli" && ("files" in os.bundled) && computer_program_def("files"), "Unga OS bundles Files")
		mc_check(computer_os_def("unga_cli") == os, "one shared OS definition")
		// A powered cable.
		var/obj/structure/cable/cable = new(locate(5, 5, 1))
		var/obj/structure/engine/E = new(cable.loc)
		E.on = TRUE
		E.maxpower = 100
		cable.connections |= E
		E.connections |= cable
		var/obj/structure/modular_computer/C = new(locate(5, 5, 1))
		C.powersource = cable
		cable.connections |= C
		mc_check(C.fault() == "It has no processor.", "a bare chassis has no processor")
		var/obj/item/computer_module/processor/cpu = new(locate(6, 5, 1))
		mc_check(!C.install_module(cpu, null) && !(cpu in C.contents), "a closed case refuses parts")
		C.case_open = TRUE
		mc_check(C.install_module(cpu, null) && C.cpu_tier() == 1, "a processor fits")
		var/obj/item/computer_module/processor/spare = new(locate(6, 5, 1))
		mc_check(!C.install_module(spare, null), "the processor slot holds one")
		mc_check(C.fault() == "" && !C.operational(), "with a processor and power it can start, but is off")
		C.enabled = TRUE
		mc_check(C.operational(), "switched on it runs")
		mc_check(findtext(mc_act(C, "open_program", "files"), "storage drive") && C.active_program == "", "Files needs a drive")
		var/list/data = C.ui_data(null)
		var/list/programs = data["programs"]
		var/list/files_entry = programs[1]
		mc_check(data["powered"] == 1 && data["shell"] == "cli" && files_entry["available"] == 0 && length(files_entry["reason"]), "the window marks Files unavailable")
		var/obj/item/computer_module/storage/tape = new(locate(6, 5, 1))
		var/obj/item/computer_module/media_reader/reader = new(locate(6, 5, 1))
		var/obj/item/computer_module/printer/printer = new(locate(6, 5, 1))
		mc_check(C.install_module(tape, null) && C.install_module(reader, null) && C.install_module(printer, null), "drive, diskette drive and printer fit")
		mc_check((COMPUTER_CAP_STORAGE in C.capabilities()) && (COMPUTER_CAP_MEDIA in C.capabilities()) && (COMPUTER_CAP_PRINT in C.capabilities()), "modules grant their capabilities")
		mc_check(mc_act(C, "open_program", "files") == "Running FILES." && C.active_program == "files", "Files runs")
		mc_act(C, "new_file")
		mc_check(C.open_file == 0, "new file opens an empty editor")
		mc_check(mc_act(C, "save_file", 0, list("name" = " field notes ", "body" = "North field: barley.\nSouth: rye.")) == "Saved FIELD NOTES." && tape.file_count() == 1 && C.open_file == 1, "save a new file with a cleaned name")
		mc_check(findtext(mc_act(C, "save_file", 0, list("name" = "field notes", "body" = "x")), "already exists") && tape.file_count() == 1, "names stay unique")
		mc_check(findtext(mc_act(C, "save_file", 0, list("name" = "", "body" = "x")), "name"), "a file needs a name")
		mc_check(mc_act(C, "save_file", 1, list("name" = "field notes", "body" = "Barley everywhere.")) == "Saved FIELD NOTES." && tape.file_bodies[1] == "Barley everywhere.", "edit a file in place")
		var/long = ""
		for (var/i = 1 to 300)
			long += "0123456789"
		mc_act(C, "save_file", 0, list("name" = "long", "body" = long))
		mc_check(length(tape.file_bodies[tape.file_index("LONG")]) == COMPUTER_FILE_MAX_CHARS, "file bodies are capped")
		var/full = 2
		while (full < 10 && mc_act(C, "save_file", 0, list("name" = "fill [full]", "body" = long)) != "Not enough space.")
			full++
		mc_check(tape.used_chars() <= tape.capacity_kb * COMPUTER_CHARS_PER_KB && full < 10, "a drive refuses files past its capacity")
		for (var/i = tape.file_count(), i > 1, i--)
			mc_act(C, "delete_file", i)
		mc_check(tape.file_count() == 1, "delete files")
		data = C.ui_data(null)
		var/list/files = data["files"]
		var/list/listed = files ? files["list"] : null
		mc_check(files && files["drive"] && listed && listed.len == 1 && isnull(files["disk"]) && files["printer"]["paper"] == 0, "the window lists the drive, no disk and an empty printer")
		var/obj/item/computer_module/disk/disk = new(reader)
		mc_check(C.disk() == disk, "a diskette sits in the drive")
		mc_check(mc_act(C, "copy_to_disk", 1) == "Copied FIELD NOTES to the diskette." && disk.file_count() == 1, "copy a file to the diskette")
		tape.delete_file(1)
		mc_check(mc_act(C, "copy_from_disk", 1) == "Copied FIELD NOTES from the diskette." && tape.file_bodies[1] == "Barley everywhere.", "copy it back")
		mc_check(mc_act(C, "print_file", 1) == "The printer is out of paper.", "no paper, no print")
		printer.paper = 2
		mc_check(mc_act(C, "print_file", 1) == "Printed FIELD NOTES." && printer.paper == 1, "print a file")
		var/obj/item/weapon/paper/sheet = locate(/obj/item/weapon/paper) in C.loc
		mc_check(sheet && sheet.name == "field notes" && findtext(sheet.info, "Barley everywhere."), "the printout carries the text")
		qdel(sheet)
		mc_check(mc_act(C, "power") == "" && !C.enabled && !C.operational(), "power off")
		mc_check(mc_act(C, "home") == "" , "actions still answer when off")
		C.enabled = TRUE
		mc_act(C, "open_program", "files")
		var/list/modules = C.modules()
		mc_check(modules.len == 4, "four parts fitted")
		C.case_open = FALSE
		mc_check(!C.remove_module(tape, null) && (tape in C.contents), "a closed case keeps its parts")
		var/hub_files = tape.file_count()
		var/disk_files = disk.file_count()
		// Native save round trip.
		mc_check(map_storage.Save_World() && map_storage.validate_world_save(), "native save")
		map_storage.ClearMap()
		mc_check(map_storage.Load_World(), "native reload")
		var/obj/structure/modular_computer/R = locate(/obj/structure/modular_computer) in locate(5, 5, 1)
		mc_check(R && R.enabled && !R.case_open && R.os_id == "unga_cli" && R.active_program == "" && R.open_file == -1, "computer settings survive, the session does not")
		var/obj/item/computer_module/RD = R ? R.drive() : null
		var/obj/item/computer_module/RK = R ? R.disk() : null
		var/obj/item/computer_module/printer/RP = R ? R.printer() : null
		mc_check(R && R.cpu_tier() == 1 && RD && RD.file_count() == hub_files && RD.file_names[1] == "FIELD NOTES" && RD.file_bodies[1] == "Barley everywhere.", "the drive keeps its files")
		mc_check(RK && RK.file_count() == disk_files && RP && RP.paper == 1, "the diskette and printer paper survive")
		var/obj/structure/cable/RC = locate(/obj/structure/cable) in locate(5, 5, 1)
		if (R && RC)
			R.powersource = RC
			RC.connections |= R
		mc_check(R && R.operational() && mc_act(R, "open_program", "files") == "Running FILES.", "the restored computer runs Files")
		R.case_open = TRUE
		var/obj/item/computer_module/processor/RCPU = R.module_in(COMPUTER_SLOT_CPU)
		mc_check(R.remove_module(RCPU, null) && !R.enabled && RCPU.loc == R.loc, "pulling the processor shuts it down")
		mc_check(R.fault() == "It has no processor.", "and it cannot start again")
	catch (var/exception/e)
		mc_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = mc_failures, "byond_build" = world.byond_build)), "result.json")
	del(world)
