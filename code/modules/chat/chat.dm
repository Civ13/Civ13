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
	var/tmp/list/examine_lines
	var/tmp/examine_delivery = 0
	var/tmp/examine_delivery_scope

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
	client << browse_rsc('interface/fonts/Wizard.ttf', "Wizard.ttf")
	client << browse_rsc('interface/fonts/Grand9K_Pixel.ttf', "Grand9K_Pixel.ttf")
	
	// No longer sending individual CSS/JS as they are inlined for reliability
	show_browse(client, 'interface/chat/chat.html', "window=browser_chat")
	// world.log << "DEBUG: Chat loading for [client.ckey]"

/datum/chat/proc/on_ready()
	is_ready = TRUE
	// The page keeps recent chat under the ckey and puts it back here, so
	// moving to another region (a new world, a fresh page) keeps the history.
	// Sent before the queued messages so they land below the restored lines.
	client << output(client.ckey, "browser_chat:setChatIdentity")
	for (var/message in message_queue)
		send_message(message)
	message_queue.Cut()
	// Only consume durable notices after the admitted client's chat is ready.
	persistence_deliver_bed_notice(client)
	// Start the page's connection watchdog (pings every 5 s, warns after 20 s
	// without an answer). The server cannot report its own death to the chat.
	client << output("5000", "browser_chat:startChatHeartbeat")
	chat_translator.announce(client)

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

/datum/chat/proc/flush_examine()
	var/list/lines = examine_lines
	examine_lines = null
	for (var/line in lines)
		send_message(line)

/datum/chat/proc/send_message(message)
	if (examine_lines)
		flush_examine()
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

// The structured packet preserves the original line and sanitization boundaries.
/datum/chat/proc/send_examine(list/lines)
	if (!client || lines.len > 32)
		return FALSE
	var/list/normalized = list()
	for (var/line in lines)
		normalized += "[extract_json_message(line)]"
	// Oversized examines keep their original per-line delivery.
	// A browser page can survive a handover or restart; scope IDs to this chat.
	if (!examine_delivery_scope)
		examine_delivery_scope = md5("[world.realtime]-[rand(1, 1000000)]-\ref[src]")
	var/payload = url_encode(json_encode(list("id" = "[examine_delivery_scope]:[examine_delivery + 1]", "lines" = normalized)))
	if (length(payload) > 16000)
		return FALSE
	examine_delivery++
	client << output(payload, "browser_chat:receiveExamine")
	return TRUE

//this skips sanitisation so make sure you use it on safe html ONLY
//DO NOT use this for player inputs!
/datum/chat/proc/send_message_html(message)
	if (examine_lines)
		flush_examine()
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
/proc/to_chat_wrapper(target, message, direct = TRUE)
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
		if (agent_characters.len)
			var/datum/agent_character/AC = agent_characters[M]
			if (AC)
				AC.capture(message)
		if (istype(M, /mob/agent_proxy))
			var/mob/agent_proxy/P = M
			P.capture(message)
			return
		if (M.client)
			var/datum/chat/C = M.client.chat
			if (direct && C?.examine_lines)
				C.examine_lines += message
			else
				to_chat_wrapper(M.client, message)
		else
			// Fallback for mobs without clients (logs or similar)
			M << message
		return

	if (istype(target, /list))
		for (var/T in target)
			to_chat_wrapper(T, message, FALSE)
		return

	if (target == world)
		for (var/client/C in clients)
			to_chat_wrapper(C, message)
		return

	// Final fallback
	target << message
