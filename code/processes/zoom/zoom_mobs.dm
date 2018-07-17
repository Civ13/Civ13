/process/zoom_mobs

/process/zoom_mobs/setup()
	name = "zoom mobs"
	schedule_interval = 0.7 SECONDS
	start_delay = 2 SECONDS
	fires_at_gamestates = list(GAME_STATE_PLAYING, GAME_STATE_FINISHED)
	priority = PROCESS_PRIORITY_MEDIUM
	processes.zoom_mobs = src

/process/zoom_mobs/fire()

	// make stuff invisible while we're scoping
	for (current in current_list)

		var/mob/living/carbon/human/H = current

		if (!isDeleted(H))
			try
				if (H.client)
					if (H.using_zoom())
						for (var/obj/O in H.client.screen)
							if (O.invisibility)
								continue
							if (istype(O, /obj/screen/movable/action_button))
								var/obj/screen/movable/action_button/A = O
								if (A.name == "Toggle Sights" || (A.owner && istype(A.owner, /datum/action/toggle_scope)))
									continue
							O.invisibility = 100
							O.scoped_invisible = TRUE
							if (istype(O, /obj/item/weapon/attachment/scope))
								zoom_scopes_list |= O
							else if (istype(O, /obj/item/weapon/gun))
								var/obj/item/weapon/gun/G = O
								for (var/obj/item/weapon/attachment/scope/S in G.attachments)
									zoom_scopes_list |= S
					else
						for (var/obj/O in H.client.screen)
							if (O.scoped_invisible)
								O.invisibility = FALSE
						H.client.pixel_x = 0
						H.client.pixel_y = 0

			catch(var/exception/e)
				catchException(e, H)
		else
			catchBadType(H)
			zoom_processing_mobs -= H

		PROCESS_LIST_CHECK
		PROCESS_TICK_CHECK

/process/zoom_mobs/reset_current_list()
	PROCESS_USE_FASTEST_LIST(zoom_processing_mobs)

/process/zoom_mobs/statProcess()
	..()
	stat(null, "[zoom_processing_mobs.len] mobs")

/process/zoom_mobs/htmlProcess()
	return ..() + "[zoom_processing_mobs.len] mobs"
