//parent object
/obj/structure/artillery/nebel
	name = "Nebelwerfer"

/obj/structure/artillery/nebel/New(var/loc, var/mob/builder, var/dir)

	if (!dir)
		dir = SOUTH

	var/fake_builder = FALSE

	if (builder == null && dir != null)
		builder = new/mob(loc)
		builder.dir = dir
		fake_builder = TRUE

	var/obj/structure/artillery/base/nebel/base = new/obj/structure/artillery/base/nebel(loc)
	var/obj/structure/artillery/tube/nebel/tube = new/obj/structure/artillery/tube/nebel(get_step(base, base.dir))

	for (var/v in TRUE to 6)
		base.lloaded[v] = new/obj/item/artillery_shell/none()

	base.dir = builder.dir
	tube.dir = builder.dir
	base.other = tube
	tube.other = base
	base.anchored = FALSE
	tube.anchored = TRUE

	if (fake_builder)
		qdel(builder)

	qdel(src)


/obj/structure/artillery/base/nebel
	name = "Nebelwerfer"
	var/lloaded[6]
	icon = 'icons/WW2/nebelwerfer.dmi'
	icon_state = ""

/obj/structure/artillery/base/nebel/getNextOpeningClosingState()
	return initial(icon_state)

/obj/structure/artillery/base/nebel/New()

/obj/structure/artillery/base/nebel/proc/Name(var/atom/a)
	if (a && istype(a))
		return a.name
	else //fallback
		return "Empty Slot"

