// Isolated OpenDream journal fixture only. OpenPort cannot control Robust sockets.
/world
	maxx = 1
	maxy = 1
	maxz = 1
	sleep_offline = 0

/world/OpenPort(port)
	return FALSE

/world/New()
	spawn(0)
		// Bounded startup-only handshake, identical for all five cases.
		// Original store assertions run only after external console/socket readback.
		for (var/store_startup_tick in 1 to 100)
			if (fexists("store-startup.go"))
				if (file2text("store-startup.go") == "EXTRACTION_STORE_GO_V2\n")
					store_fixture_body()
					return
				break
			sleep(1)
		text2file("FAIL: startup readiness handshake", "result.txt")
		shutdown()

/proc/store_startup_finish()
	shutdown()
