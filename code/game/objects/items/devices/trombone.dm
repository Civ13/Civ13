#define MAX_CHARS_PER_LINE 200
#define MAX_CHARS_TOTAL 20000


/obj/item/trombone
	name = "trumpet"
	desc = "To announce the arrival of the king!"
	icon_state = "trombone"
	item_state = "trombone"
	icon = 'icons/obj/musician.dmi'
	force = WEAPON_FORCE_WEAK
	var/datum/song/song
	var/playing = FALSE
	var/help = FALSE
	var/edit = TRUE
	var/repeat = FALSE
	flammable = TRUE
	value = 0

/obj/item/trombone/proc/playnote(var/note as text)
	//world << "Note: [note]"
	var/soundfile
	/*BYOND loads resource files at compile time if they are ''. This means you can't really manipulate them dynamically.
	Tried doing it dynamically at first but its more trouble than its worth. Would have saved many lines tho.*/
	switch(note)
		if ("Ab2")	soundfile = 'sound/trombone/Ab2.mid'
		if ("Ab3")	soundfile = 'sound/trombone/Ab3.mid'
		if ("Ab4")	soundfile = 'sound/trombone/Ab4.mid'
		if ("Ab5")	soundfile = 'sound/trombone/Ab5.mid'
		if ("Ab6")	soundfile = 'sound/trombone/Ab6.mid'
		if ("An2")	soundfile = 'sound/trombone/An2.mid'
		if ("An3")	soundfile = 'sound/trombone/An3.mid'
		if ("An4")	soundfile = 'sound/trombone/An4.mid'
		if ("An5")	soundfile = 'sound/trombone/An5.mid'
		if ("An6")	soundfile = 'sound/trombone/An6.mid'
		if ("Bb2")	soundfile = 'sound/trombone/Bb2.mid'
		if ("Bb3")	soundfile = 'sound/trombone/Bb3.mid'
		if ("Bb4")	soundfile = 'sound/trombone/Bb4.mid'
		if ("Bb5")	soundfile = 'sound/trombone/Bb5.mid'
		if ("Bb6")	soundfile = 'sound/trombone/Bb6.mid'
		if ("Bn2")	soundfile = 'sound/trombone/Bn2.mid'
		if ("Bn3")	soundfile = 'sound/trombone/Bn3.mid'
		if ("Bn4")	soundfile = 'sound/trombone/Bn4.mid'
		if ("Bn5")	soundfile = 'sound/trombone/Bn5.mid'
		if ("Bn6")	soundfile = 'sound/trombone/Bn6.mid'
		if ("Cn2")	soundfile = 'sound/trombone/Cn2.mid'
		if ("Cn3")	soundfile = 'sound/trombone/Cn3.mid'
		if ("Cn4")	soundfile = 'sound/trombone/Cn4.mid'
		if ("Cn5")	soundfile = 'sound/trombone/Cn5.mid'
		if ("Cn6")	soundfile = 'sound/trombone/Cn6.mid'
		if ("Db2")	soundfile = 'sound/trombone/Db2.mid'
		if ("Db3")	soundfile = 'sound/trombone/Db3.mid'
		if ("Db4")	soundfile = 'sound/trombone/Db4.mid'
		if ("Db5")	soundfile = 'sound/trombone/Db5.mid'
		if ("Db6")	soundfile = 'sound/trombone/Db6.mid'
		if ("Dn2")	soundfile = 'sound/trombone/Dn2.mid'
		if ("Dn3")	soundfile = 'sound/trombone/Dn3.mid'
		if ("Dn4")	soundfile = 'sound/trombone/Dn4.mid'
		if ("Dn5")	soundfile = 'sound/trombone/Dn5.mid'
		if ("Dn6")	soundfile = 'sound/trombone/Dn6.mid'
		if ("Eb2")	soundfile = 'sound/trombone/Eb2.mid'
		if ("Eb3")	soundfile = 'sound/trombone/Eb3.mid'
		if ("Eb4")	soundfile = 'sound/trombone/Eb4.mid'
		if ("Eb5")	soundfile = 'sound/trombone/Eb5.mid'
		if ("Eb6")	soundfile = 'sound/trombone/Eb6.mid'
		if ("En2")	soundfile = 'sound/trombone/En2.mid'
		if ("En3")	soundfile = 'sound/trombone/En3.mid'
		if ("En4")	soundfile = 'sound/trombone/En4.mid'
		if ("En5")	soundfile = 'sound/trombone/En5.mid'
		if ("En6")	soundfile = 'sound/trombone/En6.mid'
		if ("Fn2")	soundfile = 'sound/trombone/Fn2.mid'
		if ("Fn3")	soundfile = 'sound/trombone/Fn3.mid'
		if ("Fn4")	soundfile = 'sound/trombone/Fn4.mid'
		if ("Fn5")	soundfile = 'sound/trombone/Fn5.mid'
		if ("Fn6")	soundfile = 'sound/trombone/Fn6.mid'
		if ("Gb2")	soundfile = 'sound/trombone/Gb2.mid'
		if ("Gb3")	soundfile = 'sound/trombone/Gb3.mid'
		if ("Gb4")	soundfile = 'sound/trombone/Gb4.mid'
		if ("Gb5")	soundfile = 'sound/trombone/Gb5.mid'
		if ("Gb6")	soundfile = 'sound/trombone/Gb6.mid'
		if ("Gn2")	soundfile = 'sound/trombone/Gn2.mid'
		if ("Gn3")	soundfile = 'sound/trombone/Gn3.mid'
		if ("Gn4")	soundfile = 'sound/trombone/Gn4.mid'
		if ("Gn5")	soundfile = 'sound/trombone/Gn5.mid'
		if ("Gn6")	soundfile = 'sound/trombone/Gn6.mid'
		else		return

	hearers(15, get_turf(src)) << sound(soundfile)

