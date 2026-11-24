// An informational current sky, not a world simulation or an ephemeris.
// Neither this projection nor its private reader changes a natal record.
#define STAR_CHART_DAY_TICKS 72000
#define STAR_CHART_GAME_MINUTE_TICKS 50
#define STAR_CHART_MOON_SEARCH 36

/proc/star_chart_moment(list/now, longitude, region)
	if (!islist(now) || now.len != 2 || !isnum(longitude) || longitude < -180 || longitude > 180 || !istext(region) || !length(region) || length(region) > 64)
		return null
	var/utc_day = now[1]
	var/utc_ticks = now[2]
	if (!isnum(utc_day) || utc_day != round(utc_day) || utc_day < 0 || utc_day > 83333 || !isnum(utc_ticks) || utc_ticks < 0 || utc_ticks >= 864000)
		return null
	var/day = utc_day * 12 + round(utc_ticks / STAR_CHART_DAY_TICKS)
	if (day > 1000000)
		return null
	var/minute = round(world_calendar_fmod(utc_ticks, STAR_CHART_DAY_TICKS) / STAR_CHART_GAME_MINUTE_TICKS)
	var/zone = world_calendar_zone(longitude)
	var/local = minute + 60 * zone
	return list("day" = day, "minute" = minute, "region" = region, "local_day" = day + round(local / 1440), "local_minute" = world_calendar_fmod(local, 1440))

/proc/star_chart_now()
	if (!world_calendar_daynight())
		return null
	var/region = shard_group.region ? shard_group.name : map.title
	return star_chart_moment(world_calendar_now(), map.world_longitude, region)

// The live Sun walks the circle in a fixed 360-game-day sky cycle. This is
// deliberately independent of the character's sign and terrain-season length.
/proc/star_chart_sun_angle(day)
	return world_calendar_fmod(day, 360)

/proc/star_chart_angles(list/moment)
	return list("Sun" = star_chart_sun_angle(moment["day"]), "Moon" = birth_chart_moon_angle(moment["day"], moment["minute"]), "Rising" = birth_chart_rising_angle(moment["local_minute"]))

// Earliest moment the label changes, in shared game minutes from the sample.
// The Moon updates every 120 game minutes and can step by two at midnight;
// search those boundaries instead of assuming a linear fractional rate.
/proc/star_chart_next_sign(body_name, day, minute, angle)
	var/list/start = birth_chart_placement(angle, null)
	if (!start)
		return null
	if (body_name == "Sun")
		var/next = world_calendar_fmod(angle - start["degree"] + 30, 360)
		var/list/point = birth_chart_placement(next, null)
		return list("sign_id" = point["sign_id"], "minutes" = (30 - start["degree"]) * 1440 - minute)
	if (body_name != "Moon")
		return null
	var/elapsed = 0
	for (var/check in 1 to STAR_CHART_MOON_SEARCH)
		var/step = 120 - world_calendar_fmod(minute, 120)
		elapsed += step
		minute += step
		if (minute >= 1440)
			day++
			minute = 0
		var/list/point = birth_chart_placement(birth_chart_moon_angle(day, minute), null)
		if (point["sign_id"] != start["sign_id"])
			return list("sign_id" = point["sign_id"], "minutes" = elapsed)
	return null

// Compare only moving bodies against fixed natal points. Current Rising is
// a local reference, not a transiting body. Missing natal angles stay null.
/proc/star_chart_transits(list/sky, list/natal)
	var/list/result = list()
	if (!islist(sky) || !islist(natal))
		return result
	for (var/moving in list("Sun", "Moon"))
		var/transiting = sky[moving]
		if (isnull(transiting))
			continue
		for (var/fixed in list("Sun", "Moon", "Rising"))
			var/list/aspect = birth_chart_aspect(transiting, natal[fixed])
			if (aspect)
				aspect["moving"] = moving
				aspect["fixed"] = fixed
				result += list(aspect)
	return result

/proc/star_chart_clock_text(minute)
	var/hour = round(minute / 60)
	var/rest = minute % 60
	return "[hour < 10 ? "0" : ""][hour]:[rest < 10 ? "0" : ""][rest]"

/proc/star_chart_wait_text(minutes)
	var/day = round(minutes / 1440)
	var/hour = round(world_calendar_fmod(minutes, 1440) / 60)
	var/rest = minutes % 60
	return "[day]d [hour]h [rest]m"

// The wheel (layout by Fable, drawn with the Birth Chart's ring and markers):
// filled markers are the sky now, outlined ones the recorded birth chart, and
// a line joins a moving body to a birth point only for a listed transit.
/proc/star_chart_wheel(list/sky, list/natal, list/transits)
	var/list/labels = list("Sun", "Moon", "Rising")
	var/list/now_radii = list("Sun" = 104, "Moon" = 86, "Rising" = 68)
	var/list/natal_radii = list("Sun" = 50, "Moon" = 34, "Rising" = 18)
	var/list/art = birth_chart_wheel_ring(1 + round(sky["Sun"] / 30))
	var/compared = FALSE
	for (var/label in labels)
		if (islist(natal) && !isnull(natal[label]))
			compared = TRUE
	if (compared)
		art += "<circle cx='150' cy='150' r='60' fill='#101725' stroke='#4c5a70' stroke-dasharray='3 3'/>"
	for (var/list/entry in transits)
		art += birth_chart_wheel_line(sky[entry["moving"]], now_radii[entry["moving"]], natal[entry["fixed"]], natal_radii[entry["fixed"]], entry["color"], 2, entry["dash"])
	for (var/label in labels)
		if (compared && !isnull(natal[label]))
			art += birth_chart_wheel_marker(natal[label], natal_radii[label], label, TRUE)
		art += birth_chart_wheel_marker(sky[label], now_radii[label], label)
	art += "</svg>"
	return jointext(art, "")

