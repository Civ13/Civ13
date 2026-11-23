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

/proc/star_chart_wheel(list/sky)
	var/list/art = list("<svg viewBox='0 0 300 300' width='300' height='300' aria-hidden='true'><circle cx='150' cy='150' r='145' fill='#182437' stroke='#8d7859'/><circle cx='150' cy='150' r='116' fill='#101827' stroke='#b79c68'/>")
	for (var/i in 1 to birth_chart_signs.len)
		var/angle = (i - 1) * 30
		art += birth_chart_wheel_line(angle, 116, angle, 145, "#8d7859")
		var/x = birth_chart_wheel_x(angle + 15, 129)
		var/y = birth_chart_wheel_y(angle + 15, 129) + 3
		var/sign = html_encode(capitalize(birth_chart_signs[i]))
		art += "<text x='[x]' y='[y]' fill='#e5d0a3' font-size='10' text-anchor='middle'>[sign]</text>"
	var/list/labels = list("Sun", "Moon", "Rising")
	var/list/marks = list("S", "M", "R")
	var/list/radii = list(97, 76, 55)
	for (var/i in 1 to labels.len)
		var/angle = sky[labels[i]]
		var/x = birth_chart_wheel_x(angle, radii[i])
		var/y = birth_chart_wheel_y(angle, radii[i])
		art += "<circle cx='[x]' cy='[y]' r='8' fill='#e5d0a3'/><text x='[x]' y='[y + 3]' fill='#101827' text-anchor='middle' font-size='9'>[marks[i]]</text>"
	art += "</svg>"
	return jointext(art, "")

/proc/star_chart_html(list/moment, natal_sign, list/record)
	var/list/sky = star_chart_angles(moment)
	var/list/natal = birth_chart_angles(natal_sign, record)
	var/list/transits = star_chart_transits(sky, natal)
	var/list/content = list(
		"<h2>Star Chart &amp; Astrological Almanac</h2>",
		"<p>Current region: <b>[html_encode(moment["region"])]</b><br>Local day [moment["local_day"]], [star_chart_clock_text(moment["local_minute"])]<br>Shared day [moment["day"]], [star_chart_clock_text(moment["minute"])]</p>",
		"<div class='sky-wheel'>[star_chart_wheel(sky)]</div>",
		"<p>Model longitude runs clockwise from 0&deg; at the top. Not a compass or a report of visible stars.</p>",
		"<table aria-label='Current sky placements'><tr><th>Point</th><th>Sign &amp; degree</th><th>Longitude</th><th>Next sign (game time)</th></tr>")
	for (var/label in list("Sun", "Moon", "Rising"))
		var/angle = sky[label]
		var/list/placement = birth_chart_placement(angle, null)
		var/sign_name = html_encode(capitalize(birth_chart_name(placement["sign_id"])))
		var/list/next = star_chart_next_sign(label, moment["day"], moment["minute"], angle)
		var/next_text = label == "Rising" ? "Local reference" : "Not available"
		if (next)
			var/next_name = html_encode(capitalize(birth_chart_name(next["sign_id"])))
			next_text = "[next_name] in [star_chart_wait_text(next["minutes"])]"
		content += "<tr><td>[label]</td><td>[placement["degree"]]&deg; [sign_name]</td><td>[angle]&deg;</td><td>[next_text]</td></tr>"
	content += "</table><h3>Astrology: current sky vs. your birth chart</h3>"
	if (birth_chart_valid(natal_sign))
		content += "<p>Your fixed natal Sun sign is [html_encode(birth_chart_name(natal_sign))]. The moving Sun is a separate calendar reading.</p>"
	if (isnull(natal["Sun"]) && isnull(natal["Moon"]) && isnull(natal["Rising"]))
		content += "<p>No exact natal placements were recorded. There are no personal transits to calculate.</p>"
	else
		if (isnull(natal["Rising"]))
			content += "<p>Natal houses were not recorded.</p>"
		else
			content += "<p>Current Sun in natal house [birth_chart_house(sky["Sun"], natal["Rising"])]; current Moon in natal house [birth_chart_house(sky["Moon"], natal["Rising"])].</p>"
		if (transits.len)
			content += "<ul>"
			for (var/list/entry in transits)
				content += "<li>Current [entry["moving"]] &rarr; natal [entry["fixed"]]: <b>[entry["name"]]</b>, [entry["separation"]]&deg; apart (exact [entry["exact"]]&deg;, orb [entry["orb"]]&deg;).</li>"
			content += "</ul>"
		else
			content += "<p>No aspects within 5&deg; of the recorded natal placements at this moment.</p>"
	content += "<p>The live Sun cycles every 360 game days, separately from local weather seasons. Fictional, informational roleplay. Nothing here alters your birth chart, stats, training, spells or travel. Reopen Star Chart for a fresh reading.</p>"
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
	var/datum/browser/popup = new(src, "current_star_chart", "Star Chart", 540, 700)
	popup.add_head_content({"<style>body{background:#101827;color:#eee1c6;padding:12px;font-family:Georgia,serif}h2{color:#f1ca75;margin-top:0}.sky-wheel{width:300px;height:300px;margin:auto}table{border-collapse:collapse;width:100%}th,td{background:#182437;border:1px solid #8d7859;padding:5px}</style>"})
	popup.set_content(star_chart_html(moment, birth_chart, birth_chart_record))
	popup.open(FALSE)

#undef STAR_CHART_DAY_TICKS
#undef STAR_CHART_GAME_MINUTE_TICKS
#undef STAR_CHART_MOON_SEARCH
