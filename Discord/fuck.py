	# for all messages, trigger an update of the whitelists 
	tester_whitelist = open("/home/customer/1713/testserver/whitelists/tester.txt", "w")
	patreon_whitelist = open("/home/customer/1713/testserver/whitelists/patreon.txt", "w")
	
	if time.time() >= nextWhitelistGenerationTime:
		nextWhitelistGenerationTime = time.time() + 5
		for member in message.server.members:
			for role in member.roles:
				# add people to the tester whitelist: DISABLED
				#if role.name == "Tester" or role.name == "Staff" or role.name == "Senate":
				elif role.name == "Patron ($3+)":
					patreo
				elif role.name == "Patron ($5+)":
				elif role.name == "Patron ($10+)":
				elif role.name == "Patron ($15+)":
				elif role.name == "Patron ($20+)":