// Operating systems and programs for modular computers. Each is one shared
// definition, built the first time any computer asks for it, so a computer
// only stores ids. These globals start empty: the world's global initialiser
// is at its size limit (docs: global initialiser limit), so nothing is built
// at startup.
var/global/list/computer_os_defs = null
var/global/list/computer_program_defs = null

/datum/computer_os
	var/id = ""
	var/name = ""
	var/version = ""
	// Window look: "cli" now; "desktop" and "mobile" in later ages.
	var/shell = "cli"
	// Lowest processor tier that runs it.
	var/min_cpu = 1
	// Programs that come with the OS.
	var/list/bundled = null
	var/list/boot_lines = null

/datum/computer_os/unga_cli
	id = "unga_cli"
	name = "Unga OS"
	version = "1969 edition"
	bundled = list("files")
	boot_lines = list("UNGA OS - 1969 EDITION", "CORE MEMORY CHECK ... OK", "TYPE A COMMAND OR CHOOSE ONE BELOW.")

/datum/computer_program
	var/id = ""
	var/name = ""
	var/desc = ""
	// Capabilities the computer's modules must grant.
	var/list/requires = null

/datum/computer_program/files
	id = "files"
	name = "Files"
	desc = "Write, read, print and copy text files."
	requires = list(COMPUTER_CAP_STORAGE)

/proc/computer_os_def(id)
	if (!computer_os_defs)
		computer_os_defs = list()
		for (var/T in subtypesof(/datum/computer_os))
			var/datum/computer_os/O = new T
			computer_os_defs[O.id] = O
	return computer_os_defs[id]

/proc/computer_program_def(id)
	if (!computer_program_defs)
		computer_program_defs = list()
		for (var/T in subtypesof(/datum/computer_program))
			var/datum/computer_program/P = new T
			computer_program_defs[P.id] = P
	return computer_program_defs[id]
