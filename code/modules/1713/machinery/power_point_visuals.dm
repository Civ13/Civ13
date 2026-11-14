// Overhead wires between utility poles. The types, span_poles and
// span_images live in power_points.dm; this file only draws.

// Height of the pole-top insulator above the icon centre, in pixels: the
// wire row of icons/obj/power_distribution.dmi "utility_pole" is 26 up the tile.
#define POWER_SPAN_RISE 10

// Draws one wire to each partner in span_poles. A pair is drawn once, by the
// pole whose reference sorts first, so two poles never stack the same wire.
/obj/structure/power_point/pole/proc/update_span_overlays()
	if (span_images)
		overlays -= span_images
	span_images = null
	if (!span_poles || !span_poles.len || !isturf(loc))
		return
	var/list/drawn = list()
	var/own_ref = "\ref[src]"
	for (var/obj/structure/power_point/pole/P in span_poles)
		if (P == src || P.z != z || !isturf(P.loc))
			continue
		// sorttext() is 1 when its arguments are in ascending order.
		if (sorttext(own_ref, "\ref[P]") != 1)
			continue
		var/dx = (P.x - x) * 32
		var/dy = (P.y - y) * 32
		var/length = sqrt(dx * dx + dy * dy)
		if (length <= 0)
			continue
		var/image/I = image('icons/obj/power_distribution.dmi', "span")
		I.layer = FLY_LAYER
		I.appearance_flags = RESET_COLOR | RESET_ALPHA
		var/matrix/M = matrix()
		// The frame is a 32px horizontal wire through the icon centre.
		M.Scale(length / 32, 1)
		// arctan(x, y) is counterclockwise from east; Turn() is clockwise.
		M.Turn(-arctan(dx, dy))
		// Centre it midway between the two insulators.
		M.Translate(dx / 2, dy / 2 + POWER_SPAN_RISE)
		I.transform = M
		drawn += I
	if (drawn.len)
		span_images = drawn
		overlays += span_images

#undef POWER_SPAN_RISE
