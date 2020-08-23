/obj/structure/vehicleparts/frame/ship/update_icon()
	overlays.Cut()
	if (!axis)
		dir = 1

	if (!noroof && axis)
		roof = image(icon=icon, loc=src, icon_state="[prefix]boat2", layer=11)
		roof.overlays.Cut()
	else
		roof = image(icon=icon, loc=src, icon_state="", layer=1)
		roof.overlays.Cut()
	var/ticon = normal_icon
	if (!noroof && axis)
		if (broken)
			ticon = broken_icon
		else
			ticon = normal_icon
	switch (dir)
		if (NORTH)
			if (w_left[1] != "")
				if (w_left[5]<=0)
					ticon = broken_icon
				else
					ticon = normal_icon
				var/image/tmpimg3 = image(icon=ticon, icon_state="[prefix][w_left[1]]", layer=10, dir=WEST)
				overlays += tmpimg3
			if (w_right[1] != "")
				if (w_right[5]<=0)
					ticon = broken_icon
				else
					ticon = normal_icon
				var/image/tmpimg4 = image(icon=ticon, icon_state="[prefix][w_right[1]]", layer=10, dir=EAST)
				overlays += tmpimg4
			if (w_front[1] != "")
				if (w_front[5]<=0)
					ticon = broken_icon
				else
					ticon = normal_icon
				var/image/tmpimg1 = image(icon=ticon, icon_state="[prefix][w_front[1]]", layer=10, dir=NORTH)
				overlays += tmpimg1
			if (w_back[1] != "")
				if (w_back[5]<=0)
					ticon = broken_icon
				else
					ticon = normal_icon
				var/image/tmpimg2 = image(icon=ticon, icon_state="[prefix][w_back[1]]", layer=10, dir=SOUTH)
				overlays += tmpimg2

		if (SOUTH)
			if (w_left[1] != "")
				if (w_left[5]<=0)
					ticon = broken_icon
				else
					ticon = normal_icon
				var/image/tmpimg3 = image(icon=ticon, icon_state="[prefix][w_left[1]]", layer=10, dir=EAST)
				overlays += tmpimg3
			if (w_right[1] != "")
				if (w_right[5]<=0)
					ticon = broken_icon
				else
					ticon = normal_icon
				var/image/tmpimg4 = image(icon=ticon, icon_state="[prefix][w_right[1]]", layer=10, dir=WEST)
				overlays += tmpimg4
			if (w_front[1] != "")
				if (w_front[5]<=0)
					ticon = broken_icon
				else
					ticon = normal_icon
				var/image/tmpimg1 = image(icon=ticon, icon_state="[prefix][w_front[1]]", layer=10, dir=SOUTH)
				overlays += tmpimg1
			if (w_back[1] != "")
				if (w_back[5]<=0)
					ticon = broken_icon
				else
					ticon = normal_icon
				var/image/tmpimg2 = image(icon=ticon, icon_state="[prefix][w_back[1]]", layer=10, dir=NORTH)
				overlays += tmpimg2

		if (EAST)
			if (w_left[1] != "")
				if (w_left[5]<=0)
					ticon = broken_icon
				else
					ticon = normal_icon
				var/image/tmpimg3 = image(icon=ticon, icon_state="[prefix][w_left[1]]", layer=10, dir=NORTH)
				overlays += tmpimg3
			if (w_right[1] != "")
				if (w_right[5]<=0)
					ticon = broken_icon
				else
					ticon = normal_icon
				var/image/tmpimg4 = image(icon=ticon, icon_state="[prefix][w_right[1]]", layer=10, dir=SOUTH)
				overlays += tmpimg4
			if (w_front[1] != "")
				if (w_front[5]<=0)
					ticon = broken_icon
				else
					ticon = normal_icon
				var/image/tmpimg1 = image(icon=ticon, icon_state="[prefix][w_front[1]]", layer=10, dir=EAST)
				overlays += tmpimg1
			if (w_back[1] != "")
				if (w_back[5]<=0)
					ticon = broken_icon
				else
					ticon = normal_icon
				var/image/tmpimg2 = image(icon=ticon, icon_state="[prefix][w_back[1]]", layer=10, dir=WEST)
				overlays += tmpimg2

		if (WEST)
			if (w_left[1] != "")
				if (w_left[5]<=0)
					ticon = broken_icon
				else
					ticon = normal_icon
				var/image/tmpimg3 = image(icon=ticon, icon_state="[prefix][w_left[1]]", layer=10, dir=SOUTH)
				overlays += tmpimg3
			if (w_right[1] != "")
				if (w_right[5]<=0)
					ticon = broken_icon
				else
					ticon = normal_icon
				var/image/tmpimg4 = image(icon=ticon, icon_state="[prefix][w_right[1]]", layer=10, dir=NORTH)
				overlays += tmpimg4
			if (w_front[1] != "")
				if (w_front[5]<=0)
					ticon = broken_icon
				else
					ticon = normal_icon
				var/image/tmpimg1 = image(icon=ticon, icon_state="[prefix][w_front[1]]", layer=10, dir=WEST)
				overlays += tmpimg1
			if (w_back[1] != "")
				if (w_back[5]<=0)
					ticon = broken_icon
				else
					ticon = normal_icon
				var/image/tmpimg2 = image(icon=ticon, icon_state="[prefix][w_back[1]]", layer=10, dir=EAST)
				overlays += tmpimg2