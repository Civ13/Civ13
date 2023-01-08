//This file was auto-corrected by findeclaration.exe on 25.5.2012 20:42:31

/*
 * A large number of misc global procs.
 */

//Checks if all high bits in req_mask are set in bitfield
#define BIT_TEST_ALL(bitfield, req_mask) ((~(bitfield) & (req_mask)) == FALSE)
#define PASS pass()

// get rid of vars causing warnings or just do nothing
/proc/pass(arg1, arg2, arg3, arg4, arg5)
	return TRUE

//Inverts the colour of an HTML string
/proc/invertHTML(HTMLstring)

	if (!( istext(HTMLstring) ))
		CRASH("Given non-text argument!")
		return
	else
		if (length(HTMLstring) != 7)
			CRASH("Given non-HTML argument!")
			return
	var/textr = copytext(HTMLstring, 2, 4)
	var/textg = copytext(HTMLstring, 4, 6)
	var/textb = copytext(HTMLstring, 6, 8)
	var/r = hex2num(textr)
	var/g = hex2num(textg)
	var/b = hex2num(textb)
	textr = num2hex(255 - r)
	textg = num2hex(255 - g)
	textb = num2hex(255 - b)
	if (length(textr) < 2)
		textr = text("0[]", textr)
	if (length(textg) < 2)
		textr = text("0[]", textg)
	if (length(textb) < 2)
		textr = text("0[]", textb)
	return text("#[][][]", textr, textg, textb)
	return

//Returns the middle-most value
/proc/dd_range(var/low, var/high, var/num)
	return max(low,min(high,num))

//Returns whether or not A is the middle most value
/proc/InRange(var/A, var/lower, var/upper)
	if (A < lower) return FALSE
	if (A > upper) return FALSE
	return TRUE

/*
/proc/Get_Angle(atom/movable/start,atom/movable/end)//For beams.
	if (!start || !end) return FALSE
	var/dy
	var/dx
	dy=(32*end.y+end.pixel_y)-(32*start.y+start.pixel_y)
	dx=(32*end.x+end.pixel_x)-(32*start.x+start.pixel_x)
	if (!dy)
		return (dx>=0)?90:270
	.=arctan(dx/dy)
	if (dy<0)
		.+=180
	else if (dx<0)
		.+=360
*/
//Returns location. Returns null if no location was found.
/proc/get_teleport_loc(turf/location,mob/target,distance = TRUE, density = FALSE, errorx = FALSE, errory = FALSE, eoffsetx = FALSE, eoffsety = FALSE)
/*
Location where the teleport begins, target that will teleport, distance to go, density checking FALSE/1(yes/no).
Random error in tile placement x, error in tile placement y, and block offset.
Block offset tells the proc how to place the box. Behind teleport location, relative to starting location, forward, etc.
Negative values for offset are accepted, think of it in relation to North, -x is west, -y is south. Error defaults to positive.
Turf and target are seperate in case you want to teleport some distance from a turf the target is not standing on or something.
*/

	var/dirx = FALSE//Generic location finding variable.
	var/diry = FALSE

	var/xoffset = FALSE//Generic counter for offset location.
	var/yoffset = FALSE

	var/b1xerror = FALSE//Generic placing for point A in box. The lower left.
	var/b1yerror = FALSE
	var/b2xerror = FALSE//Generic placing for point B in box. The upper right.
	var/b2yerror = FALSE

	errorx = abs(errorx)//Error should never be negative.
	errory = abs(errory)
	//var/errorxy = round((errorx+errory)/2)//Used for diagonal boxes.

	switch(target.dir)//This can be done through equations but switch is the simpler method. And works fast to boot.
	//Directs on what values need modifying.
		if (1)//North
			diry+=distance
			yoffset+=eoffsety
			xoffset+=eoffsetx
			b1xerror-=errorx
			b1yerror-=errory
			b2xerror+=errorx
			b2yerror+=errory
		if (2)//South
			diry-=distance
			yoffset-=eoffsety
			xoffset+=eoffsetx
			b1xerror-=errorx
			b1yerror-=errory
			b2xerror+=errorx
			b2yerror+=errory
		if (4)//East
			dirx+=distance
			yoffset+=eoffsetx//Flipped.
			xoffset+=eoffsety
			b1xerror-=errory//Flipped.
			b1yerror-=errorx
			b2xerror+=errory
			b2yerror+=errorx
		if (8)//West
			dirx-=distance
			yoffset-=eoffsetx//Flipped.
			xoffset+=eoffsety
			b1xerror-=errory//Flipped.
			b1yerror-=errorx
			b2xerror+=errory
			b2yerror+=errorx

	var/turf/destination=locate(location.x+dirx,location.y+diry,location.z)

	if (destination)//If there is a destination.
		if (errorx||errory)//If errorx or y were specified.
			var/destination_list[] = list()//To add turfs to list.
			//destination_list = new()
			/*This will draw a block around the target turf, given what the error is.
			Specifying the values above will basically draw a different sort of block.
			If the values are the same, it will be a square. If they are different, it will be a rectengle.
			In either case, it will center based on offset. Offset is position from center.
			Offset always calculates in relation to direction faced. In other words, depending on the direction of the teleport,
			the offset should remain positioned in relation to destination.*/

			var/turf/center = locate((destination.x+xoffset),(destination.y+yoffset),location.z)//So now, find the new center.

			//Now to find a box from center location and make that our destination.
			for (var/turf/T in block(locate(center.x+b1xerror,center.y+b1yerror,location.z), locate(center.x+b2xerror,center.y+b2yerror,location.z) ))
				if (density&&T.density)	continue//If density was specified.
				if (T.x>world.maxx || T.x<1)	continue//Don't want them to teleport off the map.
				if (T.y>world.maxy || T.y<1)	continue
				destination_list += T
			if (destination_list.len)
				destination = pick(destination_list)
			else	return

		else//Same deal here.
			if (density&&destination.density)	return
			if (destination.x>world.maxx || destination.x<1)	return
			if (destination.y>world.maxy || destination.y<1)	return
	else	return

	return destination



