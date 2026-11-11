// Bug report screenshots: a picture of what the reporter sees when they open Help > Report bug.
// BYOND gives the server no way to read a client's screen (the client's own .screenshot command
// only saves on the player's computer), so the server draws the map the player can see from the
// atoms in their view, the way a camera photo is made (getFlatIcon, as generate_image does).
// The HUD, darkness and screen effects are not drawn.
//
// The picture is drawn in the background while the player types, saved as
// data/bug_reports/screens/<id>.png, shown to admins in Admin > Bug Reports and, when an admin
// chooses to attach it, uploaded to BUG_REPORT_SCREENSHOT_REPO with its own token
// (BUG_REPORT_SCREENSHOT_TOKEN, Contents read and write on that repository only), so the issue
// can show it. Like the issue token it is read from config/config.txt only while uploading.

#define BUG_REPORT_SHOT_DIR "data/bug_reports/screens/"
#define BUG_REPORT_SHOT_MAX_TILES 1500 // turfs drawn at most; a 21x15 view with its margin is 475
#define BUG_REPORT_SHOT_MAX_VIEW 41 // tiles across or up
#define BUG_REPORT_SHOT_WAIT 300 // ticks the report waits for a picture still being drawn

/datum/bug_report_capture
	var/icon/picture
	var/done = FALSE

// Draws in the background; result() waits for it.
/datum/bug_report_capture/proc/start(mob/M, client/C)
	set waitfor = FALSE
	try
		picture = bug_report_render_view(M, C)
	catch(var/exception/e)
		log_admin("Bug reports: the screenshot for [C ? C.ckey : M] could not be drawn ([e]).")
	done = TRUE

/datum/bug_report_capture/proc/result()
	for (var/i in 1 to BUG_REPORT_SHOT_WAIT)
		if (done)
			break
		sleep(1)
	return done ? picture : null

// The map as the client shows it: the view size and centre of the client's eye, only the turfs
// the eye can see (the rest stays black) and the atoms the mob can see on them.
/proc/bug_report_render_view(mob/M, client/C)
	var/atom/eye = C && C.eye ? C.eye : M
	var/turf/centre = get_turf(eye)
	if (!centre)
		return null
	var/size = world.icon_size
	var/list/view_size = getviewsize(C ? C.view : world.view)
	var/w = clamp(round(view_size[1]), 1, BUG_REPORT_SHOT_MAX_VIEW)
	var/h = clamp(round(view_size[2]), 1, BUG_REPORT_SHOT_MAX_VIEW)
	// World pixel of the picture's bottom-left corner; a turf's left edge is at (x - 1) * size.
	var/cx = (centre.x - 1) * size + size / 2
	var/cy = (centre.y - 1) * size + size / 2
	if (ismovable(eye))
		var/atom/movable/E = eye
		cx += E.step_x
		cy += E.step_y
	if (C)
		cx += C.pixel_x
		cy += C.pixel_y
	var/left = round(cx - w * size / 2)
	var/bottom = round(cy - h * size / 2)
	var/see = M ? M.see_invisible : SEE_INVISIBLE_LIVING

	// Two tiles of margin, so big sprites standing just off screen still reach into it.
	var/list/turfs = list()
	for (var/turf/T in view("[w + 4]x[h + 4]", eye))
		if (T.z != centre.z)
			continue
		turfs += T
		if (turfs.len >= BUG_REPORT_SHOT_MAX_TILES)
			break
	var/icon/canvas = icon('icons/effects/96x96.dmi', "")
	canvas.Scale(w * size, h * size)
	canvas.Blend("#000", ICON_OVERLAY)
	var/list/flats = list() // appearance -> flat icon; most floor tiles share one
	var/list/movables = list()
	for (var/turf/T in turfs)
		bug_report_draw(canvas, T, left, bottom, flats)
		for (var/atom/movable/A in T)
			if (A.loc != T || A.invisibility > see || istype(A, /atom/movable/lighting_overlay))
				continue
			movables += A
		CHECK_TICK
	for (var/atom/movable/A in sort_atoms_by_layer(movables))
		if (!QDELETED(A))
			bug_report_draw(canvas, A, left, bottom, flats)
		CHECK_TICK
	return canvas

