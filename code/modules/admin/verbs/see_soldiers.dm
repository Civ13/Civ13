/client/proc/see_soldiers()
	set name = "See Soldiers"
	set category = "Special"

	if (!check_rights(R_MOD))
		src << "<span class = 'danger'>You don't have the permissions.</span>"
		return

	var/i2faction[24]
	i2faction[1] = BRITISH
	i2faction[2] = PIRATES
	i2faction[3] = INDIANS
	i2faction[4] = FRENCH
	i2faction[5] = SPANISH
	i2faction[6] = PORTUGUESE
	i2faction[7] = DUTCH
	i2faction[8] = CIVILIAN
	i2faction[9] = ROMAN
	i2faction[10] = GREEK
	i2faction[11] = ARAB
	i2faction[12] = JAPANESE
	i2faction[13] = RUSSIAN
	i2faction[14] = GERMAN
	i2faction[15] = AMERICAN
	i2faction[16] = VIETNAMESE
	i2faction[17] = CHINESE
	i2faction[18] = FILIPINO
	i2faction[19] = CHECHEN
	i2faction[20] = FINNISH
	i2faction[21] = NORWEGIAN
	i2faction[22] = SWEDISH
	i2faction[23] = DANISH
	i2faction[24] = POLISH
	for (var/i in TRUE to 24)
		var/faction = i2faction[i]
		src << "<i># of [faction] total members:</i> <b>[soldiers[faction]]</b>"