/proc/LinkBlocked(turf/A, turf/B)
	if (A == null || B == null) return TRUE
	var/adir = get_dir(A,B)
	var/rdir = get_dir(B,A)
	if ((adir & (NORTH|SOUTH)) && (adir & (EAST|WEST)))	//	diagonal
		var/iStep = get_step(A,adir&(NORTH|SOUTH))
		if (!LinkBlocked(A,iStep) && !LinkBlocked(iStep,B)) return FALSE

		var/pStep = get_step(A,adir&(EAST|WEST))
		if (!LinkBlocked(A,pStep) && !LinkBlocked(pStep,B)) return FALSE
		return TRUE

	if (DirBlocked(A,adir)) return TRUE
	if (DirBlocked(B,rdir)) return TRUE
	return FALSE


/proc/DirBlocked(turf/loc,var/dir)
	for (var/obj/structure/window/D in loc)
		if (!D.density)			continue
		if (D.dir == SOUTHWEST)	return TRUE
		if (D.dir == dir)		return TRUE

	for (var/obj/structure/simple_door/S in loc)
		if (!S.density)			continue
	/*	if (istype(D, /obj/machinery/door/window))
			if ((dir & SOUTH) && (D.dir & (EAST|WEST)))		return TRUE
			if ((dir & EAST ) && (D.dir & (NORTH|SOUTH)))	return TRUE
		else */
		return TRUE	// it's a real, air blocking door
	return FALSE

/proc/TurfBlockedNonWindow(turf/loc)
	for (var/obj/O in loc)
		if (O.density && !istype(O, /obj/structure/window))
			return TRUE
	return FALSE

/proc/sign(x)
	return x!=0?x/abs(x):0

//Ultra-Fast Bresenham Line-Drawing Algorithm
/proc/getline(atom/M,atom/N, var/exclude_m_turf = FALSE)
	var/px=M.x		//starting x
	var/py=M.y
	var/line[] = list()

	if (!exclude_m_turf)
		line += locate(px,py,M.z)

	var/dx=N.x-px	//x distance
	var/dy=N.y-py
	var/dxabs=abs(dx)//Absolute value of x distance
	var/dyabs=abs(dy)
	var/sdx=sign(dx)	//Sign of x distance (+ or -)
	var/sdy=sign(dy)
	var/x=dxabs>>1	//Counters for steps taken, setting to distance/2
	var/y=dyabs>>1	//Bit-shifting makes me l33t.  It also makes getline() unnessecarrily fast.
	var/j			//Generic integer for counting
	if (dxabs>=dyabs)	//x distance is greater than y
		for (j=0;j<dxabs;j++)//It'll take dxabs steps to get there
			y+=dyabs
			if (y>=dxabs)	//Every dyabs steps, step once in y direction
				y-=dxabs
				py+=sdy
			px+=sdx		//Step on in x direction
			line+=locate(px,py,M.z)//Add the turf to the list
	else
		for (j=0;j<dyabs;j++)
			x+=dxabs
			if (x>=dyabs)
				x-=dyabs
				px+=sdx
			py+=sdy
			line+=locate(px,py,M.z)
	return line

