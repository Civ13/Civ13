import sys 
import os 

if len(sys.argv) == 1:
	print("Not enough args provided.")
	sys.exit() 
	
print("Updating git...")
	
os.chdir("/home/customer/1713-git")
os.system("git pull")
os.system("git reset --hard origin/master")
	
map = sys.argv[1]
dmms = []

if map == "FOREST":
	dmms.append("#include \"maps\\forest\\level1.dmm\"")
	dmms.append("#include \"maps\\forest\\level2.dmm\"")
	dmms.append("#include \"maps\\forest\\level3.dmm\"")
elif map == "CITY":
	dmms.append("#include \"maps\\city\\level1.dmm\"")
elif map == "TOWER":
	dmms.append("#include \"maps\\tower\\level1.dmm\"")
#	dmms.append("#include \"maps\\tower\\level2.dmm\"")
#	dmms.append("#include \"maps\\tower\\level3.dmm\"")
#	dmms.append("#include \"maps\\tower\\level4.dmm\"")
#	dmms.append("#include \"maps\\tower\\level5.dmm\"")
#	dmms.append("#include \"maps\\tower\\level6.dmm\"")
#	dmms.append("#include \"maps\\tower\\level7.dmm\"")
#	dmms.append("#include \"maps\\tower\\level8.dmm\"")

elif map == "PILLAR":
	dmms.append("#include \"maps\\pillar\\fort.dmm\"")
	dmms.append("#include \"maps\\pillar\\sewers.dmm\"")
elif map == "REICHSTAG":
	dmms.append("#include \"maps\\REICHSTAG\\reichstag.dmm\"")
	#dmms.append("#include \"maps\\pillar\\sewers.dmm\"")
elif map == "CAMP":
	dmms.append("#include \"maps\\camp.dmm\"")
elif map == "PARTISAN":
	dmms.append("#include \"maps\\partisan\\partisan.dmm\"")
elif map == "ISLAND":
	dmms.append("#include \"maps\\island\\island.dmm\"")
elif map == "OCCUPATION":
	dmms.append("#include \"maps\\occupation\\occupation.dmm\"")
else:
	print("Invalid argument.")
	sys.exit()

DME = "/home/customer/1713-git/1713.dme"

lines = []
with open(DME, "r") as search:
	for line in search:
		lines.append(line)	
	search.close()
			
wroteDMMs = False
DME = open(DME, "w")
for line in lines:
	if ".dmm" in line:
		if not wroteDMMs:
			for line2 in dmms:
				DME.write(line2)
				DME.write("\n")
			dmms = []
			wroteDMMs = True
	else:
		DME.write(line)
			
DME.close()

os.system('sudo python3.5 /home/customer/1713/scripts/updateserverabspathsnogitpull.py')

# no longer used (was never used)
#lastMapSwapStatus = open("/home/customer/lastMapSwapStatus.txt", "w")
#lastMapSwapStatus.write(map)
