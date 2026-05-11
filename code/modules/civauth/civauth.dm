/client
	var/authenticated = FALSE

/mob/new_player/Login()
	..()
	if (config.civauth)
		// check if theres a saved token to skip login
		if (!TryAutoLogin())
			// Force them into the authentication flow immediately
			spawn(0) RequireAuthentication()
		// give players 30 secs to authenticate
		spawn(300)
			if (client && config.civauth && !client.authenticated)
				spawn(50)
					close_spawn_windows()
					del(client)
					return
	else
		if (client)
			client.authenticated = TRUE

/mob/new_player/proc/RequireAuthentication()
	if (!config.civauth)
		return
		
	// 1. Show the prompt
	var/typed_password = input(src, "Welcome to Civ13. Please enter your password to Login or Register.", "Authentication") as text|null
	
	// If they close the window, boot them
	if(!typed_password)
		to_chat(src, "<span class='danger'>Authentication required. Disconnecting...</span>")
		spawn(50)
			close_spawn_windows()
			del(client)
		return

	// 2. Prepare the payload
	var/alist/payload = alist(
		"ckey" = client.ckey,
		"password" = typed_password,
		"server_secret" = config.secret_key
	)

	// 3. Send the request to your API
	var/list/http_headers = list("Content-Type" = "application/json")
	var/list/response = world.Export("https://api.civ13.com/auth_or_register", payload, 0, null, "POST", http_headers)

	// 4. Handle connection errors
	if(!response || response["STATUS"] != "200 OK")
		to_chat(src, "<span class='danger'>Authentication server is currently unreachable.</span>")
		spawn(50)
			close_spawn_windows()
			del(client)
			return

	// 5. Decode the response
	var/response_text = file2text(response["CONTENT"])
	if (!response_text || (copytext(response_text, 1, 2) != "{" && copytext(response_text, 1, 2) != "\["))
		to_chat(src, "<span class='danger'>Authentication server returned an invalid response. Contact an administrator.</span>")
		if (response_text)
			world.log << "Response starts with: [copytext(response_text, 1, 100)]"
		
		spawn(50)
			close_spawn_windows()
			del(client)
		return

	var/list/auth_result = json_decode(response_text)

	// 6. Handle the result
	if(auth_result["status"] == "authenticated" || auth_result["status"] == "registered")
		to_chat(src, "<span class='notice'>Authentication successful!</span>")
		client.authenticated = TRUE
		
		// Save the token returned by the API
		var/savefile/F = new("civ13_auth.sav")
		F["remember_token"] << auth_result["token"]
		
		to_chat(src, "Login successful. Token saved for auto-login.")
	else
		to_chat(src, "<span class='danger'>Authentication Failed: [auth_result["message"]]</span>")
		spawn(50)
			close_spawn_windows()
			del(client)
			return


/mob/new_player/proc/TryAutoLogin()
	var/savefile/F = new("civ13_auth.sav")
	var/token = ""
	F["remember_token"] >> token
	
	if(token)
		// 1. Send this token to the API instead of a password
		var/list/payload = list(
			"ckey" = src.ckey, 
			"token" = token,
			"server_secret" = config.secret_key
		)
		
		var/list/http_headers = list("Content-Type" = "application/json")
		var/list/response = world.Export("https://api.civ13.com/auto_login", json_encode(payload), 0, null, "POST", http_headers)
		
		// 2. If response is valid, bypass the input() and log them in!
		if(response && response["STATUS"] == "200 OK")
			var/response_text = file2text(response["CONTENT"])
			if (!response_text || (copytext(response_text, 1, 2) != "{" && copytext(response_text, 1, 2) != "\["))
				return FALSE

			var/list/auth_result = json_decode(response_text)
			
			if(auth_result["status"] == "authenticated")
				to_chat(src, "<span class='notice'>Auto-login successful! Welcome back.</span>")
				client.authenticated = TRUE
				return TRUE
				
	// If the file doesn't exist, the API is offline, or the token is invalid:
	return FALSE