// Television uses visible, physically paired cameras, not the military overwatch network.
#define CIV_TV_CAMERA_LIMIT 128
#define CIV_TV_VIEWER_LIMIT 32
var/global/list/civ_tv_cameras = list()
var/global/list/civ_tv_receivers = list()

/obj/item/tv_camera
	name = "studio television camera"
	desc = "A visible television camera. Use it on a television desk to pair it, then install it and drag an adjacent cable onto it."
	icon = 'icons/obj/cmss13_ports.dmi'
	icon_state = "helmet_camera"
	w_class = ITEM_SIZE_NORMAL
	powerneeded = 10
	var/network_id = ""
	var/frequency = 200
	var/enabled = FALSE
	var/camera_health = 40
	var/battery_charge = 0
	var/portable = FALSE
	var/tmp/retired = FALSE

/obj/item/tv_camera/street
	name = "street television camera"

/obj/item/tv_camera/helmet
	name = "television helmet camera"
	desc = "A visible, battery-powered TV camera. Pair it at a television desk, charge it with a power cell, and fit it to worn headgear."
	portable = TRUE
	powerneeded = 0
	w_class = ITEM_SIZE_SMALL

/obj/item/tv_camera/New()
	..()
	if (civ_tv_cameras.len < CIV_TV_CAMERA_LIMIT) civ_tv_cameras |= src

/obj/item/tv_camera/persistence_runtime_var(var_name)
	return var_name == "retired" || ..()

/obj/item/tv_camera/after_load()
	. = ..()
	retired = FALSE
	if (civ_tv_cameras.len < CIV_TV_CAMERA_LIMIT) civ_tv_cameras |= src
	if (portable && istype(loc, /obj/item/clothing/head))
		var/obj/item/clothing/head/H = loc
		H.verbs |= /obj/item/clothing/head/proc/remove_tv_camera

/obj/item/tv_camera/Destroy()
	retired = TRUE
	civ_tv_cameras -= src
	for (var/obj/structure/telecom/station/tv/S in civ_telecom_devices)
		if (S.video_camera == src) S.stop_video()
	return ..()

/obj/item/tv_camera/Del()
	civ_tv_cameras -= src
	return ..()

/obj/item/tv_camera/proc/camera_eye()
	if (!portable) return isturf(loc) && anchored ? src : null
	var/obj/item/clothing/head/H = loc
	if (!istype(H)) return null
	var/mob/living/human/wearer = H.loc
	return istype(wearer) && wearer.head == H && wearer.stat != DEAD ? wearer : null

/obj/item/tv_camera/proc/operational()
	return !retired && !QDELETED(src) && (src in civ_tv_cameras) && civ_telecom_era_allowed(type) && enabled && camera_health > 0 && camera_eye() && (portable ? battery_charge > 0 : draw_cable_power())

/obj/item/tv_camera/MouseDrop_T(atom/movable/O, mob/living/human/H)
	if (!portable) civ_attach_cable(O, H)

/obj/item/tv_camera/examine(mob/user)
	. = ..()
	to_chat(user, SPAN_NOTICE("Visible television camera, frequency [frequency]. [length(network_id) ? "Paired to a station." : "Not paired."] [enabled ? "The red power light is on." : "Switched off."]"))
	if (portable) to_chat(user, "Battery: [round(battery_charge)]/1000.")

/obj/item/tv_camera/proc/can_configure(mob/living/human/H)
	var/turf/T = get_turf(src)
	return T && istype(H) && H.stat == CONSCIOUS && H.can_use_hands() && H.z == T.z && get_dist(H, src) <= 1

/obj/item/tv_camera/attack_self(mob/living/human/H)
	if (!can_configure(H)) return
	var/list/options = list("Power", "Cancel")
	if (!portable) options += "Install"
	else options += "Fit to helmet"
	var/choice = input(H, "Pair at the desk before installing. Helmet batteries recharge from a power cell.", name) as null|anything in options
	if (!can_configure(H)) return
	if (choice == "Power")
		enabled = !enabled
		if (!enabled && powersource) powersource.update_power(-powerneeded, 1, src)
	if (choice == "Install" && !portable && loc == H)
		H.drop_from_inventory(src)
		anchored = TRUE
	if (choice == "Fit to helmet" && portable && loc == H)
		var/obj/item/clothing/head/hat = H.head
		if (!istype(hat) || (locate(/obj/item/tv_camera/helmet) in hat.contents)) return
		H.drop_from_inventory(src)
		forceMove(hat)
		hat.verbs |= /obj/item/clothing/head/proc/remove_tv_camera
		H.visible_message(SPAN_NOTICE("[H] clips a visible television camera to [hat]."))
	civ_tick_tv_views()

