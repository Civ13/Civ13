"""Opt-in copied-packet identity timing; never edit production files."""


EXPECTED_SAVER_REF_SITES = 15

def instrument_datum_references(name, source):
    if name == 'code/modules/persistence/saving.dm':
        needle = '"\\ref[A]"'
        if source.count(needle) != EXPECTED_SAVER_REF_SITES: raise ValueError('Native datum reference sites changed')
        source = source.replace(needle, 'profile_native_identity(A)')
        anchor = '\tproc/check()\n'
        if source.count(anchor) != 1: raise ValueError('Capture checker changed')
        source = source.replace(anchor, '\tvar/profile_native_ref_peak = 0\n\tvar/profile_native_ref_type = "none"\n' + anchor)
        anchor = 'elapsed_ds=[elapsed_ds]")'
        if source.count(anchor) != 1: raise ValueError('Budget diagnostic changed')
        source = source.replace(anchor, 'elapsed_ds=[elapsed_ds] native_ref_peak=[profile_native_ref_peak] native_ref_type=[profile_native_ref_type]")')
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
        needle = '"\\ref[frame.source]"'
        if source.count(needle) != 1: raise ValueError('Frame source reference site changed')
        source = source.replace(needle, 'profile_native_identity(frame.source)')
    return source
