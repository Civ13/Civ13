from __future__ import print_function
#from googletrans import Translator


import discord
import asyncio
import codecs
import random
import os
import shutil
import psutil
import time 
import datetime
import pytz
import sqlite3

from threading import Timer
import sys
import socket 
import random

import subprocess

import operator
from sortedcontainers import SortedDict
from collections import OrderedDict

import math

def bash_command(cmd):
    subprocess.Popen(cmd, shell=True, executable='/bin/bash')

def portIsAvailable(port):

	s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

	try:
		s.bind(("127.0.0.1", port))
	except socket.error as e:
		#if e.errno == 98:
			#print("Port is already in use")
		#else:
			# something else raised the socket.error exception
			#print("Error: " + e)
		s.close()
		return False
	else:
		s.close()
		return True

	s.close()	  
	return False

#translator = Translator()

client = discord.Client()

protips = ["test one", "test2"]

senate_approval_for_master_elections = []

master_election_pledged_votes = dict()

master_election_candidates = []

master_election_registered_ids = dict()

#nextWhitelistGenerationTime = -1

master_elections_end_at = -1
master_election_slots = 5
next_election_status_update = -1

def remove_prefix(text, prefix):
    if text.startswith(prefix): # only modify the text if it starts with the prefix
         text = text.replace(prefix, "", 1) # remove one instance of prefix
    return text
	
def random_line(language = None):
	lines = open('god.txt').read().splitlines()
	line = random.choice(lines)
	while line.find("@") != -1 or line.find("<") != -1 or line.find(">") != -1 or line.find("https://") != -1 or line.find(".png") != -1 or line.find(".jpg") != -1 or line.find(".gif") != -1:
		line = random.choice(lines)
	if language != None:
		if line.find(":") == -1:
			line = translator.translate(line, language).text
	return line
	
def my_message(msg):
    return msg.author == client.user

def search_players(ckey):
	conn = sqlite3.connect('../SQL/database.db')
	c = conn.cursor()
	c.execute("SELECT ckey FROM connection_log WHERE ckey LIKE '"+ckey+"'")
	x = c.fetchone()
	if str(x) == "None":
		return str(x)
	else:
		return str(x[0])	
# master elections take 36 hours
_36_hours = 129600
#def start_master_elections():
	#master_elections_end_at = time.time() + 120
	
# return a dictionary of candidates paired with number of votes they got 
def count_votes():
	votes = dict()
	for key in master_election_candidates:
		votes[key] = 0
	for key in master_election_pledged_votes:
		candidate = master_election_pledged_votes[key]
		votes[candidate] += 1
	return votes
	
def get_winners(n):
	votes = count_votes()
	winners = dict()
	while n > 0:
		n -= 1
		vote_threshold = -1
		winner = None
		for candidate in votes:
			if votes[candidate] > vote_threshold:
				winner = candidate 
				vote_threshold = votes[candidate]
		if winner == None:
			break 
		else:
			if winner in votes: # sanity check
				winners[winner] = votes[winner]
				votes[winner] = -1
	return winners
	
##def counting(client):
##	count = 0
##	while 1 == 1:
##		count += 1
##		for channel in client.get_server("468979034571931648").channels:
##			if channel.name == "staff":
##				yield from client.send_message(channel, count)
##				break

@client.event
@asyncio.coroutine
def on_ready():
	print('Logged in as')
	print(client.user.name)
	print(client.user.id)
	print('------')
	#client.loop.create_task(counting(client))


