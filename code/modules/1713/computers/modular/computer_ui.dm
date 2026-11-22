// The modular computer window ("computer.tmpl", designed by Fable). The server
// builds one data list per change; the window keeps typing drafts locally and
// sends a file only when the player saves it.

/obj/structure/modular_computer/ui_actions(ui_key)
	return list("power", "open_program", "home", "new_file", "open_file", "close_file", "save_file",
		"delete_file", "print_file", "copy_to_disk", "copy_from_disk", "delete_disk_file", "eject_disk", "remove_module")

/obj/structure/modular_computer/ui_action_fields(ui_key, action)
	if (action == "save_file")
		return list("name", "body")
	return null

/obj/structure/modular_computer/ui_interact(mob/user, ui_key = "main", datum/nanoui/ui = null, force_open = TRUE)
	open_tgui(user, ui_key, "computer.tmpl", name, 640, 480, ui_data(user), ui, force_open)

/obj/structure/modular_computer/proc/program_available(datum/computer_program/P, list/caps)
	for (var/need in P.requires)
		if (!(need in caps))
			return FALSE
	return TRUE

/obj/structure/modular_computer/proc/program_reason(datum/computer_program/P, list/caps)
	for (var/need in P.requires)
		if (!(need in caps))
			switch (need)
				if (COMPUTER_CAP_STORAGE)
					return "Needs a storage drive."
				if (COMPUTER_CAP_MEDIA)
					return "Needs a diskette drive."
				if (COMPUTER_CAP_PRINT)
					return "Needs a printer."
			return "Needs more hardware."
	return ""

/obj/structure/modular_computer/proc/installed_programs()
	var/datum/computer_os/O = os()
	return O && O.bundled ? O.bundled : list()

/obj/structure/modular_computer/proc/ui_data(mob/user)
	var/datum/computer_os/O = os()
	var/list/caps = capabilities()
	var/list/hardware = list()
	var/list/modules = modules()
	for (var/i = 1 to modules.len)
		var/obj/item/computer_module/M = modules[i]
		hardware += list(list("index" = i, "slot" = M.slot, "slot_label" = slot_label(M.slot), "name" = M.name, "detail" = M.detail_text(), "icon" = M.icon_state))
	var/list/empty = list()
	for (var/slot in list(COMPUTER_SLOT_CPU, COMPUTER_SLOT_DRIVE, COMPUTER_SLOT_MEDIA, COMPUTER_SLOT_EXPANSION))
		for (var/n = modules_in(slot) + 1 to slot_capacity(slot))
			empty += list(list("slot" = slot, "slot_label" = slot_label(slot)))
	var/list/programs = list()
	for (var/id in installed_programs())
		var/datum/computer_program/P = computer_program_def(id)
		if (P)
			var/ok = program_available(P, caps)
			programs += list(list("id" = P.id, "name" = P.name, "desc" = P.desc, "available" = ok ? 1 : 0, "reason" = ok ? "" : program_reason(P, caps)))
	. = list(
		"name" = name,
		"shell" = O ? O.shell : "cli",
		"os_name" = O ? O.name : "",
		"os_version" = O ? O.version : "",
		"boot_lines" = O && O.boot_lines ? O.boot_lines : list(),
		"powered" = operational() ? 1 : 0,
		"case_open" = case_open ? 1 : 0,
		"status" = status_line,
		"hardware" = hardware,
		"empty_slots" = empty,
		"programs" = programs,
		"active" = active_program,
		"files" = active_program == "files" ? files_data() : null)

/obj/structure/modular_computer/proc/files_data()
	var/obj/item/computer_module/D = drive()
	var/obj/item/computer_module/disk = disk()
	var/obj/item/computer_module/printer/P = printer()
	var/list/open = null
	if (D && open_file == 0)
		open = list("index" = 0, "name" = "", "body" = "")
	else if (D && open_file > 0 && open_file <= D.file_count())
		open = list("index" = open_file, "name" = D.file_names[open_file], "body" = D.file_bodies[open_file])
	return list(
		"drive" = D ? list("name" = D.name, "used_kb" = round(D.used_chars() / COMPUTER_CHARS_PER_KB, 0.1), "capacity_kb" = D.capacity_kb) : null,
		"list" = D ? D.file_list() : list(),
		"open" = open,
		"disk" = disk ? list("name" = disk.name, "used_kb" = round(disk.used_chars() / COMPUTER_CHARS_PER_KB, 0.1), "capacity_kb" = disk.capacity_kb, "list" = disk.file_list()) : null,
		"printer" = P ? list("paper" = P.paper) : null,
		"max_chars" = COMPUTER_FILE_MAX_CHARS,
		"max_name" = COMPUTER_FILE_NAME_MAX)

