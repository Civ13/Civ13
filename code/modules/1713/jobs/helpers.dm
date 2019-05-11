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
		if (DUTCH)
			for (var/mob/living/carbon/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == DUTCH)
						BATTLEREPORT_VARIABLE_CHECK(H)
							++.
		if (JAPANESE)
			for (var/mob/living/carbon/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == JAPANESE)
						BATTLEREPORT_VARIABLE_CHECK(H)
							++.
		if (RUSSIAN)
			for (var/mob/living/carbon/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == RUSSIAN)
						BATTLEREPORT_VARIABLE_CHECK(H)
							++.
		if (ROMAN)
			for (var/mob/living/carbon/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == ROMAN)
						BATTLEREPORT_VARIABLE_CHECK(H)
							++.
		if (GREEK)
			for (var/mob/living/carbon/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == GREEK)
						BATTLEREPORT_VARIABLE_CHECK(H)
							++.
		if (ARAB)
			for (var/mob/living/carbon/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == ARAB)
						BATTLEREPORT_VARIABLE_CHECK(H)
							++.
		if (GERMAN)
			for (var/mob/living/carbon/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == GERMAN)
						BATTLEREPORT_VARIABLE_CHECK(H)
							++.

		if (AMERICAN)
			for (var/mob/living/carbon/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == AMERICAN)
						BATTLEREPORT_VARIABLE_CHECK(H)
							++.
		if (VIETNAMESE)
			for (var/mob/living/carbon/human/H in player_list)
				if (H.original_job && H.stat != DEAD)
					if (H.original_job.base_type_flag() == VIETNAMESE)
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
		if (DUTCH)
			return dead_dutch.len + heavily_injured_dutch.len + alive_dutch.len
		if (JAPANESE)
			return dead_japanese.len + heavily_injured_japanese.len + alive_japanese.len
		if (RUSSIAN)
			return dead_russian.len + heavily_injured_russian.len + alive_russian.len
		if (CIVILIAN)
			return dead_civilians.len + heavily_injured_civilians.len + alive_civilians.len
		if (ROMAN)
			return dead_roman.len + heavily_injured_roman.len + alive_roman.len
		if (GREEK)
			return dead_greek.len + heavily_injured_greek.len + alive_greek.len
		if (ARAB)
			return dead_arab.len + heavily_injured_arab.len + alive_arab.len
		if (GERMAN)
			return dead_german.len + heavily_injured_german.len + alive_german.len
		if (AMERICAN)
			return dead_american.len + heavily_injured_american.len + alive_american.len
		if (VIETNAMESE)
			return dead_vietnamese.len + heavily_injured_vietnamese.len + alive_vietnamese.len