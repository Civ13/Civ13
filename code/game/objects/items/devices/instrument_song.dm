// Shared song player and editor for the piano, violin, shamisen and trumpet.
// Each instrument keeps song, playing, help, edit and repeat vars and its own
// playnote(note) sound table. A structure plays while anchored; a held
// instrument plays while a living mob carries it.

/datum/song
	var/name = "Untitled"
	var/list/lines = new()
	var/tempo = 5

/proc/instrument_ready(obj/I, atom/holder)
	if (istype(I, /obj/structure))
		return I.anchored
	return isliving(holder)

// Redraws the song panel for everyone using the instrument.
/proc/instrument_refresh(obj/I)
	if (istype(I, /obj/structure))
		I.updateUsrDialog()
		return
	var/obj/item/held = I
	for (var/mob/M in viewers(1, I.loc))
		if (M.client && M.using_object == I)
			held.attack_self(M)

/proc/instrument_playsong(obj/I)
	var/datum/song/song = I:song
	do
		var/cur_oct[7]
		var/cur_acc[7]
		for (var/i = TRUE to 7)
			cur_oct[i] = "3"
			cur_acc[i] = "n"

		for (var/line in song.lines)
			for (var/beat in splittext(lowertext(line), ","))
				var/list/notes = splittext(beat, "/")
				if (!notes || !notes.len)
					return
				for (var/note in splittext(notes[1], "-"))
					if (!I:playing || !instrument_ready(I, I.loc))
						I:playing = FALSE
						return
					if (length(note) == FALSE)
						continue
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
					I:playnote(uppertext(copytext(note,1,2)) + cur_acc[cur_note] + cur_oct[cur_note])
				if (notes.len >= 2 && text2num(notes[2]))
					sleep(song.tempo / text2num(notes[2]))
				else
					sleep(song.tempo)
		if (I:repeat > 0)
			I:repeat-- //Infinite loops are baaaad.
	while (I:repeat > 0)
	I:playing = FALSE
	if (istype(I, /obj/structure))
		I.updateUsrDialog()

