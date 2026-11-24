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

// The natal-v1 and current-sky models use the same Moon and local Rising
// formulas. Keep the natal Sun (a saved sign) separate from the live Sun.
/proc/birth_chart_moon_angle(day, minute)
	return world_calendar_fmod(13 * day + round(minute / 120), 360)

/proc/birth_chart_rising_angle(local_minute)
	return round(local_minute / 4)

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
	angles["Moon"] = birth_chart_moon_angle(day, minute)
	if (!isnull(record["zone"]))
		var/local_minute = world_calendar_fmod(minute + 60 * record["zone"], 1440)
		angles["Rising"] = birth_chart_rising_angle(local_minute)
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
	// Each aspect also has its own line pattern, so colour is never the only cue.
	var/static/list/dashes = list("Sextile" = "7 5", "Square" = "2 4", "Trine" = "12 4 2 4", "Opposition" = "16 6")
	for (var/list/aspect in aspects)
		var/orb = abs(distance - aspect[2])
		if (orb <= 5)
			return list("name" = aspect[1], "color" = aspect[3], "dash" = dashes[aspect[1]], "orb" = orb, "separation" = distance, "exact" = aspect[2])
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

/proc/birth_chart_wheel_line(angle_a, radius_a, angle_b, radius_b, color, thickness = 1, dash = null)
	var/x1 = birth_chart_wheel_x(angle_a, radius_a)
	var/y1 = birth_chart_wheel_y(angle_a, radius_a)
	var/x2 = birth_chart_wheel_x(angle_b, radius_b)
	var/y2 = birth_chart_wheel_y(angle_b, radius_b)
	return "<line x1='[x1]' y1='[y1]' x2='[x2]' y2='[y2]' stroke='[color]' stroke-width='[thickness]'[dash ? " stroke-dasharray='[dash]'" : ""]/>"

// -- the drawn wheel (layout and palette by Fable) ---------------------------
// The sky charts share one look: the house browns of the panel windows around
// a night-blue wheel. Sun, Moon and Rising keep one colour and one letter each
// everywhere, so a marker can be read without its colour.
/proc/birth_chart_point_color(label)
	switch (label)
		if ("Sun") return "#ffd985"
		if ("Moon") return "#c9dcec"
		if ("Rising") return "#9fe0b8"
	return "#eee5d3"

// One slice of a ring, between two angles.
/proc/birth_chart_wheel_wedge(start, finish, inner, outer, fill)
	return "<path d='M[birth_chart_wheel_x(start, outer)] [birth_chart_wheel_y(start, outer)] A[outer] [outer] 0 0 1 [birth_chart_wheel_x(finish, outer)] [birth_chart_wheel_y(finish, outer)] L[birth_chart_wheel_x(finish, inner)] [birth_chart_wheel_y(finish, inner)] A[inner] [inner] 0 0 0 [birth_chart_wheel_x(start, inner)] [birth_chart_wheel_y(start, inner)] Z' fill='[fill]'/>"

// A label that follows its ring and never reads upside down.
/proc/birth_chart_wheel_label(angle, radius, text, size, fill, weight = "normal", upright = FALSE)
	var/x = birth_chart_wheel_x(angle, radius)
	var/y = birth_chart_wheel_y(angle, radius)
	var/turn = upright ? 0 : ((angle > 90 && angle < 270) ? angle + 180 : angle)
	return "<text x='[x]' y='[y]' transform='rotate([turn] [x] [y])' fill='[fill]' font-size='[size]' font-weight='[weight]' text-anchor='middle' dominant-baseline='central'>[text]</text>"

