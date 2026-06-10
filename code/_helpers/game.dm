//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:31

/proc/dopage(source_obj,target)
	var/href_list
	var/href
	href_list = params2list("src=\ref[source_obj]&[target]=1")
	href = "src=\ref[source_obj];[target]=1"
	//source_obj:temphtml = null
	source_obj:Topic(href, href_list)
	return null

/*/proc/get_area(O)
	var/turf/loc = get_turf(O)
	if (loc)
		return loc.loc
	return null*/

/proc/get_area_name(N) //get area by its name
	for (var/area/A in area_list)
		if (A.name == N)
			return A
	return FALSE

/proc/in_range(source, user)
	if (get_dist(source, user) <= 1)
		return TRUE

	return FALSE //not in range and not telekinetic

/proc/get_carginal_dir(atom/start, atom/finish)
	var/dx = finish.x - start.x
	var/dy = finish.y - start.y
	if (abs(dy) > abs(dx))
		if (dy > 0)
			return NORTH
		else
			return SOUTH
	else
		if (dx > 0)
			return EAST
		else
			return WEST

// Like view but bypasses luminosity check

/proc/hear(var/range, var/atom/source)
	if (source)
		var/lum = source.luminosity
		source.luminosity = 6

		var/list/heard = view(range, source)
		source.luminosity = lum

		return heard

/proc/trange(rad = FALSE, turf/centre = null) //alternative to range (ONLY processes turfs and thus less intensive)
	if (!centre)
		return

	var/turf/x1y1 = locate(((centre.x-rad)<1 ? TRUE : centre.x-rad),((centre.y-rad)<1 ? TRUE : centre.y-rad),centre.z)
	var/turf/x2y2 = locate(((centre.x+rad)>world.maxx ? world.maxx : centre.x+rad),((centre.y+rad)>world.maxy ? world.maxy : centre.y+rad),centre.z)
	return block(x1y1,x2y2)

/proc/circlerangeturfs(radius=3,center=usr)

	var/turf/centerturf = get_turf(center)
	var/list/turfs = new/list()
	var/rsq = radius * (radius+0.5)

	for (var/turf/T in range(radius, centerturf))
		var/dx = T.x - centerturf.x
		var/dy = T.y - centerturf.y
		if (dx*dx + dy*dy <= rsq)
			turfs += T
	return turfs

// Returns a list of mobs and/or objects in range of R from source. Used in radio and say code.

/proc/get_mobs_or_objects_in_view(var/R, var/atom/source, var/include_mobs = TRUE, var/include_objects = TRUE)

	var/turf/T = get_turf(source)
	var/list/hear = list()

	if (!T)
		return hear

	var/list/range = hear(R, T)

	for (var/I in range)
		if (ismob(I))
			if (include_mobs)
				var/mob/M = I
				if (M.client)
					hear += M
		else if (istype(I,/obj/))
			if (include_objects)
				hear += I

	return hear

proc
	inLineOfSight(X1,Y1,X2,Y2,Z=1,PX1=16.5,PY1=16.5,PX2=16.5,PY2=16.5)
		var/turf/T
		if (X1==X2)
			if (Y1==Y2)
				return TRUE //Light cannot be blocked on same tile
			else
				var/s = ((Y2-Y1) ? ((Y2-Y1) < 0 ? -1 : 1) : 0)
				Y1+=s
				while (Y1!=Y2)
					T=locate(X1,Y1,Z)
					if (T.opacity)
						return FALSE
					Y1+=s
		else
			var/m=(32*(Y2-Y1)+(PY2-PY1))/(32*(X2-X1)+(PX2-PX1))
			var/b=(Y1+PY1/32-0.015625)-m*(X1+PX1/32-0.015625) //In tiles
			var/signX = ((X2-X1) ? ((X2-X1) < 0 ? -1 : 1) : 0)
			var/signY = ((Y2-Y1) ? ((Y2-Y1) < 0 ? -1 : 1) : 0)
			if (X1<X2)
				b+=m
			while (X1!=X2 || Y1!=Y2)
				if (round(m*X1+b-Y1))
					Y1+=signY //Line exits tile vertically
				else
					X1+=signX //Line exits tile horizontally
				T=locate(X1,Y1,Z)
				if (T.opacity)
					return FALSE
		return TRUE

/proc/get_mob_by_key(var/key)
	for (var/mob/M in mob_list)
		if (M.ckey == lowertext(key))
			return M
	return null


/proc/flick_overlay(image/I, list/show_to, duration)
	for (var/client/C in show_to)
		C.images += I
	spawn(duration)
		for (var/client/C in show_to)
			C.images -= I

/proc/GetRedPart(const/hexa)
	return hex2num(copytext(hexa,2,4))

/proc/GetGreenPart(const/hexa)
	return hex2num(copytext(hexa,4,6))

/proc/GetBluePart(const/hexa)
	return hex2num(copytext(hexa,6,8))

/proc/MixColors(const/list/colors)
	var/list/reds = list()
	var/list/blues = list()
	var/list/greens = list()
	var/list/weights = list()

	for (var/i = FALSE, ++i <= colors.len)
		reds.Add(GetRedPart(colors[i]))
		blues.Add(GetBluePart(colors[i]))
		greens.Add(GetGreenPart(colors[i]))
		weights.Add(1)

	var/r = mixOneColor(weights, reds)
	var/g = mixOneColor(weights, greens)
	var/b = mixOneColor(weights, blues)
	return rgb(r,g,b)

/proc/mixOneColor(var/list/weight, var/list/color)
	if (!weight || !color || length(weight)!=length(color))
		return FALSE

	var/contents = length(weight)
	var/i

	//normalize weights
	var/listsum = FALSE
	for (i=1; i<=contents; i++)
		listsum += weight[i]
	for (i=1; i<=contents; i++)
		weight[i] /= listsum

	//mix them
	var/mixedcolor = FALSE
	for (i=1; i<=contents; i++)
		mixedcolor += weight[i]*color[i]
	mixedcolor = round(mixedcolor)

	//until someone writes a formal proof for this algorithm, let's keep this in
//	if (mixedcolor<0x00 || mixedcolor>0xFF)
//		return FALSE
	//that's not the kind of operation we are running here, nerd
	mixedcolor=min(max(mixedcolor,0),255)

	return mixedcolor

/proc/SecondsToTicks(var/seconds)
	return seconds * 10
