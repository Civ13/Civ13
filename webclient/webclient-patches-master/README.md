# Deprecation Notice
This project is no longer being used in production on yogstation. As such, it has been deprecated and is no longer maintained.

# Webclient Patches

A library to patch webclient-related functionality in Dream Daemon

## What does this patch?

- Fixes the webclient protocol to send movable-change messages where the LSB of the movable object ID is not clobbered by the vis_contents bit by expanding the flags field to two bytes. Note that this requires a modified webclient to work properly.
- Patches webclient authentication code to do authentication without the BYOND hub to work around the broken webclient authentication system

## Usage

```dm
/datum/world_topic/webclient_login
	keyword = "webclient_login_token"
	require_comms_key = TRUE

/datum/world_topic/webclient_login/Run(list/input)
	var/token = input["webclient_login_token"]
	var/info = input["webclient_login_info"]
	if(fexists(WEBCLIENT_PATCHES))
		var/result = call(WEBCLIENT_PATCHES, "set_webclient_auth")(token, info)
		if(result)
			log_world("webclient_patches error: [result]")

/world/Del()
	if(fexists(WEBCLIENT_PATCHES))
		call(WEBCLIENT_PATCHES, "remove_webclient_patches")()
	..()
```
