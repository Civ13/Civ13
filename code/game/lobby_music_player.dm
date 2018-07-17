/* for backend reasons, any songs here should not contain ':' in the title
   only the end of the title should contain :1, or :2, representing the
   relative probability of that song */

/datum/lobby_music_player
	var/song_title = null
    // format is 'title:probability_multiplier = ogg'
	var/list/songs = list() // see map_metadata.dm


/datum/lobby_music_player/New()
	..()
	choose_song()

/datum/lobby_music_player/proc/choose_song()

	if (map)
		songs = map.songs.Copy()

	/* for some reason byond is horrible with randomness and overwhelmingly
	 * plays the first few songs in the list. The solution is randomizing the list
	 * - Kachnov */

	var/last_song_title = song_title
	var/list/random_order_songs = shuffle(songs)
	var/default_prob = ceil(100/songs.len)

	for (var/title_mult in random_order_songs)
		var/split_title_mult = splittext(title_mult, ":")
		var/multiplier = (text2num(split_title_mult[2]) || 1)
		if (prob(default_prob * multiplier))
			song_title = title_mult // yes, not title
			break

	// somehow we have no song, pick a random one
	if (!song_title)
		song_title = pick(random_order_songs)

	// don't play the same song as before
	while (song_title == last_song_title)
		song_title = pick(random_order_songs)

/datum/lobby_music_player/proc/announce(var/client/client)
	client << "<span class = 'notice'><font size = 2>Now playing <b>[splittext(song_title, ":")[1]]</b></font></span>"

/datum/lobby_music_player/proc/get_song()
	return songs[song_title]