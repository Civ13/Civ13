/datum/hud_data

	var/list/equip_slots = list() // Checked by mob_can_equip().
	var/list/ProcessHUD = list("health","nutrition","body temperature",/*"pressure"*/,"toxin",/*"oxygen"*/,"fire", "throw","pull",
	"resist","drop","m_intent","equip","intent","help","harm","grab","disarm","damage zone", /*"internal"*/,"swap hand",
	"toggle gun mode","allow movement","allow item use","allow radio use","toggle inventory", "mode", "secondary attack", "mood", "tactic", "fixeye", "random damage zone")
	var/icon              // If set, overrides ui_style.
	//var/has_a_intent = TRUE  // Set to draw intent box.
	//var/has_m_intent = TRUE  // Set to draw move intent box.
	//var/has_warnings = TRUE  // Set to draw environment warnings.
	//var/has_pressure = TRUE  // Draw the pressure indicator.
	//var/has_nutrition = TRUE // Draw the nutrition indicator.
	//var/has_bodytemp = TRUE  // Draw the bodytemp indicator.
	var/has_hands = TRUE     // Set to draw hands.
	//var/has_drop = TRUE      // Set to draw drop button.
	//var/has_throw = TRUE     // Set to draw throw button.
	//var/has_resist = TRUE    // Set to draw resist button.
	var/has_internals = TRUE // Set to draw the internals toggle button.

	// Contains information on the position and tag for all inventory slots
	// to be drawn for the mob. This is fairly delicate, try to avoid messing with it
	// unless you know exactly what it does.
	var/list/gear = list(
		"i_clothing" =   slot_w_uniform,
		"o_clothing" =   slot_wear_suit,
		"mask" =         slot_wear_mask,
		"gloves" =       slot_gloves,
		"l_ear" =        slot_l_ear,
		"r_ear" =        slot_r_ear,
		"head" =         slot_head,
		"shoes" =        slot_shoes,
		"back" =         slot_back,
		"shoulder" =     slot_shoulder,
		"eyes" =         slot_eyes,
		"id" =           slot_wear_id,
		"storage1" =     slot_l_store,
		"storage2" =     slot_r_store,
		"belt" =         slot_belt,
		"l_hand" =       slot_l_hand,
		"r_hand" =       slot_r_hand
		)

/datum/hud_data/New()
	..()
	for (var/slot in gear)
		equip_slots |= gear[slot]

	if (has_hands)
		equip_slots |= slot_l_hand
		equip_slots |= slot_r_hand
		equip_slots |= slot_handcuffed

	if (slot_back in equip_slots)
		equip_slots |= slot_in_backpack

	if (slot_w_uniform in equip_slots)
		equip_slots |= slot_accessory

	equip_slots |= slot_legcuffed


/datum/hud_data/monkey

	gear = list(
		"l_hand" =       slot_l_hand,
		"r_hand" =       slot_r_hand,
		"mask" =         slot_wear_mask,
		"back" =         slot_back
		)