/obj/item/trombone/proc/playsong()
	do
		var/cur_oct[7]
		var/cur_acc[7]
		for (var/i = TRUE to 7)
			cur_oct[i] = "3"
			cur_acc[i] = "n"

		for (var/line in song.lines)
			//world << line
			for (var/beat in splittext(lowertext(line), ","))
				//world << "beat: [beat]"
				var/list/notes = splittext(beat, "/")
				for (var/note in splittext(notes[1], "-"))
					//world << "note: [note]"
					if (!playing || !isliving(loc))//If the trombone is playing, or isn't held by a person
						playing = FALSE
						return
					if (lentext(note) == FALSE)
						continue
					//world << "Parse: [copytext(note,1,2)]"
					var/cur_note = text2ascii(note) - 96
					if (cur_note < 1 || cur_note > 7)
						continue
					for (var/i=2 to lentext(note))
						var/ni = copytext(note,i,i+1)
						if (!text2num(ni))
							if (ni == "#" || ni == "b" || ni == "n")
								cur_acc[cur_note] = ni
							else if (ni == "s")
								cur_acc[cur_note] = "#" // so shift is never required
						else
							cur_oct[cur_note] = ni
					playnote(uppertext(copytext(note,1,2)) + cur_acc[cur_note] + cur_oct[cur_note])
				if (notes.len >= 2 && text2num(notes[2]))
					sleep(song.tempo / text2num(notes[2]))
				else
					sleep(song.tempo)
		if (repeat > 0)
			repeat-- //Infinite loops are baaaad.
	while (repeat > 0)
	playing = FALSE