/obj/item/tv_camera/attack_hand(mob/living/human/H)
	if (anchored) return attack_self(H)
	return ..()

/obj/item/tv_camera/attackby(obj/item/W, mob/living/human/H)
	if (!can_configure(H)) return
	if (portable && istype(W, /obj/item/weapon/cell))
		var/obj/item/weapon/cell/C = W
		battery_charge += C.use(max(0, 1000 - battery_charge))
		to_chat(H, "Camera battery: [round(battery_charge)]/1000.")
		return
	if (!portable && istype(W, /obj/item/weapon/wrench))
		anchored = !anchored
		if (!anchored && powersource)
			powersource.update_power(-powerneeded, 1, src)
			powersource.connections -= src
			powersource = null
		civ_tick_tv_views()
		return
	if (W.force > 0)
		camera_health -= W.force
		H.visible_message(SPAN_WARNING("[H] strikes the visible television camera with [W]."))
		if (camera_health <= 0) qdel(src)
		return
	return ..()

/obj/item/tv_camera/bullet_act(obj/item/projectile/P)
	camera_health -= P.damage
	if (camera_health <= 0) qdel(src)

/obj/item/clothing/head/proc/remove_tv_camera()
	set name = "Remove Television Camera"
	set category = null
	set src in usr
	var/mob/living/human/H = usr
	if (!istype(H) || H.stat != CONSCIOUS || !H.can_use_hands()) return
	for (var/obj/item/tv_camera/helmet/C in contents)
		C.forceMove(get_turf(H))
		H.put_in_hands(C)
	verbs -= /obj/item/clothing/head/proc/remove_tv_camera
	civ_tick_tv_views()

/obj/structure/telecom/station/tv
	var/tv_network_id = ""
	var/tmp/obj/item/tv_camera/video_camera
	var/tmp/turf/video_desk_origin
	var/tmp/atom/movable/video_eye
	var/tmp/turf/video_camera_origin

/obj/structure/telecom/station/tv/persistence_runtime_var(var_name)
	return (var_name in list("video_camera", "video_desk_origin", "video_camera_origin", "video_eye")) || ..()

/obj/structure/telecom/station/tv/after_load()
	. = ..()
	stop_video()

/obj/structure/telecom/station/tv/Destroy()
	stop_video()
	return ..()

/obj/structure/telecom/station/tv/attackby(obj/item/W, mob/living/human/H)
	if (istype(W, /obj/item/tv_camera))
		pair_camera(H, W)
		return
	return ..()

/obj/structure/telecom/station/tv/proc/pair_camera(mob/living/human/H, obj/item/tv_camera/C)
	if (!can_present(H) || !H.can_use_hands() || !C || C.loc != H || !civ_telecom_era_allowed(type)) return FALSE
	if (!length(tv_network_id)) tv_network_id = md5("[world.realtime]-[rand(1,1000000000)]-\ref[src]")
	C.network_id = tv_network_id
	C.frequency = frequency
	to_chat(H, "You pair [C] to [broadcast_label()] on frequency [frequency].")
	civ_tick_tv_views()
	return TRUE

/obj/structure/telecom/station/tv/proc/camera_available(obj/item/tv_camera/C)
	var/turf/T = get_turf(C)
	return T && C && !QDELETED(C) && length(tv_network_id) && C.network_id == tv_network_id && C.frequency == frequency && T.z == z && get_dist(src, T) <= 60 && C.operational()

/obj/structure/telecom/station/tv/proc/prompt_video(mob/living/human/H)
	if (!can_present(H)) return
	var/list/options = list()
	var/i = 0
	for (var/obj/item/tv_camera/C in civ_tv_cameras)
		if (camera_available(C)) options["[++i]: [C.name] ([get_area(C)])"] = C
	if (!options.len)
		to_chat(H, "No powered cameras paired to this station are in range.")
		return
	var/choice = input(H, "Put a paired camera on air", name) as null|anything in options
	if (choice && can_present(H)) start_video(options[choice])

/obj/structure/telecom/station/tv/proc/start_video(obj/item/tv_camera/C)
	if (!operational() || !has_antenna() || !camera_available(C)) return FALSE
	stop_video()
	video_camera = C
	video_eye = C.camera_eye()
	video_camera_origin = get_turf(C)
	video_desk_origin = get_turf(src)
	return TRUE

/obj/structure/telecom/station/tv/proc/video_available()
	return operational() && has_antenna() && get_turf(src) == video_desk_origin && camera_available(video_camera) && video_camera.camera_eye() == video_eye && (video_camera.portable || get_turf(video_camera) == video_camera_origin)

/obj/structure/telecom/station/tv/proc/stop_video()
	video_camera = null
	video_eye = null
	video_camera_origin = null
	video_desk_origin = null
	for (var/obj/structure/telecom/tv/R in civ_tv_receivers.Copy())
		if (R.watching_station == src) R.stop_all_watching()

