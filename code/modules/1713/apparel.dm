/obj/item/clothing/under
	var/swapped = FALSE

/obj/item/clothing/under/chad
	name = "chad clothing"
	desc = "Wow!"
	icon_state = "chad"
	item_state = "chad"
	worn_state = "chad"

/obj/item/clothing/shoes/chad
	name = "chad shoes"
	desc = "Ouch!"
	icon_state = "chad"
	item_state = "chad"
	worn_state = "chad"
	force = WEAPON_FORCE_WEAK

/obj/item/clothing/shoes/flipflops
	name = "flip-flops"
	desc = "Brazilian style flip-flops."
	icon_state = "flipflops"
	item_state = "flipflops"
	worn_state = "flipflops"
	force = WEAPON_FORCE_WEAK

/obj/item/clothing/under/squid_contestant
	name = "contestant clothing"
	desc = "regular jumpsuit for contestants"
	icon_state = "squid_player"
	item_state = "squid_player"
	worn_state = "squid_player"

/obj/item/clothing/suit/storage/jacket/squid_coat
	name = "contestant jacket"
	desc = "A simple green jumpsuit jacket."
	icon_state = "squid_player"
	item_state = "squid_player"
	worn_state = "squid_player"

///////////////////////////////////////////////////////////////////
/// Majority of the Sprites under this is made by Mane from TGMC///
///////////////////////////////////////////////////////////////////

// Star Wars Outfits//

/obj/item/clothing/under/bodyglove
	name = "replicant black bodyglove"
	desc = "A tight bodyglove worn by troopers."
	icon_state = "replicant_bodyglove"
	item_state = "replicant_bodyglove"
	worn_state = "replicant_bodyglove"

//////////////////Imperial Tunics and Caps///////////////////////////////////////////////////////////////////////////////////////////////////////////////

/obj/item/clothing/under/impstormofficer
	name = "imperial stormtrooper officer uniform"
	desc = "A double-breasted black tunic rank and trousers with a metal plac denoting rank for NCO's in the Stormtrooper Corps."
	icon_state = "imp_stormofficer"
	item_state = "imp_stormofficer"
	worn_state = "imp_stormofficer"

/obj/item/clothing/under/impnavyofficer
	name = "imperial stormtrooper officer uniform"
	desc = "A double-breasted olive-green tunic rank and trousers with a metal plac denoting rank for CO's in the Imperial Navy."
	icon_state = "impofficer_captain"
	item_state = "impofficer_captain"
	worn_state = "impofficer_captain"

/obj/item/clothing/under/imptechnician
	name = "imperial technician grey uniform"
	desc = "A grey jumpsuit for technician's in the Engineering Corps."
	icon_state = "imp_technician_grey"
	item_state = "imp_technician_grey"
	worn_state = "imp_technician_grey"

/obj/item/clothing/under/imptechnician2
	name = "imperial technician blue uniform"
	desc = "A blue jumpsuit for technician's in the Engineering Corps."
	icon_state = "imp_technician_blue"
	item_state = "imp_technician_blue"
	worn_state = "imp_technician_blue"

/obj/item/clothing/under/imptechnician3
	name = "imperial technician black uniform"
	desc = "A black jumpsuit for technician's in the Engineering Corps."
	icon_state = "imp_technician_black"
	item_state = "imp_technician_black"
	worn_state = "imp_technician_black"

/obj/item/clothing/head/impcaptaincap
	name = "imperial naval officer cap"
	desc = "a tight fitting green cap."
	icon_state = "repnavalcaptain_ca"
	item_state = "repnavalcaptain_cap"
	worn_state = "repnavalcaptain_cap"

/obj/item/clothing/head/impstormcap
	name = "imperial black field cap"
	desc = "a tight fitting black cap worn by Stormtrooper CORPS Officers, Naval Lieutenants, and Technicians."
	icon_state = "impofficer_storm"
	item_state = "impofficer_storm"
	worn_state = "impofficer_storm"