// The disc, the ring of twelve signs and its degree ticks. lit is the index of
// the sign to pick out; field is the radius of the empty middle.
/proc/birth_chart_wheel_ring(lit, field = 122)
	var/list/svg = list("<svg class='sky-wheel' viewBox='0 0 300 300' aria-hidden='true' font-family='Verdana,Geneva,sans-serif'>",
		"<circle cx='150' cy='150' r='147' fill='#1c2638' stroke='#a98b4d' stroke-width='1.5'/>")
	if (lit)
		svg += birth_chart_wheel_wedge((lit - 1) * 30, lit * 30, 122, 147, "#4a3f2a")
	svg += "<circle cx='150' cy='150' r='122' fill='#151d2c' stroke='#a98b4d'/>"
	if (field < 122)
		svg += "<circle cx='150' cy='150' r='[field]' fill='#101725' stroke='#4c5a70'/>"
	for (var/tick in 0 to 71)
		if (tick % 6)
			svg += birth_chart_wheel_line(tick * 5, 122, tick * 5, tick % 2 ? 124 : 126, "#7d6a45")
	for (var/i in 1 to 12)
		var/angle = (i - 1) * 30
		svg += birth_chart_wheel_line(angle, 122, angle, 147, "#a98b4d")
		svg += birth_chart_wheel_label(angle + 15, 135.5, html_encode(capitalize(birth_chart_signs[i])), 10.5, i == lit ? "#ffd985" : "#e3d3ae", i == lit ? "bold" : "normal")
	return svg

// A lettered marker. hollow draws the outlined kind used for a fixed record
// beside a moving sky.
/proc/birth_chart_wheel_marker(angle, radius, label, hollow = FALSE)
	var/x = birth_chart_wheel_x(angle, radius)
	var/y = birth_chart_wheel_y(angle, radius)
	var/color = birth_chart_point_color(label)
	return "<circle cx='[x]' cy='[y]' r='9' fill='[hollow ? "#101725" : color]' stroke='[hollow ? color : "#101725"]' stroke-width='1.5'/><text x='[x]' y='[y]' fill='[hollow ? color : "#101725"]' font-size='10' font-weight='bold' text-anchor='middle' dominant-baseline='central'>[copytext(label, 1, 2)]</text>"

// A short sample of an aspect's line, for the lists under a wheel.
/proc/birth_chart_aspect_swatch(list/aspect)
	return "<svg width='26' height='8' viewBox='0 0 26 8' aria-hidden='true'><line x1='1' y1='4' x2='25' y2='4' stroke='[aspect["color"]]' stroke-width='2'[aspect["dash"] ? " stroke-dasharray='[aspect["dash"]]'" : ""]/></svg>"

// "12 Serpent": a degree inside a sign, by the short name on the wheel.
/proc/birth_chart_degree_text(list/placement)
	return "[placement["degree"]]&deg; [html_encode(capitalize(placement["sign_id"]))]"

