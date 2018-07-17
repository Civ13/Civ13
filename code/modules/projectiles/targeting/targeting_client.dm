//These are called by the on-screen buttons, adjusting what the victim can and cannot do.
/client/proc/add_gun_icons()
	if (!usr) return TRUE // This can runtime if someone manages to throw a gun out of their hand before the proc is called.
	for (var/obj/screen/gun/G in screen)
		if (list(/obj/screen/gun/radio,
			/obj/screen/gun/move,
			/obj/screen/gun/item).Find(G.type))
			G.invisibility = 0

/client/proc/remove_gun_icons()
	if (!usr) return TRUE // Runtime prevention on N00k agents spawning with SMG
	for (var/obj/screen/gun/G in screen)
		if (list(/obj/screen/gun/radio,
			/obj/screen/gun/move,
			/obj/screen/gun/item).Find(G.type))
			G.invisibility = 101