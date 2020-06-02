#define DEBUG

//some colors
#define COLOR_RED	"#FF0000"
#define COLOR_GREEN  "#00FF00"
#define COLOR_BLUE   "#0000FF"
#define COLOR_CYAN   "#00FFFF"
#define COLOR_PINK   "#FF00FF"
#define COLOR_YELLOW "#FFFF00"
#define COLOR_ORANGE "#FF9900"
#define COLOR_WHITE  "#FFFFFF"
#define COLOR_BLACK  "#000000"
#define COLOR_LIGHT_BLUE "#4242F0"
#define COLOR_SILVER		   "#c0c0c0"
#define COLOR_GOLD		   "#FFD700"
#define COLOR_GRAY			 "#808080"
#define COLOR_RED_LIGHT		"#b00000"
#define COLOR_MAROON		   "#800000"
#define COLOR_AMBER			"#ffbf00"
#define COLOR_OLIVE			"#808000"
#define COLOR_LIME			 "#00ff00"
#define COLOR_TEAL			 "#008080"
#define COLOR_BLUE_LIGHT	   "#33ccff"
#define COLOR_NAVY			 "#000080"
#define COLOR_PURPLE		   "#800080"
#define COLOR_LUMINOL		  "#66ffff"
#define COLOR_BEIGE			"#ceb689"
#define COLOR_BLUE_GRAY		"#6a97b0"
#define COLOR_BROWN			"#b19664"
#define COLOR_DARK_BROWN	   "#917448"
#define COLOR_DARK_ORANGE	  "#b95a00"
#define COLOR_GREEN_GRAY	   "#8daf6a"
#define COLOR_RED_GRAY		 "#aa5f61"
#define COLOR_PALE_BLUE_GRAY   "#8bbbd5"
#define COLOR_PALE_GREEN_GRAY  "#aed18b"
#define COLOR_PALE_RED_GRAY	"#cc9090"
#define COLOR_PALE_PURPLE_GRAY "#bda2ba"
#define COLOR_PURPLE_GRAY	  "#a2819e"
#define COLOR_SUN			  "#ec8b2f"

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

#define BOMBCAP_DVSTN_RADIUS (max_explosion_range/4)
#define BOMBCAP_HEAVY_RADIUS (max_explosion_range/2)
#define BOMBCAP_LIGHT_RADIUS max_explosion_range
#define BOMBCAP_FLASH_RADIUS (max_explosion_range*1.5)

//HUD element hidings flags
#define F12_FLAG 1 // 0001
#define TOGGLE_INVENTORY_FLAG 2 //0010