// Modular computer chassis. A chassis is only a case with slots: hardware
// modules (modules.dm) inside it grant capabilities, the OS (os.dm) decides
// the window's look and bundled programs, and files live on the drive. Nothing
// here ticks; the computer acts only when a player uses it.
// This is a separate family from the legacy /obj/structure/computer machines
// on TDM maps, which keep their own programs.
/obj/structure/modular_computer
	name = "minicomputer"
	desc = "A cabinet computer with a teletype console. Open the case with a screwdriver to fit parts; drag a power cable to it."
	icon = 'icons/obj/computers.dmi'
	icon_state = "1980_computer_off"
	anchored = TRUE
	density = TRUE
	flammable = FALSE
	not_movable = FALSE
	not_disassemblable = FALSE
	powerneeded = 3
	var/base_icon = "1980_computer"
	var/os_id = "unga_cli"
	// Lowest ordinal age it belongs to (7 = 1969).
	var/chassis_age = 7
	var/enabled = FALSE
	var/case_open = FALSE
	var/tmp/active_program = ""
	// File open in the editor: -1 none, 0 a new unsaved file, else its index.
	var/tmp/open_file = -1
	var/tmp/status_line = ""

/obj/structure/modular_computer/persistence_runtime_var(var_name)
	if (var_name in list("active_program", "open_file", "status_line"))
		return TRUE
	return ..()

// Slots per chassis; later chassis override this.
/obj/structure/modular_computer/proc/slot_capacity(slot)
	switch (slot)
		if (COMPUTER_SLOT_CPU, COMPUTER_SLOT_DRIVE, COMPUTER_SLOT_MEDIA)
			return 1
		if (COMPUTER_SLOT_EXPANSION)
			return 2
	return 0

/obj/structure/modular_computer/proc/slot_label(slot)
	switch (slot)
		if (COMPUTER_SLOT_CPU)
			return "Processor"
		if (COMPUTER_SLOT_DRIVE)
			return "Storage"
		if (COMPUTER_SLOT_MEDIA)
			return "Diskette drive"
		if (COMPUTER_SLOT_EXPANSION)
			return "Expansion"
	return "Slot"

/obj/structure/modular_computer/proc/modules()
	. = list()
	for (var/obj/item/computer_module/M in contents)
		if (M.slot)
			. += M

/obj/structure/modular_computer/proc/module_in(slot)
	for (var/obj/item/computer_module/M in contents)
		if (M.slot == slot)
			return M
	return null

/obj/structure/modular_computer/proc/modules_in(slot)
	. = 0
	for (var/obj/item/computer_module/M in contents)
		if (M.slot == slot)
			.++

/obj/structure/modular_computer/proc/capabilities()
	. = list()
	for (var/obj/item/computer_module/M in modules())
		if (M.capabilities)
			. |= M.capabilities

/obj/structure/modular_computer/proc/cpu_tier()
	var/obj/item/computer_module/processor/P = module_in(COMPUTER_SLOT_CPU)
	return P ? P.tier : 0

/obj/structure/modular_computer/proc/drive()
	return module_in(COMPUTER_SLOT_DRIVE)

/obj/structure/modular_computer/proc/disk()
	var/obj/item/computer_module/media_reader/R = module_in(COMPUTER_SLOT_MEDIA)
	return R ? R.disk() : null

/obj/structure/modular_computer/proc/printer()
	return locate(/obj/item/computer_module/printer) in contents

/obj/structure/modular_computer/proc/os()
	return computer_os_def(os_id)

// Why the computer cannot run, or "" when it can.
/obj/structure/modular_computer/proc/fault()
	var/datum/computer_os/O = os()
	if (!O)
		return "It has no operating system."
	if (cpu_tier() < O.min_cpu)
		return cpu_tier() ? "Its processor is too slow for [O.name]." : "It has no processor."
	if (!anchored || !isturf(loc))
		return "It must be fastened down."
	if (!draw_cable_power())
		return "It has no power."
	return ""

/obj/structure/modular_computer/proc/operational()
	return enabled && fault() == ""

/obj/structure/modular_computer/update_icon()
	icon_state = "[base_icon]_[enabled && powersource && draw_cable_power() ? "on" : "off"]"

/obj/structure/modular_computer/examine(mob/user)
	..()
	var/list/parts = list()
	for (var/obj/item/computer_module/M in modules())
		parts += M.name
	to_chat(user, parts.len ? "Fitted: [english_list(parts)]." : "No parts are fitted.")
	if (case_open)
		to_chat(user, "The case is open.")