/////////////////Republic Tunics and Caps////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/obj/item/clothing/under/repensignofficer
	name = "republic ensign uniform"
	desc = "A double-breasted blue-grey tunic and trousers for NCO's in the Republic Navy."
	icon_state = "repofficer_ensign"
	item_state = "repofficer_ensign"
	worn_state = "repofficer_ensign"

/obj/item/clothing/under/repmedicalofficer
	name = "republic medical officer"
	desc = "A double-breasted white-grey tunic and trousers for NCO's in the Republic Medical Corps."
	icon_state = "repofficer_medical"
	item_state = "repofficer_medical"
	worn_state = "repofficer_medical"

/obj/item/clothing/under/repnavyofficer
	name = "republic naval officer uniform"
	desc = "A double-breasted olive-green tunic rank and trousers with a metal plac denoting rank for CO's in the Republic Navy."
	icon_state = "repofficer_navcaptain"
	item_state = "repofficer_navcaptain"
	worn_state = "repofficer_navcaptain"

/obj/item/clothing/head/repcaptaincap
	name = "republic naval officer cap"
	desc = "a tight fitting green cap."
	icon_state = "repnavalcaptain_cap"
	item_state = "repnavalcaptain_cap"
	worn_state = "repnavalcaptain_cap"

/obj/item/clothing/head/repensigncap
	name = "republic naval ensign cap"
	desc = "a tight fitting blue grey cap."
	icon_state = "repensign_cap"
	item_state = "repensign_cap"
	worn_state = "repensign_cap"

/obj/item/clothing/head/repmedicalcap
	name = "republic medical officer cap"
	desc = "a tight fitting grey cap."
	icon_state = "repmedicalofficer_cap"
	item_state = "repmedicalofficer_cap"
	worn_state = "repmedicalofficer_cap"

/obj/item/clothing/head/impofficercap
	name = "imperial officer cap"
	desc = "a tight fitting grey cap."
	icon_state = "impofficer_storm"
	item_state = "impofficer_storm"
	worn_state = "impofficer_storm"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/obj/item/clothing/shoes/replicantshoes
	name = "plastoid boots"
	desc = "A pair of plastoid boots."
	icon_state = "replicant_boots"
	item_state = "replicant_boots"
	worn_state = "replicant_boots"
	body_parts_covered = FEET
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 45, arrow = 70, gun = 50, energy = 45, bomb = 35, bio = 15, rad = FALSE)
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE
	slowdown = 0.1
	health = 35

/obj/item/clothing/gloves/replicantgloves
	name = "plastoid gauntlets"
	desc = "A pair of armored plastoid gauntlets."
	icon_state = "replicant_gloves"
	item_state = "replicant_gloves"
	worn_state = "replicant_gloves"
	body_parts_covered = HANDS
	force = WEAPON_FORCE_PAINFUL
	armor = list(melee = 55, arrow = 60, gun = 30, energy = 48, bomb = 35, bio = 15, rad = FALSE)
	cold_protection = HANDS
	min_cold_protection_temperature = GLOVES_MIN_COLD_PROTECTION_TEMPERATURE
	slowdown = 0.1
	health = 30

// PLASTOID ARMOR

/obj/item/clothing/suit/armor/replicant
	name = "replicant trooper armor"
	desc = "A thick, expensive plastoid armor, covering most of the body."
	icon_state = "replicant_armor"
	item_state = "replicant_armor"
	worn_state = "replicant_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 45, arrow = 90, gun = 75, energy = 55, bomb = 60, bio = 20, rad = FALSE)
	value = 50
	slowdown = 1.5
	health = 60

/obj/item/clothing/suit/armor/replicant/pilot
	name = "replicant pilot armor"
	desc = "A thin, expensive plastoid armor, covering most of the body."
	icon_state = "reppilot_armor"
	item_state = "reppilot_armor"
	worn_state = "reppilot_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 25, arrow = 50, gun = 55, energy = 40, bomb = 50, bio = 20, rad = FALSE)
	value = 50
	slowdown = 1.5
	health = 60

/obj/item/clothing/suit/armor/replicant/mp
	name = "replicant MP armor"
	desc = "An extremely thick, expensive plastoid armor, covering most of the body."
	icon_state = "repmp_armor"
	item_state = "repmp_armor"
	worn_state = "repmp_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 25, arrow = 50, gun = 55, energy = 40, bomb = 50, bio = 20, rad = FALSE)
	value = 50
	slowdown = 1.5
	health = 60

