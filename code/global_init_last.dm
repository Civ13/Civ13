// Keep this file as the last #include in civ13.dme.
//
// BYOND runs global variable initializers in include order. /datum/global_init
// fills catalogs declared all over the codebase (body builds, species, jobs,
// languages, configuration, chemistry). Created from code/world.dm, near the
// top of the include list, it ran before any of those lists existed and stopped
// at the first one with "bad index", leaving all_species and the rest empty.
// Created here, after every other global, it sees them all initialized.
var/global/datum/global_init/init = new ()