// The head of a sky chart window: its title and the shared stylesheet. The
// selectors outrank the element rules of common.css, which loads after this.
/proc/birth_chart_style(title)
	return {"<title>[title]</title><style>
		html body{background:#211c16;color:#eee5d3;font-family:Verdana,Geneva,sans-serif;font-size:13px;line-height:1.45;margin:0;padding:0}
		div.uiWrapper{padding-top:0}
		.sky{padding:14px 16px 18px}
		.sky-eyebrow{font-size:10px;letter-spacing:.14em;text-transform:uppercase;color:#c9a25c}
		.sky h1.sky-title{font-family:Georgia,'Times New Roman',serif;font-weight:normal;font-size:26px;line-height:1.15;color:#f6ecd6;margin:2px 0;padding:0}
		.sky p.sky-lede{color:#bfae96;margin:0 0 12px}
		.sky-card{background:#30271e;border:1px solid #66513b;border-radius:4px;padding:12px;margin:0 0 10px}
		.sky h2.sky-h{font-family:Georgia,'Times New Roman',serif;font-weight:normal;font-size:16px;color:#f6ecd6;margin:0 0 8px;padding:0}
		.sky-wheel{display:block;width:100%;max-width:330px;height:auto;margin:0 auto}
		.sky p.sky-key{text-align:center;color:#bfae96;font-size:11.5px;margin:8px 0 0}
		.sky-dl{display:grid;grid-template-columns:auto 1fr auto 1fr;gap:3px 12px;margin:0}
		.sky-dl dt{color:#bfae96}
		.sky-dl dd{margin:0}
		.sky-points{display:flex;gap:8px;margin:0 0 10px}
		.sky-point{flex:1 1 0;min-width:0;background:#30271e;border:1px solid #66513b;border-top:3px solid #66513b;border-radius:4px;padding:8px 10px}
		.sky-point-name{font-size:11px;font-weight:bold;letter-spacing:.08em;text-transform:uppercase}
		.sky-point-main{font-family:Georgia,'Times New Roman',serif;font-size:17px;line-height:1.3;color:#f6ecd6}
		.sky-point-sub{color:#bfae96;font-size:12px}
		.sky-none{color:#a99b87;font-style:italic}
		.sky-two{display:flex;gap:18px}
		.sky-two .sky-table{flex:1 1 0}
		.sky-table{width:100%;border-collapse:collapse}
		.sky-table th{font-size:10px;font-weight:normal;letter-spacing:.06em;text-transform:uppercase;text-align:left;white-space:nowrap;color:#bfae96;padding:3px 5px;border-bottom:1px solid #66513b}
		.sky-table td{white-space:nowrap;padding:4px 5px;border-bottom:1px solid #54432f;vertical-align:middle}
		.sky-table tr:last-child td{border-bottom:0}
		.sky-table td.sky-num{color:#bfae96;white-space:nowrap}
		.sky-aspect{white-space:nowrap}
		.sky-aspect svg{vertical-align:middle;margin-right:6px}
		.sky p.sky-note{color:#a99b87;font-size:11.5px;margin:10px 2px 0}
		.sky p.sky-plain{margin:0 0 8px}
		</style>"}

/proc/birth_chart_wheel_html(sign_id, list/record)
	if (!birth_chart_record_valid(record))
		record = null
	var/list/angles = birth_chart_angles(sign_id, record)
	var/rising = angles["Rising"]
	var/list/labels = list("Sun", "Moon", "Rising")
	var/list/radii = list(82, 62, 42) // radial separation keeps conjunctions visible
	var/list/aspect_text = list()
	var/list/cusps = birth_chart_cusps(rising)
	var/list/svg = birth_chart_wheel_ring(birth_chart_signs.Find(sign_id), 100)
	for (var/i in 1 to cusps.len)
		var/list/cusp_point = cusps[i]
		var/cusp = cusp_point["longitude"]
		svg += birth_chart_wheel_line(cusp, 20, cusp, 100, i == 1 ? "#9fe0b8" : "#2c384b", i == 1 ? 1.5 : 1)
		svg += birth_chart_wheel_line(cusp, 100, cusp, 122, i == 1 ? "#9fe0b8" : "#5d6c84", i == 1 ? 1.5 : 1)
		svg += birth_chart_wheel_label(cusp + 15, 111, "[i]", 9.5, "#bfae96", "normal", TRUE)
	if (cusps.len)
		svg += "<circle cx='150' cy='150' r='20' fill='#151d2c' stroke='#4c5a70'/>"
	for (var/i in 1 to labels.len - 1)
		for (var/j in i + 1 to labels.len)
			var/a = angles[labels[i]]
			var/b = angles[labels[j]]
			var/list/aspect = birth_chart_aspect(a, b)
			if (aspect)
				svg += birth_chart_wheel_line(a, radii[i], b, radii[j], aspect["color"], 2, aspect["dash"])
				aspect_text += "<tr><td><b>[labels[i]] &ndash; [labels[j]]</b></td><td class='sky-aspect' style='color:[aspect["color"]]'>[birth_chart_aspect_swatch(aspect)][aspect["name"]] ([aspect["exact"]]&deg;)</td><td class='sky-num'>[aspect["separation"]]&deg; apart</td><td class='sky-num'>orb [aspect["orb"]]&deg;</td></tr>"
	for (var/i in 1 to labels.len)
		var/angle = angles[labels[i]]
		if (isnull(angle))
			continue
		svg += birth_chart_wheel_marker(angle, radii[i], labels[i])
	svg += "</svg>"

	var/none = "<span class='sky-none'>Not recorded</span>"
	var/date_label = none
	var/time_label = none
	var/shared_time_label = none
	var/region_label = none
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
		"<div class='sky'><div class='sky-eyebrow'>Private &middot; your character</div><h1 class='sky-title'>Birth Chart</h1>",
		"<p class='sky-lede'>The sky as it stood when this character was born. For roleplay; it never changes.</p>",
		"<div class='sky-card'><dl class='sky-dl'><dt>Birthplace</dt><dd>[region_label]</dd><dt>Birth date</dt><dd>[date_label]</dd><dt>Birth time</dt><dd>[time_label]</dd><dt>Shared calendar</dt><dd>[shared_time_label]</dd></dl></div>",
		"<div class='sky-card'>[jointext(svg, "")]<p class='sky-key'>[isnull(angles["Moon"]) ? "Only the Sun sign is known for this character, so the wheel shows the sign and no placements." : "Outer ring: the twelve signs, with the Sun sign lit. Inner ring: houses 1 to 12, counted from the Rising line."]</p></div>",
		"<div class='sky-points' aria-label='Placements, from left to right'>")
	for (var/i in 1 to labels.len)
		var/label = labels[i]
		var/angle = angles[label]
		var/main = none
		var/sub = "&nbsp;"
		var/list/placement = birth_chart_placement(angle, rising)
		if (placement)
			main = birth_chart_degree_text(placement)
			sub = "[isnull(placement["house"]) ? "House not recorded" : "House [placement["house"]]"] &middot; [placement["longitude"]]&deg;"
		else if (label == "Sun" && birth_chart_valid(sign_id))
			main = html_encode(capitalize(sign_id))
			sub = "Sign only"
		var/color = birth_chart_point_color(label)
		content += "<div class='sky-point' style='border-top-color:[color]'><div class='sky-point-name' style='color:[color]'>[label]</div><div class='sky-point-main'>[main]</div><div class='sky-point-sub'>[sub]</div></div>"
	content += "</div><div class='sky-card'><h2 class='sky-h'>Aspects</h2>"
	if (aspect_text.len)
		content += "<table class='sky-table' aria-label='Aspects'>[jointext(aspect_text, "")]</table>"
	else
		var/known = (!isnull(angles["Sun"]) ? 1 : 0) + (!isnull(angles["Moon"]) ? 1 : 0) + (!isnull(rising) ? 1 : 0)
		content += known >= 2 ? "<p class='sky-plain'>No aspects within 5&deg; between recorded placements.</p>" : "<p class='sky-plain sky-none'>Not enough placements recorded.</p>"
	content += "<p class='sky-note'>An aspect is listed when two points stand within 5&deg; of 0&deg;, 60&deg;, 90&deg;, 120&deg; or 180&deg; apart, by the shorter way round.</p></div><div class='sky-card'><h2 class='sky-h'>House cusps</h2>"
	if (cusps.len)
		content += "<div class='sky-two'>"
		for (var/half in 0 to 1)
			content += "<table class='sky-table' aria-label='House cusps [half * 6 + 1] to [half * 6 + 6]'><tr><th>House</th><th>Cusp</th><th>Longitude</th></tr>"
			for (var/i in half * 6 + 1 to half * 6 + 6)
				var/list/cusp = cusps[i]
				content += "<tr><td>[i]</td><td>[birth_chart_degree_text(cusp)]</td><td class='sky-num'>[cusp["longitude"]]&deg;</td></tr>"
			content += "</table>"
		content += "</div>"
	else
		content += "<p class='sky-plain sky-none'>House cusps not recorded.</p>"
	content += "</div><p class='sky-note'>The Sun keeps its sign and that sign's bonuses. Nothing else on this chart changes what your character can do.</p></div>"
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
	var/datum/browser/popup = new(src, "birth_chart_wheel", FALSE, 500, 720)
	popup.add_head_content(birth_chart_style("Birth Chart"))
	popup.set_content(birth_chart_wheel_html(birth_chart, birth_chart_record))
	popup.open(FALSE)
