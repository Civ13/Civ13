# Civilization 13

[![Build Status](https://travis-ci.com/Civ13-SS13/Civ13.svg?branch=master)](https://travis-ci.com/Civ13-SS13/Civ13)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/civ13-SS13/civ13.svg?style=flat)
![GitHub repo size](https://img.shields.io/github/repo-size/civ13-SS13/civ13.svg?style=flat)

## WHAT IS THIS?

Civ13 (formerly 1713) is a game based on Space Station 13 code, which features several epochs of human history. (hence the name). It features both RP and Combat maps and gamemodes.

<kbd>
 <img src="https://i.imgur.com/napac0L.png">
</kbd>


## Civ13 Discord
[![discord](https://discordapp.com/api/guilds/468979034571931648/widget.png)](https://discord.gg/hBEtg4x)


## Official Website
https://1713.eu/


## Playing the game
You will need a windows machine or a virtual machine running it from another OS.

1. Download the latest BYOND distribution from http://www.byond.com/download/

2. Register a BYOND account at https://secure.byond.com/Join

3. Launch BYOND from **BYOND/bin/Byond.exe** and login.

4. Navigate to **Space Station 13** and search for the **Civilization 13** server.

5. You will start playing in seconds!


## Setting up a Server
1. You will need a windows or linux machine with the following apps installed:
 - Python 3.6 or above
 - Byond (latest version)
 - Git
 
 2. Navigate to the master folder where you want the game to be.
 
 3. Create a git-linked folder (on Linux, use ***sudo git clone https://github.com/Civ13-SS13/Civ13 civ13-git***).
 
 4. Use DreamMaker to create the DMB file (on Linux, go inside the civ13-git folder and use ***sudo DreamMaker civ13.dme***)
 
 5. Create another folder named **civ13** and manually copy the **UI**, **config** and **scripts** folders and the **civ13.dmb** and **civ13.rsc** files inside.
 
 6. Go inside the civ13 folder and run DreamDaemon (on Linux, run ***sudo DreamDaemon civ13.dmb [port] -trusted -logself -webclient***. Replace "port" with whatever port you want to use.
 
 7. You're all set! The server will be up and running.
