#!/bin/bash
set -e


if [ -d "$HOME/BYOND/byond/bin" ] && grep -Fxq "${BYOND_MAJOR}.${BYOND_MINOR}" $HOME/BYOND/version.txt;
then
	echo "Using cached directory."
else
	echo "Setting up BYOND."
	rm -rf "$HOME/BYOND"
	mkdir -p "$HOME/BYOND"
	cd "$HOME/BYOND"
	curl "http://www.byond.com/download/build/${BYOND_MAJOR}/${BYOND_MAJOR}.${BYOND_MINOR}_byond_linux.zip" -o byond.zip
	unzip byond.zip
	rm byond.zip
	cd byond
	make here
	echo "$BYOND_MAJOR.$BYOND_MINOR" > "$HOME/BYOND/version.txt"
	DreamMaker -max_errors 0 $HOME/Civ13-SS13/Civ13/civ13.dme 2>&1 | tee result.log
	retval=$?
	if ! grep '\- 0 errors, 0 warnings' result.log
	then
		retval=1 #hard fail, due to warnings or errors
	fi