/obj/item/clothing/suit/armor/replicant/sgt
	name = "replicant sergeant armor"
	desc = "A thick, expensive green marked plastoid armor, covering most of the body."
	icon_state = "repsgt_armor"
	item_state = "repsgt_armor"
	worn_state = "repsgt_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 45, arrow = 90, gun = 75, energy = 55, bomb = 60, bio = 20, rad = FALSE)
	value = 50
	slowdown = 1.5
	health = 60

/obj/item/clothing/suit/armor/replicant/lieutenant
	name = "replicant lieutenant armor"
	desc = "A thick, expensive blue marked plastoid armor, covering most of the body."
	icon_state = "replieutenant_armor"
	item_state = "replieutenant_armor"
	worn_state = "replieutenant_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 45, arrow = 90, gun = 75, energy = 55, bomb = 60, bio = 20, rad = FALSE)
	value = 50
	slowdown = 1.5
	health = 60

/obj/item/clothing/suit/armor/replicant/captain
	name = "replicant captain armor"
	desc = "A thick, expensive red marked plastoid armor, covering most of the body."
	icon_state = "repcaptain_armor"
	item_state = "repcaptain_armor"
	worn_state = "repcaptain_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 45, arrow = 90, gun = 75, energy = 55, bomb = 60, bio = 20, rad = FALSE)
	value = 50
	slowdown = 1.5
	health = 60

/obj/item/clothing/suit/armor/replicant/commander
	name = "replicant commander armor"
	desc = "A thick, expensive gold marked plastoid armor, covering most of the body."
	icon_state = "repcommander_armor"
	item_state = "repcommander_armor"
	worn_state = "repcommander_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 55, arrow = 95, gun = 85, energy = 55, bomb = 60, bio = 20, rad = FALSE)
	value = 50
	slowdown = 1.5
	health = 60

/obj/item/clothing/suit/armor/stormtrooper
	name = "stormtrooper armor"
	desc = "A thick, expensive imperial plastoid armor, covering most of the body."
	icon_state = "stormtrooper_armor"
	item_state = "stormtrooper_armor"
	worn_state = "stormtrooper_armor"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	armor = list(melee = 65, arrow = 96, gun = 88, energy = 75, bomb = 60, bio = 20, rad = FALSE)
	value = 50
	slowdown = 1.5
	health = 100

// HELMETS

/obj/item/clothing/head/helmet/replicant/ARF
	name = "Phase I Replicant ARF Helmet"
	desc = "A reinforced plastoid helmet of the Republic Army."
	icon_state = "repARF_helmet"
	item_state = "repARF_helmet"
	worn_state = "repARF_helmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 30, arrow = 50, gun = 40, energy = 45, bomb = 30, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/replicant/airborne
	name = "Phase I Replicant Airborne Helmet"
	desc = "A reinforced airborne helmet of the Republic Army."
	icon_state = "repairborne_helmet"
	item_state = "repairborne_helmet"
	worn_state = "repairborne_helmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 35, arrow = 50, gun = 35, energy = 55, bomb = 40, bio = 30, rad = FALSE)

/obj/item/clothing/head/helmet/replicant/stormtrooper
	name = "Replicant Stormtrooper Helmet"
	desc = "A reinforced helmet of the Imperial Army."
	icon_state = "repstormtrooper_helmet"
	item_state = "repstormtrooper_helmet"
	worn_state = "repstormtrooper_helmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 45, arrow = 60, gun = 65, energy = 60, bomb = 30, bio = 30, rad = FALSE)

/obj/item/clothing/head/helmet/replicant
	name = "Phase I Replicant Trooper Helmet"
	desc = "A reinforced plastoid helmet of the Republic Army."
	icon_state = "replicant_helmet"
	item_state = "replicant_helmet"
	worn_state = "replicant_helmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 30, arrow = 50, gun = 40, energy = 55, bomb = 30, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/replicant2
	name = "Phase II Replicant Trooper Helmet"
	desc = "A phase II helmet used by clone troopers of the Republic Army."
	icon_state = "replicant_helmet2"
	item_state = "replicant_helmet2"
	worn_state = "replicant_helmet2"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 40, arrow = 60, gun = 40, energy = 58, bomb = 30, bio = 20, rad = FALSE)


