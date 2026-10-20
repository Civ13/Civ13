#!/bin/bash
set -e
echo "Setting up the system for BYOND compilation."
sudo dpkg --add-architecture i386
# Install the build dependencies only. Upgrading the entire hosted image can
# trigger unrelated Firefox/snap provisioning and fail before BYOND is installed.
sudo env DEBIAN_FRONTEND=noninteractive apt-get update
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y python3 wget git unzip make sudo
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y libstdc++6:i386 libgcc1:i386 libc6-i386 libcurl4:i386 lib32z1 libncurses6 libncurses6:i386

echo "Setting up BYOND."
rm -rf "BYOND"
mkdir -p "BYOND"
cd "BYOND"
# Bound transient download failures without weakening TLS or changing source/version.
wget --timeout=60 --tries=3 --waitretry=5 -O 516.1681_byond_linux.zip "https://civ13.com/downloads/516.1681_byond_linux.zip"
ls
unzip -o 516.1681_byond_linux.zip
cd byond
make here
echo "Compiling the dme..."
retval=1
source /home/runner/work/Civ13/Civ13/BYOND/byond/bin/byondsetup
cd /home/runner/work/Civ13/Civ13/
python3 scripts/build-crafting-atlas.py --catalog-only --game-catalog UI/crafting-atlas.json
DreamMaker -max_errors 0 civ13.dme | tee result.log
retval=$?
if ! grep '\- 0 errors, 0 warnings' result.log
then
	retval=1 #hard fail, due to warnings or errors
	echo "Failed to compile!"
	exit 1
	fi
