var/list/clients = list()							//list of all clients
var/list/movementMachine_clients = list()			//list of all clients the movementMachine datum iterates through
var/list/admins = list()							//list of all clients who are admins
var/list/directory = list()							//list of all ckeys with associated client

//Since it didn't really belong in any other category, I'm putting this here
//This is for procs to replace all the goddamn 'in world's that are chilling around the code

var/global/list/player_list = list()				//List of all mobs **with clients attached**.
var/global/list/mob_list = list()					//List of all mobs, including clientless
var/global/list/human_mob_list = list()				//List of all human mobs and sub-types, including clientless
//var/global/list/silicon_mob_list = list()			//List of all silicon mobs, including clientless
var/global/list/living_mob_list = list()			//List of all alive mobs, including clientless. Excludes /mob/new_player
var/global/list/dog_mob_list = list()				//List of all dogs
var/global/list/dead_mob_list = list()				//List of all dead mobs, including clientless. Excludes /mob/new_player
var/global/list/observer_mob_list = list()			//List of all observers, excluding clientless
var/global/list/human_clients_mob_list = list()     //List of all human mobs with clients
var/global/list/new_player_mob_list = list()	//List of all new_players, excludes clientless by definition

var/global/list/fallschirm_landmarks = list()

var/global/list/burning_obj_list = list()
var/global/list/burning_turf_list = list()

var/global/list/cable_list = list()					//Index for all cables, so that powernets don't have to look through the entire world all the time
var/global/list/chemical_reactions_list				//list of all /datum/chemical_reaction datums. Used during chemical reactions
var/global/list/chemical_reagents_list				//list of all /datum/reagent datums indexed by reagent id. Used by chemistry stuff
var/global/list/landmarks_list = list()				//list of all landmarks created
var/global/list/surgery_steps = list()				//list of all surgery steps  |BS12
var/global/list/side_effects = list()				//list of all medical sideeffects types by their names |BS12
var/global/list/mechas_list = list()				//list of all mechs. Used by hostile mobs target tracking.
var/global/list/joblist = list()					//list of all jobstypes, minus borg and AI

var/global/list/global_corporations = list()
var/global/list/HUDdatums = list()

var/global/list/area_list = list()

var/global/list/projectile_list = list()

var/global/list/thrown_list = list()

var/global/list/cleanables = list()

var/global/list/crate_list = list()

var/global/list/artillery_list = list()

var/global/list/cannon_piece_list = list()

var/global/list/catapult_piece_list = list()

var/global/list/door_list = list()

var/global/list/vending_machine_list = list()


/* because different levers are currently snowflake types that aren't actually related (train levers, lift levers, etc)
 * this list needs typechecking always - Kachnov */
var/global/list/lift_list = list()
var/global/list/lever_list = list()

var/global/list/organ_list = list()

var/global/list/tank_list = list()

var/global/list/ladder_list = list()

var/global/list/paper_list = list()

var/global/list/lighting_update_lights = list()  // List of lighting sources queued for update.

var/global/list/lighting_overlay_list = list() // List of lighting overlays queued for update.

var/global/list/processing_objects = list()

var/global/list/zoom_scopes_list = list()

var/global/list/zoom_processing_mobs = list()

var/global/list/menacing_atoms = list()

var/global/list/faction_hud_users = list()

var/global/list/hud_icon_reference = list()

// names
var/global/list/names_used[1000] // map

var/global/list/alphabet_lowercase = list("a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z")
var/global/list/alphabet_uppercase = list("A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z")

#define all_genders_define_list list(MALE,FEMALE,PLURAL,NEUTER)

var/global/list/turfs = list()						//list of all turfs
var/global/list/grass_turf_list = list() // list of all /turf/floor/grass
//Languages/species/whitelist.
var/global/list/all_species[0]
var/global/list/all_languages[0]
var/global/list/language_keys[0]					// Table of say codes for all languages
var/global/list/whitelisted_species = list("Human") // Species that require a whitelist check.
var/global/list/playable_species = list("Human")    // A list of ALL playable species, whitelisted, latejoin or otherwise.

