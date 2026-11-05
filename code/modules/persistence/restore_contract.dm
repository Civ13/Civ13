// Restore contract. A world load builds each saved atom with new type(loc)
// before any saved field arrives, then applies the fields, then calls
// persistence_import_fields() for that entry, then after_load() once the
// whole level is in. The saver omits a field still at its compiled default,
// so a constructor that moves a field off its default under restore keeps
// that value after the load (a loaded round that comes back spent, a casing
// that jumps to a random offset).
//
// - restoring is TRUE from the start of /atom/New until after_load() has run.
//   Code that runs before ..() in a constructor reads
//   persistence_saved_atom_construction instead.
// - on_runtime_spawn() holds first-spawn work: random looks, starting
//   inventory, initial reagents, loops that start the object's life. /atom/New
//   calls it for every creation that is not a restore, map placement included.
// - Anything derived from a saved field is rebuilt in after_load() (or in
//   persistence_import_fields() when it needs to know which fields the save
//   held), never in New() and never by a timer.
//
// tests/load_construction builds every saveable type under restore and fails
// on a scalar field the constructor moved off its default.

/atom/var/tmp/restoring = FALSE

/atom/New()
	if (persistence_saved_atom_construction)
		restoring = TRUE
	. = ..()
	if (!restoring)
		on_runtime_spawn()

/atom/proc/on_runtime_spawn()
	return

/atom/persistence_runtime_var(key)
	return key == "restoring" || ..()

/atom/persistence_restore_finished()
	..()
	restoring = FALSE

// Many constructors scatter an item with a random pixel offset. The saver
// omits an offset still at its default, so without this a restored item that
// sat centred would land at a fresh random offset on every load. Allowlisted
// types already restore every omitted field to its default.
/atom/persistence_reset_omitted_fields(list/saved_fields)
	..()
	if (persistence_uses_field_allowlist())
		return
	if (!("pixel_x" in saved_fields) && pixel_x != initial(pixel_x))
		pixel_x = initial(pixel_x)
	if (!("pixel_y" in saved_fields) && pixel_y != initial(pixel_y))
		pixel_y = initial(pixel_y)