//Bresenham's algorithm. This one deals efficiently with all 8 octants.
/proc/getline2(atom/from_atom, atom/to_atom, include_from_atom = TRUE)
	if(!from_atom || !to_atom) return 0
	var/list/turf/turfs = list()

	var/cur_x = from_atom.x
	var/cur_y = from_atom.y

	var/w = to_atom.x - from_atom.x
	var/h = to_atom.y - from_atom.y
	var/dx1 = 0
	var/dx2 = 0
	var/dy1 = 0
	var/dy2 = 0
	if(w < 0)
		dx1 = -1
		dx2 = -1
	else if(w > 0)
		dx1 = 1
		dx2 = 1
	if(h < 0) dy1 = -1
	else if(h > 0) dy1 = 1
	var/longest = abs(w)
	var/shortest = abs(h)
	if(!(longest > shortest))
		longest = abs(h)
		shortest = abs(w)
		if(h < 0) dy2 = -1
		else if (h > 0) dy2 = 1
		dx2 = 0

	var/numerator = longest >> 1
	var/i
	for(i = 0; i <= longest; i++)
		if(i > 0 || include_from_atom)
			turfs += locate(cur_x,cur_y,from_atom.z)
		numerator += shortest
		if(!(numerator < longest))
			numerator -= longest
			cur_x += dx1
			cur_y += dy1
		else
			cur_x += dx2
			cur_y += dy2


	return turfs

/proc/getstraightline(atom/M, atom/N, var/exclude_m_turf = FALSE, var/skip_turfs = FALSE)//Ultra-Fast Bresenham Line-Drawing Algorithm
	var/list/line = list()

	if (!exclude_m_turf)
		line += get_turf(M)

	var/active_turf = get_step(M, M.dir)

	for (var/v in TRUE to rand(7,9))
		if (skip_turfs)
			--skip_turfs
			continue
		line += active_turf
		if (active_turf == get_turf(N))
			break
		active_turf = get_step(active_turf, M.dir)

	return line

/proc/getturfsbetween(atom/start, atom/target, var/maxrange = 5, var/safe = TRUE)

	var/list/turfs = list()
	var/horizontal_dir_2_target = target.x > start.x ? EAST : WEST
	var/vertical_dir_2_target = target.y > start.y ? NORTH : SOUTH

	for (var/turf/t in range(maxrange, start))

		if (safe)
			if (t == get_turf(start) || t == get_turf(target))
				continue

			if (locate(get_turf(start)) in range(1, t))
				continue

		if (horizontal_dir_2_target == EAST && t.x > start.x && t.x <= target.x)
			turfs += t
		else if (horizontal_dir_2_target == WEST && t.x < start.x && t.x >= target.x)
			turfs += t

		if (vertical_dir_2_target == NORTH && t.y > start.y && t.y <= target.y)
			turfs += t
		else if (vertical_dir_2_target == SOUTH && t.y < start.y && t.y >= target.y)
			turfs += t


	return turfs

#define LOCATE_COORDS(X, Y, Z) locate(between(1, X, world.maxx), between(1, Y, world.maxy), Z)
/proc/getcircle(turf/center, var/radius) //Uses a fast Bresenham rasterization algorithm to return the turfs in a thin circle.
	if (!radius) return list(center)

	var/x = FALSE
	var/y = radius
	var/p = 3 - 2 * radius

	. = list()
	while (y >= x) // only formulate TRUE/8 of circle

		. += LOCATE_COORDS(center.x - x, center.y - y, center.z) //upper left left
		. += LOCATE_COORDS(center.x - y, center.y - x, center.z) //upper upper left
		. += LOCATE_COORDS(center.x + y, center.y - x, center.z) //upper upper right
		. += LOCATE_COORDS(center.x + x, center.y - y, center.z) //upper right right
		. += LOCATE_COORDS(center.x - x, center.y + y, center.z) //lower left left
		. += LOCATE_COORDS(center.x - y, center.y + x, center.z) //lower lower left
		. += LOCATE_COORDS(center.x + y, center.y + x, center.z) //lower lower right
		. += LOCATE_COORDS(center.x + x, center.y + y, center.z) //lower right right

		if (p < 0)
			p += 4*x++ + 6;
		else
			p += 4*(x++ - y--) + 10;

#undef LOCATE_COORDS

