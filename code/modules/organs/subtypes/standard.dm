/****************************************************
			   ORGAN DEFINES
****************************************************/

/obj/item/organ/external/chest
	name = "upper body"
	limb_name = "chest"
	icon_name = "torso"
	w_class = 5
	body_part = UPPER_TORSO
	vital = TRUE
	amputation_point = "spine"
	joint = "neck"
	dislocated = -1
//	gendered_icon = TRUE
	cannot_amputate = TRUE
	parent_organ = null

/obj/item/organ/external/groin
	name = "lower body"
	limb_name = "groin"
	icon_name = "groin"
	w_class = 4
	body_part = LOWER_TORSO
	vital = TRUE
	parent_organ = "chest"
	amputation_point = "lumbar"
	joint = "hip"
	dislocated = -1
//	gendered_icon = TRUE

/obj/item/organ/external/arm
	limb_name = "l_arm"
	name = "left arm"
	icon_name = "l_arm"
	w_class = 3
	body_part = ARM_LEFT
	parent_organ = "chest"
	joint = "left elbow"
	amputation_point = "left shoulder"
	can_grasp = TRUE

/obj/item/organ/external/arm/right
	limb_name = "r_arm"
	name = "right arm"
	icon_name = "r_arm"
	body_part = ARM_RIGHT
	joint = "right elbow"
	amputation_point = "right shoulder"

/obj/item/organ/external/leg
	limb_name = "l_leg"
	name = "left leg"
	icon_name = "l_leg"
	w_class = 3
	body_part = LEG_LEFT
	icon_position = LEFT
	parent_organ = "groin"
	joint = "left knee"
	amputation_point = "left hip"
	can_stand = TRUE

/obj/item/organ/external/leg/right
	limb_name = "r_leg"
	name = "right leg"
	icon_name = "r_leg"
	body_part = LEG_RIGHT
	icon_position = RIGHT
	joint = "right knee"
	amputation_point = "right hip"

/obj/item/organ/external/foot
	limb_name = "l_foot"
	name = "left foot"
	icon_name = "l_foot"
	w_class = 2
	body_part = FOOT_LEFT
	icon_position = LEFT
	parent_organ = "l_leg"
	joint = "left ankle"
	amputation_point = "left ankle"
	can_stand = TRUE

/obj/item/organ/external/foot/removed()
	if (owner) owner.u_equip(owner.shoes)
	..()

/obj/item/organ/external/foot/right
	limb_name = "r_foot"
	name = "right foot"
	icon_name = "r_foot"
	body_part = FOOT_RIGHT
	icon_position = RIGHT
	parent_organ = "r_leg"
	joint = "right ankle"
	amputation_point = "right ankle"

/obj/item/organ/external/hand
	limb_name = "l_hand"
	name = "left hand"
	icon_name = "l_hand"
	w_class = 2
	body_part = HAND_LEFT
	parent_organ = "l_arm"
	joint = "left wrist"
	amputation_point = "left wrist"
	can_grasp = TRUE

/obj/item/organ/external/hand/removed()
	owner.u_equip(owner.gloves)
	..()

/obj/item/organ/external/hand/right
	limb_name = "r_hand"
	name = "right hand"
	icon_name = "r_hand"
	body_part = HAND_RIGHT
	parent_organ = "r_arm"
	joint = "right wrist"
	amputation_point = "right wrist"

/obj/item/organ/external/head
	limb_name = "head"
	icon_name = "head"
	name = "head"
	w_class = 3
	body_part = HEAD
	vital = TRUE
	parent_organ = "chest"
	joint = "jaw"
	amputation_point = "neck"
//	gendered_icon = TRUE
	var/can_intake_reagents = TRUE

/obj/item/organ/external/head/removed()
	if (owner)
		name = "[owner.real_name]'s head"
		owner.u_equip(owner.head)
		owner.u_equip(owner.l_ear)
		owner.u_equip(owner.r_ear)
		owner.u_equip(owner.wear_mask)
		spawn(1)
			owner.update_hair()
	..()

/obj/item/organ/external/head/take_damage(brute, burn, sharp, edge, used_weapon = null, list/forbidden_limbs = list())
	..(brute, burn, sharp, edge, used_weapon, forbidden_limbs)
	if (!disfigured)
		if (brute_dam > 40)
			if (prob(50))
				disfigure("brute")
		if (burn_dam > 40)
			disfigure("burn")