/proc/instrument_panel(obj/I, mob/user, title, window, max_lines)
	var/datum/song/song = I:song
	var/dat = "<HEAD><TITLE>[title]</TITLE></HEAD><BODY>"

	if (song)
		if (song.lines.len > 0 && !(I:playing))
			dat += "<A href='?src=\ref[I];play=1'>Play Song</A><BR><BR>"
			dat += "<A href='?src=\ref[I];repeat=1'>Repeat Song: [I:repeat] times.</A><BR><BR>"
		if (I:playing)
			dat += "<A href='?src=\ref[I];stop=1'>Stop Playing</A><BR>"
			dat += "Repeats left: [I:repeat].<BR><BR>"
	if (!I:edit)
		dat += "<A href='?src=\ref[I];edit=2'>Show Editor</A><BR><BR>"
	else
		dat += "<A href='?src=\ref[I];edit=1'>Hide Editor</A><BR>"
		dat += "<A href='?src=\ref[I];newsong=1'>Start a New Song</A><BR>"
		dat += "<A href='?src=\ref[I];import=1'>Import a Song</A><BR><BR>"
		if (song)
			var/calctempo = (10/song.tempo)*60
			dat += "Tempo : <A href='?src=\ref[I];tempo=10'>-</A><A href='?src=\ref[I];tempo=1'>-</A> [calctempo] BPM <A href='?src=\ref[I];tempo=-1'>+</A><A href='?src=\ref[I];tempo=-10'>+</A><BR><BR>"
			var/linecount = FALSE
			for (var/line in song.lines)
				linecount += 1
				dat += "Line [linecount]: [line] <A href='?src=\ref[I];deleteline=[linecount]'>Delete Line</A> <A href='?src=\ref[I];modifyline=[linecount]'>Modify Line</A><BR>"
			dat += "<A href='?src=\ref[I];newline=1'>Add Line</A><BR><BR>"
		if (I:help)
			dat += "<A href='?src=\ref[I];help=1'>Hide Help</A><BR>"
			dat += {"
					Lines are a series of chords, separated by commas (,), each with notes separated by hyphens (-).<br>
					Every note in a chord will play together, with chord timed by the tempo.<br>
					<br>
					Notes are played by the names of the note, and optionally, the accidental, and/or the octave number.<br>
					By default, every note is natural and in octave 3. Defining otherwise is remembered for each note.<br>
					Example: <i>C,D,E,F,G,A,B</i> will play a C major scale.<br>
					After a note has an accidental placed, it will be remembered: <i>C,C4,C,C3</i> is <i>C3,C4,C4,C3</i><br>
					Chords can be played simply by separating each note with a hyphon: <i>A-C#,Cn-E,E-G#,Gn-B</i><br>
					A pause may be denoted by an empty chord: <i>C,E,,C,G</i><br>
					To make a chord be a different time, end it with /x, where the chord length will be length<br>
					defined by tempo / x: <i>C,G/2,E/4</i><br>
					Combined, an example is: <i>E-E4/4,/2,G#/8,B/8,E3-E4/4</i>
					<br>
					Lines may be up to [MAX_CHARS_PER_LINE] characters.<br>
					A song may only contain up to [max_lines] lines.<br>
					"}
		else
			dat += "<A href='?src=\ref[I];help=2'>Show Help</A><BR>"
	dat += "</BODY></HTML>"
	show_browse(user, dat, "window=[window];size=700x300")
	onclose(user, window)

/proc/instrument_topic(obj/I, mob/user, list/href_list, title, window, max_lines)
	if (!in_range(I, user) || !instrument_ready(I, user) || !user.canmove || user.restrained())
		show_browse(user, null, "window=[window];size=700x300")
		onclose(user, window)
		return

	var/datum/song/song = I:song
	if (href_list["newsong"])
		I:song = new /datum/song
	else if (song)
		if (href_list["repeat"]) //Changing this from a toggle to a number of repeats to avoid infinite loops.
			if (I:playing) return //So that people can't keep adding to repeat. If the do it intentionally, it could result in the server crashing.
			I:repeat = round(Clamp(WWinput(user, "How many times do you want to repeat this piece? (maximum of 5 times)", "Repeats", 1, "num"), 0, 5))

		else if (href_list["tempo"])
			song.tempo += round(text2num(href_list["tempo"]))
			if (song.tempo < 1)
				song.tempo = TRUE

		else if (href_list["play"])
			I:playing = TRUE
			spawn() instrument_playsong(I)

		else if (href_list["newline"])
			var/newline = html_encode(player_input(user, "Enter your line: ", title, null, "text", null, TRUE))
			if (!newline)
				return
			if (song.lines.len > max_lines)
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
			var/content = html_encode(player_input(user, "Enter your line: ", title, song.lines[num], "text", null, TRUE))
			if (!content)
				return
			if (length(content) > MAX_CHARS_PER_LINE)
				content = copytext(content, TRUE, MAX_CHARS_PER_LINE)
			if (num > song.lines.len || num < 1)
				return
			song.lines[num] = content

		else if (href_list["stop"])
			I:playing = FALSE

		else if (href_list["help"])
			I:help = text2num(href_list["help"]) - 1

		else if (href_list["edit"])
			I:edit = text2num(href_list["edit"]) - 1

		else if (href_list["import"])
			var/t = ""
			do
				t = html_encode(player_input(user, "Please paste the entire song, formatted:", text("[]", I.name), t, "message", null, FALSE))
				if (!in_range(I, user))
					return

				if (length(t) >= MAX_CHARS_TOTAL)
					var/cont = WWinput(user, "Your song is too long! Would you like to continue editing it?", "Error", "Yes", list("Yes", "No"))
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
				if (lines.len > max_lines)
					to_chat(user, "Too many lines!")
					lines.Cut(max_lines+1)
				var/linenum = TRUE
				for (var/l in lines)
					if (length(l) > MAX_CHARS_PER_LINE)
						to_chat(user, "Line [linenum] too long!")
						lines.Remove(l)
					else
						linenum++
				var/datum/song/imported = new /datum/song
				imported.lines = lines
				imported.tempo = tempo
				I:song = imported
				instrument_refresh(I)

	I.add_fingerprint(user)
	instrument_refresh(I)
