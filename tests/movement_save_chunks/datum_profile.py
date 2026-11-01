"""Opt-in copied-packet identity timing; never edit production files."""


EXPECTED_SAVER_REF_SITES = 13

def instrument_datum_references(name, source):
    if name == 'code/modules/persistence/saving.dm':
        needle = '"\\ref[A]"'
        if source.count(needle) != EXPECTED_SAVER_REF_SITES: raise ValueError('Native datum reference sites changed')
        start = '/map_storage/proc/drain_moving_save_roster('
        end = '\n#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL'
        if source.count(start) != 1: raise ValueError('Drain boundary changed')
        tail = source.split(start, 1)[1]
        if end not in tail: raise ValueError('Drain boundary changed')
        drain = tail.split(end, 1)[0]
        anchor = '\t\tif(!A || record["atom"] != A || "\\ref[A]" != identity || !moving_save_root_supported(A) || A.z != saving_z)\n\t\t\tthrow EXCEPTION("Moving save roster member changed after drain checkpoint")'
        if drain.count(anchor) != 1 or drain.index('save_work_check()') > drain.index(anchor): raise ValueError('Final drain reference guard changed')
        source = source.replace(needle, 'profile_native_identity(A)')
        anchor = '\tproc/check()\n'
        if source.count(anchor) != 1: raise ValueError('Capture checker changed')
        source = source.replace(anchor, '\tvar/profile_native_ref_peak = 0\n\tvar/profile_native_ref_type = "none"\n' + anchor)
        anchor = 'start_usage=[start_usage]")'
        if source.count(anchor) != 1: raise ValueError('Budget diagnostic changed')
        source = source.replace(anchor, 'start_usage=[start_usage] native_ref_peak=[profile_native_ref_peak] native_ref_type=[profile_native_ref_type]")')
        source += '''
/map_storage/proc/profile_native_identity(datum/value)
	var/datum/moving_save_capture/profile = moving_save_chunk
	if(!profile) return "\\ref[value]"
	var/started = world.tick_usage
	var/identity = "\\ref[value]"
	var/cost = world.tick_usage - started
	if(cost > profile.profile_native_ref_peak)
		profile.profile_native_ref_peak = cost
		profile.profile_native_ref_type = value ? "[value.type]" : "null"
	return identity
'''
    elif name == 'code/modules/persistence/functions.dm':
        anchor = '/map_storage/proc/save_entry_identity(datum/A)\n'
        if source.count(anchor) != 1: raise ValueError('Identity helper declaration changed')
        head, body = source.split(anchor)
        body, tail = body.split('\n\n', 1)
        needle = 'return "\\ref[A]"'
        if body.count(needle) != 1: raise ValueError('Identity helper native reference changed')
        body = body.replace(needle, 'return profile_native_identity(A)')
        source = head + anchor + body + '\n\n' + tail
    return source


def restore_matrix_reference_identity(source):
    """Matrix-only omission control: remove the helper's direct-return branch."""
    anchor = '/map_storage/proc/save_entry_identity(datum/A)\n\tif(istype(A, /matrix)) return A\n\treturn "\\ref[A]"'
    if source.count(anchor) != 1: raise ValueError('Matrix identity baseline anchor changed')
    return source.replace(anchor, '/map_storage/proc/save_entry_identity(datum/A)\n\treturn "\\ref[A]"')


def restore_old_identity_keys(name, source):
    """Shared exact pre-optimization identity baseline for both native harnesses.

    Restores list keys, matrix helper string behavior and prior nonmovable
    roster/durable guards. This changes copied packets only, never source files.
    """
    if name == 'code/modules/persistence/functions.dm':
        return restore_matrix_reference_identity(source)
    if name == 'code/modules/persistence/saving.dm':
        replacements = (
            ('saving_lists[L]', 'saving_lists["\\ref[L]"]', 2),
            ('if(!moving_save_chunk && istype(A, /atom/movable) && moving_save_roots["\\ref[A]"])', 'if(!moving_save_chunk && moving_save_roots["\\ref[A]"])', 1),
            ('if(durable_export && istype(A, /atom/movable)) durable_export.bind_entry(A, saving_z, ref, src)', 'if(durable_export) durable_export.bind_entry(A, saving_z, ref, src)', 1),
        )
        for old, new, count in replacements:
            if source.count(old) != count: raise ValueError('Old identity baseline anchor changed: ' + old)
            source = source.replace(old, new)
    return source