/obj/item/clothing/head/helmet/replicant/pilot
	name = "Phase I Replicant Pilot Helmet"
	desc = "A reinforced plastoid helmet of the Republic Army."
	icon_state = "reppilot_helmet"
	item_state = "reppilot_helmet"
	worn_state = "reppilot_helmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 30, arrow = 50, gun = 40, energy = 55, bomb = 30, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/replicant/MP
	name = "Phase I Replicant MP Helmet"
	desc = "A highly reinforced plastoid helmet of the Republic Army."
	icon_state = "repmp_helmet"
	item_state = "repmp_helmet"
	worn_state = "repmp_helmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 30, arrow = 50, gun = 40, energy = 45, bomb = 30, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/replicant/sgt
	name = "Phase I Replicant Sergeant Helmet"
	desc = "A reinforced plastoid helmet of the Republic Army."
	icon_state = "repsgt_helmet"
	item_state = "repsgt_helmet"
	worn_state = "repsgt_helmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 30, arrow = 50, gun = 40, energy = 55, bomb = 30, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/replicant/lt
	name = "Phase I Replicant Lieutenant Helmet"
	desc = "A reinforced plastoid helmet of the Republic Army."
	icon_state = "replt_helmet"
	item_state = "replt_helmet"
	worn_state = "replt_helmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 30, arrow = 50, gun = 40, energy = 55, bomb = 30, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/replicant/captain
	name = "Phase I Replicant Captain Helmet"
	desc = "A reinforced plastoid helmet of the Republic Army."
	icon_state = "repcaptain_helmet"
	item_state = "repcaptain_helmet"
	worn_state = "repcaptain_helmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 30, arrow = 50, gun = 40, energy = 55, bomb = 30, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/replicant/commander
	name = "Phase I Replicant Commander Helmet"
	desc = "A reinforced plastoid helmet of the Republic Army."
	icon_state = "repcommander_helmet"
	item_state = "repcommander_helmet"
	worn_state = "repcommander_helmet"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 30, arrow = 50, gun = 40, energy = 55, bomb = 30, bio = 20, rad = FALSE)

// OFFICER UNIFORMS //

/obj/item/clothing/under/navalcaptain
	name = "republic naval captain uniform"
	desc = "A well adjusted captain's jacket."
	icon_state = "repcaptain_uniform"
	item_state = "repcaptain_uniform"
	worn_state = "repcaptain_uniform"

/obj/item/clothing/under/navalensign
	name = "republic naval ensign uniform"
	desc = "A well adjusted ensign's jacket."
	icon_state = "repensign_uniform"
	item_state = "repensign_uniform"
	worn_state = "repensign_uniform"

/obj/item/clothing/under/navalsurgeon
	name = "republic medical officer uniform"
	desc = "A well adjusted medical jacket."
	icon_state = "repmedical_uniform"
	item_state = "repmedical_uniform"
	worn_state = "repmedical_uniform"

/obj/item/clothing/under/dartharmor
	name = "black cybernetic armor"
	desc = "A dark mechanical armor made for souless individuals."
	icon_state = "darth_armor"
	item_state = "darth_armor"
	worn_state = "darth_armor"

/obj/item/clothing/under/navallieutenant
	name = "imperial naval lieutenant uniform"
	desc = "A well adjusted lieutenant's jacket."
	icon_state = "imp_stormofficer"
	item_state = "imp_stormofficer"
	worn_state = "imp_stormofficer"

////////////IRISH BERET/////////////////////////////////////////////////////////////

/obj/item/clothing/head/caubeen
	name = "caubeen"
	desc = "an Irish beret, typically in dark green color."
	icon_state = "caubeen"
	item_state = "caubeen"
	worn_state = "caubeen"


////////////////////////////////////////////////////////////////////////////////////

