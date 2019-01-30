/*

	Hello and welcome to sprite_accessories: For sprite accessories, such as hair,
	facial hair, and possibly tattoos and stuff somewhere along the line. This file is
	intended to be friendly for people with little to no actual coding experience.
	The process of adding in new hairstyles has been made pain-free and easy to do.
	Enjoy! - Doohl

	Notice: This all gets automatically compiled in a list in dna2.dm, so you do not
	have to define any UI values for sprite accessories manually for hair and facial
	hair. Just add in new hair types and the game will naturally adapt.

	!!WARNING!!: changing existing hair information can be VERY hazardous to savefiles,
	to the point where you may completely corrupt a server's savefiles. Please refrain
	from doing this unless you absolutely know what you are doing, and have defined a
	conversion in savefile.dm
*/

/datum/sprite_accessory

	var/icon			// the icon file the accessory is located in
	var/icon_state		// the icon_state of the accessory
	var/preview_state	// a custom preview state for whatever reason

	var/name			// the preview name of the accessory

	// Determines if the accessory will be skipped or included in random hair generations
	var/gender = NEUTER

	// Restrict some styles to specific species
	var/list/species_allowed = list("Human")

	// Whether or not the accessory can be affected by colouration
	var/do_colouration = TRUE

	var/growth = 0 // to order by lenght. 0 = bald, 1 = short, 2 = medium (covering the ears), 3 = shoulder length, 4 = mid-back

/*
////////////////////////////
/  =--------------------=  /
/  == Hair Definitions ==  /
/  =--------------------=  /
////////////////////////////
*/

/datum/sprite_accessory/hair

	icon = 'icons/mob/Human_face.dmi'	  // default icon for all hairs

	bald
		name = "Bald"
		icon_state = "bald"
		gender = MALE
		growth = 0

	short
		name = "Short Hair"	  // try to capatilize the names please!
		icon_state = "hair_a" // you do not need to define _s or _l sub-states, game automatically does this for you
		growth = 1

	cut
		name = "Cut Hair"
		icon_state = "hair_c"
		growth = 1

	flair
		name = "Flaired Hair"
		icon_state = "hair_flair"
		gender = FEMALE
		growth = 3

	long
		name = "Shoulder-length Hair"
		icon_state = "hair_b"
		growth = 3

	longalt
		name = "Shoulder-length Hair Alt"
		icon_state = "hair_longfringe"
		gender = FEMALE
		growth = 3

	/*longish
		name = "Longer Hair"
		icon_state = "hair_b2"*/

	longer
		name = "Long Hair"
		icon_state = "hair_vlong"
		gender = FEMALE
		growth = 4

	longeralt
		name = "Long Hair Alt"
		icon_state = "hair_vlongfringe"
		gender = FEMALE
		growth = 4

//	longest
//		name = "Very Long Hair"
//		icon_state = "hair_longest"

//	longfringe
//		name = "Long Fringe"
//		icon_state = "hair_longfringe"

//	longestalt
//		name = "Longer Fringe"
//		icon_state = "hair_vlongfringe"

	halfbang
		name = "Half-banged Hair"
		icon_state = "hair_halfbang"
		growth = 2

	halfbangalt
		name = "Half-banged Hair Alt"
		icon_state = "hair_halfbang_alt"
		growth = 2

	ponytail1
		name = "Ponytail 1"
		icon_state = "hair_ponytail"
		gender = FEMALE
		growth = 2

	ponytail2
		name = "Ponytail 2"
		icon_state = "hair_pa"
		gender = FEMALE
		growth = 2

	ponytail3
		name = "Ponytail 3"
		icon_state = "hair_ponytail3"
		gender = FEMALE
		growth = 2

	ponytail4
		name = "Ponytail 4"
		icon_state = "hair_ponytail4"
		gender = FEMALE
		growth = 3

	sideponytail
		name = "Side Ponytail"
		icon_state = "hair_stail"
		gender = FEMALE
		growth = 2

	parted
		name = "Parted"
		icon_state = "hair_parted"
		growth = 2

	pompadour
		name = "Pompadour"
		icon_state = "hair_pompadour"
		gender = MALE
		growth = 2

	quiff
		name = "Quiff"
		icon_state = "hair_quiff"
		gender = MALE
		growth = 1
	bedhead
		name = "Bedhead"
		icon_state = "hair_bedhead"
		growth = 2

	bedhead2
		name = "Bedhead 2"
		icon_state = "hair_bedheadv2"
		growth = 2

	bedhead3
		name = "Bedhead 3"
		icon_state = "hair_bedheadv3"
		growth = 2

	beehive
		name = "Beehive"
		icon_state = "hair_beehive"
		gender = FEMALE
		growth = 3

	beehive2
		name = "Beehive 2"
		icon_state = "hair_beehive2"
		gender = FEMALE
		growth = 3

	bobcurl
		name = "Bobcurl"
		icon_state = "hair_bobcurl"
		gender = FEMALE
		growth = 2

	bob
		name = "Bob"
		icon_state = "hair_bobcut"
		gender = FEMALE
		growth = 2

	bowl
		name = "Bowl"
		icon_state = "hair_bowlcut"
		gender = MALE
		growth = 1

	buzz
		name = "Buzzcut"
		icon_state = "hair_buzzcut"
		gender = MALE
		growth = 1

	crew
		name = "Crewcut"
		icon_state = "hair_crewcut"
		gender = MALE
		growth = 1

	combover
		name = "Combover"
		icon_state = "hair_combover"
		gender = MALE
		growth = 1

	father
		name = "Father"
		icon_state = "hair_father"
		gender = MALE
		growth = 1

