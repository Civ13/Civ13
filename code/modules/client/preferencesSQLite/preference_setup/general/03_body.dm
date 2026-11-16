var/global/list/valid_bloodtypes = list("A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-")

/datum/category_item/player_setup_item/general/body
	name = "Body"
	sort_order = 3

/datum/category_item/player_setup_item/general/body/sanitize_character()
	if (!pref.species || !(pref.species in playable_species))
		pref.species = "Human"
	pref.r_hair			= sanitize_integer(pref.r_hair, FALSE, 255, initial(pref.r_hair))
	pref.g_hair			= sanitize_integer(pref.g_hair, FALSE, 255, initial(pref.g_hair))
	pref.b_hair			= sanitize_integer(pref.b_hair, FALSE, 255, initial(pref.b_hair))
	pref.r_facial		= sanitize_integer(pref.r_facial, FALSE, 255, initial(pref.r_facial))
	pref.g_facial		= sanitize_integer(pref.g_facial, FALSE, 255, initial(pref.g_facial))
	pref.b_facial		= sanitize_integer(pref.b_facial, FALSE, 255, initial(pref.b_facial))
	pref.s_tone			= sanitize_integer(pref.s_tone, -185, 34, initial(pref.s_tone))
	pref.r_skin			= sanitize_integer(pref.r_skin, FALSE, 255, initial(pref.r_skin))
	pref.g_skin			= sanitize_integer(pref.g_skin, FALSE, 255, initial(pref.g_skin))
	pref.b_skin			= sanitize_integer(pref.b_skin, FALSE, 255, initial(pref.b_skin))
	pref.h_style		= sanitize_inlist(pref.h_style, hair_styles_list, initial(pref.h_style))
	pref.f_style		= sanitize_inlist(pref.f_style, facial_hair_styles_list, initial(pref.f_style))
	pref.r_eyes			= sanitize_integer(pref.r_eyes, FALSE, 255, initial(pref.r_eyes))
	pref.g_eyes			= sanitize_integer(pref.g_eyes, FALSE, 255, initial(pref.g_eyes))
	pref.b_eyes			= sanitize_integer(pref.b_eyes, FALSE, 255, initial(pref.b_eyes))
	pref.b_type			= sanitize_text(pref.b_type, initial(pref.b_type))