var/global/list/main_radios = list()
// Posters
var/global/list/poster_designs = list()

// Uplinks
var/list/obj/item/uplink/world_uplinks = list()

//Preferences stuff
	//Bodybuilds
var/global/list/male_body_builds = list()
var/global/list/female_body_builds = list()
	//Hairstyles
var/global/list/hair_styles_list = list()			//stores /datum/sprite_accessory/hair indexed by name
var/global/list/hair_styles_male_list = list()
var/global/list/hair_styles_female_list = list()
var/global/list/facial_hair_styles_list = list()	//stores /datum/sprite_accessory/facial_hair indexed by name
var/global/list/facial_hair_styles_male_list = list()
var/global/list/facial_hair_styles_female_list = list()
var/global/list/skin_styles_female_list = list()		//unused


var/global/list/exclude_jobs = list()

// Visual nets
//var/list/datum/visualnet/visual_nets = list()
//var/datum/visualnet/cult/cultnet = new()

//spawn
var/global/list/latejoin_turfs = list()

// Runes
var/global/list/rune_list = new()
var/global/list/escape_list = list()
var/global/list/endgame_exits = list()
var/global/list/endgame_safespawns = list()

// for mass deletion
var/global/list/bullet_casings = list()
var/global/list/blood = list()

// Strings which corraspond to bodypart covering flags, useful for outputting what something covers.
var/global/list/string_part_flags = list(
	"head" = HEAD,
	"face" = FACE,
	"eyes" = EYES,
	"upper body" = UPPER_TORSO,
	"lower body" = LOWER_TORSO,
	"legs" = LEGS,
	"feet" = FEET,
	"arms" = ARMS,
	"hands" = HANDS
)

// Strings which corraspond to slot flags, useful for outputting what slot something is.
var/global/list/string_slot_flags = list(
	"back" = SLOT_BACK,
	"face" = SLOT_MASK,
	"waist" = SLOT_BELT,
	"pouch" = SLOT_ID,
	"ears" = SLOT_EARS,
	"shoulder" = SLOT_SHOULDER,
	"hands" = SLOT_GLOVES,
	"head" = SLOT_HEAD,
	"feet" = SLOT_FEET,
	"suit" = SLOT_OCLOTHING,
	"body" = SLOT_ICLOTHING,
	"shoulder" = SLOT_SHOULDER,
	"holster" = SLOT_HOLSTER
)

// new hair colors
var/list/hair_colors = list(
	"Black" = "#090806",
	"Light Brown" = "#6A4E42",
	"Dark Brown" = "#3B3024",
	"Red" = "#B55239",
	"Orange" = "#91553D",
	"Light Blond" = "#E6CEA8",
	"Blond" = "#E5C8A8",
	"Dirty Blond" = "#B89778",
	"Light Grey" = "#d3d3d3",
	"Grey" = "#808080"
)
// new eye colors
var/list/eye_colors = list(
	"Black" = "#000000",
	"Dark Brown" = "#2B1D0E",
	"Brown" = "#542A0E",
	"Green" = "#4B7248",
	"Blue" = "#5EA4E7",
)

var/global/list/global_mutations  = list() // List of hidden mutation things.
// Noises made when hit while typing.
var/list/hit_appends = list("-OOF", "-ACK", "-UGH", "-HRNK", "-HURGH", "-GLORF")
var/list/jobMax        = list()
var/list/admin_log     = list()
var/list/reg_dna       = list()
var/list/newplayer_start = list()
//Spawnpoints.
var/list/latejoin         = list()
var/list/cardinal    = list(NORTH, SOUTH, EAST, WEST)
var/list/cornerdirs  = list(NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST)
var/list/alldirs     = list(NORTH, SOUTH, EAST, WEST, NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST)
var/list/reverse_dir = list( // reverse_dir[dir] = reverse of dir
	 2,  1,  3,  8, 10,  9, 11,  4,  6,  5,  7, 12, 14, 13, 15, 32, 34, 33, 35, 40, 42,
	41, 43, 36, 38, 37, 39, 44, 46, 45, 47, 16, 18, 17, 19, 24, 26, 25, 27, 20, 22, 21,
	23, 28, 30, 29, 31, 48, 50, 49, 51, 56, 58, 57, 59, 52, 54, 53, 55, 60, 62, 61, 63
)

