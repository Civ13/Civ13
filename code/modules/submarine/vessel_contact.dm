/datum/vessel_contact
	var/name = "Unknown"
	var/bearing = 0           // 0-360 degrees relative to North
	var/range = 0             // Distance in meters
	var/noise_signature = 0   // Decibels or frequency ID
	var/contact_type = SUB_CONTACT_SURFACE
	var/nationality = SUB_NATION_NEUTRAL

/datum/vessel_contact/New(var/_name, var/_type, var/_nat)
	name = _name
	contact_type = _type
	nationality = _nat