/proc/star_chart_html(list/moment, natal_sign, list/record)
	var/list/sky = star_chart_angles(moment)
	var/list/natal = birth_chart_angles(natal_sign, record)
	var/list/transits = star_chart_transits(sky, natal)
	var/compared = !isnull(natal["Sun"]) || !isnull(natal["Moon"]) || !isnull(natal["Rising"])
	var/list/content = list(
		"<div class='sky'><div class='sky-eyebrow'>Private &middot; the sky now</div><h1 class='sky-title'>Star Chart</h1>",
		"<p class='sky-lede'><b>[html_encode(moment["region"])]</b> &middot; local day [moment["local_day"]], [star_chart_clock_text(moment["local_minute"])] &middot; shared day [moment["day"]], [star_chart_clock_text(moment["minute"])]</p>",
		"<div class='sky-card'>[star_chart_wheel(sky, natal, transits)]<p class='sky-key'>[compared ? "Filled markers: the sky now, with the Sun's present sign lit. Outlined markers, inside the dotted ring: your birth chart." : "The markers show the sky now, with the Sun's present sign lit."]</p></div>",
		"<div class='sky-points' aria-label='Current sky placements, from left to right'>")
	for (var/label in list("Sun", "Moon", "Rising"))
		var/angle = sky[label]
		var/list/placement = birth_chart_placement(angle, null)
		var/list/next = star_chart_next_sign(label, moment["day"], moment["minute"], angle)
		var/next_text = label == "Rising" ? "Local to this region<br>&nbsp;" : "Next sign not available<br>&nbsp;"
		if (next)
			next_text = "Next sign: [html_encode(capitalize(next["sign_id"]))]<br>in [star_chart_wait_text(next["minutes"])]"
		var/color = birth_chart_point_color(label)
		content += "<div class='sky-point' style='border-top-color:[color]'><div class='sky-point-name' style='color:[color]'>[label]</div><div class='sky-point-main'>[birth_chart_degree_text(placement)]</div><div class='sky-point-sub'>Longitude [angle]&deg;<br>[next_text]</div></div>"
	content += "</div><div class='sky-card'><h2 class='sky-h'>Against your birth chart</h2>"
	if (birth_chart_valid(natal_sign))
		content += "<p class='sky-plain'>Your Sun sign stays [html_encode(birth_chart_name(natal_sign))]. The moving Sun above is a separate reading of the calendar.</p>"
	if (!compared)
		content += "<p class='sky-plain sky-none'>No exact natal placements were recorded. There are no personal transits to calculate.</p>"
	else
		if (isnull(natal["Rising"]))
			content += "<p class='sky-plain sky-none'>Natal houses were not recorded.</p>"
		else
			content += "<p class='sky-plain'>The Sun is now in your house [birth_chart_house(sky["Sun"], natal["Rising"])], the Moon in your house [birth_chart_house(sky["Moon"], natal["Rising"])].</p>"
		if (transits.len)
			content += "<table class='sky-table' aria-label='Transits'><tr><th>Now</th><th>At birth</th><th>Aspect</th><th>Apart</th><th>Orb</th></tr>"
			for (var/list/entry in transits)
				content += "<tr><td><b>[entry["moving"]]</b></td><td><b>[entry["fixed"]]</b></td><td class='sky-aspect' style='color:[entry["color"]]'>[birth_chart_aspect_swatch(entry)][entry["name"]] ([entry["exact"]]&deg;)</td><td class='sky-num'>[entry["separation"]]&deg;</td><td class='sky-num'>[entry["orb"]]&deg;</td></tr>"
			content += "</table>"
		else
			content += "<p class='sky-plain'>No aspects within 5&deg; of the recorded natal placements at this moment.</p>"
	content += "</div><p class='sky-note'>The Sun here goes round once in 360 game days, apart from the weather seasons. Sign changes are given in game time. This is an almanac for roleplay, not a compass or a view of visible stars, and it changes nothing about your character. Reopen Star Chart for a fresh reading.</p></div>"
	return jointext(content, "")

/mob/living/human/verb/view_star_chart()
	set name = "Star Chart"
	set category = "IC"
	set desc = "Read the current fictional sky and compare it privately with your own birth chart."
	if (usr != src || !client || client.mob != src || stat == DEAD)
		return
	var/list/moment = star_chart_now()
	if (!moment)
		to_chat(src, SPAN_NOTICE("The shared sky calendar is not available in this region."))
		return
	var/datum/browser/popup = new(src, "current_star_chart", FALSE, 500, 720)
	popup.add_head_content(birth_chart_style("Star Chart"))
	popup.set_content(star_chart_html(moment, birth_chart, birth_chart_record))
	popup.open(FALSE)

#undef STAR_CHART_DAY_TICKS
#undef STAR_CHART_GAME_MINUTE_TICKS
#undef STAR_CHART_MOON_SEARCH
