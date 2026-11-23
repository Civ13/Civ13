// The saved sign and its mechanical effects still live in birth_charts.dm.
// Only a successfully created player body gets a clock snapshot. Never infer
// a birth from a restored body, a character's age, or the observer's region.
/mob/living/human/var/list/birth_chart_record

/proc/birth_chart_record_valid(list/record)
	if (!islist(record) || record.len != 5 || record["v"] != 1 || !("day" in record) || !("minute" in record) || !("zone" in record) || !("region" in record))
		return FALSE
	var/day = record["day"]
	var/minute = record["minute"]
	var/zone = record["zone"]
	var/region = record["region"]
	if (!isnull(region) && (!istext(region) || !length(region) || length(region) > 64))
		return FALSE
	if (isnull(day) || isnull(minute))
		return isnull(day) && isnull(minute) && isnull(zone) && !isnull(region)
	if (!isnum(day) || day != round(day) || day < 0 || day > 1000000 || !isnum(minute) || minute != round(minute) || minute < 0 || minute >= 1440)
		return FALSE
	return isnull(zone) || (!isnull(region) && isnum(zone) && zone == round(zone) && zone >= -12 && zone <= 12)

/mob/living/human/proc/record_birth_chart()
	if (birth_chart_record || persistence_restored || !map || !(map.nomads || map.civilizations))
		return
	var/region = shard_group.region ? shard_group.name : map.title
	region = istext(region) && length(region) && length(region) <= 64 ? region : null
	var/day = null
	var/minute = null
	var/zone = null
	// The existing shared clock advances twelve game days per UTC day.
	// Use one source observation. An administrative daylight override is
	// not a different birth moment; this is the shared local calendar time.
	if (world_calendar_daynight())
		var/list/now = world_calendar_now()
		day = now[1] * 12 + round(now[2] / 72000)
		minute = round(world_calendar_fmod(now[2], 72000) / 50)
		if (region)
			zone = world_calendar_zone(map.world_longitude)
	var/list/record = list("v" = 1, "day" = day, "minute" = minute, "zone" = zone, "region" = region)
	if (birth_chart_record_valid(record))
		birth_chart_record = record

// Fictional angular model, fixed under record version 1 (not an ephemeris).
/proc/birth_chart_angles(sign_id, list/record)
	var/list/angles = list("Sun" = null, "Moon" = null, "Rising" = null)
	if (!birth_chart_record_valid(record) || isnull(record["day"]))
		return angles
	var/day = record["day"]
	var/minute = record["minute"]
	var/index = birth_chart_signs.Find(sign_id)
	if (index)
		angles["Sun"] = (index - 1) * 30 + world_calendar_fmod(day, 30)
	angles["Moon"] = world_calendar_fmod(13 * day + round(minute / 120), 360)
	if (!isnull(record["zone"]))
		var/local_minute = world_calendar_fmod(minute + 60 * record["zone"], 1440)
		angles["Rising"] = round(local_minute / 4)
	return angles

/proc/birth_chart_house(angle, rising)
	if (isnull(angle) || isnull(rising))
		return null
	return 1 + round(world_calendar_fmod(angle - rising, 360) / 30)

/proc/birth_chart_aspect(angle_a, angle_b)
	if (isnull(angle_a) || isnull(angle_b))
		return null
	var/distance = abs(angle_a - angle_b)
	distance = min(distance, 360 - distance)
	var/static/list/aspects = list(
		list("Conjunction", 0, "#c4a7e7"), list("Sextile", 60, "#72d6ad"),
		list("Square", 90, "#ff8989"), list("Trine", 120, "#83c5f4"),
		list("Opposition", 180, "#ffbb82"))
	for (var/list/aspect in aspects)
		var/orb = abs(distance - aspect[2])
		if (orb <= 5)
			return list("name" = aspect[1], "color" = aspect[3], "orb" = orb, "separation" = distance, "exact" = aspect[2])
	return null

// Shared numeric projection; future consumers do not parse the rendered chart.
/proc/birth_chart_placement(angle, rising)
	if (isnull(angle))
		return null
	return list("longitude" = angle, "sign_id" = birth_chart_signs[1 + round(angle / 30)], "degree" = world_calendar_fmod(angle, 30), "house" = birth_chart_house(angle, rising))

/proc/birth_chart_cusps(rising)
	var/list/cusps = list()
	if (!isnull(rising))
		for (var/i in 1 to 12)
			cusps[++cusps.len] = birth_chart_placement(world_calendar_fmod(rising + (i - 1) * 30, 360), rising)
	return cusps

