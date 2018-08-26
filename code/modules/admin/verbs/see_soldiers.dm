/client/proc/see_soldiers()
	set name = "See Soldiers"
	set category = "Special"

	if (!check_rights(R_MOD))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return

	var/i2faction[8]
	i2faction[1] = BRITISH
	i2faction[2] = PIRATES
	i2faction[3] = INDIANS
	i2faction[4] = FRENCH
	i2faction[5] = SPANISH
	i2faction[6] = PORTUGUESE
	i2faction[7] = DUTCH
	i2faction[8] = CIVILIAN

	for (var/i in TRUE to 6)
		var/faction = i2faction[i]
		src << "<i># of [faction] total members:</i> <b>[soldiers[faction]]</b>"
