#define DEBUG

// Turf-only flags.
// Some arbitrary defines to be used by self-pruning global lists. (see master_controller)
#define PROCESS_KILL 26 // Used to trigger removal from a processing list.

//some colors
#define COLOR_WHITE            "#ffffff"
#define COLOR_SILVER           "#c0c0c0"
#define COLOR_GRAY             "#808080"
#define COLOR_BLACK            "#000000"
#define COLOR_RED              "#ff0000"
#define COLOR_RED_LIGHT        "#b00000"
#define COLOR_MAROON           "#800000"
#define COLOR_YELLOW           "#ffff00"
#define COLOR_AMBER            "#ffbf00"
#define COLOR_OLIVE            "#808000"
#define COLOR_LIME             "#00ff00"
#define COLOR_GREEN            "#008000"
#define COLOR_CYAN             "#00ffff"
#define COLOR_TEAL             "#008080"
#define COLOR_BLUE             "#0000ff"
#define COLOR_BLUE_LIGHT       "#33ccff"
#define COLOR_NAVY             "#000080"
#define COLOR_PINK             "#ff00ff"
#define COLOR_PURPLE           "#800080"
#define COLOR_ORANGE           "#ff9900"
#define COLOR_LUMINOL          "#66ffff"
#define COLOR_BEIGE            "#ceb689"
#define COLOR_BLUE_GRAY        "#6a97b0"
#define COLOR_BROWN            "#b19664"
#define COLOR_DARK_BROWN       "#917448"
#define COLOR_DARK_ORANGE      "#b95a00"
#define COLOR_GREEN_GRAY       "#8daf6a"
#define COLOR_RED_GRAY         "#aa5f61"
#define COLOR_PALE_BLUE_GRAY   "#8bbbd5"
#define COLOR_PALE_GREEN_GRAY  "#aed18b"
#define COLOR_PALE_RED_GRAY    "#cc9090"
#define COLOR_PALE_PURPLE_GRAY "#bda2ba"
#define COLOR_PURPLE_GRAY      "#a2819e"
#define COLOR_SUN              "#ec8b2f"

#define DEFAULT_JOB_TYPE /datum/job/assistant
/*
//Area flags, possibly more to come
#define RAD_SHIELDED 1 //shielded from radiation, clearly
*/
// Custom layer definitions, supplementing the default TURF_LAYER, MOB_LAYER, etc.
#define DOOR_OPEN_LAYER 2.7		//Under all objects if opened. 2.7 due to tables being at 2.6
#define DOOR_CLOSED_LAYER 3.1	//Above most items if closed
#define LIGHTING_LAYER 11
#define HUD_LAYER 20			//Above lighting, but below obfuscation. For in-game HUD effects (whereas SCREEN_LAYER is for abstract/OOC things like inventory slots)
#define OBFUSCATION_LAYER 21	//Where images covering the view for eyes are put
#define SCREEN_LAYER 22			//Mob HUD/effects layer

// Convoluted setup so defines can be supplied by Bay12 main server compile script.
// Should still work fine for people jamming the icons into their repo.
#ifndef CUSTOM_ITEM_OBJ
#define CUSTOM_ITEM_OBJ 'icons/obj/custom_items_obj.dmi'
#endif
#ifndef CUSTOM_ITEM_MOB
#define CUSTOM_ITEM_MOB 'icons/mob/custom_items_mob.dmi'
#endif
#ifndef CUSTOM_ITEM_SYNTH
#define CUSTOM_ITEM_SYNTH 'icons/mob/custom_synthetic.dmi'
#endif

#define WALL_CAN_OPEN 1
#define WALL_OPENING 2

#define DEFAULT_TABLE_MATERIAL "plastic"
#define DEFAULT_WALL_MATERIAL "steel"

#define SHARD_SHARD "shard"
#define SHARD_SHRAPNEL "shrapnel"
#define SHARD_STONE_PIECE "piece"
#define SHARD_SPLINTER "splinters"
#define SHARD_NONE ""

#define MATERIAL_UNMELTABLE 0x1
#define MATERIAL_BRITTLE    0x2
#define MATERIAL_PADDING    0x4

#define TABLE_BRITTLE_MATERIAL_MULTIPLIER 4 // Amount table damage is multiplied by if it is made of a brittle material (e.g. glass)

#define BOMBCAP_DVSTN_RADIUS (max_explosion_range/4)
#define BOMBCAP_HEAVY_RADIUS (max_explosion_range/2)
#define BOMBCAP_LIGHT_RADIUS max_explosion_range
#define BOMBCAP_FLASH_RADIUS (max_explosion_range*1.5)

#define WEAPON_FORCE_HARMLESS    3
#define WEAPON_FORCE_WEAK        7
#define WEAPON_FORCE_NORMAL      10
#define WEAPON_FORCE_PAINFUL    15
#define WEAPON_FORCE_DANGEROUS   20
#define WEAPON_FORCE_ROBUST      26
#define WEAPON_FORCE_LETHAL      51

// Special return values from bullet_act(). Positive return values are already used to indicate the blocked level of the projectile.
#define PROJECTILE_CONTINUE   -1 //if the projectile should continue flying after calling bullet_act()
#define PROJECTILE_FORCE_MISS -2 //if the projectile should treat the attack as a miss (suppresses attack and admin logs) - only applies to mobs.

//HUD element hidings flags
#define F12_FLAG 1 // 0001
#define TOGGLE_INVENTORY_FLAG 2 //0010