//Returns whether or not a player is a guest using their ckey as an input
/proc/IsGuestKey(key)
	if (findtext(key, "Guest-", TRUE, 7) != TRUE) //was findtextEx
		return FALSE

	var/i = 7, ch, len = length(key)

	if (copytext(key, 7, 8) == "W") //webclient
		i++

	for (, i <= len, ++i)
		ch = text2ascii(key, i)
		if (ch < 48 || ch > 57)
			return FALSE
	return TRUE
/*
//Ensure the frequency is within bounds of what it should be sending/recieving at
/proc/sanitize_frequency(var/f, var/low = PUBLIC_LOW_FREQ, var/high = PUBLIC_HIGH_FREQ)
	f = round(f)
	f = max(low, f)
	f = min(high, f)
	if ((f % 2) == FALSE) //Ensure the last digit is an odd number
		f += 1
	return f

//Turns 1479 into 147.9
/proc/format_frequency(var/f)
	return "[round(f / 10)].[f % 10]"

*/

//This will update a mob's name, real_name, mind.name, data_core records, pda and id
//Calling this proc without an oldname will only update the mob and skip updating the pda, id and records ~Carn
/mob/proc/fully_replace_character_name(var/oldname,var/newname)
	if (!newname)	return FALSE
	real_name = newname
	name = newname
	if (mind)
		mind.name = newname
	if (dna)
		dna.real_name = real_name
/*
	if (oldname)
		//update the datacore records! This is goig to be a bit costly.
		for (var/list/L in list(data_core.general,data_core.medical,data_core.security,data_core.locked))
			for (var/datum/data/record/R in L)
				if (R.fields["name"] == oldname)
					R.fields["name"] = newname
					break*/
	return TRUE



//Generalised helper proc for letting mobs rename themselves. Used to be clname() and ainame()
//Last modified by Carn
/mob/proc/rename_self(var/role, var/allow_numbers=0)
	spawn(0)
		var/oldname = real_name

		var/time_passed = world.time
		var/newname

		for (var/i=1,i<=3,i++)	//we get 3 attempts to pick a suitable name.
			newname = WWinput(src, "You are \a [role]. Would you like to change your name to something else?", "Name change", oldname, "text")
			if ((world.time-time_passed)>3000)
				return	//took too long
			newname = sanitizeName(newname, ,allow_numbers)	//returns null if the name doesn't meet some basic requirements. Tidies up a few other things like bad-characters.

			for (var/mob/living/M in player_list)
				if (M == src)
					continue
				if (!newname || M.real_name == newname)
					newname = null
					break
			if (newname)
				break	//That's a suitable name!
			src << "Sorry, that [role]-name wasn't appropriate, please try another. It's possibly too long/short, has bad characters or is already taken."

		if (!newname)	//we'll stick with the oldname then
			return


		fully_replace_character_name(oldname,newname)



//Picks a string of symbols to display as the law number for hacked or ion laws
/proc/ionnum()
	return "[pick("1","2","3","4","5","6","7","8","9","0")][pick("!","@","#","$","%","^","&","*")][pick("!","@","#","$","%","^","&","*")][pick("!","@","#","$","%","^","&","*")]"

/proc/get_sorted_mobs()
	var/list/old_list = getmobs()
	var/list/Dead_list = list()
	var/list/keyclient_list = list()
	var/list/key_list = list()
	var/list/logged_list = list()
	for (var/named in old_list)
		var/mob/M = old_list[named]
		if (isghost(M) || M.stat == DEAD)
			Dead_list |= M
		else if (M.key && M.client)
			keyclient_list |= M
		else if (M.key)
			key_list |= M
		else
			logged_list |= M
		old_list.Remove(named)
	var/list/new_list = list()
	new_list += keyclient_list
	new_list += key_list
	new_list += logged_list
	new_list += Dead_list
	return new_list


//Forces a variable to be posative
/proc/modulus(var/M)
	if (M >= 0)
		return M
	if (M < 0)
		return -M

// returns the turf located at the map edge in the specified direction relative to A
// used for mass driver
/proc/get_edge_target_turf(var/atom/A, var/direction)

	var/turf/target = locate(A.x, A.y, A.z)
	if (!A || !target)
		return FALSE
		//since NORTHEAST == NORTH & EAST, etc, doing it this way allows for diagonal mass drivers in the future
		//and isn't really any more complicated

		// Note diagonal directions won't usually be accurate
	if (direction & NORTH)
		target = locate(target.x, world.maxy, target.z)
	if (direction & SOUTH)
		target = locate(target.x, TRUE, target.z)
	if (direction & EAST)
		target = locate(world.maxx, target.y, target.z)
	if (direction & WEST)
		target = locate(1, target.y, target.z)

	return target