/obj/structure/modular_computer/proc/refresh_windows()
	if (GLOB.nanomanager)
		GLOB.nanomanager.update_uis(src)

/obj/structure/modular_computer/proc/power_down()
	enabled = FALSE
	active_program = ""
	open_file = -1
	if (powersource)
		powersource.update_power(-powerneeded, 1, src)
	update_icon()
	if (GLOB.nanomanager)
		GLOB.nanomanager.close_uis(src)

/obj/structure/modular_computer/MouseDrop_T(atom/movable/O, mob/living/human/H)
	civ_attach_cable(O, H)
	update_icon()

/obj/structure/modular_computer/attack_hand(mob/living/human/H)
	if (!istype(H) || H.stat != CONSCIOUS || !H.can_use_hands() || !H.Adjacent(src))
		return
	if (!enabled)
		var/reason = fault()
		if (reason != "")
			to_chat(H, "<span class='notice'>[reason]</span>")
			return
		enabled = TRUE
		status_line = ""
		update_icon()
		playsound(loc, 'sound/machines/computer/key_enter.ogg', 20, TRUE)
	else if (!operational())
		to_chat(H, "<span class='notice'>[fault()]</span>")
		power_down()
		return
	ui_interact(H)

/obj/structure/modular_computer/attackby(obj/item/W, mob/living/human/H)
	if (!istype(H) || !H.Adjacent(src))
		return
	if (is_tool(W, TOOL_SCREWDRIVER))
		case_open = !case_open
		playsound(loc, 'sound/items/Screwdriver.ogg', 50, TRUE)
		to_chat(H, "You [case_open ? "open" : "close"] the case of \the [src].")
		refresh_windows()
		return
	if (is_tool(W, TOOL_WRENCH))
		if (enabled)
			to_chat(H, "<span class='notice'>Turn it off first.</span>")
			return
		toggle_anchor(H)
		return
	if (istype(W, /obj/item/computer_module/disk))
		var/obj/item/computer_module/media_reader/R = module_in(COMPUTER_SLOT_MEDIA)
		if (!R)
			to_chat(H, "<span class='notice'>It has no diskette drive.</span>")
			return
		if (R.disk())
			to_chat(H, "<span class='notice'>There is already a diskette in the drive.</span>")
			return
		H.drop_from_inventory(W, R)
		playsound(loc, 'sound/machines/computer/floppydisk.ogg', 50, TRUE)
		to_chat(H, "You insert \the [W].")
		refresh_windows()
		return
	if (istype(W, /obj/item/computer_module))
		install_module(W, H)
		return
	if (istype(W, /obj/item/weapon/paper))
		var/obj/item/computer_module/printer/P = printer()
		var/obj/item/weapon/paper/sheet = W
		if (!P)
			return ..()
		if (length(sheet.info) || sheet.type != /obj/item/weapon/paper)
			to_chat(H, "<span class='notice'>The printer only takes blank paper.</span>")
			return
		if (P.paper >= COMPUTER_PRINTER_MAX_PAPER)
			to_chat(H, "<span class='notice'>The printer is full.</span>")
			return
		P.paper++
		H.drop_from_inventory(sheet)
		qdel(sheet)
		to_chat(H, "You load a sheet into the printer ([P.paper] loaded).")
		refresh_windows()
		return
	return ..()

/obj/structure/modular_computer/proc/install_module(obj/item/computer_module/M, mob/living/human/H)
	if (!case_open)
		to_chat(H, "<span class='notice'>Open the case with a screwdriver first.</span>")
		return FALSE
	if (!M.slot)
		to_chat(H, "<span class='notice'>That does not fit in a slot.</span>")
		return FALSE
	if (modules_in(M.slot) >= slot_capacity(M.slot))
		to_chat(H, "<span class='notice'>The [lowertext(slot_label(M.slot))] slot is full.</span>")
		return FALSE
	if (H)
		H.drop_from_inventory(M, src)
	else
		M.forceMove(src)
	to_chat(H, "You fit \the [M] into \the [src].")
	refresh_windows()
	return TRUE

/obj/structure/modular_computer/proc/remove_module(obj/item/computer_module/M, mob/living/human/H)
	if (!case_open || !(M in modules()))
		return FALSE
	if (M == module_in(COMPUTER_SLOT_DRIVE) || M.slot == COMPUTER_SLOT_MEDIA)
		open_file = -1
		if (active_program == "files")
			active_program = ""
	M.forceMove(loc)
	if (H)
		H.put_in_hands(M)
	if (enabled && !operational())
		power_down()
	status_line = "Removed [M.name]."
	return TRUE