/obj/item/clothing/under/wise_tutor
	name = "wise tutor's outfit"
	desc = "A loose outfit worn by the wise & experienced."
	icon_state = "wise_tutor"
	item_state = "wise_tutor"
	worn_state = "wise_tutor"

/obj/item/clothing/under/wise_tutor2
	name = "wise tutor's alternative outfit"
	desc = "A loose outfit worn by the wise & experienced."
	icon_state = "wise_tutor2"
	item_state = "wise_tutor2"
	worn_state = "wise_tutor2"

/obj/item/clothing/under/wise_disciple
	name = "wise disciple outfit"
	desc = "A loose outfit worn by the unwise & unexperienced."
	icon_state = "wise_tutor3"
	item_state = "wise_tutor3"
	worn_state = "wise_tutor3"

/obj/item/clothing/under/arrogant_student
	name = "arrogant student's outfit"
	desc = "A loose outfit worn by arrogant students."
	icon_state = "arrogant_student"
	item_state = "arrogant_student"
	worn_state = "arrogant_student"

/obj/item/clothing/suit/storage/coat/wise_tutor_robes
	name = "wise tutor robes"
	desc = "Robes commonly worn by wise tutors."
	icon_state = "wise_tutor_robe"
	item_state = "wise_tutor_robe"
	worn_state = "wise_tutor_robe"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 65
	flags_inv = BLOCKHEADHAIR

/obj/item/clothing/suit/storage/coat/wise_tutor_robes/verb/toggle_hood()
	set category = null
	set src in usr
	set name = "Toggle Hood"
	if (hood)
		icon_state = "wise_tutor_robe"
		item_state = "wise_tutor_robe"
		worn_state = "wise_tutor_robe"
		body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
		cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
		item_state_slots["slot_wear_suit"] = "wise_tutor_robe"
		usr << "<span class = 'danger'>you take off your robes' hood.</span>"
		update_icon()
		hood = FALSE
		usr.update_inv_head(1)
		usr.update_inv_wear_suit(1)
		return
	else if (!hood)
		icon_state = "wise_tutor_hooded"
		item_state = "wise_tutor_hooded"
		worn_state = "wise_tutor_hooded"
		body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS|HEAD
		cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT|HEAD
		item_state_slots["slot_wear_suit"] = "wise_tutor_hooded"
		usr << "<span class = 'danger'>you cover your head with your robes' hood.</span>"
		update_icon()
		hood = TRUE
		usr.update_inv_head(1)
		usr.update_inv_wear_suit(1)
		return

/obj/item/clothing/suit/storage/coat/arrogant_student_robes
	name = "arrogant student robes"
	desc = "Robes commonly worn by spiteful students."
	icon_state = "arrogant_student_robe"
	item_state = "arrogant_student_robe"
	worn_state = "arrogant_student_robe"
	body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
	cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
	armor = list(melee = 10, arrow = 0, gun = FALSE, energy = 15, bomb = 5, bio = 30, rad = 30)
	value = 65
	flags_inv = BLOCKHEADHAIR

/obj/item/clothing/suit/storage/coat/arrogant_student_robes/verb/toggle_hood()
	set category = null
	set src in usr
	set name = "Toggle Hood"
	if (hood)
		icon_state = "arrogant_student_robe"
		item_state = "arrogant_student_robe"
		worn_state = "arrogant_student_robe"
		body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS
		cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT
		item_state_slots["slot_wear_suit"] = "arrogant_student_robe"
		usr << "<span class = 'danger'>you take off your robes' hood.</span>"
		update_icon()
		hood = FALSE
		usr.update_inv_head(1)
		usr.update_inv_wear_suit(1)
		return
	else if (!hood)
		icon_state = "arrogant_student_robe_hooded"
		item_state = "arrogant_student_robe_hooded"
		worn_state = "arrogant_student_robe_hooded"
		body_parts_covered = UPPER_TORSO|LOWER_TORSO|LEGS|ARMS|HEAD
		cold_protection = UPPER_TORSO|LOWER_TORSO|LEG_LEFT|LEG_RIGHT|ARM_LEFT|ARM_RIGHT|HEAD
		item_state_slots["slot_wear_suit"] = "arrogant_student_robe_hooded"
		usr << "<span class = 'danger'>you cover your head with your robes' hood.</span>"
		update_icon()
		hood = TRUE
		usr.update_inv_head(1)
		usr.update_inv_wear_suit(1)
		return

