/**
 * Chat module for browser-based chat interface.
 */
var/global/chat_style = {"
	<style>

		body {
			background-color: #392611;
			color: #e1e1d7;
			font-family: "Book Antiqua", "Bookman Old Style", serif;
			text-rendering: optimizeLegibility;
			-webkit-font-smoothing: antialiased;
			-moz-osx-font-smoothing: grayscale;
			font-size: 14px;
			margin: 0;
			padding: 0;
			overflow: hidden;
			height: 100vh;
		}

		#chat-container {
			height: 100%;
			padding: 8px;
			box-sizing: border-box;
			overflow-y: scroll;
			scrollbar-face-color: #a68b7d;
			scrollbar-shadow-color: #271a0c;
			scrollbar-highlight-color: #e1e1d7;
			scrollbar-3dlight-color: #a68b7d;
			scrollbar-darkshadow-color: #000000;
			scrollbar-track-color: #392611;
			scrollbar-arrow-color: #271a0c;
		}

		/* Modern scrollbar for Chromium-based BYOND */
		#chat-container::-webkit-scrollbar {
			width: 12px;
		}

		#chat-container::-webkit-scrollbar-track {
			background: #392611;
		}

		#chat-container::-webkit-scrollbar-thumb {
			background: #a68b7d;
			border: 2px solid #392611;
			border-radius: 4px;
		}

		#chat-container::-webkit-scrollbar-thumb:hover {
			background: #bda294;
		}

		#messages {
			display: flex;
			flex-direction: column;
			word-wrap: break-word;
		}

		.message {
			line-height: 1.3;
			opacity: 0;
			animation: fadeIn 0.2s forwards ease-out;
			white-space: pre-wrap;
			margin-bottom: 2px;
		}

		.message.html-content {
			white-space: normal;
		}

		@keyframes fadeIn {
			from {
				opacity: 0;
				transform: translateY(5px);
			}

			to {
				opacity: 1;
				transform: translateY(0);
			}
		}

		/* Standard SS13 styles fallback */

		.admin {
			color: #9b59b6;
			font-weight: bold;
		}

		.ooc {
			color: #3498db;
			font-weight: bold;
		}

		a {
			color: #a68b7d;
			text-decoration: underline;
		}

		a:hover {
			color: #e1e1d7;
		}

		.prefix {
			font-weight: bold;
		}

		.log_message {
			color: #A9B6E7;
			font-weight: bold;
		}

		.small_message {
			color: #E1E1FF;
			font-weight: bold;
			font-size: 0.66em;
		}

		a,
		a:link,
		a:visited,
		a:active,
		a:hover {
			color: #CD4C6C;
		}

		/* OOC */
		.ooc {
			font-weight: bold;
		}

		.ooc img.text_tag {
			width: 32px;
			height: 10px;
		}

		.ooc .everyone {
			color: #1E8CBE;
		}

		.ooc .looc {
			color: #75B5B5;
		}

		.ooc .elevated {
			color: #2e78d9;
		}

		.ooc .mentor {
			color: #2e78d9;
		}

		.ooc .moderator {
			color: #2ed9ab;
		}

		.ooc .developer {
			color: #a649bf;
		}

		.ooc .admin {
			color: #39ac41;
		}

		.ooc .highstaff {
			color: #b82e00;
		}

		/* Admin: Private Messages */
		.pm .howto {
			color: #ff0000;
			font-weight: bold;
			font-size: 200%;
		}

		.pm .in {
			color: #ff0000;
		}

		.pm .out {
			color: #ff0000;
		}

		.pm .other {
			color: #1E8CBE;
		}

		/* Admin: Channels */
		.mod_channel {
			color: #735638;
			font-weight: bold;
		}

		.mod_channel .admin {
			color: #b82e00;
			font-weight: bold;
		}

		.admin_channel {
			color: #9611D4;
			font-weight: bold;
		}

		/* Radio: Misc */
		.deadsay {
			color: #8657C5;
		}

		.radio {
			color: #4CA64C;
		}

		/* Radio Channels */
		.blueradio {
			color: #6A80A9;
		}

		.SSradio {
			color: #466194;
		}

		.redradio {
			color: #B53232;
		}

		.brownradio {
			color: #7E6A46;
		}

		/* Miscellaneous */
		.name {
			font-weight: bold;
		}

		.alert {
			color: #ff0000;
		}

		h1.alert,
		h2.alert {
			color: #ff0000;
		}

		.ghostalert {
			color: #5c00e6;
			font-style: italic;
			font-weight: bold;
		}

		.emote {
			font-style: italic;
		}

		/* Game Messages */

		.attack {
			color: #ff0000;
		}

		.moderate {
			color: #CC0000;
		}

		.disarm {
			color: #990000;
		}

		.passive {
			color: #660000;
		}

		.red {
			color: #ff3737
		}

		.green {
			color: #289120
		}

		.green_bold {
			color: #289120;
			font-weight: bold;
		}

		@keyframes danger-blink {

			0%,
			100% {
				color: #b30000;
			}

			50% {
				color: #ff3737;
			}
		}

		.danger {
			font-weight: bold;
			animation: danger-blink 1s infinite;
		}

		.userdanger {
			font-weight: bold;
			font-size: 2.0em;
			animation: danger-blink 1s infinite;
		}

		.userdanger_yellow {
			color: #ffff00;
			font-weight: bold;
			font-size: 2.5em;
		}

		.hugedanger {
			font-weight: bold;
			font-size: 3.0em;
			animation: danger-blink 1s infinite;
		}

		.warning {
			color: #ff3737;
			font-style: italic;
		}

		.rose {
			color: #ff5050;
		}

		.notice {
			color: #5a6d8d;
		}

		.ping {
			color: #E1E1FF;
			font-weight: bold;
		}

		.reflex_shoot {
			color: #000099;
			font-style: italic;
		}

		/* Languages */

		.rough {
			font-family: "Trebuchet MS", cursive, sans-serif;
		}

		.say_quote {
			font-family: Georgia, Verdana, sans-serif;
		}

		.interface {
			color: #704C70;
		}

		.good {
			color: #839E69;
			font-weight: bold;
		}

		.bad {
			color: #ff3737;
			font-weight: bold;
		}

		/* Chat Tags */
		.text_tag {
			display: inline-block;
			padding: 1px 4px;
			border-radius: 3px;
			font-size: 10px;
			font-weight: bold;
			text-transform: uppercase;
			margin-right: 4px;
			vertical-align: middle;
			font-family: Arial, sans-serif;
			line-height: 1;
			border: 1px solid rgba(255, 255, 255, 0.1);
		}

		.tag-ooc {
			background-color: #1a56f0;
			color: white;
			border-color: #0d41bc;
		}

		.tag-looc {
			background-color: #36b6a6;
			color: white;
			border-color: #2a8d81;
		}

		.tag-dead,
		.tag-lobby {
			background-color: #6326c0;
			color: white;
			border-color: #4a1d8f;
		}

		.tag-asay,
		.tag-admin,
		.tag-a-discord {
			background-color: #a123f0;
			color: white;
			border-color: #7b1ab8;
		}

		.tag-mentor {
			background-color: #3986f0;
			color: white;
			border-color: #2b65b6;
		}

		.tag-pm_in {
			background-color: #f01a1a;
			color: white;
			border-color: #b81414;
		}

		.tag-pm_out_alt {
			background-color: #b04343;
			color: white;
			border-color: #8a3434;
		}

		.tag-pm_other {
			background-color: #5092c0;
			color: white;
			border-color: #3d6f92;
		}

		.tag-help {
			background-color: #ff0000;
			color: white;
			border-color: #cc0000;
		}

		.tag-discord,
		.tag-discord2 {
			background-color: #00b0f0;
			color: white;
			border-color: #0089bc;
		}

		.tag-ping {
			background-color: #f1c40f;
			color: #2c3e50;
			border-color: #f39c12;
			font-size: 9px;
		}

		.motd {
			color: #E1E1FF;
			font-family: "Civ13Custom", "Book Antiqua", Verdana, sans-serif;
		}

		.motd h1,
		.motd h2,
		.motd h3,
		.motd h4,
		.motd h5,
		.motd h6 {
			margin-top: 0.2em;
			margin-bottom: 0.2em;
			color: #E1E1FF;
		}

		.motd a,
		.motd a:link,
		.motd a:visited,
		.motd a:active,
		.motd a:hover {
			color: #CD4C6C;
		}
	</style>