// returns turf relative to A in given direction at set range
// result is bounded to map size
// note range is non-pythagorean
// used for disposal system
/proc/get_ranged_target_turf(var/atom/A, var/direction, var/range)

	var/x = A.x
	var/y = A.y
	if (direction & NORTH)
		y = min(world.maxy, y + range)
	if (direction & SOUTH)
		y = max(1, y - range)
	if (direction & EAST)
		x = min(world.maxx, x + range)
	if (direction & WEST)
		x = max(1, x - range)

	return locate(x,y,A.z)


// returns turf relative to A offset in dx and dy tiles
// bound to map limits
/proc/get_offset_target_turf(var/atom/A, var/dx, var/dy)
	var/x = min(world.maxx, max(1, A.x + dx))
	var/y = min(world.maxy, max(1, A.y + dy))
	return locate(x,y,A.z)

//Makes sure MIDDLE is between LOW and HIGH. If not, it adjusts it. Returns the adjusted value. Lower bound takes priority.
/proc/between(var/low, var/middle, var/high)
	return max(min(middle, high), low)

//Will return the contents of an atom recursivly to a depth of 'searchDepth'
/atom/proc/GetAllContents(searchDepth = 5)
	var/list/toReturn = list()

	for (var/atom/part in contents)
		toReturn += part
		if (part.contents.len && searchDepth)
			toReturn += part.GetAllContents(searchDepth - 1)

	return toReturn

//Step-towards method of determining whether one atom can see another. Similar to viewers()
/proc/can_see(var/atom/source, var/atom/target, var/length=5) // I couldn't be arsed to do actual raycasting :I This is horribly inaccurate.
	var/turf/current = get_turf(source)
	var/turf/target_turf = get_turf(target)
	var/steps = FALSE

	if (!current || !target_turf)
		return FALSE

	while (current != target_turf)
		if (steps > length) return FALSE
		if (current.opacity) return FALSE
		for (var/atom/A in current)
			if (A.opacity) return FALSE
		current = get_step_towards(current, target_turf)
		steps++

	return TRUE

/proc/is_blocked_turf(var/turf/T)
	var/cant_pass = FALSE
	if (T.density) cant_pass = TRUE
	for (var/atom/A in T)
		if (A.density)//&&A.anchored
			cant_pass = TRUE
	return cant_pass

/proc/get_step_towards2(var/atom/ref , var/atom/trg)
	var/base_dir = get_dir(ref, get_step_towards(ref,trg))
	var/turf/temp = get_step_towards(ref,trg)

	if (is_blocked_turf(temp))
		var/dir_alt1 = turn(base_dir, 90)
		var/dir_alt2 = turn(base_dir, -90)
		var/turf/turf_last1 = temp
		var/turf/turf_last2 = temp
		var/free_tile = null
		var/breakpoint = FALSE

		while (!free_tile && breakpoint < 10)
			if (!is_blocked_turf(turf_last1))
				free_tile = turf_last1
				break
			if (!is_blocked_turf(turf_last2))
				free_tile = turf_last2
				break
			turf_last1 = get_step(turf_last1,dir_alt1)
			turf_last2 = get_step(turf_last2,dir_alt2)
			breakpoint++

		if (!free_tile) return get_step(ref, base_dir)
		else return get_step_towards(ref,free_tile)

	else return get_step(ref, base_dir)

//Takes: Anything that could possibly have variables and a varname to check.
//Returns: TRUE if found, FALSE if not.
/proc/hasvar(var/datum/A, var/varname)
	if (A.vars.Find(lowertext(varname))) return TRUE
	else return FALSE

//Returns: all the areas in the world
/proc/return_areas()
	var/list/area/areas = list()
	for (var/area/A in area_list)
		areas += A
	return areas

//Returns: all the areas in the world, sorted.
/proc/return_sorted_areas()
	return sortAtom(return_areas())

//Takes: Area type as text string or as typepath OR an instance of the area.
//Returns: A list of all areas of that type in the world.
/proc/get_areas(var/areatype)
	if (!areatype) return null
	if (istext(areatype)) areatype = text2path(areatype)
	if (isarea(areatype))
		var/area/areatemp = areatype
		areatype = areatemp.type

	var/list/areas = new/list()
	for (var/area/N in area_list)
		if (istype(N, areatype)) areas += N
	return areas

