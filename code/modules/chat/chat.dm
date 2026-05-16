/**
 * Chat module for browser-based chat interface.
 */

/client
	var/datum/chat/chat
	var/obj/screen/lobby_image/lobby_image_obj

/datum/chat
	var/client/client
	var/is_ready = FALSE
	var/list/message_queue = list()

/datum/chat/New(client/C)
	src.client = C

/datum/chat/proc/load()
	if (!client)
		return
	
	client << browse_rsc('code/js/purify.min.js', "purify.min.js")
	client << browse_rsc('interface/fonts/Alegreya-Regular.ttf', "Alegreya-Regular.ttf")
	client << browse_rsc('interface/fonts/Alegreya-Bold.ttf', "Alegreya-Bold.ttf")
	client << browse_rsc('interface/fonts/Alegreya-Italic.ttf', "Alegreya-Italic.ttf")
	client << browse_rsc('interface/fonts/Alegreya-BoldItalic.ttf', "Alegreya-BoldItalic.ttf")
	client << browse_rsc('interface/fonts/Alegreya-Black.ttf', "Alegreya-Black.ttf")
	
	// No longer sending individual CSS/JS as they are inlined for reliability
	client << browse('interface/chat/chat.html', "window=browser_chat")
	// world.log << "DEBUG: Chat loading for [client.ckey]"

/datum/chat/proc/on_ready()
	is_ready = TRUE
	for (var/message in message_queue)
		send_message(message)
	message_queue.Cut()

#define MAX_CHAT_QUEUE 200

/proc/extract_json_message(var/text_string)
    // Make sure we actually have a string to work with
    if(!istext(text_string))
        return text_string

    var/prefix = "{\"message\":"
    var/prefix_len = length(prefix)

    // Check if the string starts with {"message":
    // copytext() end-index is exclusive, so we add 1 to the length
    if(copytext(text_string, 1, prefix_len + 1) == prefix)
        text_string = copytext(text_string, prefix_len + 1)

    // Check if the string ends with }
    // Modern BYOND & OpenDream allow negative indexing to grab from the end
    if(copytext(text_string, -1) == "}")
        text_string = copytext(text_string, 1, -1)

    return text_string

/datum/chat/proc/send_message(message)
	if (!client)
		return
	
	if (!is_ready)
		if (message_queue.len >= MAX_CHAT_QUEUE)
			message_queue.Cut(1, 2) // drop oldest
		message_queue += message
		return

	// Escape message for JS
	var/escaped_message = extract_json_message(message)
	client << output(url_encode(escaped_message), "browser_chat:receiveMessage")

//this skips sanitisation so make sure you use it on safe html ONLY
//DO NOT use this for player inputs!
/datum/chat/proc/send_message_html(message)
	if (!client)
		return
	
	if (!is_ready)
		if (message_queue.len >= MAX_CHAT_QUEUE)
			message_queue.Cut(1, 2) // drop oldest
		message_queue += message
		return

	client << output("[url_encode(message)];1", "browser_chat:receiveMessage")



/**
 * Global chat wrapper to replace the to_chat macro functionality.
 */
/proc/to_chat_wrapper(target, message)
	if (!target || !message)
		return

	if (istype(target, /client))
		var/client/C = target
		if (C.chat)
			C.chat.send_message(message)
		else
			C << message
			world.log << "to_chat_wrapper: [C.ckey] has no chat datum, message dropped: [message]"
		return

	if (istype(target, /mob))
		var/mob/M = target
		if (M.client)
			to_chat_wrapper(M.client, message)
		else
			// Fallback for mobs without clients (logs or similar)
			M << message
		return

	if (istype(target, /list))
		for (var/T in target)
			to_chat_wrapper(T, message)
		return

	if (target == world)
		for (var/client/C in clients)
			to_chat_wrapper(C, message)
		return

	// Final fallback
	target << message
