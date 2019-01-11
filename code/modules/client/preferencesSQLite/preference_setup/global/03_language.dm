/datum/category_item/player_setup_item/player_global/language
	name = "Language"
	sort_order = 3

/datum/category_item/player_setup_item/player_global/language/content(var/mob/user)
	. += "<b>Language Keys</b><br><br>"
	. += " [english_list(config.language_prefixes, and_text = " ", comma_text = " ")]<br>"

/datum/category_item/player_setup_item/player_global/language/OnTopic(var/href, var/list/href_list, var/mob/user)
	return ..()

