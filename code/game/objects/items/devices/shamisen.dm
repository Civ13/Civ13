/obj/item/shamisen
	name = "Shamisen"
	desc = "A japanese shamisen."
	icon = 'icons/obj/musician.dmi'
	icon_state = "shamisen"
	item_state = "shamisen"
	force = WEAPON_FORCE_PAINFUL
	var/datum/song/song
	var/playing = FALSE
	var/help = FALSE
	var/edit = TRUE
	var/repeat = FALSE
	flammable = TRUE
	value = 0

/obj/item/shamisen/proc/playnote(var/note as text)
	//world << "Note: [note]"
	var/soundfile
	/*BYOND loads resource files at compile time if they are ''. This means you can't really manipulate them dynamically.
	Tried doing it dynamically at first but its more trouble than its worth. Would have saved many lines tho.*/
	switch(note)
		if ("A#2")	soundfile = 'sound/shamisen/shamisen A#2.ogg'
		if ("A#3")	soundfile = 'sound/shamisen/shamisen A#3.ogg'
		if ("A#4")	soundfile = 'sound/shamisen/shamisen A#4.ogg'
		if ("A#6")	soundfile = 'sound/shamisen/shamisen A#6.ogg'
		if ("A#8")	soundfile = 'sound/shamisen/shamisen A#8.ogg'
		if ("Ab2")	soundfile = 'sound/shamisen/shamisen Ab2.ogg'
		if ("B#2")	soundfile = 'sound/shamisen/shamisen B#2.ogg'
		if ("C#2")	soundfile = 'sound/shamisen/shamisen C#2.ogg'
		if ("C#4")	soundfile = 'sound/shamisen/shamisen C#4.ogg'
		if ("C#5")	soundfile = 'sound/shamisen/shamisen C#5.ogg'
		if ("Cb2")	soundfile = 'sound/shamisen/shamisen Cb2.ogg'
		if ("Cb4")	soundfile = 'sound/shamisen/shamisen Cb4.ogg'
		if ("Cb5")	soundfile = 'sound/shamisen/shamisen Cb5.ogg'
		if ("D#3")	soundfile = 'sound/shamisen/shamisen D#3.ogg'
		if ("D#5")	soundfile = 'sound/shamisen/shamisen D#5.ogg'
		if ("D#8")	soundfile = 'sound/shamisen/shamisen D#8.ogg'
		if ("Db2")	soundfile = 'sound/shamisen/shamisen Db2.ogg'
		if ("Db4")	soundfile = 'sound/shamisen/shamisen Db4.ogg'
		if ("Eb2")	soundfile = 'sound/shamisen/shamisen Eb2.ogg'
		if ("En5")	soundfile = 'sound/shamisen/shamisen En5.ogg'
		if ("En6")	soundfile = 'sound/shamisen/shamisen En6.ogg'
		if ("En7")	soundfile = 'sound/shamisen/shamisen En7.ogg'
		if ("F#2")	soundfile = 'sound/shamisen/shamisen F#2.ogg'
		if ("F#4")	soundfile = 'sound/shamisen/shamisen F#4.ogg'
		if ("F#6")	soundfile = 'sound/shamisen/shamisen F#6.ogg'
		if ("Fb2")	soundfile = 'sound/shamisen/shamisen Fb2.ogg'
		if ("Fb4")	soundfile = 'sound/shamisen/shamisen Fb4.ogg'
		else		return

	hearers(15, get_turf(src)) << sound(soundfile)

/obj/item/shamisen/proc/playsong()
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
				if (!notes.len)
					return
				for (var/note in splittext(notes[1], "-"))
					//world << "note: [note]"
					if (!playing || !isliving(loc))//If the shamisen is playing, or isn't held by a person
						playing = FALSE
						return
					if (length(note) == FALSE)
						continue
					//world << "Parse: [copytext(note,1,2)]"
					var/cur_note = text2ascii(note) - 96
					if (cur_note < 1 || cur_note > 7)
						continue
					for (var/i=2 to length(note))
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

/obj/item/shamisen/attack_self(mob/user as mob)
	if (!isliving(user) || user.stat || user.restrained() || user.lying)	return
	user.set_using_object(src)

	var/dat = "<HEAD><TITLE>Shamisen</TITLE></HEAD><BODY>"

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
	user << browse(dat, "window=shamisen;size=700x300")
	onclose(user, "shamisen")

/obj/item/shamisen/Topic(href, href_list)

	if (!in_range(src, usr) || !isliving(usr) || !usr.canmove || usr.restrained())
		usr << browse(null, "window=shamisen;size=700x300")
		onclose(usr, "shamisen")
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
			var/newline = html_encode(input("Enter your line: ", "shamisen") as text|null)
			if (!newline)
				return
			if (song.lines.len > MAX_CHARS_PER_LINE)
				return
			if (length(newline) > MAX_CHARS_PER_LINE)
				newline = copytext(newline, TRUE, MAX_CHARS_PER_LINE)
			song.lines.Add(newline)

		else if (href_list["deleteline"])
			var/num = round(text2num(href_list["deleteline"]))
			if (num > song.lines.len || num < 1)
				return
			song.lines.Cut(num, num+1)

		else if (href_list["modifyline"])
			var/num = round(text2num(href_list["modifyline"]),1)
			var/content = html_encode(input("Enter your line: ", "shamisen", song.lines[num]) as text|null)
			if (!content)
				return
			if (length(content) > MAX_CHARS_PER_LINE)
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
				t = html_encode(input(usr, "Please paste the entire song, formatted:", text("[]", name), t)  as message)
				if (!in_range(src, usr))
					return

				if (length(t) >= MAX_CHARS_TOTAL)
					var/cont = WWinput(usr, "Your song is too long! Would you like to continue editing it?", "Error", "Yes", list("Yes", "No"))
					if (cont == "No")
						break
			while (length(t) > MAX_CHARS_TOTAL)

			//split into lines
			spawn()
				var/list/lines = splittext(t, "\n")
				var/tempo = 5
				if (!lines || !lines.len)
					return
				if (copytext(lines[1],1,6) == "BPM: " && text2num(copytext(lines[1],6)))
					tempo = 600 / text2num(copytext(lines[1],6))
					lines.Cut(1,2)
				if (lines.len > MAX_CHARS_PER_LINE)
					usr << "Too many lines!"
					lines.Cut(MAX_CHARS_PER_LINE+1)
				var/linenum = TRUE
				for (var/l in lines)
					if (length(l) > MAX_CHARS_PER_LINE)
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
