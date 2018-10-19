
#define MIDDLE_CLICK FALSE
#define ALT_CLICK TRUE
#define CTRL_CLICK 2
#define MAX_HARDSUIT_CLICK_MODE 2

/client
	var/hardsuit_click_mode = MIDDLE_CLICK

/mob/living/MiddleClickOn(atom/A)
	if (client && client.hardsuit_click_mode == MIDDLE_CLICK)
		if (HardsuitClickOn(A))
			return
	..()

/mob/living/AltClickOn(atom/A)
	if (client && client.hardsuit_click_mode == ALT_CLICK)
		if (HardsuitClickOn(A))
			return
	..()

/mob/living/CtrlClickOn(atom/A)
	if (client && client.hardsuit_click_mode == CTRL_CLICK)
		if (HardsuitClickOn(A))
			return
	..()

/mob/living/proc/can_use_rig()
	return FALSE

/mob/living/carbon/human/can_use_rig()
	return TRUE

/mob/living/carbon/brain/can_use_rig()
	return FALSE

/mob/living/proc/HardsuitClickOn(var/atom/A, var/alert_ai = FALSE)
	return FALSE

#undef MIDDLE_CLICK
#undef ALT_CLICK
#undef CTRL_CLICK
#undef MAX_HARDSUIT_CLICK_MODE
