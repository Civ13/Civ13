#!/bin/bash
set -e

echo "Setting up BYOND."
rm -rf "$HOME/BYOND"
mkdir -p "$HOME/BYOND"
cd "$HOME/BYOND"
curl "http://www.byond.com/download/build/${BYOND_MAJOR}/${BYOND_MAJOR}.${BYOND_MINOR}_byond_linux.zip" -o byond.zip
unzip byond.zip
rm byond.zip
cd byond
make here
echo "Compiling the dme..."
retval=1
source $HOME/BYOND/byond/bin/byondsetup
cd /home/travis/build/Civ13-SS13/Civ13
DreamMaker -max_errors 0 civ13.dme | tee result.log
retval=$?
if ! grep '\- 0 errors, 0 warnings' result.log
then
	retval=1 #hard fail, due to warnings or errors
	echo "Failed to compile!"
	exit 1
	fi