//Takes: Area type as text string or as typepath OR an instance of the area.
//Returns: A list of all atoms	(objs, turfs, mobs) in areas of that type of that type in the world.
/proc/get_area_all_atoms(var/areatype)
	if (!areatype) return null
	if (istext(areatype)) areatype = text2path(areatype)
	if (isarea(areatype))
		var/area/areatemp = areatype
		areatype = areatemp.type

	var/list/atoms = new/list()
	for (var/area/N in area_list)
		if (istype(N, areatype))
			for (var/atom/A in N)
				atoms += A
	return atoms

/datum/coords //Simple datum for storing coordinates.
	var/x_pos = null
	var/y_pos = null
	var/z_pos = null

proc/DuplicateObject(obj/original, var/perfectcopy = FALSE , var/sameloc = FALSE)
	if (!original)
		return null

	var/obj/O = null

	if (sameloc)
		O=new original.type(original.loc)
	else
		O=new original.type(locate(0,0,0))

	if (perfectcopy)
		if ((O) && (original))
			for (var/V in original.vars)
				if (!(V in list("type","loc","locs","vars", "parent", "parent_type","verbs","ckey","key")))
					O.vars[V] = original.vars[V]
	return O


/area/proc/copy_contents_to(var/area/A , var/platingRequired = FALSE )
	//Takes: Area. Optional: If it should copy to areas that don't have plating
	//Returns: Nothing.
	//Notes: Attempts to move the contents of one area to another area.
	//	   Movement based on lower left corner. Tiles that do not fit
	//		 into the new area will not be moved.

	// Does *not* affect gases etc; copied turfs will be changed via ChangeTurf, and the dir, icon, and icon_state copied. All other vars will remain default.

	if (!A || !src) return FALSE

	var/list/turfs_src = get_area_turfs(type)
	var/list/turfs_trg = get_area_turfs(A.type)

	var/src_min_x = FALSE
	var/src_min_y = FALSE
	for (var/turf/T in turfs_src)
		if (T.x < src_min_x || !src_min_x) src_min_x	= T.x
		if (T.y < src_min_y || !src_min_y) src_min_y	= T.y

	var/trg_min_x = FALSE
	var/trg_min_y = FALSE
	for (var/turf/T in turfs_trg)
		if (T.x < trg_min_x || !trg_min_x) trg_min_x	= T.x
		if (T.y < trg_min_y || !trg_min_y) trg_min_y	= T.y

	var/list/refined_src = new/list()
	for (var/turf/T in turfs_src)
		refined_src += T
		refined_src[T] = new/datum/coords
		var/datum/coords/C = refined_src[T]
		C.x_pos = (T.x - src_min_x)
		C.y_pos = (T.y - src_min_y)

	var/list/refined_trg = new/list()
	for (var/turf/T in turfs_trg)
		refined_trg += T
		refined_trg[T] = new/datum/coords
		var/datum/coords/C = refined_trg[T]
		C.x_pos = (T.x - trg_min_x)
		C.y_pos = (T.y - trg_min_y)

	var/list/toupdate = new/list()

	var/copiedobjs = list()


	moving:
		for (var/turf/T in refined_src)
			var/datum/coords/C_src = refined_src[T]
			for (var/turf/B in refined_trg)
				var/datum/coords/C_trg = refined_trg[B]
				if (C_src.x_pos == C_trg.x_pos && C_src.y_pos == C_trg.y_pos)

					var/old_dir1 = T.dir
					var/old_icon_state1 = T.icon_state
					var/old_icon1 = T.icon
					var/old_overlays = T.overlays.Copy()
					var/old_underlays = T.underlays.Copy()

					if (platingRequired)
						if (istype(B, get_base_turf_by_area(B)))
							continue moving

					var/turf/X = B
					X.ChangeTurf(T.type)
					X.set_dir(old_dir1)
					X.icon_state = old_icon_state1
					X.icon = old_icon1 //Shuttle floors are in shuttle.dmi while the defaults are floors.dmi
					X.overlays = old_overlays
					X.underlays = old_underlays

					var/list/objs = new/list()
					var/list/newobjs = new/list()
					var/list/mobs = new/list()
					var/list/newmobs = new/list()

					for (var/obj/O in T)

						if (!istype(O,/obj))
							continue

						objs += O


					for (var/obj/O in objs)
						newobjs += DuplicateObject(O , TRUE)


					for (var/obj/O in newobjs)
						O.loc = X

					for (var/mob/M in T)

						if (!istype(M,/mob) || isEye(M)) continue // If we need to check for more mobs, I'll add a variable
						mobs += M

					for (var/mob/M in mobs)
						newmobs += DuplicateObject(M , TRUE)

					for (var/mob/M in newmobs)
						M.loc = X

					copiedobjs += newobjs
					copiedobjs += newmobs

