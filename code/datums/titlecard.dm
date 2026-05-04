var/global/pregameHTML = null

/datum/titlecard
	var/global/list/maptext_areas = list()
	var/global/last_pregame_html = ""

	var/image_url = "civ13.png"

	var/is_game_mode = FALSE
	var/add_html = ""
	var/pixelated = TRUE


/datum/titlecard/proc/set_pregame_html()
	var/html = {"<!doctype html><html><head>
	<title>Civilization 13 - Pregame</title>
	<meta charset="utf-8">
	<style>
		body {
			width: 100%;
			height: 100%;
			margin: 0;
			padding: 0;
			background: black;
			overflow: hidden;
		}

		#main-img {
			z-index: -2;
			position: fixed;
			left: 50%;
			top: 50%;
			transform: translate(-50%, -50%);
			width: 100%;
			height: 100%;
			object-fit: cover;
		}

		.area {
			display: none;
			white-space: pre;
			color: #fff;
			text-shadow:
				-2px -2px 0px #000,
				2px -2px 0px #000,
				-2px 2px 0px #000,
				2px 2px 0px #000,
				2px 0px 0px #000,
				-2px 0px 0px #000,
				0px 2px 0px #000,
				0px -2px 0px #000;
			/**font: 1em 'PxPlus IBM VGA9';**/
		}

		a {
			text-decoration: none;
		}

	</style>
</head>

<body oncontextmenu="return false">
	<script>
		document.onclick = () => {
			location = 'byond://winset?id=mapwindow.map&focus=true';
		};
		function set_area(id, text) {
			var el = document.getElementById(id);
			el.innerHTML = text || '';
			el.style.display = text ? 'block' : 'none';
		}
	</script>

	<img id="main-img" src="[src.image_url]" style="[src.pixelated ? "image-rendering: pixelated;" : ""]">
	[src.add_html]</body></html>"}

	last_pregame_html = html
	pregameHTML = last_pregame_html
	if (config && config.opendream)
		for (var/client/C)
			if (C && isnewplayer(C.mob))
				C.load_pregame()

/client/proc/load_pregame()
	if (config && config.opendream)
		if (!pregameHTML || !src) return
		src << browse(pregameHTML, "window=pregameBrowser")
		winshow(src, "pregameBrowser", TRUE)

		if (isnewplayer(src.mob))
			var/mob/new_player/new_player = src.mob
			new_player.pregameBrowserLoaded = TRUE

/client/proc/unload_pregame()
	src << browse("", "window=pregameBrowser")
	winshow(src, "pregameBrowser", FALSE)