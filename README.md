# Metro13

## Description

Branched from Civilization13, Metro13 aims to replicate the atmosphere and setting of the Metro 2033 series in Space Station 13 with faction based survival gameplay.

<kbd>
 <img src="https://i.imgur.com/LMYske3.png">
</kbd>

We're currently in the Pre-Alpha stage, but tests are planned in the future, check out our discord below for updates!

## Metro13 Discord
[Say Hi to the Nazis!](https://discord.gg/hBEtg4x)


## Our Wiki
https://metro13.fandom.com/wiki/


## Trello
https://trello.com/b/s3iubf6J/metro-13-roadmap


## Playing the game
Tutorial stolen from https://github.com/Civ13-SS13/Civ13/blob/master/README.md

You will need a windows machine or a virtual machine running it from another OS.

1. Download the latest BYOND distribution from http://www.byond.com/download/

2. Register a BYOND account at https://secure.byond.com/Join

3. Launch BYOND from **BYOND/bin/Byond.exe** and login.

4. Navigate to **Space Station 13** and search for the **Civilization 13** server.

5. You will start playing in seconds!


## Setting up a Server
Tutorial stolen from https://github.com/Civ13-SS13/Civ13/blob/master/README.md

1. You will need a linux machine for the automated install, preferably Ubuntu. Open the command line.
 
 2. Download the INSTALL file. You can use ***wget https://raw.githubusercontent.com/Civ13-SS13/Civ13/master/INSTALL*** for it. If you don't have wget installed, use ***sudo apt install*** wget first.
 
 3. Use **sudo bash INSTALL** and it should install everything you need.
 
 7. You're all set! Run the **launch.py** file inside the **scripts/** folder. Use ***python3 launch.py***.
 
 
 ## For Developers
 Here's how to activate debug mode after having downloaded the repository
 1. Change the line ``//#define TESTING``to ``#define TESTING`` in the first line of the file global.md which can be found in the ``/code/`` folder.
2. Rebuild the Server in Dream Maker.
3. When you enter the game, type ``debugtime`` into the verb bar at the bottom right of the screen.
4. Receive your inspirational message and get debugging!
