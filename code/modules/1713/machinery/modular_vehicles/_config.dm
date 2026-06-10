//////////////////////// MODULAR VEHICLES CONFIGURATION ////////////////////////
/// This file defines all constants and static configuration for the vehicle system.
/// Centralized here to eliminate magic numbers throughout the codebase.

var/global/datum/vehicle_constants/VEHICLE_CONSTANTS = new()

/datum/vehicle_constants
	/// Vehicle Limits
	var/static/MAX_VEHICLE_SIZE = 5          // Maximum length/width in tiles
	var/static/MAX_COMPONENTS = 25           // Maximum frame pieces per vehicle

	/// Wall Configuration Type Definitions
	var/static/list/VEHICLE_WALLS = list(
		"" = list(
			type = "",
			opacity = FALSE,
			density = FALSE,
			armor = 0,
			max_health = 40,
			can_open = FALSE,
			icon_state = "",
		),
		"c_wall" = list(
			type = "c_wall",
			opacity = TRUE,
			density = TRUE,
			armor = 20,
			max_health = 50,
			can_open = FALSE,
			icon_state = "c_wall",
		),
		"c_window" = list(
			type = "c_window",
			opacity = FALSE,
			density = TRUE,
			armor = 10,
			max_health = 40,
			can_open = FALSE,
			icon_state = "c_window",
		),
		"c_windshield" = list(
			type = "c_windshield",
			opacity = FALSE,
			density = TRUE,
			armor = 6,
			max_health = 35,
			can_open = FALSE,
			icon_state = "c_windshield",
		),
		"c_armoredfront" = list(
			type = "c_armoredfront",
			opacity = FALSE,
			density = TRUE,
			armor = 45,
			max_health = 80,
			can_open = FALSE,
			icon_state = "c_armoredfront",
		),
		"c_armoredwall" = list(
			type = "c_armoredwall",
			opacity = TRUE,
			density = TRUE,
			armor = 55,
			max_health = 90,
			can_open = FALSE,
			icon_state = "c_armoredwall",
		),
		"c_door" = list(
			type = "c_door",
			opacity = TRUE,
			density = TRUE,
			armor = 20,
			max_health = 45,
			can_open = TRUE,
			icon_state = "c_door",
		),
		"c_windowdoor" = list(
			type = "c_windowdoor",
			opacity = FALSE,
			density = TRUE,
			armor = 28,
			max_health = 60,
			can_open = TRUE,
			icon_state = "c_windowdoor",
		),
	)

/// Rotation matrices for vehicle turning calculations
/// These define how vehicle parts rotate when turning
var/global/list/rotation_matrixes1 = list(
	"right" = list(
		"1,1" = list("1,1"),),
	"left" = list(
		"1,1" = list("1,1"),),)

var/global/list/rotation_matrixes2 = list(
	"right" = list(
		"1,1" = list("1,2"),
		"1,2" = list("2,2"),
		"2,1" = list("1,1"),
		"2,2" = list("2,1"),),
	"left" = list(
		"1,1" = list("2,1"),
		"1,2" = list("1,1"),
		"2,1" = list("2,2"),
		"2,2" = list("1,2"),),)

var/global/list/rotation_matrixes3 = list(
	"right" = list(
		"1,1" = list("1,3"),
		"1,2" = list("2,3"),
		"1,3" = list("3,3"),
		"2,1" = list("1,2"),
		"2,2" = list("2,2"),
		"2,3" = list("3,2"),
		"3,1" = list("1,1"),
		"3,2" = list("2,1"),
		"3,3" = list("3,1"),),
	"left" = list(
		"1,1" = list("3,1"),
		"1,2" = list("2,1"),
		"1,3" = list("1,1"),
		"2,1" = list("3,2"),
		"2,2" = list("2,2"),
		"2,3" = list("1,2"),
		"3,1" = list("3,3"),
		"3,2" = list("2,3"),
		"3,3" = list("1,3"),),)

var/global/list/rotation_matrixes4 = list(
	"right" = list(
		"1,1" = list("1,4"),
		"1,2" = list("2,4"),
		"1,3" = list("3,4"),
		"1,4" = list("4,4"),
		"2,1" = list("1,3"),
		"2,2" = list("2,3"),
		"2,3" = list("3,3"),
		"2,4" = list("4,3"),
		"3,1" = list("1,2"),
		"3,2" = list("2,2"),
		"3,3" = list("3,2"),
		"3,4" = list("4,2"),
		"4,1" = list("1,1"),
		"4,2" = list("2,1"),
		"4,3" = list("3,1"),
		"4,4" = list("4,1"),),
	"left" = list(
		"1,1" = list("4,1"),
		"1,2" = list("3,1"),
		"1,3" = list("2,1"),
		"1,4" = list("1,1"),
		"2,1" = list("4,2"),
		"2,2" = list("3,2"),
		"2,3" = list("2,2"),
		"2,4" = list("1,2"),
		"3,1" = list("4,3"),
		"3,2" = list("3,3"),
		"3,3" = list("2,3"),
		"3,4" = list("1,3"),
		"4,1" = list("4,4"),
		"4,2" = list("3,4"),
		"4,3" = list("2,4"),
		"4,4" = list("1,4"),),)

var/global/list/rotation_matrixes5 = list(
	"right" = list(
		"1,1" = list("1,5"),
		"1,2" = list("2,5"),
		"1,3" = list("3,5"),
		"1,4" = list("4,5"),
		"1,5" = list("5,5"),
		"2,1" = list("1,4"),
		"2,2" = list("2,4"),
		"2,3" = list("3,4"),
		"2,4" = list("4,4"),
		"2,5" = list("5,4"),
		"3,1" = list("1,3"),
		"3,2" = list("2,3"),
		"3,3" = list("3,3"),
		"3,4" = list("4,3"),
		"3,5" = list("5,3"),
		"4,1" = list("1,2"),
		"4,2" = list("2,2"),
		"4,3" = list("3,2"),
		"4,4" = list("4,2"),
		"4,5" = list("5,2"),
		"5,1" = list("1,1"),
		"5,2" = list("2,1"),
		"5,3" = list("3,1"),
		"5,4" = list("4,1"),
		"5,5" = list("5,1"),),
	"left" = list(
		"1,1" = list("5,1"),
		"1,2" = list("4,1"),
		"1,3" = list("3,1"),
		"1,4" = list("2,1"),
		"1,5" = list("1,1"),
		"2,1" = list("5,2"),
		"2,2" = list("4,2"),
		"2,3" = list("3,2"),
		"2,4" = list("2,2"),
		"2,5" = list("1,2"),
		"3,1" = list("5,3"),
		"3,2" = list("4,3"),
		"3,3" = list("3,3"),
		"3,4" = list("2,3"),
		"3,5" = list("1,3"),
		"4,1" = list("5,4"),
		"4,2" = list("4,4"),
		"4,3" = list("3,4"),
		"4,4" = list("2,4"),
		"4,5" = list("1,4"),
		"5,1" = list("5,5"),
		"5,2" = list("4,5"),
		"5,3" = list("3,5"),
		"5,4" = list("2,5"),
		"5,5" = list("1,5"),),)