"}

var/global/chat_template = {"
<!DOCTYPE html>
<html lang="en">

<head>
	<meta charset="utf-8">
	<meta http-equiv="X-UA-Compatible" content="IE=edge">
	<meta http-equiv="Content-Security-Policy" content="base-uri *;">
	[chat_style]
	<title>Civilization 13 Chat</title>
</head>

<body style="background-color: #392611; color: #e1e1d7;">
	<div id="chat-container">
		<div id="messages">/* MESSAGES */</div>
	</div>
	<script>
		window.onload = function() {
			var container = document.getElementById('chat-container');
			container.scrollTop = container.scrollHeight;
		};
	</script>
</body>

</html>
"}

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

	var/list/rendered = list()
	for(var/msg in message_queue)
		rendered += "<div class=\"message\">[msg]</div>"

	var/html = chat_template
	html = replacetext(html, "/* MESSAGES */", rendered.Join(""))

	client << browse(html, "window=browser_chat")

#define MAX_CHAT_HISTORY 100

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
	
	message_queue += extract_json_message(message)
	if(message_queue.len > MAX_CHAT_HISTORY)
		message_queue.Cut(1, 2)
	client.update_chatpanel()
	// We no longer call load() here immediately to avoid spamming browse()
	// The periodic refresh in the subsystem will handle the update.

//this skips sanitisation so make sure you use it on safe html ONLY
//DO NOT use this for player inputs!
/datum/chat/proc/send_message_html(message)
	if (!client)
		return
	
	message_queue += extract_json_message(message)
	if(message_queue.len > MAX_CHAT_HISTORY)
		message_queue.Cut(1, 2)
	client.update_chatpanel()


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
