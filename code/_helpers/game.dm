//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:31

/proc/dopage(src,target)
	var/href_list
	var/href
	href_list = params2list("src=\ref[src]&[target]=1")
	href = "src=\ref[src];[target]=1"
	//src:temphtml = null
	src:Topic(href, href_list)
	return null

/proc/get_area(O)
	var/turf/loc = get_turf(O)
	if (loc)
		return loc.loc
	return null

/proc/get_area_name(N) //get area by its name
	for (var/area/A in area_list)
		if (A.name == N)
			return A
	return FALSE

/proc/get_area_master(const/O)
	var/area/A = get_area(O)
	if (isarea(A))
		return A

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

/proc/circlerange(center=usr,radius=3)

	var/turf/centerturf = get_turf(center)
	var/list/turfs = new/list()
	var/rsq = radius * (radius+0.5)

	for (var/atom/T in range(radius, centerturf))
		var/dx = T.x - centerturf.x
		var/dy = T.y - centerturf.y
		if (dx*dx + dy*dy <= rsq)
			turfs += T

	//turfs += centerturf
	return turfs

/proc/circleview(center=usr,radius=3)

	var/turf/centerturf = get_turf(center)
	var/list/atoms = new/list()
	var/rsq = radius * (radius+0.5)

	for (var/atom/A in view(radius, centerturf))
		var/dx = A.x - centerturf.x
		var/dy = A.y - centerturf.y
		if (dx*dx + dy*dy <= rsq)
			atoms += A

	//turfs += centerturf
	return atoms

/proc/trange(rad = FALSE, turf/centre = null) //alternative to range (ONLY processes turfs and thus less intensive)
	if (!centre)
		return

	var/turf/x1y1 = locate(((centre.x-rad)<1 ? TRUE : centre.x-rad),((centre.y-rad)<1 ? TRUE : centre.y-rad),centre.z)
	var/turf/x2y2 = locate(((centre.x+rad)>world.maxx ? world.maxx : centre.x+rad),((centre.y+rad)>world.maxy ? world.maxy : centre.y+rad),centre.z)
	return block(x1y1,x2y2)

/proc/get_dist_euclidian(atom/Loc1 as turf|mob|obj,atom/Loc2 as turf|mob|obj)
	var/dx = Loc1.x - Loc2.x
	var/dy = Loc1.y - Loc2.y

	var/dist = sqrt(dx**2 + dy**2)

	return dist

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

/proc/circleviewturfs(center=usr,radius=3)		//Is there even a diffrence between this proc and circlerangeturfs()?

	var/turf/centerturf = get_turf(center)
	var/list/turfs = new/list()
	var/rsq = radius * (radius+0.5)

	for (var/turf/T in view(radius, centerturf))
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
				var/s = SIGN(Y2-Y1)
				Y1+=s
				while (Y1!=Y2)
					T=locate(X1,Y1,Z)
					if (T.opacity)
						return FALSE
					Y1+=s
		else
			var/m=(32*(Y2-Y1)+(PY2-PY1))/(32*(X2-X1)+(PX2-PX1))
			var/b=(Y1+PY1/32-0.015625)-m*(X1+PX1/32-0.015625) //In tiles
			var/signX = SIGN(X2-X1)
			var/signY = SIGN(Y2-Y1)
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
#undef SIGN

proc/isInSight(var/atom/A, var/atom/B)
	var/turf/Aturf = get_turf(A)
	var/turf/Bturf = get_turf(B)

	if (!Aturf || !Bturf)
		return FALSE

	if (inLineOfSight(Aturf.x,Aturf.y, Bturf.x,Bturf.y,Aturf.z))
		return TRUE

	else
		return FALSE

/proc/get_cardinal_step_away(atom/start, atom/finish) //returns the position of a step from start away from finish, in one of the cardinal directions
	//returns only NORTH, SOUTH, EAST, or WEST
	var/dx = finish.x - start.x
	var/dy = finish.y - start.y
	if (abs(dy) > abs (dx)) //slope is above TRUE:1 (move horizontally in a tie)
		if (dy > 0)
			return get_step(start, SOUTH)
		else
			return get_step(start, NORTH)
	else
		if (dx > 0)
			return get_step(start, WEST)
		else
			return get_step(start, EAST)

/proc/get_mob_by_key(var/key)
	for (var/mob/M in mob_list)
		if (M.ckey == lowertext(key))
			return M
	return null


// Will return a list of active candidates. It increases the buffer 5 times until it finds a candidate which is active within the buffer.
/proc/get_active_candidates(var/buffer = TRUE)

	var/list/candidates = list() //List of candidate KEYS to assume control of the new larva ~Carn
	var/i = FALSE
	while (candidates.len <= 0 && i < 5)
		for (var/mob/observer/ghost/G in player_list)
			if (((G.client.inactivity/10)/60) <= buffer + i) // the most active players are more likely to become an alien
				if (!(G.mind && G.mind.current && G.mind.current.stat != DEAD))
					candidates += G.key
		i++
	return candidates


