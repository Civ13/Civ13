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

elif map == "NAVAL":
	dmms.append("#include \"maps\\naval\\naval.dmm\"")

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
