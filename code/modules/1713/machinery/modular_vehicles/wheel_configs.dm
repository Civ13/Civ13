//////////////////////// WHEEL & TRACK CONFIGURATION LIBRARY ////////////////////////
/// Consolidated configuration objects for all vehicle movement types.
/// Replaces 50+ type definitions with data-driven configuration.

var/global/list/WHEEL_CONFIGS = list()

/proc/get_wheel_config(name)
	if (!WHEEL_CONFIGS.len)
		build_all()
	world.log << "Retrieving wheel config: [name]"
	if (!WHEEL_CONFIGS[name])
		world.log << "ERROR: Wheel config [name] not found!"
	return WHEEL_CONFIGS[name]

/datum/wheel_configs
	proc/register(name, config)
		WHEEL_CONFIGS[name] = config

/proc/build_all()
	/// Standard Wheels
	WHEEL_CONFIGS["standard_wheel"] = new /datum/wheel_config(
		name = "Standard Wheel",
		type_name = "wheel",
		icon = 'icons/obj/vehicles/vehicleparts.dmi',
		icon_state = "wheel_t_dark",
		base_icon_state = "wheel_t_dark",
		movement_icon_state = "wheel_t_dark_m",
		is_reversed = FALSE,
	)

	WHEEL_CONFIGS["standard_wheel_reversed"] = new /datum/wheel_config(
		name = "Standard Wheel (Reversed)",
		type_name = "wheel",
		icon = 'icons/obj/vehicles/vehicleparts.dmi',
		icon_state = "wheel_t_dark",
		base_icon_state = "wheel_t_dark",
		movement_icon_state = "wheel_t_dark_m",
		is_reversed = TRUE,
	)

	/// Armored Wheels (Generic)
	WHEEL_CONFIGS["armored_wheel"] = new /datum/wheel_config(
		name = "Armored Wheels",
		type_name = "wheel",
		icon = 'icons/obj/vehicles/vehicleparts.dmi',
		icon_state = "wheel_t_dark",
		base_icon_state = "wheel_t_dark",
		movement_icon_state = "wheel_t_dark_m",
		is_reversed = FALSE,
		armor = 5,
		max_health = 60,
	)

	WHEEL_CONFIGS["armored_wheel_reversed"] = new /datum/wheel_config(
		name = "Armored Wheels (Reversed)",
		type_name = "wheel",
		icon = 'icons/obj/vehicles/vehicleparts.dmi',
		icon_state = "wheel_t_dark",
		base_icon_state = "wheel_t_dark",
		movement_icon_state = "wheel_t_dark_m",
		is_reversed = TRUE,
		armor = 5,
		max_health = 60,
	)

	/// BTR-80 Wheels
	WHEEL_CONFIGS["btr80_wheel_front_left"] = new /datum/wheel_config(
		name = "BTR-80 Wheel (Front Left)",
		type_name = "wheel",
		icon = 'icons/obj/vehicles/apcparts96x96.dmi',
		icon_state = "btr80_wheels_front_left",
		base_icon_state = "btr80_wheels_front_left",
		movement_icon_state = "btr80_wheels_front_left_m",
		is_reversed = FALSE,
		position = "front",
		side = "left",
	)

	WHEEL_CONFIGS["btr80_wheel_front_right"] = new /datum/wheel_config(
		name = "BTR-80 Wheel (Front Right)",
		type_name = "wheel",
		icon = 'icons/obj/vehicles/apcparts96x96.dmi',
		icon_state = "btr80_wheels_front_right",
		base_icon_state = "btr80_wheels_front_right",
		movement_icon_state = "btr80_wheels_front_right_m",
		is_reversed = FALSE,
		position = "front",
		side = "right",
	)

	WHEEL_CONFIGS["btr80_wheel_back_left"] = new /datum/wheel_config(
		name = "BTR-80 Wheel (Back Left)",
		type_name = "wheel",
		icon = 'icons/obj/vehicles/apcparts96x96.dmi',
		icon_state = "btr80_wheels_back_left",
		base_icon_state = "btr80_wheels_back_left",
		movement_icon_state = "btr80_wheels_back_left_m",
		is_reversed = TRUE,
		position = "back",
		side = "left",
	)

	WHEEL_CONFIGS["btr80_wheel_back_right"] = new /datum/wheel_config(
		name = "BTR-80 Wheel (Back Right)",
		type_name = "wheel",
		icon = 'icons/obj/vehicles/apcparts96x96.dmi',
		icon_state = "btr80_wheels_back_right",
		base_icon_state = "btr80_wheels_back_right",
		movement_icon_state = "btr80_wheels_back_right_m",
		is_reversed = TRUE,
		position = "back",
		side = "right",
	)

	/// Generic Tracks
	WHEEL_CONFIGS["track_standard"] = new /datum/wheel_config(
		name = "Armored Tracks",
		type_name = "track",
		icon = 'icons/obj/vehicles/vehicleparts.dmi',
		icon_state = "tracks_end",
		base_icon_state = "tracks_end",
		movement_icon_state = "tracks_end_m",
		is_reversed = FALSE,
	)

	WHEEL_CONFIGS["track_standard_reversed"] = new /datum/wheel_config(
		name = "Armored Tracks",
		type_name = "track",
		icon = 'icons/obj/vehicles/vehicleparts.dmi',
		icon_state = "tracks_end",
		base_icon_state = "tracks_end",
		movement_icon_state = "tracks_end_m",
		is_reversed = TRUE,
	)
	WHEEL_CONFIGS["track_standard_left"] = new /datum/wheel_config(
		name = "Armored Tracks (Left)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts.dmi',
		icon_state = "tracks_end_left",
		base_icon_state = "tracks_end_left",
		movement_icon_state = "tracks_end_left_m",
		is_reversed = FALSE,
		side = "left",
	)

	WHEEL_CONFIGS["track_standard_right"] = new /datum/wheel_config(
		name = "Armored Tracks (Right)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts.dmi',
		icon_state = "tracks_end_right",
		base_icon_state = "tracks_end_right",
		movement_icon_state = "tracks_end_right_m",
		is_reversed = FALSE,
		side = "right",
	)

	/// MT-LB Tracks (New 96x96 variant)
	WHEEL_CONFIGS["mtlb_track_left_front"] = new /datum/wheel_config(
		name = "MT-LB Track (Left Front)",
		type_name = "track",
		icon = 'icons/obj/vehicles/apcparts96x96.dmi',
		icon_state = "mtlb_tracks_left_front",
		base_icon_state = "mtlb_tracks_left_front",
		movement_icon_state = "mtlb_tracks_left_front_m",
		is_reversed = FALSE,
		position = "front",
		side = "left",
	)

	WHEEL_CONFIGS["mtlb_track_right_front"] = new /datum/wheel_config(
		name = "MT-LB Track (Right Front)",
		type_name = "track",
		icon = 'icons/obj/vehicles/apcparts96x96.dmi',
		icon_state = "mtlb_tracks_right_front",
		base_icon_state = "mtlb_tracks_right_front",
		movement_icon_state = "mtlb_tracks_right_front_m",
		is_reversed = FALSE,
		position = "front",
		side = "right",
	)

	WHEEL_CONFIGS["mtlb_track_left_back"] = new /datum/wheel_config(
		name = "MT-LB Track (Left Back)",
		type_name = "track",
		icon = 'icons/obj/vehicles/apcparts96x96.dmi',
		icon_state = "mtlb_tracks_left_back",
		base_icon_state = "mtlb_tracks_left_back",
		movement_icon_state = "mtlb_tracks_left_back_m",
		is_reversed = TRUE,
		position = "back",
		side = "left",
	)

	WHEEL_CONFIGS["mtlb_track_right_back"] = new /datum/wheel_config(
		name = "MT-LB Track (Right Back)",
		type_name = "track",
		icon = 'icons/obj/vehicles/apcparts96x96.dmi',
		icon_state = "mtlb_tracks_right_back",
		base_icon_state = "mtlb_tracks_right_back",
		movement_icon_state = "mtlb_tracks_right_back_m",
		is_reversed = TRUE,
		position = "back",
		side = "right",
	)

	/// BMD-2 Tracks (New 96x96 variant)
	WHEEL_CONFIGS["bmd2_track_left_front"] = new /datum/wheel_config(
		name = "BMD-2 Track (Left Front)",
		type_name = "track",
		icon = 'icons/obj/vehicles/apcparts96x96.dmi',
		icon_state = "bmd2new_tracks_left_front",
		base_icon_state = "bmd2new_tracks_left_front",
		movement_icon_state = "bmd2new_tracks_left_front_m",
		position = "front",
		side = "left",
	)

	WHEEL_CONFIGS["bmd2_track_right_front"] = new /datum/wheel_config(
		name = "BMD-2 Track (Right Front)",
		type_name = "track",
		icon = 'icons/obj/vehicles/apcparts96x96.dmi',
		icon_state = "bmd2new_tracks_right_front",
		base_icon_state = "bmd2new_tracks_right_front",
		movement_icon_state = "bmd2new_tracks_right_front_m",
		position = "front",
		side = "right",
	)

	WHEEL_CONFIGS["bmd2_track_left_back"] = new /datum/wheel_config(
		name = "BMD-2 Track (Left Back)",
		type_name = "track",
		icon = 'icons/obj/vehicles/apcparts96x96.dmi',
		icon_state = "bmd2new_tracks_left_back",
		base_icon_state = "bmd2new_tracks_left_back",
		movement_icon_state = "bmd2new_tracks_left_back_m",
		position = "back",
		side = "left",
	)

	WHEEL_CONFIGS["bmd2_track_right_back"] = new /datum/wheel_config(
		name = "BMD-2 Track (Right Back)",
		type_name = "track",
		icon = 'icons/obj/vehicles/apcparts96x96.dmi',
		icon_state = "bmd2new_tracks_right_back",
		base_icon_state = "bmd2new_tracks_right_back",
		movement_icon_state = "bmd2new_tracks_right_back_m",
		position = "back",
		side = "right",
	)

	/// Bradley Tracks
	WHEEL_CONFIGS["bradley_track_left_front"] = new /datum/wheel_config(
		name = "Bradley Track (Left Front)",
		type_name = "track",
		icon = 'icons/obj/vehicles/apcparts96x96.dmi',
		icon_state = "bradley_tracks_left_front",
		base_icon_state = "bradley_tracks_left_front",
		movement_icon_state = "bradley_tracks_left_front_m",
		position = "front",
		side = "left",
	)

	WHEEL_CONFIGS["bradley_track_right_front"] = new /datum/wheel_config(
		name = "Bradley Track (Right Front)",
		type_name = "track",
		icon = 'icons/obj/vehicles/apcparts96x96.dmi',
		icon_state = "bradley_tracks_right_front",
		base_icon_state = "bradley_tracks_right_front",
		movement_icon_state = "bradley_tracks_right_front_m",
		position = "front",
		side = "right",
	)

	WHEEL_CONFIGS["bradley_track_left_back"] = new /datum/wheel_config(
		name = "Bradley Track (Left Back)",
		type_name = "track",
		icon = 'icons/obj/vehicles/apcparts96x96.dmi',
		icon_state = "bradley_tracks_left_back",
		base_icon_state = "bradley_tracks_left_back",
		movement_icon_state = "bradley_tracks_left_back_m",
		position = "back",
		side = "left",
	)

	WHEEL_CONFIGS["bradley_track_right_back"] = new /datum/wheel_config(
		name = "Bradley Track (Right Back)",
		type_name = "track",
		icon = 'icons/obj/vehicles/apcparts96x96.dmi',
		icon_state = "bradley_tracks_right_back",
		base_icon_state = "bradley_tracks_right_back",
		movement_icon_state = "bradley_tracks_right_back_m",
		position = "back",
		side = "right",
	)

	/// IS-3 Tracks (96x96 variant)
	WHEEL_CONFIGS["is3_track_left_front"] = new /datum/wheel_config(
		name = "IS-3 Track (Left Front)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts96x96.dmi',
		icon_state = "is3_tracks_left_front",
		base_icon_state = "is3_tracks_left_front",
		movement_icon_state = "is3_tracks_left_front_m",
		position = "front",
		side = "left",
	)

	WHEEL_CONFIGS["is3_track_right_front"] = new /datum/wheel_config(
		name = "IS-3 Track (Right Front)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts96x96.dmi',
		icon_state = "is3_tracks_right_front",
		base_icon_state = "is3_tracks_right_front",
		movement_icon_state = "is3_tracks_right_front_m",
		position = "front",
		side = "right",
	)

	WHEEL_CONFIGS["is3_track_left_back"] = new /datum/wheel_config(
		name = "IS-3 Track (Left Back)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts96x96.dmi',
		icon_state = "is3_tracks_left_back",
		base_icon_state = "is3_tracks_left_back",
		movement_icon_state = "is3_tracks_left_back_m",
		position = "back",
		side = "left",
	)

	WHEEL_CONFIGS["is3_track_right_back"] = new /datum/wheel_config(
		name = "IS-3 Track (Right Back)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts96x96.dmi',
		icon_state = "is3_tracks_right_back",
		base_icon_state = "is3_tracks_right_back",
		movement_icon_state = "is3_tracks_right_back_m",
		position = "back",
		side = "right",
	)

	/// IS-2 Tracks
	WHEEL_CONFIGS["is2_track_left_front"] = new /datum/wheel_config(
		name = "IS-2 Track (Left Front)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts96x96.dmi',
		icon_state = "is2_tracks_left_front",
		base_icon_state = "is2_tracks_left_front",
		movement_icon_state = "is2_tracks_left_front_m",
		position = "front",
		side = "left",
	)

	WHEEL_CONFIGS["is2_track_right_front"] = new /datum/wheel_config(
		name = "IS-2 Track (Right Front)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts96x96.dmi',
		icon_state = "is2_tracks_right_front",
		base_icon_state = "is2_tracks_right_front",
		movement_icon_state = "is2_tracks_right_front_m",
		position = "front",
		side = "right",
	)

	WHEEL_CONFIGS["is2_track_left_back"] = new /datum/wheel_config(
		name = "IS-2 Track (Left Back)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts96x96.dmi',
		icon_state = "is2_tracks_left_back",
		base_icon_state = "is2_tracks_left_back",
		movement_icon_state = "is2_tracks_left_back_m",
		position = "back",
		side = "left",
	)

	WHEEL_CONFIGS["is2_track_right_back"] = new /datum/wheel_config(
		name = "IS-2 Track (Right Back)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts96x96.dmi',
		icon_state = "is2_tracks_right_back",
		base_icon_state = "is2_tracks_right_back",
		movement_icon_state = "is2_tracks_right_back_m",
		position = "back",
		side = "right",
	)

	/// T-34 Tracks
	WHEEL_CONFIGS["t34_track_left_front"] = new /datum/wheel_config(
		name = "T-34 Track (Left Front)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts96x96.dmi',
		icon_state = "t34_tracks_left_front",
		base_icon_state = "t34_tracks_left_front",
		movement_icon_state = "t34_tracks_left_front_m",
		position = "front",
		side = "left",
	)

	WHEEL_CONFIGS["t34_track_right_front"] = new /datum/wheel_config(
		name = "T-34 Track (Right Front)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts96x96.dmi',
		icon_state = "t34_tracks_right_front",
		base_icon_state = "t34_tracks_right_front",
		movement_icon_state = "t34_tracks_right_front_m",
		position = "front",
		side = "right",
	)

	WHEEL_CONFIGS["t34_track_left_back"] = new /datum/wheel_config(
		name = "T-34 Track (Left Back)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts96x96.dmi',
		icon_state = "t34_tracks_left_back",
		base_icon_state = "t34_tracks_left_back",
		movement_icon_state = "t34_tracks_left_back_m",
		position = "back",
		side = "left",
	)

	WHEEL_CONFIGS["t34_track_right_back"] = new /datum/wheel_config(
		name = "T-34 Track (Right Back)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts96x96.dmi',
		icon_state = "t34_tracks_right_back",
		base_icon_state = "t34_tracks_right_back",
		movement_icon_state = "t34_tracks_right_back_m",
		position = "back",
		side = "right",
	)

	/// Char-B1 Tracks
	WHEEL_CONFIGS["char1_track_left_front"] = new /datum/wheel_config(
		name = "Char-B1 Track (Left Front)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts96x96.dmi',
		icon_state = "char1_tracks_left_front",
		base_icon_state = "char1_tracks_left_front",
		movement_icon_state = "char1_tracks_left_front_m",
		position = "front",
		side = "left",
	)

	WHEEL_CONFIGS["char1_track_right_front"] = new /datum/wheel_config(
		name = "Char-B1 Track (Right Front)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts96x96.dmi',
		icon_state = "char1_tracks_right_front",
		base_icon_state = "char1_tracks_right_front",
		movement_icon_state = "char1_tracks_right_front_m",
		position = "front",
		side = "right",
	)

	WHEEL_CONFIGS["char1_track_left_back"] = new /datum/wheel_config(
		name = "Char-B1 Track (Left Back)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts96x96.dmi',
		icon_state = "char1_tracks_left_back",
		base_icon_state = "char1_tracks_left_back",
		movement_icon_state = "char1_tracks_left_back_m",
		position = "back",
		side = "left",
	)

	WHEEL_CONFIGS["char1_track_right_back"] = new /datum/wheel_config(
		name = "Char-B1 Track (Right Back)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts96x96.dmi',
		icon_state = "char1_tracks_right_back",
		base_icon_state = "char1_tracks_right_back",
		movement_icon_state = "char1_tracks_right_back_m",
		position = "back",
		side = "right",
	)

	/// M41 Walker Bulldog Tracks
	WHEEL_CONFIGS["m41_track_left_front"] = new /datum/wheel_config(
		name = "M41 Track (Left Front)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts96x96.dmi',
		icon_state = "m41_tracks_left_front",
		base_icon_state = "m41_tracks_left_front",
		movement_icon_state = "m41_tracks_left_front_m",
		position = "front",
		side = "left",
	)

	WHEEL_CONFIGS["m41_track_right_front"] = new /datum/wheel_config(
		name = "M41 Track (Right Front)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts96x96.dmi',
		icon_state = "m41_tracks_right_front",
		base_icon_state = "m41_tracks_right_front",
		movement_icon_state = "m41_tracks_right_front_m",
		position = "front",
		side = "right",
	)

	WHEEL_CONFIGS["m41_track_left_back"] = new /datum/wheel_config(
		name = "M41 Track (Left Back)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts96x96.dmi',
		icon_state = "m41_tracks_left_back",
		base_icon_state = "m41_tracks_left_back",
		movement_icon_state = "m41_tracks_left_back_m",
		position = "back",
		side = "left",
	)

	WHEEL_CONFIGS["m41_track_right_back"] = new /datum/wheel_config(
		name = "M41 Track (Right Back)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts96x96.dmi',
		icon_state = "m41_tracks_right_back",
		base_icon_state = "m41_tracks_right_back",
		movement_icon_state = "m41_tracks_right_back_m",
		position = "back",
		side = "right",
	)

	/// Ha-Go Tracks
	WHEEL_CONFIGS["hago_track_left_front"] = new /datum/wheel_config(
		name = "Ha-Go Track (Left Front)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts.dmi',
		icon_state = "hago_tracks_l",
		base_icon_state = "hago_tracks_l",
		movement_icon_state = "hago_tracks_l_m",
		position = "front",
		side = "left",
	)

	WHEEL_CONFIGS["hago_track_right_front"] = new /datum/wheel_config(
		name = "Ha-Go Track (Right Front)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts.dmi',
		icon_state = "hago_tracks_r",
		base_icon_state = "hago_tracks_r",
		movement_icon_state = "hago_tracks_r_m",
		position = "front",
		side = "right",
	)

	WHEEL_CONFIGS["hago_track_left_back"] = new /datum/wheel_config(
		name = "Ha-Go Track (Left Back)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts.dmi',
		icon_state = "hago_tracks_l",
		base_icon_state = "hago_tracks_l",
		movement_icon_state = "hago_tracks_l_m",
		is_reversed = TRUE,
		position = "back",
		side = "left",
	)

	WHEEL_CONFIGS["hago_track_right_back"] = new /datum/wheel_config(
		name = "Ha-Go Track (Right Back)",
		type_name = "track",
		icon = 'icons/obj/vehicles/tankparts.dmi',
		icon_state = "hago_tracks_r",
		base_icon_state = "hago_tracks_r",
		movement_icon_state = "hago_tracks_r_m",
		is_reversed = TRUE,
		position = "back",
		side = "right",
	)

	/// M113 Tracks
	WHEEL_CONFIGS["m113_track_left_front"] = new /datum/wheel_config(
		name = "M113 Track (Left Front)",
		type_name = "track",
		icon = 'icons/obj/vehicles/apcparts.dmi',
		icon_state = "m113_tracks_end_left",
		base_icon_state = "m113_tracks_end_left",
		movement_icon_state = "m113_tracks_end_left_m",
		position = "front",
		side = "left",
	)

	WHEEL_CONFIGS["m113_track_right_front"] = new /datum/wheel_config(
		name = "M113 Track (Right Front)",
		type_name = "track",
		icon = 'icons/obj/vehicles/apcparts.dmi',
		icon_state = "m113_tracks_end_right",
		base_icon_state = "m113_tracks_end_right",
		movement_icon_state = "m113_tracks_end_right_m",
		position = "front",
		side = "right",
	)

	WHEEL_CONFIGS["m113_track_left_back"] = new /datum/wheel_config(
		name = "M113 Track (Left Back)",
		type_name = "track",
		icon = 'icons/obj/vehicles/apcparts.dmi',
		icon_state = "m113_tracks_end_left",
		base_icon_state = "m113_tracks_end_left",
		movement_icon_state = "m113_tracks_end_left_m",
		is_reversed = TRUE,
		position = "back",
		side = "left",
	)

	WHEEL_CONFIGS["m113_track_right_back"] = new /datum/wheel_config(
		name = "M113 Track (Right Back)",
		type_name = "track",
		icon = 'icons/obj/vehicles/apcparts.dmi',
		icon_state = "m113_tracks_end_right",
		base_icon_state = "m113_tracks_end_right",
		movement_icon_state = "m113_tracks_end_right_m",
		is_reversed = TRUE,
		position = "back",
		side = "right",
	)

	return WHEEL_CONFIGS