/proc/ScreenText(obj/O, maptext="", screen_loc="CENTER-7,CENTER-7", maptext_height=480, maptext_width=480)
	if (!isobj(O))	O = new /obj/screen/text()
	O.maptext = maptext
	O.maptext_height = maptext_height
	O.maptext_width = maptext_width
	O.screen_loc = screen_loc
	return O

/proc/Show2Group4Delay(obj/O, list/group, delay=0)
	if (!isobj(O))	return
	if (!group)	group = clients
	for (var/client/C in group)
		C.screen += O
	if (delay)
		spawn(delay)
			for (var/client/C in group)
				C.screen -= O

/proc/flick_overlay(image/I, list/show_to, duration)
	for (var/client/C in show_to)
		C.images += I
	spawn(duration)
		for (var/client/C in show_to)
			C.images -= I

datum/projectile_data
	var/src_x
	var/src_y
	var/time
	var/distance
	var/power_x
	var/power_y
	var/dest_x
	var/dest_y

/datum/projectile_data/New(var/_src_x, var/_src_y, var/_time, var/_distance, \
						   var/_power_x, var/_power_y, var/_dest_x, var/_dest_y)
	src_x = _src_x
	src_y = _src_y
	time = _time
	distance = _distance
	power_x = _power_x
	power_y = _power_y
	dest_x = _dest_x
	dest_y = _dest_y

/proc/projectile_trajectory(var/src_x, var/src_y, var/rotation, var/angle, var/power)

	// returns the destination (Vx,y) that a projectile shot at [src_x], [src_y], with an angle of [angle],
	// rotated at [rotation] and with the power of [power]
	// Thanks to VistaPOWA for this function

	var/power_x = power * cos(angle)
	var/power_y = power * sin(angle)
	var/time = 2* power_y / 10 //10 = g

	var/distance = time * power_x

	var/dest_x = src_x + distance*sin(rotation);
	var/dest_y = src_y + distance*cos(rotation);

	return new /datum/projectile_data(src_x, src_y, time, distance, power_x, power_y, dest_x, dest_y)

/proc/GetRedPart(const/hexa)
	return hex2num(copytext(hexa,2,4))

/proc/GetGreenPart(const/hexa)
	return hex2num(copytext(hexa,4,6))

/proc/GetBluePart(const/hexa)
	return hex2num(copytext(hexa,6,8))

/proc/GetHexColors(const/hexa)
	return list(
			GetRedPart(hexa),
			GetGreenPart(hexa),
			GetBluePart(hexa)
		)

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

/*
* Gets the highest and lowest pressures from the tiles in cardinal directions
* around us, then checks the difference.
*/
/*
/proc/getOPressureDifferential(var/turf/loc)
	var/minp=16777216;
	var/maxp=0;
	for (var/dir in cardinal)
		var/turf/T=get_turf(get_step(loc,dir))
		var/cp=0
		if (T && istype(T) && T.zone)
			var/datum/gas_mixture/environment = T.return_air()
			cp = environment.return_pressure()
		else
			if (istype(T,/turf))
				continue
		if (cp<minp)minp=cp
		if (cp>maxp)maxp=cp
	return abs(minp-maxp)
*/
/proc/convert_k2c(var/temp)
	return ((temp - T0C))

/proc/convert_c2k(var/temp)
	return ((temp + T0C))

/proc/getCardinalAirInfo(var/turf/loc, var/list/stats=list("temperature"))
	var/list/temps = new/list(4)
	for (var/dir in cardinal)
		var/direction
		switch(dir)
			if (NORTH)
				direction = TRUE
			if (SOUTH)
				direction = 2
			if (EAST)
				direction = 3
			if (WEST)
				direction = 4
		var/turf/T=get_turf(get_step(loc,dir))
		var/list/rstats = new /list(stats.len)
		if (istype(T, /turf))
			rstats = null // Exclude zone (wall, door, etc).
		temps[direction] = rstats
	return temps

/proc/MinutesToTicks(var/minutes)
	return SecondsToTicks(60 * minutes)

/proc/SecondsToTicks(var/seconds)
	return seconds * 10

/proc/getviewsize(view)
	var/viewX
	var/viewY
	if(isnum(view))
		var/totalviewrange = 1 + 2 * view
		viewX = totalviewrange
		viewY = totalviewrange
	else
		var/list/viewrangelist = splittext(view,"x")
		viewX = text2num(viewrangelist[1])
		viewY = text2num(viewrangelist[2])
	return list(viewX, viewY)