/obj/structure/modular_computer/ui_act(action, list/params, mob/user, datum/nanoui/ui)
	var/mob/living/human/H = user
	if (!istype(H) || H.stat != CONSCIOUS || !H.can_use_hands() || !H.Adjacent(src))
		return TRUE
	if (action == "remove_module")
		var/list/modules = modules()
		var/i = text2num("[params["value"]]")
		if (!case_open)
			status_line = "Open the case with a screwdriver to remove parts."
		else if (isnum(i) && i >= 1 && i <= modules.len)
			remove_module(modules[i], H)
		return TRUE
	if (!operational())
		if (enabled)
			power_down()
		return TRUE
	. = TRUE
	status_line = computer_action(action, params, H)
	playsound(loc, pick('sound/machines/computer/key_1.ogg', 'sound/machines/computer/key_2.ogg', 'sound/machines/computer/key_3.ogg'), 10, TRUE)

// Runs one window action on a working computer; returns the status line.
// Separate from ui_act so the fixture can drive it without a client.
/obj/structure/modular_computer/proc/computer_action(action, list/params, mob/living/human/H)
	var/value = params ? params["value"] : null
	var/index = text2num("[value]")
	if (!isnum(index))
		index = 0
	switch (action)
		if ("power")
			power_down()
			return ""
		if ("home")
			active_program = ""
			open_file = -1
			return ""
		if ("open_program")
			var/datum/computer_program/P = computer_program_def("[value]")
			if (!P || !(P.id in installed_programs()))
				return "No such program."
			if (!program_available(P, capabilities()))
				return program_reason(P, capabilities())
			active_program = P.id
			open_file = -1
			return "Running [uppertext(P.name)]."
	if (active_program != "files")
		return "Run a program first."
	var/obj/item/computer_module/D = drive()
	if (!D)
		return "No storage drive."
	var/obj/item/computer_module/disk = disk()
	switch (action)
		if ("new_file")
			open_file = 0
			return ""
		if ("open_file")
			if (index < 1 || index > D.file_count())
				return "No such file."
			open_file = index
			return ""
		if ("close_file")
			open_file = -1
			return ""
		if ("save_file")
			if (index < 0 || index > D.file_count())
				return "That file is gone."
			var/body = replacetext("[params["body"]]", ascii2text(13), "")
			var/reason = D.write_file(params["name"], body, index)
			if (reason != "")
				return reason
			open_file = index ? index : D.file_count()
			return "Saved [D.file_names[open_file]]."
		if ("delete_file")
			if (index < 1 || index > D.file_count())
				return "No such file."
			var/gone = D.file_names[index]
			D.delete_file(index)
			open_file = -1
			return "Deleted [gone]."
		if ("print_file")
			return print_file(D, index)
		if ("copy_to_disk")
			if (!disk)
				return "No diskette in the drive."
			if (index < 1 || index > D.file_count())
				return "No such file."
			var/reason = disk.write_file(D.file_names[index], D.file_bodies[index], disk.file_index(D.file_names[index]))
			return reason != "" ? reason : "Copied [D.file_names[index]] to the diskette."
		if ("copy_from_disk")
			if (!disk)
				return "No diskette in the drive."
			if (index < 1 || index > disk.file_count())
				return "No such file on the diskette."
			var/reason = D.write_file(disk.file_names[index], disk.file_bodies[index], D.file_index(disk.file_names[index]))
			return reason != "" ? reason : "Copied [disk.file_names[index]] from the diskette."
		if ("delete_disk_file")
			if (!disk || index < 1 || index > disk.file_count())
				return "No such file on the diskette."
			var/gone = disk.file_names[index]
			disk.delete_file(index)
			return "Deleted [gone] from the diskette."
		if ("eject_disk")
			if (!disk)
				return "No diskette in the drive."
			disk.forceMove(loc)
			if (H)
				H.put_in_hands(disk)
			playsound(loc, 'sound/machines/computer/floppydisk.ogg', 50, TRUE)
			return "Diskette ejected."
	return ""

/obj/structure/modular_computer/proc/print_file(obj/item/computer_module/D, index)
	var/obj/item/computer_module/printer/P = printer()
	if (!P)
		return "No printer."
	if (index < 1 || index > D.file_count())
		return "No such file."
	if (P.paper < 1)
		return "The printer is out of paper."
	P.paper--
	var/obj/item/weapon/paper/sheet = new /obj/item/weapon/paper(loc)
	sheet.name = lowertext(D.file_names[index])
	sheet.info = replacetext(html_encode(D.file_bodies[index]), "\n", "<BR>")
	sheet.update_icon()
	return "Printed [D.file_names[index]]."
