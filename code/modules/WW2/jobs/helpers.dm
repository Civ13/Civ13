// get all alive mobs of x faction
/proc/alive_n_of_side(x)
	. = 0
	switch (x)
		if (PARTISAN)
			for (var/mob/living/carbon/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == PARTISAN)
						BATTLEREPORT_VARIABLE_CHECK(H)
							++.
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

// get every single mob of x faction: useful for counting deceased & gibbed mobs. More efficient than n_of_side()
// currently does not support undead/pillarmen faction
/proc/total_n_of_side(x)
	. = 0
	switch (x)
		if (PARTISAN)
			return dead_partisans.len + heavily_injured_partisans.len + alive_partisans.len
		if (CIVILIAN)
			return dead_civilians.len + heavily_injured_civilians.len + alive_civilians.len
		if (BRITISH)
			return dead_british.len + heavily_injured_british.len + alive_british.len
		if (PIRATES)
			return dead_pirates.len + heavily_injured_pirates.len + alive_pirates.len


