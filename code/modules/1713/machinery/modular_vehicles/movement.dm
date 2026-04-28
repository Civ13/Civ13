//////////////////////// REFACTORED MOVEMENT SYSTEM ////////////////////////
/// Consolidated wheel and track implementation using wheel_config datums.
/// This replaces 50+ type definitions with a single parameterizable type.

/obj/structure/vehicleparts/movement
	name = "wheel"
	var/datum/wheel_config/wconfig = null
	layer = 2.99
	crushable = FALSE
	var/broken = FALSE
	var/reversed = FALSE
	var/obj/structure/vehicleparts/axis/axis = null
	var/obj/structure/vehicleparts/frame/connected = null
	var/ntype = "wheel"
	var/base_icon = ""
	var/movement_icon = ""
	var/type_name = "wheel"  // For compatibility with old code

	/// Initialize movement with a wheel configuration
	New()
		..()
		if (!wconfig)
			// Default to standard wheel if none provided
			wconfig = get_wheel_config("standard_wheel")

		if (wconfig)
			src.name = wconfig.name
			src.icon = wconfig.icon
			src.icon_state = wconfig.icon_state
			src.type_name = wconfig.type_name  // Set for compatibility
			src.ntype = wconfig.type_name      // Set ntype for rendering logic
			src.reversed = wconfig.is_reversed
			broken = FALSE

	/// Get movement component type (wheel or track)
	proc/get_type()
		if (wconfig)
			return wconfig.type_name
		return "wheel"

	/// Get base icon state for this movement
	proc/get_base_icon()
		if (wconfig)
			return wconfig.base_icon_state
		return "wheel_default"

	/// Get movement animation icon state
	proc/get_movement_icon()
		if (wconfig)
			return wconfig.movement_icon_state
		return "wheel_default_m"

	/// Check if this movement is reversed
	proc/is_reversed()
		return src.reversed

	proc/load_config(var/datum/wheel_config/new_config = null)
		if (new_config)
			wconfig = new_config
		if (wconfig)
			src.name = wconfig.name
			src.icon = wconfig.icon
			src.icon_state = wconfig.icon_state
			src.type_name = wconfig.type_name  // Set for compatibility
			src.ntype = wconfig.type_name      // Set ntype for rendering logic
			src.reversed = wconfig.is_reversed
			broken = FALSE

	update_icon()
		if (!wconfig)
			return

		if (broken)
			icon_state = "[wconfig.base_icon_state]_broken"
		else
			if (axis)
				if (axis.moving && axis.currentspeed > 0)
					icon_state = "[wconfig.movement_icon_state]"
				else
					icon_state = "[wconfig.base_icon_state]"
			else
				icon_state = "[wconfig.base_icon_state]"

		if (connected)
			invisibility = 101
			connected.update_icon()
			return

	MouseDrop(var/obj/structure/vehicleparts/frame/VP)
		if (istype(VP, /obj/structure/vehicleparts/frame) && VP.axis)
			//Front-Right, Front-Left, Back-Right, Back-Left; FR, FL, BR, BL
			if (!isemptylist(VP.axis.corners))
				var/corner_idx = 0
				if (VP == VP.axis.corners[1])
					corner_idx = 1
				else if (VP == VP.axis.corners[2])
					corner_idx = 2
				else if (VP == VP.axis.corners[3])
					corner_idx = 3
				else if (VP == VP.axis.corners[4])
					corner_idx = 4
				else
					return

				// Determine reversed state based on corner position
					var/movement_type = src.type_name
					if (wconfig)
						movement_type = wconfig.type_name
					if (movement_type == "wheel")
						reversed = (corner_idx > 2)  // Back wheels are reversed
					else if (movement_type == "track")
						reversed = (corner_idx > 2)  // Tracks may reverse differently
					dir = VP.axis.dir

				VP.axis.wheels += src
				axis = VP.axis
				connected = VP
				VP.mwheel = src
				forceMove(VP)
				playsound(loc, 'sound/effects/lever.ogg', 80, TRUE)

	attackby(var/obj/item/I, var/mob/living/human/H)
		if (broken && istype(I, /obj/item/weapon/weldingtool))
			var/repair_type = src.type_name
			if (wconfig)
				repair_type = wconfig.type_name
			visible_message("[H] starts repairing \the [repair_type]...")
			if (do_after(H, 200, src))
				visible_message("[H] successfully repairs \the [repair_type].")
				broken = FALSE
				update_icon()
				return
		else
			..()

	ex_act(severity)
		switch(severity)
			if (1.0)
				Destroy()
				return
			if (2.0)
				if (prob(30))
					Destroy()
					return
			if (3.0)
				if (!broken)
					broken = TRUE
					visible_message(SPAN_DANGER("\The [name] breaks down!"))
					update_icon()

	Destroy()
		if (axis)
			axis.wheels -= src
		if (connected)
			connected.mwheel = null
		..()


/// Compatibility layer: These types now map to configs
/// Old code can still use /obj/structure/vehicleparts/movement/tracks/mtlb/left_front, etc.
/// and it will create the proper config-based movement