//////////////////////////
/////Initial Building/////
//////////////////////////

/proc/makeDatumRefLists()
	var/list/paths

	//Bodybuilds
	paths = typesof(/datum/body_build)
	for (var/path in paths)
		var/datum/body_build/B = new path()
		if (B.gender == FEMALE)
			female_body_builds[B.name] = B
		else
			male_body_builds[B.name] = B

	//Hair - Initialise all /datum/sprite_accessory/hair into an list indexed by hair-style name
	paths = typesof(/datum/sprite_accessory/hair) - /datum/sprite_accessory/hair
	for (var/path in paths)
		var/datum/sprite_accessory/hair/H = new path()
		hair_styles_list[H.name] = H
		switch(H.gender)
			if (MALE)	hair_styles_male_list += H.name
			if (FEMALE)	hair_styles_female_list += H.name
			else
				hair_styles_male_list += H.name
				hair_styles_female_list += H.name

	//Facial Hair - Initialise all /datum/sprite_accessory/facial_hair into an list indexed by facialhair-style name
	paths = typesof(/datum/sprite_accessory/facial_hair) - /datum/sprite_accessory/facial_hair
	for (var/path in paths)
		var/datum/sprite_accessory/facial_hair/H = new path()
		facial_hair_styles_list[H.name] = H
		switch(H.gender)
			if (MALE)	facial_hair_styles_male_list += H.name
			if (FEMALE)	facial_hair_styles_female_list += H.name
			else
				facial_hair_styles_male_list += H.name
				facial_hair_styles_female_list += H.name

	//Surgery Steps - Initialize all /datum/surgery_step into a list
	paths = typesof(/datum/surgery_step)-/datum/surgery_step
	for (var/T in paths)
		var/datum/surgery_step/S = new T
		surgery_steps += S
	sort_surgeries()

	//List of job. I can't believe this was calculated multiple times per tick!
	paths = typesof(/datum/job)-/datum/job
	paths -= exclude_jobs
	for (var/T in paths)
		var/datum/job/J = new T
		joblist[J.title] = J

	//Languages and species.
	paths = typesof(/datum/language)-/datum/language
	for (var/T in paths)
		var/datum/language/L = new T
		all_languages[L.name] = L

	for (var/language_name in all_languages)
		var/datum/language/L = all_languages[language_name]
		if (!(L.flags & NONGLOBAL))
			language_keys[lowertext(L.key)] = L

	var/rkey = FALSE
	paths = typesof(/datum/species)-/datum/species
	for (var/T in paths)
		rkey++
		var/datum/species/S = new T
		S.race_key = rkey //Used in mob icon caching.
		all_species[S.name] = S

		if (!(S.spawn_flags & IS_RESTRICTED))
			playable_species += S.name
		if (S.spawn_flags & IS_WHITELISTED)
			whitelisted_species += S.name

	paths = typesof(/datum/hud) - /datum/hud
	for (var/T in paths)
		var/datum/hud/C = new T
		global.HUDdatums[C.name] = C

	return TRUE

/* // Uncomment to debug chemical reaction list.
/client/verb/debug_chemical_list()

	for (var/reaction in chemical_reactions_list)
		. += "chemical_reactions_list\[\"[reaction]\"\] = \"[chemical_reactions_list[reaction]]\"\n"
		if (islist(chemical_reactions_list[reaction]))
			var/list/L = chemical_reactions_list[reaction]
			for (var/t in L)
				. += "    has: [t]\n"
	world << .
*/