/obj/structure/artillery/base/nebel/do_html(var/mob/m)

	if (m)

		m << browse({"

		<html>

		<script language="javascript">

		function set(input) {
		  window.location="byond://?src=\ref[src];action="+input.name+"&value="+input.value;
		}

		</script>

		<center>
		<big><b>[name]</b></big><br><br>
		<a href='?src=\ref[src];open=1'>Open the shell slot</a><br>
		<a href='?src=\ref[src];close=1'>Close the shell slot</a><br><br>
		<b>Loaded Shells</b><br><br>
		<a href='?src=\ref[src];load_slot_1=1'>[Name(lloaded[1])]</a><br><br>
		<a href='?src=\ref[src];load_slot_2=1'>[Name(lloaded[2])]</a><br><br>
		<a href='?src=\ref[src];load_slot_3=1'>[Name(lloaded[3])]</a><br><br>
		<a href='?src=\ref[src];load_slot_4=1'>[Name(lloaded[4])]</a><br><br>
		<a href='?src=\ref[src];load_slot_5=1'>[Name(lloaded[5])]</a><br><br>
		<a href='?src=\ref[src];load_slot_6=1'>[Name(lloaded[6])]</a><br><br>
		<b>Firing Options</b><br><br>
		Artillery Piece X-coordinate:<input type="text" name="xcoord" readonly value="[x]" onchange="set(this);" /><br>
		Artillery Piece Y-coordinate:<input type="text" name="ycoord" readonly value="[y]" onchange="set(this);" /><br>
		Offset X-coordinate:<input type="text" name="xocoord" value="[offset_x]" onchange="set(this);" /><br>
		Offset Y-coordinate:<input type="text" name="yocoord" value="[offset_y]" onchange="set(this);" /><br>
		Fire At X-coordinate:<input type="text" name="xplusxocoord" value="[offset_x + x]" onchange="set(this);" /><br>
		Fire At Y-coordinate:<input type="text" name="yplusyocoord" value="[offset_y + y]" onchange="set(this);" /><br>
		<br>
		<a href='?src=\ref[src];fire=1'><b><big>FIRE!</big></b></a>
		</center>

		</html>
		"},  "window=artillery_window;border=1;can_close=1;can_resize=1;can_minimize=0;titlebar=1;size=500x500")

/obj/structure/artillery/base/nebel/Topic(href, href_list, hsrc)

	if (!user.lying)

		user.face_atom(src)

		if (!locate(src) in get_step(user, user.dir))
			user << "<span class = 'danger'>Get behind the artillery to use it.</span>"
			return

		if (!user.can_use_hands())
			user << "<span class = 'danger'>You have no hands to use this with.</span>"
			return

		if (!anchored)
			user << "<span class = 'danger'>The artillery piece must be anchored to use.</span>"
			return

		var/value = href_list["value"]

		switch (href_list["action"])
			//we can enter offsets directly
			if ("xocoord")
				offset_x = text2num(value)
			if ("yocoord")
				offset_y = text2num(value)
			//or enter the firing location directly and have them generated
			if ("xplusxocoord")
				var/val = text2num(value)
				offset_x = val - x
			if ("yplusyocoord")
				var/val = text2num(value)
				offset_y = val - y

		if (href_list["fire"])
			if ("fire")
				if (state == "OPEN")
					user << "<span class='danger'>Close the shell loading slot first.</span>"
					return
				if (abs(offset_x) > 0 || abs(offset_y) > 0)
					if (abs(offset_x) + abs(offset_y) < 20)
						user << "<span class='danger'>This location is too close to fire to.</span>"
						return
					else
						if (other.use_slot())
							for (var/v in TRUE to 6)
								spawn (v * 2)
									other.fire(x + offset_x + rand(3,-3), y + offset_y + rand(3,-3), rand(14,20))
						else
							user << "<span class='danger'>Load a shell in first.</span>"
							return
				else
					user << "<span class='danger>Set an offset x and offset y coordinate.</span>"
					return

		if (href_list["open"])
			if (state == "OPEN")
				return
			flick("opening", src)
			spawn (8)
				state = "OPEN"
			spawn (6)
				if (other.drop_casing)
					new/obj/item/artillery_shell/casing(get_step(src, dir))
					user << "<span class='danger'>The casing falls out of the artillery.</span>"
					other.drop_casing = FALSE
					playsound(get_turf(src), 'sound/effects/Stamp.wav', 100, TRUE)

		if (href_list["close"])
			if (state == "CLOSED")
				return
			flick("closing", src)
			spawn (12)
				state = "CLOSED"

		for (var/i in TRUE to 10)
			if (href_list["load_slot_[i]"])
				if (state == "CLOSED")
					user << "<span class = 'danger'>The shell loading slot must be open to add a shell.</span>"
					return

				var/obj/o = user.get_active_hand()
				if (o && istype(o, /obj/item/artillery_shell) && !istype(o, /obj/item/artillery_shell/casing))
					if (!istype(lloaded[i], /obj/item/artillery_shell/none))
						var/atom/movable/a = lloaded[i]
						a.loc = get_turf(user)

					user.drop_from_inventory(o)
					o.loc = src
					lloaded[i] = o

		//	flick("opening", src)


		do_html(user)



/obj/structure/artillery/tube/nebel/use_slot()

	var/obj/structure/artillery/base/nebel/other_arty = other

	for (var/v in TRUE to 6)
		if (istype(other_arty.lloaded[v], /obj/item/artillery_shell))
			if (!istype(other_arty.lloaded[v], /obj/item/artillery_shell/none))
				if (!istype(other_arty.lloaded[v], /obj/item/artillery_shell/casing))
					other_arty.lloaded[v] = new/obj/item/artillery_shell/none(src)
				else
					if (other_arty.user)
						other_arty.user << "<span class = 'danger'>Every slot must be loaded for the Nebelwerfer to fire.</span>"
						return FALSE
			else
				if (other_arty.user)
					other_arty.user << "<span class = 'danger'>Every slot must be loaded for the Nebelwerfer to fire.</span>"
				return FALSE
		else
			if (other_arty.user)
				other_arty.user << "<span class = 'danger'>Every slot must be loaded for the Nebelwerfer to fire.</span>"
			return FALSE

	return TRUE