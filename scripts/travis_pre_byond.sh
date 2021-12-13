#!/bin/bash
set -e

echo "Setting up BYOND."
rm -rf "BYOND"
mkdir -p "BYOND"
cd "BYOND"
curl "https://www.byond.com/download/build/514/514.1571_byond_linux.zip" -o byond.zip
unzip -o byond.zip
cd byond
make here
echo "Compiling the dme..."
retval=1
source /home/runner/work/Civ13/Civ13/BYOND/byond/bin/byondsetup
cd /home/runner/work/Civ13/Civ13/
DreamMaker -max_errors 0 civ13.dme | tee result.log
retval=$?
if ! grep '\- 0 errors, 0 warnings' result.log
then
	retval=1 #hard fail, due to warnings or errors
	echo "Failed to compile!"
	exit 1
	fi