// Ecliptic zero is at the top; increasing model longitude moves clockwise.
/proc/birth_chart_wheel_x(angle, radius)
	return 150 + round(sin(angle) * radius, 0.1)

/proc/birth_chart_wheel_y(angle, radius)
	return 150 - round(cos(angle) * radius, 0.1)

/proc/birth_chart_wheel_line(angle_a, radius_a, angle_b, radius_b, color, thickness = 1)
	var/x1 = birth_chart_wheel_x(angle_a, radius_a)
	var/y1 = birth_chart_wheel_y(angle_a, radius_a)
	var/x2 = birth_chart_wheel_x(angle_b, radius_b)
	var/y2 = birth_chart_wheel_y(angle_b, radius_b)
	return "<line x1='[x1]' y1='[y1]' x2='[x2]' y2='[y2]' stroke='[color]' stroke-width='[thickness]'/>"

/proc/birth_chart_wheel_html(sign_id, list/record)
	if (!birth_chart_record_valid(record))
		record = null
	var/list/angles = birth_chart_angles(sign_id, record)
	var/rising = angles["Rising"]
	var/list/labels = list("Sun", "Moon", "Rising")
	var/list/radii = list(99, 86, 73) // radial separation keeps conjunctions visible
	var/list/colors = list("#f1ca75", "#c6dbea", "#9ce8bf")
	var/list/aspect_text = list()
	var/list/cusps = birth_chart_cusps(rising)
	var/list/svg = list("<svg viewBox='0 0 300 300' width='300' height='300' aria-hidden='true'>",
		"<circle cx='150' cy='150' r='145' fill='#182437' stroke='#8d7859'/>",
		"<circle cx='150' cy='150' r='116' fill='#131d2d' stroke='#b79c68'/>",
		"<circle cx='150' cy='150' r='62' fill='#101827' stroke='#59667a'/>")
	for (var/i in 1 to 12)
		var/angle = (i - 1) * 30
		svg += birth_chart_wheel_line(angle, 116, angle, 145, "#8d7859")
		var/sign_x = birth_chart_wheel_x(angle + 15, 129)
		var/sign_y = birth_chart_wheel_y(angle + 15, 129) + 3
		var/sign = capitalize(birth_chart_signs[i])
		svg += "<text x='[sign_x]' y='[sign_y]' fill='#e5d0a3' font-size='10' text-anchor='middle'>[sign]</text>"
		if (!isnull(rising))
			var/list/cusp_point = cusps[i]
			var/cusp = cusp_point["longitude"]
			svg += birth_chart_wheel_line(cusp, 62, cusp, 116, i == 1 ? "#9ce8bf" : "#59667a", i == 1 ? 2 : 1)
			var/tx = birth_chart_wheel_x(cusp + 15, 109)
			var/ty = birth_chart_wheel_y(cusp + 15, 109) + 3
			svg += "<text x='[tx]' y='[ty]' fill='#e5d0a3' font-size='10' text-anchor='middle'>[i]</text>"
	for (var/i in 1 to labels.len - 1)
		for (var/j in i + 1 to labels.len)
			var/a = angles[labels[i]]
			var/b = angles[labels[j]]
			var/list/aspect = birth_chart_aspect(a, b)
			if (aspect)
				svg += birth_chart_wheel_line(a, radii[i], b, radii[j], aspect["color"], 2)
				aspect_text += "<li><b>[labels[i]] &amp; [labels[j]]:</b> [aspect["name"]]: [aspect["separation"]]&deg; apart (exact [aspect["exact"]]&deg;, orb [aspect["orb"]]&deg;)</li>"
	for (var/i in 1 to labels.len)
		var/angle = angles[labels[i]]
		if (isnull(angle))
			continue
		var/dot_x = birth_chart_wheel_x(angle, radii[i])
		var/dot_y = birth_chart_wheel_y(angle, radii[i])
		svg += "<circle cx='[dot_x]' cy='[dot_y]' r='5' fill='[colors[i]]' stroke='#101827'/>"
	svg += "</svg>"

	var/date_label = "Not recorded"
	var/time_label = "Not recorded"
	var/shared_time_label = "Not recorded"
	var/region_label = "Not recorded"
	if (record)
		if (!isnull(record["region"]))
			region_label = html_encode(record["region"])
		if (!isnull(record["day"]))
			var/day = record["day"]
			var/minute = record["minute"]
			var/shared_hours = round(minute / 60)
			var/shared_minutes = minute % 60
			shared_time_label = "Day [day], [shared_hours < 10 ? "0" : ""][shared_hours]:[shared_minutes < 10 ? "0" : ""][shared_minutes]"
			var/clock_label = "shared calendar"
			if (!isnull(record["zone"]))
				var/local = minute + 60 * record["zone"]
				day += round(local / 1440)
				minute = world_calendar_fmod(local, 1440)
				clock_label = "local time"
			var/hours = round(minute / 60)
			var/minutes = minute % 60
			date_label = "Calendar day [day]"
			time_label = "[hours < 10 ? "0" : ""][hours]:[minutes < 10 ? "0" : ""][minutes] ([clock_label])"
	var/list/content = list(
		"<div class='bc-card'><h2>Birth Chart</h2><p class='bc-sub'>Civ13 sky model &middot; Roleplay</p>",
		"<p><b>Birth date:</b> [date_label]<br><b>Birth time:</b> [time_label]<br><b>Birthplace:</b> [region_label]<br><b>Shared calendar:</b> [shared_time_label]</p>",
		"<div class='bc-wheel'>[jointext(svg, "")]</div>",
		"<p class='bc-sub'>Outer ring: signs. Inner ring: equal houses from the Rising cusp.</p>",
		"<table class='bc-placements' aria-label='Placements, from left to right'><tr>")
	for (var/i in 1 to labels.len)
		var/label = labels[i]
		var/angle = angles[label]
		var/sign = label == "Sun" ? birth_chart_name(sign_id) : null
		var/degree_text = "Not recorded"
		var/house_text = "Not recorded"
		var/longitude_text = "Not recorded"
		var/list/placement = birth_chart_placement(angle, rising)
		if (placement)
			sign = birth_chart_name(placement["sign_id"])
			degree_text = "[placement["degree"]]&deg;"
			longitude_text = "[placement["longitude"]]&deg;"
			if (!isnull(placement["house"]))
				house_text = "[placement["house"]]"
		content += "<td><b style='color:[colors[i]]'>[label]</b><br>Sign: [sign ? html_encode(capitalize(sign)) : "Not recorded"]<br>Degree: [degree_text]<br>House: [house_text]<br>Longitude: [longitude_text]</td>"
	content += "</tr></table><h3>Aspects</h3>"
	if (aspect_text.len)
		content += "<ul>[jointext(aspect_text, "")]</ul>"
	else
		var/known = (!isnull(angles["Sun"]) ? 1 : 0) + (!isnull(angles["Moon"]) ? 1 : 0) + (!isnull(rising) ? 1 : 0)
		content += known >= 2 ? "<p>No aspects within 5&deg; between recorded placements.</p>" : "<p>Not enough placements recorded.</p>"
	content += "<h3>House cusps</h3>"
	if (cusps.len)
		content += "<table class='bc-placements' aria-label='House cusps'><tr><th>House</th><th>Sign and degree</th><th>Longitude</th></tr>"
		for (var/i in 1 to cusps.len)
			var/list/cusp = cusps[i]
			var/name = html_encode(capitalize(birth_chart_name(cusp["sign_id"])))
			content += "<tr><td>[i]</td><td>[cusp["degree"]]&deg; [name]</td><td>[cusp["longitude"]]&deg;</td></tr>"
		content += "</table>"
	else
		content += "<p>House cusps not recorded.</p>"
	content += "<p class='bc-sub'>Shortest arc: conjunction 0&deg;, sextile 60&deg;, square 90&deg;, trine 120&deg;, opposition 180&deg; (within 5&deg;). The Sun keeps its existing sign and bonuses; the wheel adds no bonuses.</p></div>"
	return jointext(content, "")

/mob/living/human/verb/view_birth_chart()
	set name = "Birth Chart"
	set category = "IC"
	set desc = "View your own character's private roleplay chart."
	if (usr != src || !client || client.mob != src || stat == DEAD)
		return
	if (!birth_chart_valid(birth_chart) && !birth_chart_record_valid(birth_chart_record))
		to_chat(src, SPAN_NOTICE("No birth chart is recorded for this character."))
		return
	var/datum/browser/popup = new(src, "birth_chart_wheel", "Birth Chart", 470, 680)
	popup.add_head_content({"<style>
		.bc-card{background:#101827;color:#eee1c6;padding:12px;font-family:Georgia,serif}
		.bc-card h2{text-align:center;margin:0;color:#f1ca75}
		.bc-sub{text-align:center;color:#c5cde0}
		.bc-wheel{position:relative;width:300px;height:300px;margin:0 auto}
		.bc-placements{width:100%;border-collapse:collapse}
		.bc-placements td{padding:7px;border:1px solid #8d7859;background:#182437;width:33%;color:#eee1c6}
		</style>"})
	popup.set_content(birth_chart_wheel_html(birth_chart, birth_chart_record))
	popup.open(FALSE)