/obj/structure/telecom/tv
	var/tmp/list/tv_watchers = list()
	var/tmp/obj/structure/telecom/station/tv/watching_station
	var/tmp/turf/receiver_origin

/obj/structure/telecom/tv/persistence_runtime_var(var_name)
	return (var_name in list("tv_watchers", "watching_station", "receiver_origin")) || ..()

/obj/structure/telecom/tv/after_load()
	. = ..()
	stop_all_watching()

/obj/structure/telecom/tv/Destroy()
	stop_all_watching()
	return ..()

/obj/structure/telecom/tv/Del()
	stop_all_watching()
	return ..()

/obj/structure/telecom/tv/proc/can_watch(mob/living/human/H)
	return H && !QDELETED(H) && H.broadcast_online() && H.stat == CONSCIOUS && !H.sleeping && !H.blinded && H.z == z && get_dist(H, src) <= 1

/obj/structure/telecom/tv/attack_hand(mob/living/human/H)
	if (!can_watch(H)) return
	if (H in tv_watchers)
		stop_watching(H)
		return
	var/choice = input(H, "Receiver controls", name) in list("Equipment", "Watch video", "Cancel")
	if (!can_watch(H)) return
	if (choice == "Equipment") return ..()
	if (choice != "Watch video") return
	var/list/options = list()
	var/i = 0
	for (var/obj/structure/telecom/station/tv/S in civ_telecom_devices)
		if (S.node_receiver_available(src) && S.video_available()) options["[++i]: [S.broadcast_label()]"] = S
	if (!options.len)
		to_chat(H, "No matching television station has a live video feed.")
		return
	var/selected = input(H, "Choose a station's video feed", name) as null|anything in options
	if (selected) start_watching(H, options[selected])

/obj/structure/telecom/tv/proc/start_watching(mob/living/human/H, obj/structure/telecom/station/tv/S)
	if (!can_watch(H) || !S || !S.node_receiver_available(src) || !S.video_available()) return FALSE
	var/count = 0
	for (var/obj/structure/telecom/tv/R in civ_tv_receivers)
		if (R.watching_station == S) count += R.tv_watchers.len
	if (count >= CIV_TV_VIEWER_LIMIT || (watching_station && watching_station != S)) return FALSE
	// Do not leave this mob registered with a previous camera receiver.
	if (istype(H.using_object, /obj/structure/telecom/tv))
		var/obj/structure/telecom/tv/previous = H.using_object
		previous.stop_watching(H)
	H.set_using_object(src)
	watching_station = S
	receiver_origin = get_turf(src)
	tv_watchers[H] = get_turf(H)
	civ_tv_receivers |= src
	H.reset_view(S.video_eye)
	to_chat(H, "You watch the television feed. Move or click the receiver to stop.")
	return TRUE

/obj/structure/telecom/tv/proc/feed_ok(mob/living/human/H)
	return (H in tv_watchers) && H.using_object == src && can_watch(H) && get_turf(H) == tv_watchers[H] && get_turf(src) == receiver_origin && watching_station && watching_station.node_receiver_available(src) && watching_station.video_available()

/obj/structure/telecom/tv/proc/stop_watching(mob/living/human/H)
	tv_watchers -= H
	if (H && H.using_object == src)
		H.unset_using_object()
		H.reset_view(null)
		to_chat(H, "The television feed ends.")
	if (!tv_watchers.len)
		civ_tv_receivers -= src
		watching_station = null
		receiver_origin = null

/obj/structure/telecom/tv/proc/stop_all_watching()
	for (var/mob/living/human/H in tv_watchers.Copy()) stop_watching(H)
	civ_tv_receivers -= src
	watching_station = null
	receiver_origin = null

/obj/structure/telecom/tv/check_eye(mob/user)
	if (feed_ok(user)) return 0
	stop_watching(user)
	return -1

/proc/civ_tick_tv_views()
	for (var/obj/structure/telecom/station/tv/S in civ_telecom_devices)
		if (S.video_camera && !S.video_available()) S.stop_video()
	for (var/obj/structure/telecom/tv/R in civ_tv_receivers.Copy())
		for (var/mob/living/human/H in R.tv_watchers.Copy())
			if (!R.feed_ok(H)) R.stop_watching(H)

/proc/civ_tick_television()
	for (var/obj/item/tv_camera/C in civ_tv_cameras)
		if (C.portable && C.enabled && C.camera_eye()) C.battery_charge = max(0, C.battery_charge - 1)
	civ_tick_tv_views()

#undef CIV_TV_CAMERA_LIMIT
#undef CIV_TV_VIEWER_LIMIT
