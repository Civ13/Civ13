// get all alive mobs of x faction
/proc/alive_n_of_side(x)
	. = 0
	switch (x)
		if (CIVILIAN)
			for (var/mob/living/carbon/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == CIVILIAN)
						BATTLEREPORT_VARIABLE_CHECK(H)
							++.
		if (BRITISH)
			for (var/mob/living/carbon/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == BRITISH)
						BATTLEREPORT_VARIABLE_CHECK(H)
							++.
		if (PIRATES)
			for (var/mob/living/carbon/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == PIRATES)
						BATTLEREPORT_VARIABLE_CHECK(H)
							++.
		if (SPANISH)
			for (var/mob/living/carbon/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == SPANISH)
						BATTLEREPORT_VARIABLE_CHECK(H)
							++.
		if (PORTUGUESE)
			for (var/mob/living/carbon/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == PORTUGUESE)
						BATTLEREPORT_VARIABLE_CHECK(H)
							++.
		if (FRENCH)
			for (var/mob/living/carbon/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == FRENCH)
						BATTLEREPORT_VARIABLE_CHECK(H)
							++.
		if (INDIANS)
			for (var/mob/living/carbon/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == INDIANS)
						BATTLEREPORT_VARIABLE_CHECK(H)
							++.

// get every single mob of x faction: useful for counting deceased & gibbed mobs. More efficient than n_of_side()
// currently does not support undead/pillarmen faction
/proc/total_n_of_side(x)
	. = 0
	switch (x)
		if (BRITISH)
			return dead_british.len + heavily_injured_british.len + alive_british.len
		if (PIRATES)
			return dead_pirates.len + heavily_injured_pirates.len + alive_pirates.len
		if (SPANISH)
			return dead_spanish.len + heavily_injured_spanish.len + alive_spanish.len
		if (PORTUGUESE)
			return dead_portuguese.len + heavily_injured_portuguese.len + alive_portuguese.len
		if (FRENCH)
			return dead_french.len + heavily_injured_french.len + alive_french.len
		if (INDIANS)
			return dead_indians.len + heavily_injured_indians.len + alive_indians.len