@client.event
@asyncio.coroutine
def on_message(message):

	global senate_approval_for_master_elections
	global master_election_pledged_votes
	global master_election_candidates
	global master_elections_end_at
	global master_election_slots
	global next_election_status_update
	global master_election_registered_ids
		
	if str(message.channel) == 'hosting' or str(message.channel) == 'website':
		return 
	elif message.content.startswith('!s '):
		message.content = remove_prefix(message.content, '!s ')
	#	if message.content.startswith('!test'):
		#	counter = 0
		#	tmp = yield from client.send_message(message.channel, 'Calculating messages...')
		#	async for log in client.logs_from(message.channel, limit=100):
		#		if log.author == message.author:
		#			counter += 1

		#	yield from client.edit_message(tmp, 'You have {} messages.'.format(counter))
		#if message.content.startswith('sleep'):
			#yield from asyncio.sleep(5)
			#yield from client.send_message(message.channel, 'Done sleeping')
			
		#if message.content.startswith('curchannel'):
		#	yield from client.send_message(message.channel, message.channel)
		if message.content.lower().startswith('approveme'):
		
			# dammit harcourt
			accepted = False
			for role in message.author.roles:
				if role.name == "Admiral" or role.name == "Captain" or role.name == "Seaman" or role.name == "Able Seaman" or role.name == "Master":
					accepted = True 
					break
			if not accepted:
				return 
				
			split_message = message.content.split("approveme ")
			z = search_players(str(split_message[1]))
			if z in open('approved.txt').read():
				result = "You have already been approved!"
			elif (z == "None"):
				result = "Invalid Ckey"
			else:
				with open("approved.txt", "a") as myfile:
					myfile.write(z)
				result = "You have been approved!"
				#server = Client.get_server("331613189462556672")
				#role = discord.utils.get(server.roles, name="Seaman")
				approved = discord.utils.get(message.server.roles, name="Seaman")
				#role = discord.utils.get(message.server.roles, name="approved")
				yield from client.add_roles(message.author, approved)
			yield from client.send_message(message.channel, result)
		elif message.content.startswith('cpu'):
			CPU_Pct= str(psutil.cpu_percent())
			yield from client.send_message(message.channel, 'CPU Usage: ' + CPU_Pct +"%")
		#elif message.content.startswith('meme'):
			#yield from client.send_message(message.channel, ':swastika: :swastika: :swastika: :fire: :fire: :fire: mecha :b:itler :ok_hand: :fire: :fire: :fire: :swastika: :swastika: :swastika:')
		elif message.content.startswith('serverstatus'):
			_13000 = not portIsAvailable(12000)
			_13001 = not portIsAvailable(12001)
			_13002 = not portIsAvailable(12002)
			_13003 = not portIsAvailable(12003)
			server_is_up = (_13000 and _13001) or (_13002 and _13003)
			if not server_is_up:
				embed = discord.Embed(color=0x00ff00)
				embed.add_field(name="Server Status",value="Offline", inline=False)
				yield from client.send_message(message.channel, embed=embed)
				return
			else:
				data = None;
				if _13000 and _13001:
					if os.path.isfile('/home/customer/1713/1713-1/serverdata.txt') == True:
						data = codecs.open('/home/customer/1713/1713-1/serverdata.txt', encoding='utf-8').read()
					elif os.path.isfile('/home/customer/1713/1713-2/serverdata.txt') == True:
						data = codecs.open('/home/customer/1713/1713-2/serverdata.txt', encoding='utf-8').read()
				elif _13002 and _13003:
					if os.path.isfile('/home/customer/1713/1713-3/serverdata.txt') == True:
						data = codecs.open('/home/customer/1713/1713-3/serverdata.txt', encoding='utf-8').read()
					elif os.path.isfile('/home/customer/1713/1713-4/serverdata.txt') == True:
						data = codecs.open('/home/customer/1713/1713-4/serverdata.txt', encoding='utf-8').read()
				else:
					embed = discord.Embed(color=0x00ff00)
					embed.add_field(name="Server Status",value="Offline", inline=False)
					yield from client.send_message(message.channel, embed=embed)
					return 
					
				data = data.replace('<b>Server Status</b>: ','')
				data = data.replace('<b>Address</b>: ', '')
				data = data.replace('<b>Map</b>: ', '')
				data = data.replace('<b>Players</b>:','')
				data = data.replace('</b>','')
				data = data.replace('<b>','')
				data = data.replace('Whitelist: ','')
				data = data.split(";")
				#embed = discord.Embed(title="**1713 Bot**", color=0x00ff00)
				embed = discord.Embed(color=0x00ff00)
				embed.add_field(name="Server Status", value=data[0], inline=False)
				embed.add_field(name="Address", value='<'+data[1]+'>', inline=False)
				embed.add_field(name="Map", value=data[2], inline=False)
				embed.add_field(name="Players", value=data[3], inline=False)
				
				metadata = None
				
				# final field is for metadata
				
				if len(data) == 5:
					metadata = data[4]
				elif len(data) == 6:
					metadata = data[5]
					embed.add_field(name="Whitelist", value=data[4], inline=False) 
			
				# metadata no longer used for now
			
				yield from client.send_message(message.channel, embed=embed)

		elif message.content.startswith('chinaman'):
			yield from client.send_message(message.channel, 'http://mechahitler.co.nf/chinaman.jpg')
		elif message.content.startswith('sopademacaco'):
			yield from client.send_message(message.channel, 'https://i.kym-cdn.com/photos/images/original/001/278/910/42e.jpg')
		elif message.content.startswith('piratechan'):
			yield from client.send_message(message.channel, 'https://vignette.wikia.nocookie.net/percyjacksonfanfiction/images/a/ab/Anime-pirate.png')	
		elif message.content.startswith('help'):
			yield from client.send_message(message.channel, '**List of Commands**: serverstatus, chinaman, sopademacaco, piratechan, cpu, ping, (un)whitelistme, updateserver, rebuildbinaries, host-1713, kill-1713, restart-1713')

		elif message.content.startswith('pingeveryone'):
			accepted = False
			for role in message.author.roles:
				if role.name == "Admiral":
					accepted = True 
			if accepted:
				yield from client.send_message(message.channel, "@everyone")
		elif message.content.startswith('ping'):
			channel = message.channel
			t1 = time.perf_counter()
			yield from client.send_typing(channel)
			t2 = time.perf_counter()
			embed=discord.Embed(title=None, description='Pong: {} ms'.format(round((t2-t1)*1000)), color=0x2874A6)
			yield from client.send_message(message.channel, embed=embed)
			
		# tester whitelist 
		elif message.content.startswith('whitelistme'):
			split_message = message.content.split("whitelistme ")
			if len(split_message) > 1 and len(split_message[1]) > 0:
				ckey = split_message[1]
				accepted = False
				for role in message.author.roles:
					if role.name == "Admiral" or role.name == "Captain" or role.name == "Seaman" or role.name == "Able Seaman" or role.name == "Master":
						accepted = True 
				if accepted:
				
					whitelist = "/home/customer/1713/testserver/whitelist.txt"
					
					open(whitelist, "a").close()
					
					with open(whitelist, "r") as search:
						for line in search:
							line = line.rstrip()  # remove '\n' at end of line
							if line == ckey+"="+str(message.author):
								yield from client.send_message(message.channel, "{} is already in the whitelist, soyboy.".format(ckey))
								return
							elif str(message.author) in line:
								yield from client.send_message(message.channel, "Woah there, {}, you already whitelisted one key!".format(str(message.author).split("#")[0]))
								return 
								
						search.close()
								
					somefile = open(whitelist, "a")
					somefile.write(ckey+"="+str(message.author))
					somefile.write("\n")
					somefile.close()
					
					yield from client.send_message(message.channel, "{} has been added to the whitelist.".format(ckey))
				else:
					yield from client.send_message(message.channel, "Rejected! Please apply for tester in #tester-applications.")
			else:
				yield from client.send_message(message.channel, "Wrong format. Please try '!s whitelistme [ckey]'")
				
		elif message.content.startswith("unwhitelistme"):
			
			accepted = False
			for role in message.author.roles:
				if role.name == "Admiral" or role.name == "Captain" or role.name == "Seaman" or role.name == "Able Seaman" or role.name == "Master":
					accepted = True 
					break
			if accepted:
			
				removed = "N/A"
			
				list = "/home/customer/1713/testserver/whitelist.txt"
				
				open(list, "a").close()
				
				f = open(list, "r")
				lines = f.readlines()
				f.close()
				f = open(list, "w")
				for line in lines:
					if not str(message.author) in line:
						f.write(line)
					else:
						removed = line.split("=")[0]
							
				f.close()
				
				yield from client.send_message(message.channel, "Ckey {} has been removed from the test server whitelist".format(removed))
			else:
				yield from client.send_message(message.channel, "Rejected! You are not a tester.")
		
		# patron list
	
			
		elif message.content.startswith("updateserver"):
			accepted = False 
			for role in message.author.roles:
				if role.name == "Captain" or role.name == "Admiral":
					accepted = True 
					break 
			if accepted:
			
				yield from client.send_message(message.channel, "Now updating the server to the latest git build...")
				os.system('sudo python3.5 /home/customer/1713/scripts/updateserverabspaths.py')
				yield from client.send_message(message.channel, "Finished updating the server to the latest git build.")
					
				for channel in message.server.channels:
					if channel.name.lower() == "updates":
						yield from client.send_message(channel, "The server has been updated. Update triggered by {}. See https://github.com/WW2-SS13/1713/pulse or development channels for recent changes.".format(message.author.name))
			#	yield from client.send_message(message.channel, "Now updating the code to the latest git build. It will take about 15 seconds.")
				#subprocess.call(['/bin/bash', '-i', '-c', "update-server-auto"])
				#bash_command("update-server-auto")
				#subprocess.Popen(['/bin/bash', '-b', 'update-server-auto'])
			#	subprocess.Popen(['/bin/bash', '-i', '-c', 'update-server-auto'])
			
			#	yield from client.send_message(message.channel, "Finished updating the code to the latest git build.")

			else:
				yield from client.send_message(message.channel, "Piss off nu-male :soyboy:")
				
		elif message.content.startswith("rebuildbinaries"):
			accepted = False 
			for role in message.author.roles:
				if role.name == "Captain" or role.name == "Admiral":
					accepted = True 
					break 
			if accepted:
			
				yield from client.send_message(message.channel, "Now updating & rebuilding server binaries to the latest git build...")
				os.system('sudo python3.5 /home/customer/1713/scripts/updateserverabspaths.py')
				yield from client.send_message(message.channel, "Finished updating & rebuilding server binaries to the latest git build.")

			else:
				yield from client.send_message(message.channel, "Piss off nu-male <:picklerickldab:373260795104067588><:picklerickrdab:373260846362525696>")
		
		elif message.content.startswith("host-1713"):
		
			private = False 
			if "private" in message.content.split("host-1713")[1]:
				private = True
		
			accepted = False 
			for role in message.author.roles:
				if role.name == "Admiral" or role.name == "Captain":
					accepted = True 
					break 
			if accepted:
				yield from client.send_message(message.channel, "Please wait, updating the code...")
				os.system('sudo python3.5 /home/customer/1713/scripts/updateserverabspaths.py')
				yield from client.send_message(message.channel, "Updated the code.")
				if not private:
					os.system('sudo rm -f /home/customer/1713/sharedinfo/*.txt')
					os.system('sudo rm -f /home/customer/1713/1713-1/serverdata.txt')
					os.system('sudo rm -f /home/customer/1713/1713-2/serverdata.txt')
					os.system('sudo DreamDaemon /home/customer/1713/1713-1/1713.dmb 12000 -trusted -webclient -logself &')
					time.sleep(5) # this is pretty important 
					os.system('sudo DreamDaemon /home/customer/1713/1713-2/1713.dmb 12001 -trusted -webclient -logself &')
					yield from client.send_message(message.channel, "Attempted to bring up 1713 (Main Server)")
					time.sleep(10) # ditto
					os.system('sudo python3.5 /home/customer/1713/scripts/killsudos.py')
				else:
					os.system('sudo rm -f /home/customer/1713/testserver/sharedinfo/*.txt')
					os.system('sudo rm -f /home/customer/1713/1713-3/serverdata.txt')
					os.system('sudo rm -f /home/customer/1713/1713-4/serverdata.txt')
					os.system('sudo DreamDaemon /home/customer/1713/1713-3/1713.dmb 12002 -trusted -webclient -logself &')
					time.sleep(5) # this is pretty important 
					os.system('sudo DreamDaemon /home/customer/1713/1713-4/1713.dmb 12003 -trusted -webclient -logself &')
					yield from client.send_message(message.channel, "Attempted to bring up 1713 (Testing Server)")
					time.sleep(10) # ditto
					os.system('sudo python3.5 /home/customer/1713/scripts/killsudos.py')

			else:
				yield from client.send_message(message.channel, "Piss off nu-male <:picklerickldab:373260795104067588><:picklerickrdab:373260846362525696>")
		
		elif message.content.startswith("kill-1713"):
		
			private = False 
			if "private" in message.content.split("kill-1713")[1]:
				private = True
		
			accepted = False 
			for role in message.author.roles:
				if role.name == "Admiral" or role.name == "Captain":
					accepted = True 
					break 
					
			if accepted:
				if private:
					os.system('sudo python3.5 /home/customer/1713/scripts/kill1713_private.py')
				else:
					os.system('sudo python3.5 /home/customer/1713/scripts/kill1713.py')
				yield from client.send_message(message.channel, "Attempted to kill 1713.")
			else:
				yield from client.send_message(message.channel, "Piss off nu-male <:picklerickldab:373260795104067588><:picklerickrdab:373260846362525696>")
		
		elif message.content.startswith("restart-1713"):
		
			private = False 
			if "private" in message.content.split("restart-1713")[1]:
				private = True
		
			accepted = False
			for role in message.author.roles:
				if role.name == "Admiral" or role.name == "Captain":
					accepted = True 
					break 
					
			if accepted:
		#		yield from client.send_message(message.channel, "Please wait for 10 seconds.")
		#		os.system('sudo python3 /home/customer/1713/scripts/restartinactiveserver.py')
		#		time.sleep(10)
				if private:
					os.system('sudo python3.5 /home/customer/1713/scripts/restart1713_private.py')
				else:
					os.system('sudo python3.5 /home/customer/1713/scripts/restart1713.py')
				yield from client.send_message(message.channel, "Attempted to restart 1713.")
			else:
				yield from client.send_message(message.channel, "Piss off nu-male <:picklerickldab:373260795104067588><:picklerickrdab:373260846362525696>")
		

		# elections 
		elif message.content.startswith("voteelection"):
			accepted = False 
			for role in message.author.roles:
				if role.name == "Admiral":
					accepted = True 
					break 
			if accepted or len(senate_approval_for_master_elections) >= 3:
				if message.author.name in senate_approval_for_master_elections:
					yield from client.send_message(message.channel, "You have already voted for master elections this cycle.")
				else:
					senate_approval_for_master_elections.append(message.author.name)
					yield from client.send_message(message.channel, "{} has voted for master elections. master elections now have {}/3 of Senate votes necessary to commence.".format(message.author.name, len(senate_approval_for_master_elections)))
					if len(senate_approval_for_master_elections) >= 3:
						yield from client.send_message(message.channel, "master elections have 3/4 needed votes and will commence. Please ensure that this bot is not shut down or restarted within the next 36 hours, or the vote will be canceled!")

						
						# allow voting now
						master_elections_end_at = time.time() + _36_hours
						next_election_status_update = time.time() + 600
						
						# dissolve the master team 
						for member in message.server.members:
							for role in member.roles:
								if role.name in ["Master"]:
									yield from client.remove_roles(member, role)
						
						# inform everyone about the elections
						for channel in message.server.channels:
							if channel.name == "elections" or channel.name == "Elections":
								yield from client.send_message(channel, "Master elections have been automatically started by Admiralty vote, and the Master Team has been dissolved! If you have a role, please use the commands '!s votefor [name]' or '!s register [name]' to vote/run for Master! You can also see election results with '!s election'. @everyone")
								admins_and_managers = []
								for member in message.server.members:
									for role in member.roles:
										if role.name in ["Admin Team", "Staff Manager", "Staff Managers", "Head Admin"]:
											if not member in admins_and_managers:
												admins_and_managers.append(member)
								master_election_slots = math.floor(len(admins_and_managers)/2)
								yield from client.send_message(channel, "As many as **{}**	Masters will be elected after **36 hours**, when the elections will end.".format(master_election_slots))
								
			else:
				yield from client.send_message(message.channel, "You are not an Admiral.")
				
		elif message.content.startswith("forceelections"):
			accepted = False 
			if message.author.name == "Kachnov" and str(message.author.discriminator) == "0051":
				accepted = True 
			if accepted:
				senate_approval_for_master_elections.append("this")
				senate_approval_for_master_elections.append("is")
				senate_approval_for_master_elections.append("hacky")
						
		elif message.content.startswith("votefor"):
		
			if master_elections_end_at == -1:
				yield from client.send_message(message.channel, "Elections are not in session.")
				return
						
			split_message = message.content.split("votefor ")
			if len(split_message) > 1 and len(split_message[1]) > 0:
				votingfor = split_message[1].lower()
				accepted = False
				for role in message.author.roles:
					if role.name in ["Able Seaman", "Captain", "Admiral", "Master"]:
						accepted = True 
						break
				if accepted:
					if votingfor in master_election_candidates:
						oldvote_message = ""
						if message.author.id in master_election_pledged_votes:
							if votingfor == master_election_pledged_votes[message.author.id]:
								yield from client.send_message(message.channel, "You've already voted for them, {}.".format(message.author.name))
								return
							else:
								oldvote_message = " Your old vote towards {} was rescinded.".format(master_election_pledged_votes[message.author.id].capitalize())
						master_election_pledged_votes[message.author.id] = votingfor
						yield from client.send_message(message.channel, "You've voted for {}, {}.{}".format(votingfor.capitalize(), message.author.name, oldvote_message))
					else:
						yield from client.send_message(message.channel, "You can't vote for them, {}.".format(message.author.name))
				else:
					yield from client.send_message(message.channel, "Rejected! To vote, you need to have one or more of the following roles: Able Seaman, Captain, Admiral, Master")
			else:
				yield from client.send_message(message.channel, "Wrong format. Please try '!s votefor [name]'")
				
		elif message.content.startswith("register"):
		
			if message.author.id in master_election_registered_ids:
				yield from client.send_message(message.channel, "You're already registered, {}.".format(message.author.name))
				return
		
			split_message = message.content.split("register ")
			if len(split_message) > 1 and len(split_message[1]) > 0:
				votename = split_message[1]
				if not votename.lower() in message.author.name.lower():
					yield from client.send_message(message.channel, "Invalid name.")
					return
				accepted = False
				for role in message.author.roles:
					if role.name in ["Able Seaman", "Captain", "Admiral", "Master"]:
						accepted = True 
						break
				if accepted:
					for role in message.author.roles:
						if role.name in ["Captain", "Admiral"]:
							yield from client.send_message(message.channel, "You may not run for Master, because you have a conflicting role.")
							return
					if not votename.lower() in master_election_candidates:
						master_election_candidates.append(votename.lower())
						master_election_registered_ids[message.author.id] = votename.lower()
						yield from client.send_message(message.channel, "You've been registered as a candidate for Master under the name '{}'. If this bot restarts, you will have to re-register.".format(votename))
				else:
					yield from client.send_message(message.channel, "Rejected! To vote, you need to have one or more of the following roles: Able Seaman, Captain, Admiral, Master.")
			else:
				yield from client.send_message(message.channel, "Wrong format. Please try '!s register [name]'. Whatever name you select is what others will type in to vote for you.")
		
		elif message.content.startswith("election"):
		
			if master_elections_end_at == -1:
				yield from client.send_message(message.channel, "Elections are not in session.")
				return
				
			results = count_votes()
			sorted_results = [(k, results[k]) for k in sorted(results, key=results.get, reverse=True)]					
			
			place = 1
			strmessage = "**Current election results:**\n\n"
			
			for tuple in sorted_results:
				candidate = tuple[0]
				votes = tuple[1]
				placestr = "???"
				if place == 1:
					placestr = "1st"
				elif place == 2:
					placestr = "2nd"
				else:
					placestr = "{}th".format(place)
				place += 1
				strmessage += "{} has {} votes, putting them in {} place.\n".format(candidate.capitalize(), votes, placestr)
				
			yield from client.send_message(message.channel, strmessage)
			
		elif message.content.startswith("voters"):
			members = []
			for member in message.server.members:
				for role in member.roles:
					if role.name in ["Able Seaman", "Captain", "Admiral", "Master"]:
						if not member in members:
							members.append(member)
			yield from client.send_message(message.channel, "There are {} eligible voters.".format(len(members)))

			
	elif "<@122431044270948354>" in message.content.lower():
		accepted = False 
		authorping = "<@" + str(message.author.id) + ">" # <@312693734729056256> = @Kachnov
		for role in message.author.roles:
			if role.name == "Degenerate":
				accepted = True
		if not accepted:
			if message.author == message.server.me:
				accepted = True
		if accepted:
			yield from client.delete_message(message)
			if message.author != client:
				yield from client.send_message(message.channel, "Do not ping Matt filthy degenerate")
				for i in range(50):
					time.sleep(0.2)
					yield from client.send_message(message.channel, authorping + " " + random.choice(['<:picklerickldab:373260795104067588>', '<:picklerickrdab:373260846362525696>', '<:angery:417389685229486082>']))

	# elections dude
	if master_elections_end_at != -1:
		if time.time() >= master_elections_end_at:
			master_elections_end_at = -1
			# actually send the results to #elections channel 
			for channel in message.server.channels:
				if channel.name.lower() == "elections":
					yield from client.send_message(channel, "**The elections are over!** The winners are:")
					winners = get_winners(master_election_slots)
					i = 0
					for winner in winners:
						votes = winners[winner]
						if i == 0:										
							yield from client.send_message(channel, "**1st Place**, {} votes (Captain): {}".format(votes, winner.capitalize()))
						else:
							place = "???"
							if i == 1:
								place = "2nd"
							elif i == 2:
								place = "3rd"
							else:
								place = "{}th".format(str(i))
								
							yield from client.send_message(channel, "**{} Place**, {} votes (Master): {}".format(place, votes, winner.capitalize()))

						for id in master_election_registered_ids:
								if master_election_registered_ids[id] == winner:
									for member in message.server.members:
										if member.id == id:
											if i == 0:
												master = discord.utils.get(message.server.roles, name="Master")
												captain = discord.utils.get(message.server.roles, name="Captain")
												yield from client.add_roles(member, master)
												yield from client.add_roles(member, captain)
											else:
												master = discord.utils.get(message.server.roles, name="Master")
												yield from client.add_roles(member, master)		
						i += 1
												
			# clear unneeded data 
			senate_approval_for_master_elections = []

			master_election_pledged_votes = dict()

			master_election_candidates = []

			master_election_registered_ids = dict()							
		else:
			if time.time() >= next_election_status_update:
				next_election_status_update = time.time() + 600 # 10 minutes
				results = count_votes()
				sorted_results = [(k, results[k]) for k in sorted(results, key=results.get, reverse=True)]		

				for channel in message.server.channels:
					if channel.name.lower() == "elections":
						yield from client.send_message(channel, "**Current election results:**")
						
						place = 1
						for tuple in sorted_results:
							candidate = tuple[0]
							votes = tuple[1]
							placestr = "???"
							if place == 1:
								placestr = "1st"
							elif place == 2:
								placestr = "2nd"
							else:
								placestr = "{}th".format(place)
							votesname = "votes"
							if votes == 1:
								votesname = "vote"
							yield from client.send_message(channel, "{} has {} {}, putting them in {} place.".format(candidate.capitalize(), votes, votesname, placestr))
							place += 1

					#else:
	#	print(message.content.lower())
	#elif not message.content.startswith('God Says') and not message.content.startswith('Hitler Says') and not message.content.startswith('Stalin Says') and not message.content.startswith('Hirohito Says') and not message.content.startswith('Yahweh Says') and not message.content.startswith('!s'):
	#	f = open("god.txt","a")
	#	f.write(str(message.content).replace(" ","\n"))
	#	f.close()
			
client.run('NDcxMTU4MTYyOTA5NjkxOTI0.DjgwCw.B4-McI2xyB2NVs5OZwAZcdPFChI')
