/*
	These defines specificy screen locations.  For more information, see the byond documentation on the screen_loc var.

	The short version:

	Everything is encoded as strings because apparently that's how Byond rolls.

	"1,1" is the bottom left square of the user's screen.  This aligns perfectly with the turf grid.
	"1:2,3:4" is the square (1,3) with pixel offsets (+2, +4); slightly right and slightly above the turf grid.
	Pixel offsets are used so you don't perfectly hide the turf under them, that would be crappy.

	The size of the user's screen is defined by client.view (indirectly by WORLD_VIEW), in our case "15x15".
	Therefore, the top right corner (except during admin shenanigans) is at "15,15"
*/
// TODO: Sort definitions by type of HUD

#define ui_entire_screen "WEST,SOUTH to EAST,NORTH"
#define ui_blank "blank"

///////////////////// Icons /////////////////////
// What we see
// Types of HUDs
#define ui_hud_1713 'icons/mob/screen/1713Style.dmi' // Standard, used even in the new one from offs
#define ui_hud_liteweb 'icons/mob/screen/litewebStyle.dmi' // A mixture of regular and lifeweb
#define ui_hud_FoF 'icons/mob/screen/FoFStyle.dmi' // Straight from the build of the same name

// Overlay
#define ui_hud_overlay 'icons/mob/screen1_full.dmi' // Overlay of damage, gas mask and everything in general
#define ui_hud_effects 'icons/mob/screen/effects.dmi' // Overlay of single-tile screen effects such as pain or interference
#define ui_hud_drug "" // In the process, the effect of intoxication


// Interface
// Doll
#define ui_hud_health_1713 'icons/mob/screen/healthdoll.dmi'
#define ui_hud_health_liteweb 'icons/mob/screen/healthdoll_lw.dmi'
#define ui_hud_health_FoF 'icons/mob/screen/healthdoll_fof.dmi'

// Aiming zone, tied to the doll
#define ui_hud_zone_sel_1713 'icons/mob/screen/zone_sel.dmi'
#define ui_hud_zone_sel_liteweb 'icons/mob/screen/zone_sel_lw.dmi'
#define ui_hud_zone_sel_FoF 'icons/mob/screen/zone_sel_fof.dmi'

///////////////////// Position /////////////////////
// What is located at the required screen coordinates

// Overlay
#define ui_screen_cover "-2,1"
#define ui_damageoverlay "CENTER-7,CENTER-7"
#define ui_flash "WEST,SOUTH to EAST,NORTH"
#define ui_pain "WEST,SOUTH to EAST,NORTH"
#define ui_drugeffect "WEST,SOUTH to EAST,NORTH"
#define ui_nvg "WEST,SOUTH to EAST,NORTH"
#define ui_thermal "WEST,SOUTH to EAST,NORTH"
#define ui_fov "CENTER-7,CENTER-7"
#define ui_gasmask "CENTER-7,CENTER-7"

// Basics
// Need to sort
#define ui_health "EAST-1:28,7:5" // "15,7"
#define ui_nutrition "EAST-1:28,6:5" // "15,6"
#define ui_mood "EAST-1:28,8:5" // "15,8"
#define ui_body_temperature "EAST-1:28,9:5" // "15,9"
#define ui_throw "EAST-2:28,2:5" // "14,2"
#define ui_pull "EAST-2:28,2:5" // "14,2"
#define ui_drop "EAST-2:28,2:5" // "14,2"
#define ui_resist "EAST-2:28,2:5" // "14,2"
#define ui_m_intent "EAST-2:28,1:5" // "14,1"
#define ui_secondary_attack "EAST-5:28,1:5" // "11,1"
#define ui_mode "EAST-6:28,1:5" // "10,1"


#define ui_tactic "EAST-7:28,1:5" // "9,1"
#define ui_equip "WEST+6:16,2:5" // "7,2"
// Replace with modern intent changes
#define ui_intent "EAST-4:44,1:5" // "12:16,1" 
#define ui_help "EAST-4:28,1:5" // "12,1"
#define ui_disarm "EAST-4:28,1:5" // "12,1"
#define ui_harm "EAST-3:28,1:5" // "13,1"
#define ui_grab "EAST-3:28,1:5" // "13,1"
#define ui_random_damage_zone "EAST-1:28,3:5" // "15,3"
#define ui_damage_zone "EAST-1:28,1:5" // "15,1"
#define ui_swap_hand "WEST+6:16,2:5" // "7,2"
#define ui_fixeye "EAST-1:28,3:24" // "15,3:13"
#define ui_toggle_inventory "WEST:6,1:5" // "1,1"

// Inventory
#define ui_i_clothing "WEST:6,2:7" // "2,3"
#define ui_o_clothing "WEST+1:8,2:7" // "2,2"
#define ui_mask "WEST+1:8,3:8" // "3,3"
#define ui_gloves "WEST+2:10,2:7" // "1,3"
#define ui_l_ear "WEST:6,4:9" // "1,4"
#define ui_r_ear "WEST+2:10,4:9" // "3,4"
#define ui_head "WEST+1:8,4:11" // "2,5"
#define ui_shoes "WEST+1:8,1:5" // "1,2"
#define ui_eyes "WEST:6,3:8" // "2,4"
#define ui_shoulder "WEST+2:10,1:5" // "5,1"
#define ui_storage1 "WEST+8:18,1:5" // "2,1"
#define ui_storage2 "WEST+9:20,1:5" // "3,1"
#define ui_id "WEST+2:10,3:8" // "3,2"
#define ui_belt "WEST+4:14,1:5" // "4,1"
#define ui_back "WEST+5:14,1:5" // "6,1"
#define ui_l_hand "WEST+7:16,1:5" // "8,1"
#define ui_r_hand "WEST+6:16,1:5" // "7,1"