/obj/item/trombone/attack_self(mob/user as mob)
	if (!isliving(user) || user.stat || user.restrained() || user.lying)	return
	user.set_using_object(src)

	var/dat = "<HEAD><TITLE>trombone</TITLE></HEAD><BODY>"

	if (song)
		if (song.lines.len > 0 && !(playing))
			dat += "<A href='?src=\ref[src];play=1'>Play Song</A><BR><BR>"
			dat += "<A href='?src=\ref[src];repeat=1'>Repeat Song: [repeat] times.</A><BR><BR>"
		if (playing)
			dat += "<A href='?src=\ref[src];stop=1'>Stop Playing</A><BR>"
			dat += "Repeats left: [repeat].<BR><BR>"
	if (!edit)
		dat += "<A href='?src=\ref[src];edit=2'>Show Editor</A><BR><BR>"
	else
		dat += "<A href='?src=\ref[src];edit=1'>Hide Editor</A><BR>"
		dat += "<A href='?src=\ref[src];newsong=1'>Start a New Song</A><BR>"
		dat += "<A href='?src=\ref[src];import=1'>Import a Song</A><BR><BR>"
		if (song)
			var/calctempo = (10/song.tempo)*60
			dat += "Tempo : <A href='?src=\ref[src];tempo=10'>-</A><A href='?src=\ref[src];tempo=1'>-</A> [calctempo] BPM <A href='?src=\ref[src];tempo=-1'>+</A><A href='?src=\ref[src];tempo=-10'>+</A><BR><BR>"
			var/linecount = FALSE
			for (var/line in song.lines)
				linecount += 1
				dat += "Line [linecount]: [line] <A href='?src=\ref[src];deleteline=[linecount]'>Delete Line</A> <A href='?src=\ref[src];modifyline=[linecount]'>Modify Line</A><BR>"
			dat += "<A href='?src=\ref[src];newline=1'>Add Line</A><BR><BR>"
		if (help)
			dat += "<A href='?src=\ref[src];help=1'>Hide Help</A><BR>"
			dat += {"
					Lines are a series of chords, separated by commas (,), each with notes seperated by hyphens (-).<br>
					Every note in a chord will play together, with chord timed by the tempo.<br>
					<br>
					Notes are played by the names of the note, and optionally, the accidental, and/or the octave number.<br>
					By default, every note is natural and in octave 3. Defining otherwise is remembered for each note.<br>
					Example: <i>C,D,E,F,G,A,B</i> will play a C major scale.<br>
					After a note has an accidental placed, it will be remembered: <i>C,C4,C,C3</i> is <i>C3,C4,C4,C3</i><br>
					Chords can be played simply by seperating each note with a hyphon: <i>A-C#,Cn-E,E-G#,Gn-B</i><br>
					A pause may be denoted by an empty chord: <i>C,E,,C,G</i><br>
					To make a chord be a different time, end it with /x, where the chord length will be length<br>
					defined by tempo / x: <i>C,G/2,E/4</i><br>
					Combined, an example is: <i>E-E4/4,/2,G#/8,B/8,E3-E4/4</i>
					<br>
					Lines may be up to [MAX_CHARS_PER_LINE] characters.<br>
					A song may only contain up to [MAX_CHARS_PER_LINE] lines.<br>
					"}
		else
			dat += "<A href='?src=\ref[src];help=2'>Show Help</A><BR>"
	dat += "</BODY></HTML>"
	user << browse(dat, "window=trombone;size=700x300")
	onclose(user, "trombone")

/obj/item/trombone/Topic(href, href_list)

	if (!in_range(src, usr) || !isliving(usr) || !usr.canmove || usr.restrained())
		usr << browse(null, "window=trombone;size=700x300")
		onclose(usr, "trombone")
		return

	if (href_list["newsong"])
		song = new()
	else if (song)
		if (href_list["repeat"]) //Changing this from a toggle to a number of repeats to avoid infinite loops.
			if (playing) return //So that people cant keep adding to repeat. If the do it intentionally, it could result in the server crashing.
			repeat = round(Clamp(WWinput(usr, "How many times do you want to repeat this piece? (maximum of 5 times)", "Repeats", 1, "num"), 0, 5))

		else if (href_list["tempo"])
			song.tempo += round(text2num(href_list["tempo"]))
			if (song.tempo < 1)
				song.tempo = TRUE

		else if (href_list["play"])
			if (song)
				playing = TRUE
				spawn() playsong()

		else if (href_list["newline"])
			var/newline = rhtml_encode(input("Enter your line: ", "trombone") as text|null)
			if (!newline)
				return
			if (song.lines.len > MAX_CHARS_PER_LINE)
				return
			if (lentext(newline) > MAX_CHARS_PER_LINE)
				newline = copytext(newline, TRUE, MAX_CHARS_PER_LINE)
			song.lines.Add(newline)

		else if (href_list["deleteline"])
			var/num = round(text2num(href_list["deleteline"]))
			if (num > song.lines.len || num < 1)
				return
			song.lines.Cut(num, num+1)

		else if (href_list["modifyline"])
			var/num = round(text2num(href_list["modifyline"]),1)
			var/content = rhtml_encode(input("Enter your line: ", "trombone", song.lines[num]) as text|null)
			if (!content)
				return
			if (lentext(content) > MAX_CHARS_PER_LINE)
				content = copytext(content, TRUE, MAX_CHARS_PER_LINE)
			if (num > song.lines.len || num < 1)
				return
			song.lines[num] = content

		else if (href_list["stop"])
			playing = FALSE

		else if (href_list["help"])
			help = text2num(href_list["help"]) - 1

		else if (href_list["edit"])
			edit = text2num(href_list["edit"]) - 1

		else if (href_list["import"])
			var/t = ""
			do
				t = rhtml_encode(input(usr, "Please paste the entire song, formatted:", text("[]", name), t)  as message)
				if (!in_range(src, usr))
					return

				if (lentext(t) >= MAX_CHARS_TOTAL)
					var/cont = WWinput(usr, "Your song is too long! Would you like to continue editing it?", "Error", "Yes", list("Yes", "No"))
					if (cont == "No")
						break
			while (lentext(t) > MAX_CHARS_TOTAL)

			//split into lines
			spawn()
				var/list/lines = splittext(t, "\n")
				var/tempo = 5
				if (copytext(lines[1],1,6) == "BPM: ")
					tempo = 600 / text2num(copytext(lines[1],6))
					lines.Cut(1,2)
				if (lines.len > MAX_CHARS_PER_LINE)
					usr << "Too many lines!"
					lines.Cut(MAX_CHARS_PER_LINE+1)
				var/linenum = TRUE
				for (var/l in lines)
					if (lentext(l) > MAX_CHARS_PER_LINE)
						usr << "Line [linenum] too long!"
						lines.Remove(l)
					else
						linenum++
				song = new()
				song.lines = lines
				song.tempo = tempo

	add_fingerprint(usr)
	for (var/mob/M in viewers(1, loc))
		if ((M.client && M.using_object == src))
			attack_self(M)
	return

