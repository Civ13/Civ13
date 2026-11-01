"""Prepare a deterministic fixture-only lighting yield seam; does not execute DM."""

CASES = ("positive", "qdel", "hard_null", "atom_legacy", "atom_new", "turf_legacy",
         "turf_new", "omitted_guard", "replace_list", "change_level")


def instrument_loading(source):
    start = source.index("\t\t\tvar/list/lighting_entries = all_loaded\n")
    end = source.index("\t\t\tlog_startup_progress(", start)
    section = source[start:end]
    needle = "\t\t\t\tif(TICK_CHECK)\n"
    if section.count(needle) != 2:
        raise ValueError("Expected exactly two production lighting yield sites")
    for phase, name, call in (("opacity", "light_turf", "recalc_atom_opacity"),
                              ("light", "light_owner", "update_light")):
        original = f'\t\t\t\tif(!QDELETED({name}) && !{name}.gcDestroyed) {name}.{call}()'
        changed = (f'\t\t\t\tif((!QDELETED({name}) && !{name}.gcDestroyed) || '
                   f'(lighting_interleave_omit_guard && {name} == lighting_interleave_target))\n'
                   f'\t\t\t\t\tlighting_interleave_record("{phase}", {name})\n'
                   f'\t\t\t\t\t{name}.{call}()')
        if section.count(original) != 1:
            raise ValueError("Expected one retirement guard for " + phase)
        section = section.replace(original, changed, 1)
    section = section.replace(needle,
        '\t\t\t\tif(lighting_interleave_checkpoint(src, operation, "opacity", B) || TICK_CHECK)\n', 1)
    section = section.replace(needle,
        '\t\t\t\tif(lighting_interleave_checkpoint(src, operation, "light", B) || TICK_CHECK)\n', 1)
    if section.count("!operation.current(src, \"load\") || all_loaded != lighting_entries || loading_z != B") != 2:
        raise ValueError("Production ownership checks drifted")
    return source[:start] + section + source[end:]