//	reversemohawk
//		name = "Reverse Mohawk"
//		icon_state = "hair_reversemohawk"
//		gender = MALE

	devillock
		name = "Devil Lock"
		icon_state = "hair_devilock"
		growth = 1

	dreadlocks
		name = "Dreadlocks"
		icon_state = "hair_dreads"
		growth = 3

	curls
		name = "Curls"
		icon_state = "hair_curls"
		gender = FEMALE
		growth = 2

	afro
		name = "Afro"
		icon_state = "hair_afro"
		growth = 3

	afro2
		name = "Afro 2"
		icon_state = "hair_afro2"
		growth = 3

	afro_large
		name = "Big Afro"
		icon_state = "hair_bigafro"
		gender = MALE
		growth = 4

	sargeant
		name = "Flat Top"
		icon_state = "hair_sargeant"
		gender = MALE
		growth = 1

// nope
//	emo
//		name = "Emo"
//		icon_state = "hair_emo"

	longemo
		name = "Long Emo"
		icon_state = "hair_emolong"
		gender = FEMALE
		growth = 3

//	rightemo
//		name = "Right Emo"
//		icon_state = "hair_emoright"

//	shortovereye
//		name = "Overeye Short"
//		icon_state = "hair_shortovereye"

//	longovereye
//		name = "Overeye Long"
//		icon_state = "hair_longovereye"

//	fag
//		name = "Flow Hair"
//		icon_state = "hair_f"

	feather
		name = "Feather"
		icon_state = "hair_feather"
		gender = FEMALE
		growth = 3

// just... no
//	hitop
//		name = "Hitop"
//		icon_state = "hair_hitop"
//		gender = MALE

	mohawk
		name = "Mohawk"
		icon_state = "hair_d"
		growth = 2

	jensen
		name = "Adam Jensen Hair"
		icon_state = "hair_jensen"
		gender = MALE
		growth = 2

	gelled
		name = "Gelled Back"
		icon_state = "hair_gelled"
		gender = FEMALE
		growth = 2

	gentle
		name = "Gentle"
		icon_state = "hair_gentle"
		gender = FEMALE
		growth = 3

	spiky
		name = "Spiky"
		icon_state = "hair_spikey"
		growth = 1

//	kusangi
//		name = "Kusanagi Hair"
//		icon_state = "hair_kusanagi"

	kagami
		name = "Pigtails"
		icon_state = "hair_kagami"
		gender = FEMALE
		growth = 3

	himecut
		name = "Hime Cut"
		icon_state = "hair_himecut"
		gender = FEMALE
		growth = 4

//ultra meme zone here. yeah, nope

//	braid
//		name = "Floorlength Braid"
//		icon_state = "hair_braid"
//		gender = FEMALE

//	mbraid
//		name = "Medium Braid"
//		icon_state = "hair_shortbraid"
//		gender = FEMALE

//	braid2
//		name = "Long Braid"
//		icon_state = "hair_hbraid"
//		gender = FEMALE

//	braid3
//		name = "Long Braid 2"
//		icon_state = "hair_longbraid"
//		gender = FEMALE

//	odango
//		name = "Odango"
//		icon_state = "hair_odango"
//		gender = FEMALE

	ombre
		name = "Ombre"
		icon_state = "hair_ombre"
		gender = FEMALE
		growth = 3

	updo
		name = "Updo"
		icon_state = "hair_updo"
		gender = FEMALE
		growth = 2

//no idea why this is called skinhead :shrug:
	skinhead
		name = "Skinhead"
		icon_state = "hair_skinhead"
		growth = 1

	balding
		name = "Balding Hair"
		icon_state = "hair_e"
		gender = MALE // turnoff!
		growth = 1

//nonononono
//	familyman
//		name = "The Family Man"
//		icon_state = "hair_thefamilyman"
//		gender = MALE

//	mahdrills
//		name = "Drillruru"
//		icon_state = "hair_drillruru"
//		gender = FEMALE