// Standard wheels (backwards compatibility)
/obj/structure/vehicleparts/movement/reversed/New()
	..()
	wconfig = get_wheel_config("standard_wheel_reversed")
	load_config(wconfig)

/obj/structure/vehicleparts/movement/armored/New()
	..()
	wconfig = get_wheel_config("armored_wheel")
	load_config(wconfig)

/obj/structure/vehicleparts/movement/armored/reversed/New()
	..()
	wconfig = get_wheel_config("armored_wheel_reversed")
	load_config(wconfig)

// BTR-80 wheels
/obj/structure/vehicleparts/movement/armored/btr/left/New()
	..()
	wconfig = get_wheel_config("btr80_wheel_front_left")
	load_config(wconfig)

/obj/structure/vehicleparts/movement/armored/btr/right/New()
	..()
	wconfig = get_wheel_config("btr80_wheel_front_right")
	load_config(wconfig)

/obj/structure/vehicleparts/movement/armored/btr/left/reversed/New()
	..()
	wconfig = get_wheel_config("btr80_wheel_back_left")
	load_config(wconfig)

/obj/structure/vehicleparts/movement/armored/btr/right/reversed/New()
	..()
	wconfig = get_wheel_config("btr80_wheel_back_right")
	load_config(wconfig)

// Generic tracks
/obj/structure/vehicleparts/movement/tracks/New()
	..()
	wconfig = get_wheel_config("track_standard")
	load_config(wconfig)

// Generic tracks
/obj/structure/vehicleparts/movement/tracks/reversed/New()
	..()
	wconfig = get_wheel_config("track_standard_reversed")
	load_config(wconfig)

/obj/structure/vehicleparts/movement/tracks/left/New()
	..()
	wconfig = get_wheel_config("track_standard_left")
	load_config(wconfig)

/obj/structure/vehicleparts/movement/tracks/right/New()
	..()
	wconfig = get_wheel_config("track_standard_right")
	load_config(wconfig)

// MT-LB tracks
/obj/structure/vehicleparts/movement/tracks/mtlb/left_front/New()
	..()
	wconfig = get_wheel_config("mtlb_track_left_front")
	load_config(wconfig)

/obj/structure/vehicleparts/movement/tracks/mtlb/right_front/New()
	..()
	wconfig = get_wheel_config("mtlb_track_right_front")
	load_config(wconfig)

/obj/structure/vehicleparts/movement/tracks/mtlb/left_back/New()
	..()
	wconfig = get_wheel_config("mtlb_track_left_back")
	load_config(wconfig)

/obj/structure/vehicleparts/movement/tracks/mtlb/right_back/New()
	..()
	wconfig = get_wheel_config("mtlb_track_right_back")
	load_config(wconfig)

// BMD-2 tracks (new 96x96 variant)
/obj/structure/vehicleparts/movement/tracks/bmd2new/left_front/New()
	..()
	wconfig = get_wheel_config("bmd2_track_left_front")
	load_config(wconfig)

/obj/structure/vehicleparts/movement/tracks/bmd2new/right_front/New()
	..()
	wconfig = get_wheel_config("bmd2_track_right_front")
	load_config(wconfig)

/obj/structure/vehicleparts/movement/tracks/bmd2new/left_back/New()
	..()
	wconfig = get_wheel_config("bmd2_track_left_back")
	load_config(wconfig)

/obj/structure/vehicleparts/movement/tracks/bmd2new/right_back/New()
	..()
	wconfig = get_wheel_config("bmd2_track_right_back")
	load_config(wconfig)

// Bradley tracks
/obj/structure/vehicleparts/movement/tracks/bradley/left_front/New()
	..()
	wconfig = get_wheel_config("bradley_track_left_front")
	load_config(wconfig)

/obj/structure/vehicleparts/movement/tracks/bradley/right_front/New()
	..()
	wconfig = get_wheel_config("bradley_track_right_front")
	load_config(wconfig)

/obj/structure/vehicleparts/movement/tracks/bradley/left_back/New()
	..()
	wconfig = get_wheel_config("bradley_track_left_back")
	load_config(wconfig)

/obj/structure/vehicleparts/movement/tracks/bradley/right_back/New()
	..()
	wconfig = get_wheel_config("bradley_track_right_back")
	load_config(wconfig)

// IS-3 tracks (96x96 variant)
/obj/structure/vehicleparts/movement/tracks/is3/left_front/New()
	..()
	wconfig = get_wheel_config("is3_track_left_front")
	load_config(wconfig)

/obj/structure/vehicleparts/movement/tracks/is3/right_front/New()
	..()
	wconfig = get_wheel_config("is3_track_right_front")
	load_config(wconfig)

/obj/structure/vehicleparts/movement/tracks/is3/left_back/New()
	..()
	wconfig = get_wheel_config("is3_track_left_back")
	load_config(wconfig)

/obj/structure/vehicleparts/movement/tracks/is3/right_back/New()
	..()
	wconfig = get_wheel_config("is3_track_right_back")
	load_config(wconfig)

// Additional type stubs for IS-2, T-34, Char-B1, M41, etc. follow same pattern
