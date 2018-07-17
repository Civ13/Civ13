#define LOGMODULE_SUCCESS return TRUE
#define LOGMODULE_FAILURE return TRUE

var/list/admin_modules = list()

/admin_module
	parent_type = /datum
	var/list/perms = list()
	var/name = "Admin Module"
	var/desc = ""
	var/category = "Misc"

/admin_module/proc/called_behavior(var/client/caller)
	. = FALSE
	if (caller.holder)
		for (var/perm in perms)
			if (caller.holder.rights & perm)
				. = TRUE
	if (.)
		called(caller)
		LOGMODULE_SUCCESS
	else
		LOGMODULE_FAILURE

/admin_module/Topic(href,href_list[])
	if (href_list["call"])
		if (href_list["client"])
			called_behavior(locate(href_list["client"]))

/admin_module/test
	perms = list(R_ADMIN)
	name = "Test Module"
	desc = "Displays a test message to the world"
	category = "Misc"

/admin_module/test/called(var/client/caller)
	world << "[caller] test message"

/client/verb/adminpanel()
	if (!admin_modules.len)
		for (var/mtype in typesof(/admin_module) - /admin_module)
			admin_modules += new mtype
	var/text = "<center>Admin Modules</center>"
	for (var/admin_module/AM in admin_modules)
		text += "<br>[AM.name]: [AM.desc] (<a href='byond://?src=\ref[AM];call=1;client=\ref[src]'>Call</a>)"
	src << browse(text, "window=adminmodules;")