//	dandypomp
//		name = "Dandy Pompadour"
//		icon_state = "hair_dandypompadour"
//		gender = MALE

//	poofy
//		name = "Poofy"
//		icon_state = "hair_poofy"
//		gender = FEMALE

//	crono
//		name = "Chrono"
//		icon_state = "hair_toriyama"
//		gender = MALE

//	vegeta
//		name = "Vegeta"
//		icon_state = "hair_toriyama2"
//		gender = MALE

	cia
		name = "CIA"
		icon_state = "hair_cia"
		gender = MALE
		growth = 2

	mulder
		name = "Mulder"
		icon_state = "hair_mulder"
		gender = MALE
		growth = 2

	scully
		name = "Scully"
		icon_state = "hair_scully"
		gender = FEMALE
		growth = 3

//	nitori
//		name = "Nitori"
//		icon_state = "hair_nitori"
//		gender = FEMALE

	joestar
		name = "Joestar"
		icon_state = "hair_joestar"
		gender = MALE
		growth = 1

//	volaju
//		name = "Volaju"
//		icon_state = "hair_volaju"

//	longeralt2
//		name = "Long Hair Alt 2"
//		icon_state = "hair_longeralt2"

//	shortbangs
//		name = "Short Bangs"
//		icon_state = "hair_shortbangs"

// who the fuck put this in here
//	halfshaved
//		name = "Half-Shaved Emo"
//		icon_state = "hair_halfshaved"

	bun
		name = "Bun"
		icon_state = "hair_bun"
		growth = 2

//	doublebun
//		name = "Double-Bun"
//		icon_state = "hair_doublebun"

	Mia
		name = "Mia"
		icon_state = "hair_mia"
		gender = FEMALE
		growth = 2

	bald
		name = "Bald"
		icon_state = "bald"
		growth = 0

//ADL pls no bully
	jewlocks
		name = "Jewlocks"
		icon_state = "hair_jewlocks"
		gender = MALE
		growth = 3

//BANG!
	chad
		name = "Chad"
		icon_state = "hair_chad"
		gender = MALE
		growth = 1


/*
///////////////////////////////////
/  =---------------------------=  /
/  == Facial Hair Definitions ==  /
/  =---------------------------=  /
///////////////////////////////////
*/

/datum/sprite_accessory/facial_hair

	icon = 'icons/mob/Human_face.dmi'
	gender = MALE // barf (unless you're a dorf, dorfs dig chix /w beards :P)

	shaved
		name = "Shaved"
		icon_state = "bald"
		gender = NEUTER
		growth = 0

	watson
		name = "Watson Mustache"
		icon_state = "facial_watson"
		growth = 1

	hogan
		name = "Hulk Hogan Mustache"
		icon_state = "facial_hogan" //-Neek
		growth = 1

	vandyke
		name = "Van Dyke Mustache"
		icon_state = "facial_vandyke"
		growth = 1

	chaplin
		name = "Square Mustache"
		icon_state = "facial_chaplin"
		growth = 1

	selleck
		name = "Selleck Mustache"
		icon_state = "facial_selleck"
		growth = 1

	neckbeard
		name = "Neckbeard"
		icon_state = "facial_neckbeard"
		growth = 2

	fullbeard
		name = "Medium Beard"
		icon_state = "facial_smallbeard"
		growth = 2

	fullbeard
		name = "Full Beard"
		icon_state = "facial_fullbeard"
		growth = 3

	longbeard
		name = "Long Beard"
		icon_state = "facial_longbeard"
		growth = 3

	vlongbeard
		name = "Very Long Beard"
		icon_state = "facial_wise"
		growth = 4


	elvis
		name = "Elvis Sideburns"
		icon_state = "facial_elvis"
		growth = 1

	abe
		name = "Abraham Lincoln Beard"
		icon_state = "facial_abe"
		growth = 2

	chinstrap
		name = "Chinstrap"
		icon_state = "facial_chin"
		growth = 1

	hip
		name = "Hipster Beard"
		icon_state = "facial_hip"
		growth = 2

	gt
		name = "Goatee"
		icon_state = "facial_gt"
		growth = 2

	jensen
		name = "Adam Jensen Beard"
		icon_state = "facial_jensen"
		growth = 1

	volaju
		name = "Volaju"
		icon_state = "facial_volaju"
		growth = 2

	dwarf
		name = "Dwarf Beard"
		icon_state = "facial_dwarf"
		growth = 4

//skin styles - WIP
//going to have to re-integrate this with surgery
//let the icon_state hold an icon preview for now
/datum/sprite_accessory/skin
	icon = 'icons/mob/human_races/r_human.dmi'

	human
		name = "Default human skin"
		icon_state = "default"

	human_tatt01
		name = "Tatt01 human skin"
		icon_state = "tatt1"
