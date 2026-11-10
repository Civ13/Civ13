/world/New()
	var/mob/living/human/patient = new
	var/mob/living/human/surgeon = new
	var/obj/item/organ/external/left = new
	var/obj/item/organ/external/right = new
	var/obj/item/organ/external/donor_right = new
	var/obj/item/organ/external/other_left = new
	left.limb_name = "l_arm"
	right.limb_name = "r_arm"
	donor_right.limb_name = "r_arm"
	other_left.limb_name = "l_arm"
	patient.limbs["r_arm"] = right
	var/datum/surgery_step/limb/attach/S = new
	var/failures = 0
	if (S.can_use(surgeon, patient, "l_arm", left) != TRUE)
		failures++
	if (S.can_use(surgeon, patient, "l_arm", donor_right) != SURGERY_FAILURE)
		failures++
	if (S.can_use(surgeon, patient, "r_arm", right) != FALSE)
		failures++
	S.end_step(surgeon, patient, "l_arm", donor_right)
	if (patient.limbs["r_arm"] != right || patient.limbs["l_arm"])
		failures++
	patient.limbs["l_arm"] = other_left
	S.end_step(surgeon, patient, "l_arm", left)
	if (patient.limbs["l_arm"] != other_left)
		failures++
	patient.limbs["l_arm"] = null
	S.end_step(surgeon, patient, "l_arm", left)
	if (patient.limbs["l_arm"] != left)
		failures++
	text2file("[failures]", "result.txt")
	shutdown()