//					var/area/AR = X.loc

//					if (AR.lighting_use_dynamic)
//						X.opacity = !X.opacity
//						X.sd_SetOpacity(!X.opacity)			//TODO: rewrite this code so it's not messed by lighting ~Carn

					toupdate += X

					refined_src -= T
					refined_trg -= B
					continue moving


/*

	if (toupdate.len)
		for (var/turf/T1 in toupdate)
			air_master.mark_for_update(T1)*/

	return copiedobjs



proc/get_cardinal_dir(atom/A, atom/B)
	var/dx = abs(B.x - A.x)
	var/dy = abs(B.y - A.y)
	return get_dir(A, B) & (rand() * (dx+dy) < dy ? 3 : 12)

//chances are TRUE:value. anyprob(1) will always return true
proc/anyprob(value)
	return (rand(1,value)==value)

proc/view_or_range(distance = 7 , center = usr , type)
	switch(type)
		if ("view")
			. = view(distance,center)
		if ("range")
			. = range(distance,center)
	return

proc/oview_or_orange(distance = 7 , center = usr , type)
	switch(type)
		if ("view")
			. = oview(distance,center)
		if ("range")
			. = orange(distance,center)
	return

proc/get_mob_with_client_list()
	var/list/mobs = list()
	for (var/mob/M in mob_list)
		if (M.client)
			mobs += M
	return mobs


/proc/parse_zone(zone)
	if (zone == "r_hand") return "right hand"
	else if (zone == "l_hand") return "left hand"
	else if (zone == "l_arm") return "left arm"
	else if (zone == "r_arm") return "right arm"
	else if (zone == "l_leg") return "left leg"
	else if (zone == "r_leg") return "right leg"
	else if (zone == "l_foot") return "left foot"
	else if (zone == "r_foot") return "right foot"
	else if (zone == "l_hand") return "left hand"
	else if (zone == "r_hand") return "right hand"
	else if (zone == "l_foot") return "left foot"
	else if (zone == "r_foot") return "right foot"
	else return zone

//gets the turf the atom is located in (or itself, if it is a turf).
//returns null if the atom is not in a turf.
/proc/get_turf(atom/A)
	if (!istype(A)) return
	for (A, A && !isturf(A), A=A.loc);
	return A

/proc/get(atom/loc, type)
	while (loc)
		if (istype(loc, type))
			return loc
		loc = loc.loc
	return null

/proc/get_turf_or_move(turf/location)
	return get_turf(location)


//Quick type checks for some tools
var/global/list/common_tools = list(
/obj/item/weapon/wrench,
/obj/item/weapon/hammer,
/obj/item/weapon/wirecutters,
///obj/item/multitool,
/obj/item/weapon/crowbar)

/proc/istool(O)
	if (O && is_type_in_list(O, common_tools))
		return TRUE
	return FALSE

/proc/iswrench(O)
	if (istype(O, /obj/item/weapon/wrench))
		return TRUE
	return FALSE

/proc/iswirecutter(O)
	if (istype(O, /obj/item/weapon/wirecutters))
		return TRUE
	return FALSE

/proc/isscrewdriver(O)
	if (istype(O, /obj/item/weapon/hammer))
		return TRUE
	return FALSE
/*
/proc/ismultitool(O)
	if (istype(O, /obj/item/multitool))
		return TRUE
	return FALSE
*/
/proc/iscrowbar(O)
	if (istype(O, /obj/item/weapon/crowbar))
		return TRUE
	return FALSE

proc/is_hot(obj/item/W as obj)
	switch(W.type)
		if (/obj/item/weapon/flame/lighter)
			if (W:lit)
				return 1500
			else
				return FALSE
		if (/obj/item/weapon/flame/match)
			if (W:lit)
				return 1000
			else
				return FALSE
		if (/obj/item/clothing/mask/smokable/cigarette)
			if (W:lit)
				return 1000
			else
				return FALSE
/*		if (/obj/item/weapon/melee/energy)
			return 3500*/
		else
			return FALSE

	return FALSE

//Whether or not the given item counts as cutting with an edge in terms of removing limbs
/proc/has_edge(obj/O as obj)
	if (!O) return 0
	if (O.edge) return 1
	return 0


