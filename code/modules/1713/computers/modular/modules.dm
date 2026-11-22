// Hardware modules for modular computers. A module is an ordinary item: it
// saves with the chassis as contents and can be carried, traded or stolen.
// Each one grants capabilities; programs list the capabilities they need.
// Anything that holds files (drives and diskettes) keeps them in two parallel
// text lists, so a save stores plain strings only.
/obj/item/computer_module
	name = "computer module"
	desc = "A part for a modular computer."
	icon = 'icons/obj/computers.dmi'
	icon_state = "generic_chip"
	w_class = ITEM_SIZE_SMALL
	flammable = FALSE
	// Which chassis slot it fits; null for media that goes into a reader.
	var/slot = null
	var/tier = 1
	// Ordinal age the part belongs to (7 = 1969, 8 = 2013, 9 = 2026).
	var/module_age = 7
	var/list/capabilities = null
	// File storage, in KB of 1,000 characters. 0 = holds no files.
	var/capacity_kb = 0
	var/list/file_names = null
	var/list/file_bodies = null

/obj/item/computer_module/examine(mob/user)
	..()
	if (capacity_kb)
		to_chat(user, "It holds [file_count()] file\s, [computer_kb_text(used_chars())] of [capacity_kb] KB used.")
	else if (tier > 1)
		to_chat(user, "It is a tier [tier] part.")

/proc/computer_kb_text(chars)
	return "[round(chars / COMPUTER_CHARS_PER_KB, 0.1)] KB"

/proc/computer_clean_file_name(name)
	name = uppertext(trim(sanitize(copytext("[name]", 1, COMPUTER_FILE_NAME_MAX * 2), COMPUTER_FILE_NAME_MAX)))
	return copytext(name, 1, COMPUTER_FILE_NAME_MAX + 1)

/obj/item/computer_module/proc/detail_text()
	if (capacity_kb)
		return "[computer_kb_text(used_chars())] of [capacity_kb] KB"
	return "tier [tier]"

/obj/item/computer_module/proc/file_count()
	return file_names ? file_names.len : 0

/obj/item/computer_module/proc/used_chars()
	. = 0
	for (var/i = 1 to file_count())
		. += length(file_names[i]) + length(file_bodies[i])

/obj/item/computer_module/proc/file_size_kb(i)
	return round((length(file_names[i]) + length(file_bodies[i])) / COMPUTER_CHARS_PER_KB, 0.1)

/obj/item/computer_module/proc/file_index(name)
	return file_names ? file_names.Find(name) : 0

// Writes or replaces a file. Returns "" on success, otherwise the reason.
/obj/item/computer_module/proc/write_file(name, body, replace_index = 0)
	if (!capacity_kb)
		return "This holds no files."
	name = computer_clean_file_name(name)
	if (!length(name))
		return "Give the file a name."
	body = copytext("[body]", 1, COMPUTER_FILE_MAX_CHARS + 1)
	var/existing = file_index(name)
	if (existing && existing != replace_index)
		return "A file named [name] already exists."
	var/freed = 0
	if (replace_index)
		if (replace_index < 1 || replace_index > file_count())
			return "That file is gone."
		freed = length(file_names[replace_index]) + length(file_bodies[replace_index])
	else if (file_count() >= COMPUTER_FILES_PER_MEDIUM)
		return "No room for more files."
	if (used_chars() - freed + length(name) + length(body) > capacity_kb * COMPUTER_CHARS_PER_KB)
		return "Not enough space."
	if (!file_names)
		file_names = list()
		file_bodies = list()
	if (replace_index)
		file_names[replace_index] = name
		file_bodies[replace_index] = body
	else
		file_names += name
		file_bodies += body
	return ""

/obj/item/computer_module/proc/delete_file(i)
	if (i < 1 || i > file_count())
		return FALSE
	file_names.Cut(i, i + 1)
	file_bodies.Cut(i, i + 1)
	if (!file_names.len)
		file_names = null
		file_bodies = null
	return TRUE

/obj/item/computer_module/proc/file_list()
	. = list()
	for (var/i = 1 to file_count())
		. += list(list("index" = i, "name" = file_names[i], "size_kb" = file_size_kb(i)))

// --- Processors: run the OS --------------------------------------------------

/obj/item/computer_module/processor
	name = "transistor logic board"
	desc = "A board of discrete transistors that runs a simple operating system."
	icon_state = "cpu_chip"
	slot = COMPUTER_SLOT_CPU
	capabilities = list(COMPUTER_CAP_CPU)

/obj/item/computer_module/processor/microprocessor
	name = "microprocessor"
	desc = "A whole processor on one chip."
	icon_state = "cpu_chip_blue"
	tier = 2
	module_age = 8

/obj/item/computer_module/processor/multicore
	name = "multicore processor"
	desc = "A chip with several processor cores."
	icon_state = "chip_small"
	tier = 3
	module_age = 9

// --- Storage: holds files ---------------------------------------------------

/obj/item/computer_module/storage
	name = "tape drive"
	desc = "A reel-to-reel magnetic tape unit. It stores files inside the computer."
	icon_state = "tape"
	slot = COMPUTER_SLOT_DRIVE
	capabilities = list(COMPUTER_CAP_STORAGE)
	capacity_kb = 16

/obj/item/computer_module/storage/hard_drive
	name = "hard drive"
	desc = "Spinning magnetic platters in a sealed case."
	icon_state = "card_small"
	tier = 2
	module_age = 8
	capacity_kb = 64

/obj/item/computer_module/storage/solid_state
	name = "solid-state drive"
	desc = "Flash memory with no moving parts."
	icon_state = "card_ram"
	tier = 3
	module_age = 9
	capacity_kb = 256

// --- Removable media ----------------------------------------------------------

/obj/item/computer_module/media_reader
	name = "diskette drive"
	desc = "Reads and writes data diskettes."
	icon_state = "floppy_drive"
	slot = COMPUTER_SLOT_MEDIA
	capabilities = list(COMPUTER_CAP_MEDIA)

/obj/item/computer_module/media_reader/proc/disk()
	return locate(/obj/item/computer_module/disk) in contents

/obj/item/computer_module/disk
	name = "data diskette"
	desc = "A flexible magnetic disk in a paper sleeve. Put it in a computer's diskette drive."
	icon_state = "5.25_inch_floppy"
	w_class = ITEM_SIZE_TINY
	capacity_kb = 4

// --- Expansion: printer -------------------------------------------------------

/obj/item/computer_module/printer
	name = "line printer"
	desc = "Prints files on paper. Load paper by using it on the computer."
	icon_state = "card_video"
	slot = COMPUTER_SLOT_EXPANSION
	capabilities = list(COMPUTER_CAP_PRINT)
	var/paper = 0

/obj/item/computer_module/printer/detail_text()
	return "[paper] sheet\s of paper"