/proc/bug_report_draw(icon/canvas, atom/A, left, bottom, list/flats)
	var/lying = isliving(A) && A:lying
	var/key = "[ref(A.appearance)][lying ? "L" : ""]"
	var/icon/flat = flats[key]
	if (!flat)
		flat = getFlatIcon(A)
		if (!istype(flat, /icon))
			return
		if (lying)
			flat.BecomeLying()
		flats[key] = flat
	var/x = (A.x - 1) * world.icon_size + A.pixel_x + A.pixel_w - left
	var/y = (A.y - 1) * world.icon_size + A.pixel_y + A.pixel_z - bottom
	if (ismovable(A))
		var/atom/movable/AM = A
		x += AM.step_x
		y += AM.step_y
	canvas.Blend(flat, blendMode2iconMode(A.blend_mode), x + 1, y + 1)

// The saved file's name (as kept on the report), or null.
/proc/bug_report_save_screenshot(id, icon/picture)
	if (!istype(picture, /icon) || !isnum(id))
		return null
	var/name = "[id].png"
	var/path = BUG_REPORT_SHOT_DIR + name
	if (fexists(path))
		fdel(path)
	if (!fcopy(picture, path) || !fexists(path))
		return null
	return name

/proc/bug_report_screenshot_path(name)
	return bug_report_screenshot_name_valid(name) ? BUG_REPORT_SHOT_DIR + name : null

/proc/bug_report_screenshot_exists(name)
	var/path = bug_report_screenshot_path(name)
	return path && fexists(path)

/proc/bug_report_forget_screenshot(name)
	var/path = bug_report_screenshot_path(name)
	if (path && fexists(path))
		fdel(path)

// The uploaded picture's address for the issue, or null with why in error_out[1].
/datum/bug_report_queue/proc/upload_screenshot(datum/bug_report/R, list/error_out)
	var/repo = config ? config.bug_report_screenshot_repo : null
	if (!bug_report_repo_valid(repo))
		error_out[1] = "BUG_REPORT_SCREENSHOT_REPO is not set"
		return null
	var/path = bug_report_screenshot_path(R.screenshot)
	if (!path || !fexists(path))
		error_out[1] = "the picture file is gone"
		return null
	var/content = agent_icon_base64(icon(file(path)))
	if (!length(content))
		error_out[1] = "the picture could not be read"
		return null
	if (!fexists("config/config.txt"))
		error_out[1] = "BUG_REPORT_SCREENSHOT_TOKEN is not set"
		return null
	var/token = bug_report_token_from_lines(file2list("config/config.txt"), "bug_report_screenshot_token")
	if (!token)
		error_out[1] = "BUG_REPORT_SCREENSHOT_TOKEN is not set"
		return null
	var/name = "screens/[time2text(world.realtime, "YYYY-MM")]/[time2text(world.realtime, "YYYYMMDD-hhmmss")]-report-[R.id].png"
	var/list/result = github_request(RUSTG_HTTP_METHOD_PUT, "https://api.github.com/repos/[repo]/contents/[name]", token,
		list("message" = "Screenshot for in-game bug report #[R.id]", "content" = content))
	token = null
	var/list/answer = result["answer"]
	if (result["status"] == 201 && islist(answer) && islist(answer["content"]))
		var/list/made = answer["content"]
		var/url = made["download_url"]
		if (bug_report_screenshot_url_valid(url))
			return url
	error_out[1] = result["error"] ? result["error"] : "GitHub gave no picture address"
	return null

#undef BUG_REPORT_SHOT_DIR
#undef BUG_REPORT_SHOT_MAX_TILES
#undef BUG_REPORT_SHOT_MAX_VIEW
#undef BUG_REPORT_SHOT_WAIT
