from __future__ import print_function
from googletrans import Translator


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

translator = Translator()

client = discord.Client()

protips = ["test one", "test2"]

senate_approval_for_judge_elections = []

judge_election_pledged_votes = dict()

judge_election_candidates = []

judge_election_registered_ids = dict()

#nextWhitelistGenerationTime = -1

judge_elections_end_at = -1
judge_election_slots = 5
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


	
# return a dictionary of candidates paired with number of votes they got 
def counting(client):
	count = 0
	while 1 == 1:
		count += 1
		for channel in client.get_server("331613189462556672").channels:
			if channel.name == "senate":
				yield from client.send_message(channel, count)
				break

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

	global senate_approval_for_judge_elections
	global judge_election_pledged_votes
	global judge_election_candidates
	global judge_elections_end_at
	global judge_election_slots
	global next_election_status_update
	global judge_election_registered_ids
		
	if str(message.channel) == 'hosting' or str(message.channel) == 'website':
		return 
	#elif message.content.lower().startswith('bad bot'):
		#yield from client.send_file(message.channel, 'god.txt', "")
	elif message.content.lower().startswith('>>'):
		embed = discord.Embed(color=0x00ff00)
		messagetouse = str(message.content)
		#print(messagetouse)
		embed.add_field(name="Implications from @"+str(message.author), value=messagetouse, inline=False)
		yield from client.send_message(message.channel, embed=embed)
	elif message.content.startswith('!s serverstatis'):
		embed = discord.Embed(color=0x00ff00)
		embed.add_field(name="Server Status", value="Onaline", inline=False)
		embed.add_field(name="Address", value='colonialmarine.xxx', inline=False)
		embed.add_field(name="Map", value='bigred', inline=False)
		embed.add_field(name="Players", value='5', inline=False)
		embed.add_field(name="Whitelist", value='its !s serverstatus you fucking gook', inline=False)
		yield from client.send_message(message.channel, embed=embed)
	elif message.content.lower().startswith('omae wa mou shindeiru'):
		yield from client.send_message(message.channel, '**NANI!?**')
	elif message.content == 'start neuralnet':
		yield from client.send_message(message.channel, "Stroheim Neural Net Based Chatbot has been activated @here ... PLease talk to me! ")
		while (1 != 2):
			x = str(input())
			yield from client.send_message(message.channel, x)
	elif message.content == '<:picklerickldab:373260795104067588>':
		if not my_message(message):
			yield from client.send_message(message.channel, '<:picklerickrdab:373260846362525696>')
	elif message.content == '<:picklerickrdab:373260846362525696>':
		if not my_message(message):
			yield from client.send_message(message.channel, '<:picklerickldab:373260795104067588>')
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
		if message.content.startswith('germanscience'):
			yield from client.send_message(message.channel, '**BBBBBBBBBBBAKAMONO GAAAAAAAAAAA! DOITSU NO KAGAKU WO SEKAI ICHI**')
		elif message.content.startswith('germanmedicine'):
			yield from client.send_message(message.channel, '**GERMAN MEDICINE IS THE BEST IN THE WORLD!**')
		elif message.content.lower().startswith('approveme'):
		
		elif message.content.startswith('cpu'):
			CPU_Pct= str(psutil.cpu_percent())
			yield from client.send_message(message.channel, 'CPU Usage: ' + CPU_Pct +"%")
		#elif message.content.startswith('meme'):
			#yield from client.send_message(message.channel, ':swastika: :swastika: :swastika: :fire: :fire: :fire: mecha :b:itler :ok_hand: :fire: :fire: :fire: :swastika: :swastika: :swastika:')
		elif message.content.startswith('serverstatus'):
			_13000 = not portIsAvailable(3350)
			server_is_up = (3350)
			if not server_is_up:
				embed = discord.Embed(color=0x00ff00)
				embed.add_field(name="Server Status",value="Offline", inline=False)
				yield from client.send_message(message.channel, embed=embed)
				return
			else:
				#data = None;
				#embed = discord.Embed(color=0x00ff00)
				#embed.add_field(name="Server Status",value="Offline", inline=False)
				#yield from client.send_message(message.channel, embed=embed)
				#return 
					
				#data = data.replace('<b>Server Status</b>: ','')
				#ata = data.replace('<b>Address</b>: ', '')
				#data = data.replace('<b>Map</b>: ', '')
				#data = data.replace('<b>Players</b>:','')
				#data = data.replace('</b>','')
				#data = data.replace('<b>','')
				#data = data.replace('Whitelist: ','')
				#data = data.split(";")
				#embed = discord.Embed(title="**1713 Bot**", color=0x00ff00)
				#embed = discord.Embed(color=0x00ff00)
				#embed.add_field(name="Server Status", value=data[0], inline=False)
				#embed.add_field(name="Address", value='<'+data[1]+'>', inline=False)
				#embed.add_field(name="Map", value=data[2], inline=False)
				#embed.add_field(name="Players", value=data[3], inline=False)
				
				#metadata = None
				
				# final field is for metadata
				
				#if len(data) == 5:
				#	metadata = data[4]
				#elif len(data) == 6:
				#	metadata = data[5]
				#	embed.add_field(name="Whitelist", value=data[4], inline=False) 
			
				# metadata no longer used for now
			
				yield from client.send_message(message.channel, "Not Yet.")

		elif message.content.startswith('chinaman'):
			yield from client.send_message(message.channel, 'http://mechahitler.co.nf/chinaman.jpg')
		elif message.content.startswith('hdab'):
			yield from client.send_message(message.channel, 'http://mechahitler.co.nf/hdab.jpg')
		elif message.content.startswith('wry'):
			yield from client.send_message(message.channel, 'http://mechahitler.co.nf/wryyy.png')
		elif message.content.startswith('help'):
			yield from client.send_message(message.channel, '**List of Commands**: germanscience, germanmedicine, serverstatus, lebensraum, lebenchan, chinaman, wryyy, hdab, dabon, cpu, ping, (un)whitelistme, (un)patronme, updateserver, rebuildbinaries, host-lebensraum, host-ahnenerbe, kill-lebensraum, kill-ahnenerbe, restart-lebensraum, restart-ahnenerbe')
		elif message.content.startswith('dabon'):
			dabbingOn = message.content.split("dabon ")
			if len(dabbingOn) == 1:
				return
			dabbingOn = dabbingOn[1]
			yield from client.send_message(message.channel, '<:picklerickldab:373260795104067588>' + dabbingOn + '<:picklerickrdab:373260846362525696>')
		elif message.content.startswith('pingeveryone'):
			accepted = False
			for role in message.author.roles:
				if role.name == "Senate":
					accepted = True 
			if accepted:
				yield from client.send_message(message.channel, "@everyone")
		elif message.content.startswith('lebenchan'):
			yield from client.send_message(message.channel, 'https://cdn.discordapp.com/attachments/331613625963773953/413741473759232022/unknown.png')
		# https://gist.github.com/NNTin/d92e2a8c8edfe46e9e47afe7cf3fc138
		elif message.content.startswith('ping'):
			channel = message.channel
			t1 = time.perf_counter()
			yield from client.send_typing(channel)
			t2 = time.perf_counter()
			embed=discord.Embed(title=None, description='Pong: {} ms'.format(round((t2-t1)*1000)), color=0x2874A6)
			yield from client.send_message(message.channel, embed=embed)
			
		elif message.content.startswith("updateserver"):
			accepted = False 
			for role in message.author.roles:
				if role.name == "Git Maintainers" or role.name == "Git Maintainer" or role.name == "Senate":
					accepted = True 
					break 
			if accepted:
			
				yield from client.send_message(message.channel, "Now updating the server to the latest git build...")
				#os.system('sudo python3 /home/customer/1713/scripts/updateserverabspaths.py')
				yield from client.send_message(message.channel, "Finished updating the server to the latest git build. Not really!")
					
				for channel in message.server.channels:
					if channel.name.lower() == "changelog":
						yield from client.send_message(channel, "The server has been updated. Update triggered by {}. See https://github.com/1713-SS13/1713 or development channels for recent changes.".format(message.author.name))
			#	yield from client.send_message(message.channel, "Now updating the code to the latest git build. It will take about 15 seconds.")
				#subprocess.call(['/bin/bash', '-i', '-c', "update-server-auto"])
				#bash_command("update-server-auto")
				#subprocess.Popen(['/bin/bash', '-b', 'update-server-auto'])
			#	subprocess.Popen(['/bin/bash', '-i', '-c', 'update-server-auto'])
			
			#	yield from client.send_message(message.channel, "Finished updating the code to the latest git build.")

			else:
				yield from client.send_message(message.channel, "Piss off nu-male <:picklerickldab:373260795104067588><:picklerickrdab:373260846362525696>")
				

		elif message.content.startswith("host-fallout"):
		
			private = False 
		
			accepted = False 
			for role in message.author.roles:
				if role.name == "Admiral":
					accepted = True 
					break 
			if accepted:
				yield from client.send_message(message.channel, "Please wait, updating the code...")
				#os.system('sudo python3 /home/customer/1713/scripts/updateserverabspaths.py')
				yield from client.send_message(message.channel, "Updated the code.")
					#os.system('sudo rm -f /home/customer/1713/sharedinfo/*.txt')
					#os.system('sudo rm -f /home/customer/1713/1713-1/serverdata.txt')
					#os.system('sudo rm -f /home/customer/1713/1713-2/serverdata.txt')
					#os.system('sudo DreamDaemon /home/customer/1713/1713-1/1713.dmb 13000 -trusted -webclient -logself &')
					#time.sleep(5) # this is pretty important 
					#os.system('sudo DreamDaemon /home/customer/1713/1713-2/1713.dmb 13001 -trusted -webclient -logself &')
				yield from client.send_message(message.channel, "Attempted to bring up the 1713 server (Main Server)")
					#time.sleep(10) # ditto
					#os.system('sudo python3 /home/customer/1713/scripts/killsudos.py')
					#os.system('sudo rm -f /home/customer/1713/testserver/sharedinfo/*.txt')
					#os.system('sudo rm -f /home/customer/1713/1713-3/serverdata.txt')
					#os.system('sudo rm -f /home/customer/1713/1713-4/serverdata.txt')
					#os.system('sudo DreamDaemon /home/customer/1713/1713-3/1713.dmb 13002 -trusted -webclient -logself &')
					#time.sleep(5) # this is pretty important 
					#os.system('sudo DreamDaemon /home/customer/1713/1713-4/1713.dmb 13003 -trusted -webclient -logself &')
					#yield from client.send_message(message.channel, "Attempted to bring up Lebensraum (Testing Server)")
					#time.sleep(10) # ditto
					#os.system('sudo python3 /home/customer/1713/scripts/killsudos.py')

			else:
				yield from client.send_message(message.channel, "Piss off nu-male <:picklerickldab:373260795104067588><:picklerickrdab:373260846362525696>")
		
		elif message.content.startswith("kill-fallout"):
		
			private = False 
		
			accepted = False 
			for role in message.author.roles:
				if role.name == "Senate" or (private and "Git" in role.name and "Maintainer" in role.name):
					accepted = True 
					break 
					
			if accepted:
				#os.system('sudo python3 /home/customer/1713/scripts/kill1713.py')
				yield from client.send_message(message.channel, "Attempted to kill the 1713 server")
			else:
				yield from client.send_message(message.channel, "Piss off nu-male <:picklerickldab:373260795104067588><:picklerickrdab:373260846362525696>")
		

					#else:
	#	print(message.content.lower())
	#elif not message.content.startswith('God Says') and not message.content.startswith('Hitler Says') and not message.content.startswith('Stalin Says') and not message.content.startswith('Hirohito Says') and not message.content.startswith('Yahweh Says') and not message.content.startswith('!s'):
	#	f = open("god.txt","a")
	#	f.write(str(message.content).replace(" ","\n"))
	#	f.close()
			
client.run('')