/obj/item/clothing/shoes/heavyboots/wrappedboots
	name = "\improper wrapped boots"
	icon_state = "wrappedboots"
	force = WEAPON_FORCE_WEAK
	armor = list(melee = 80, arrow = 10, gun = FALSE, energy = 25, bomb = 50, bio = 10, rad = 40)
	item_flags = NOSLIP
	siemens_coefficient = 0.6
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

/obj/item/clothing/suit/storage/hazard
	name = "hazard vest"
	desc = "A vest used for high visibility and reflectivity."
	icon_state = "hazard"
	item_state = "hazard"
	worn_state = "hazard"

/obj/item/clothing/suit/storage/hazard/blue
	name = "blue hazard vest"
	desc = "A vest used for high visibility and reflectivity."
	icon_state = "hazard_b"
	item_state = "hazard_b"
	worn_state = "hazard_b"

/obj/item/clothing/suit/storage/hazard/yellow
	name = "yellow high visibility vest"
	desc = "A vest used for high visibility and reflectivity."
	icon_state = "hazard_y"
	item_state = "hazard_y"
	worn_state = "hazard_y"
	w_class = 1.0

/obj/item/clothing/suit/storage/hazard/green
	name = "green hazard vest"
	desc = "A vest used for high visibility and reflectivity."
	icon_state = "hazard_g"
	item_state = "hazard_g"
	worn_state = "hazard_g"

/obj/item/clothing/suit/storage/sealvest
	name = "seal lifevest"
	desc = "A vest used for keeping the seals afloat during training among other things."
	icon_state = "sealvest"
	item_state = "sealvest"
	worn_state = "sealvest"


/////////////////REBELS///////////////////////////////////////////
/obj/item/clothing/head/helmet/rebel
	name = "Rebel Fleet Trooper Helmet"
	desc = "A reinforced plastoid helmet of the Rebel Alliance."
	icon_state = "rebel_helmet1"
	item_state = "rebel_helmet1"
	worn_state = "rebel_helmet1"
	body_parts_covered = HEAD
	flags_inv = BLOCKHEADHAIR
	armor = list(melee = 30, arrow = 50, gun = 40, energy = 45, bomb = 30, bio = 20, rad = FALSE)

/obj/item/clothing/head/helmet/rebel/New()
	..()
	icon_state = "rebel_helmet[rand(1,2)]"
	worn_state = "[icon_state]"
	update_icon()

/obj/item/clothing/under/rebel
	name = "rebellion trooper uniform"
	desc = "A plain looking uniform worn by soldiers of the rebel alliance."
	icon_state = "rebel1"
	item_state = "rebel1"
	worn_state = "rebel1"

/obj/item/clothing/under/rebel/New()
	..()
	icon_state = "rebel[rand(1,2)]"
	worn_state = "[icon_state]"
	update_icon()

/obj/item/clothing/under/rebel/officer
	name = "rebellion officer uniform"
	desc = "A plain looking uniform worn by officers of the rebel alliance."
	icon_state = "rebel_officer"
	item_state = "rebel_officer"
	worn_state = "rebel_officer"

/obj/item/clothing/under/rebel/officer/New()
	icon_state = "rebel_officer"
	item_state = "rebel_officer"
	worn_state = "rebel_officer"

/obj/item/clothing/suit/storage/jacket/rebel_vest
	name = "black vest"
	desc = "A simple black vest."
	icon_state = "rebel_vest"
	item_state = "rebel_vest"
	worn_state = "rebel_vest"

/obj/item/clothing/suit/storage/jacket/rebel_vest/officer
	name = "rebel officer vest"
	desc = "A khaki and orange vest worn by officers of the Rebel Alliance."
	icon_state = "rebel_officer_vest"
	item_state = "rebel_officer_vest"
	worn_state = "rebel_officer_vest"