//Whether or not the given item counts as sharp in terms of dealing damage
/proc/is_sharp(obj/O as obj)
	if (!O) return FALSE
	if (O.sharp) return TRUE
	if (O.edge) return TRUE
	return FALSE

//Returns TRUE if the given item is capable of popping things like balloons, inflatable barriers, or cutting police tape.
/proc/can_puncture(obj/item/W as obj)		// For the record, WHAT THE HELL IS THIS METHOD OF DOING IT?
	if (!W) return FALSE
	if (W.sharp) return TRUE
	return ( \
		W.sharp													  || \
		istype(W, /obj/item/weapon/hammer)				   || \
		istype(W, /obj/item/weapon/pen)						   || \
		istype(W, /obj/item/weapon/flame/lighter/zippo)			  || \
		istype(W, /obj/item/weapon/flame/match)					  || \
		istype(W, /obj/item/clothing/mask/smokable/cigarette) 			  || \
		istype(W, /obj/item/weapon/material/shovel) \
	)

/proc/is_surgery_tool(obj/item/W as obj)
	return (	\
	istype(W, /obj/item/weapon/surgery/scalpel)			||	\
	istype(W, /obj/item/weapon/surgery/hemostat)		||	\
	istype(W, /obj/item/weapon/surgery/retractor)		||	\
	istype(W, /obj/item/weapon/surgery/cautery)			||	\
	istype(W, /obj/item/weapon/surgery/bonesetter)
	)

//check if mob is lying down on something we can operate him on.
/proc/can_operate(mob/living/human/M)
	var/M_turf = get_turf(M)
	for (var/obj/structure/optable/O in M_turf)
		return TRUE
	for (var/obj/structure/bed/B in M_turf)
		return prob(95)
	for (var/obj/structure/table/T in M_turf)
		return prob(90)
	return prob(85)

/proc/reverse_direction(var/dir)
	switch(dir)
		if (NORTH)
			return SOUTH
		if (NORTHEAST)
			return SOUTHWEST
		if (EAST)
			return WEST
		if (SOUTHEAST)
			return NORTHWEST
		if (SOUTH)
			return NORTH
		if (SOUTHWEST)
			return NORTHEAST
		if (WEST)
			return EAST
		if (NORTHWEST)
			return SOUTHEAST

/proc/format_text(text)
	return replacetext(replacetext(text,"\proper ",""),"\improper ","")

/proc/topic_link(var/datum/D, var/arglist, var/content)
	if (istype(arglist,/list))
		arglist = list2params(arglist)
	return "<a href='?src=\ref[D];[arglist]'>[content]</a>"

/proc/get_random_colour(var/simple, var/lower, var/upper)
	var/colour
	if (simple)
		colour = pick(list("FF0000","FF7F00","FFFF00","00FF00","0000FF","4B0082","8F00FF"))
	else
		for (var/i=1;i<=3;i++)
			var/temp_col = "[num2hex(rand(lower,upper))]"
			if (length(temp_col )<2)
				temp_col  = "0[temp_col]"
			colour += temp_col
	return "#[colour]"

var/mob/dview/dview_mob = new

//Version of view() which ignores darkness, because BYOND doesn't have it.
/proc/dview(var/range = 7, var/center, var/invis_flags = FALSE)
	if (!center)
		return

	dview_mob.loc = center

	dview_mob.see_invisible = invis_flags

	. = view(range, dview_mob)
	dview_mob.loc = null

/mob/dview
	invisibility = 101
	density = FALSE

	anchored = TRUE
	simulated = FALSE

	see_in_dark = 1e6

/atom/proc/get_light_and_color(var/atom/origin)
	if (origin)
		color = origin.color
		set_light(origin.light_range, origin.light_power, origin.light_color)

/mob/dview/New()
	..()
	// We don't want to be in any mob lists; we're a dummy not a mob.
	mob_list -= src
	if (stat == DEAD)
		dead_mob_list -= src
	else
		living_mob_list -= src

// call to generate a stack trace and print to runtime logs
/proc/crash_with(msg)
	CRASH(msg)

/proc/CheckFace(var/atom/Obj1, var/atom/Obj2)
	var/CurrentDir = get_dir(Obj1, Obj2)
	//if ((Obj1.loc == Obj2.loc) || (CurrentDir == Obj1.dir) || (CurrentDir == turn(Obj1.dir, 45)) || (CurrentDir == turn(Obj1.dir, -45)))
	if ((CurrentDir & Obj1.dir) || (CurrentDir == FALSE))
		return TRUE
	else
		return FALSE


