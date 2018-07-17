// This file is a modified version of https://raw2.github.com/Baystation12/OldCode-BS12/master/code/TakePicture.dm

#define NANOMAP_ICON_SIZE 4
#define NANOMAP_MAX_ICON_DIMENSION 1024

#define NANOMAP_TILES_PER_IMAGE (NANOMAP_MAX_ICON_DIMENSION / NANOMAP_ICON_SIZE)

#define NANOMAP_TERMINALERR 5
#define NANOMAP_INPROGRESS 2
#define NANOMAP_BADOUTPUT 2
#define NANOMAP_SUCCESS TRUE
#define NANOMAP_WATCHDOGSUCCESS 4
#define NANOMAP_WATCHDOGTERMINATE 3


//Call these procs to dump your world to a series of image files (!!)
//NOTE: Does not explicitly support non 32x32 icons or stuff with large pixel_* values, so don't blame me if it doesn't work perfectly

/client/proc/nanomapgen_DumpImage()
	set name = "Generate NanoUI Map"
	set category = "Server"

	if (holder)
		nanomapgen_DumpTile(1, TRUE, text2num(input(usr,"Enter the Z level to generate")))

/client/proc/nanomapgen_DumpTile(var/startX = TRUE, var/startY = TRUE, var/currentZ = TRUE, var/endX = -1, var/endY = -1)

	if (endX < 0 || endX > world.maxx)
		endX = world.maxx

	if (endY < 0 || endY > world.maxy)
		endY = world.maxy

	if (currentZ < 0 || currentZ > world.maxz)
		usr << "NanoMapGen: <b>ERROR: currentZ ([currentZ]) must be between TRUE and [world.maxz]</b>"

		sleep(3)
		return NANOMAP_TERMINALERR

	if (startX > endX)
		usr << "NanoMapGen: <b>ERROR: startX ([startX]) cannot be greater than endX ([endX])</b>"

		sleep(3)
		return NANOMAP_TERMINALERR

	if (startY > endX)
		usr << "NanoMapGen: <b>ERROR: startY ([startY]) cannot be greater than endY ([endY])</b>"
		sleep(3)
		return NANOMAP_TERMINALERR

	var/icon/Tile = icon(file("UI/mapbase1024.png"))
	if (Tile.Width() != NANOMAP_MAX_ICON_DIMENSION || Tile.Height() != NANOMAP_MAX_ICON_DIMENSION)
		world.log << "NanoMapGen: <b>ERROR: BASE IMAGE DIMENSIONS ARE NOT [NANOMAP_MAX_ICON_DIMENSION]x[NANOMAP_MAX_ICON_DIMENSION]</b>"
		sleep(3)
		return NANOMAP_TERMINALERR

	world.log << "NanoMapGen: <b>GENERATE MAP ([startX],[startY],[currentZ]) to ([endX],[endY],[currentZ])</b>"
	usr << "NanoMapGen: <b>GENERATE MAP ([startX],[startY],[currentZ]) to ([endX],[endY],[currentZ])</b>"

	var/count = FALSE;
	for (var/WorldX = startX, WorldX <= endX, WorldX++)
		for (var/WorldY = startY, WorldY <= endY, WorldY++)

			var/atom/Turf = locate(WorldX, WorldY, currentZ)

			var/icon/TurfIcon = new(Turf.icon, Turf.icon_state, dir = Turf.dir)
			TurfIcon.Scale(NANOMAP_ICON_SIZE, NANOMAP_ICON_SIZE)

			Tile.Blend(TurfIcon, ICON_OVERLAY, ((WorldX - 1) * NANOMAP_ICON_SIZE), ((WorldY - 1) * NANOMAP_ICON_SIZE))

			count++

			if (count % 8000 == FALSE)
				world.log << "NanoMapGen: <b>[count] tiles done</b>"
				sleep(1)

	var/mapFilename = "nanomap_z[currentZ]-new.png"

	world.log << "NanoMapGen: <b>sending [mapFilename] to client</b>"

	usr << browse(Tile, "window=picture;file=[mapFilename];display=0")

	world.log << "NanoMapGen: <b>Done.</b>"

	usr << "NanoMapGen: <b>Done. File [mapFilename] uploaded to your cache.</b>"

	if (Tile.Width() != NANOMAP_MAX_ICON_DIMENSION || Tile.Height() != NANOMAP_MAX_ICON_DIMENSION)
		return NANOMAP_BADOUTPUT

	return NANOMAP_SUCCESS