//factions only
#define PIRATES "PIRATES"
#define CIVILIAN "CIVILIAN"
#define INDIANS "INDIANS"
#define BRITISH "BRITISH"
#define ROMAN "ROMAN"
#define AMERICAN "AMERICAN"

// used for languages only
#define ENGLISH "ENGLISH"
#define CARIB "CARIB"
#define LATIN "LATIN"
#define UKRAINIAN "UKRAINIAN"
#define CHINESE "CHINESE"
#define HEBREW "HEBREW"
#define SWAHILI "SWAHILI"
#define ZULU "ZULU"
#define AINU "AINU"
#define GAELIC "GAELIC"
#define ITALIAN "ITALIAN"
#define CHEROKEE "CHEROKEE"
#define IROQUOIS "IROQUOIS"
#define SIOUX "SIOUX"
#define APACHE "APACHE"
#define NAVAJO "NAVAJO"
#define CHINOOK "CHINOOK"
#define COMANCHE "COMANCHE"
#define MAYAN "MAYAN"
#define AZTEC "AZTEC"
#define HAWAIIAN "HAWAIIAN"
#define INUIT "INUIT"
#define OLDNNORSE "OLDNORSE"
#define EGYPTIAN "EGYPTIAN"
#define PASHTO "PASHTO"
#define DARI "DARI"
#define FARSI "FARSI"

//used for languages & factions
#define SPANISH "SPANISH"
#define PORTUGUESE "PORTUGUESE"
#define FRENCH "FRENCH"
#define DUTCH "DUTCH"
#define JAPANESE "JAPANESE"
#define RUSSIAN "RUSSIAN"
#define CHECHEN "CHECHEN"
#define FINNISH "FINNISH"
#define NORWEGIAN "NORWEGIAN"
#define SWEDISH "SWEDISH"
#define DANISH "DANISH"
#define GREEK "GREEK"
#define ARAB "ARAB"
#define GERMAN "GERMAN"
#define VIETNAMESE "VIETNAMESE"
#define KOREAN "KOREAN"
#define FILIPINO "FILIPINO"
#define POLISH "POLISH"
#define MONGOLIAN "MONGOLIAN"
#define SCOTS "SCOTS"
#define SCOTTISHGAELIC "SCOTTISHGAELIC"
#define WELSH "WELSH"
#define BLUEFACTION "BLUEFACTION"
#define REDFACTION "REDFACTION"
#define TSFSR "TSFSR"
#define CAFR "CAFR"


/proc/faction_const2name(constant,age = 0)
	switch(constant)
		if (PIRATES)
			return "Pirates"

		if (BRITISH)
			if (age >= 6)
				return "United Kingdom"
			else
				if (map.ID == "TWOTRIBES")
					return "Red Tribe"
				else
					return "British Empire"

		if (CIVILIAN)
			switch(map.ID)
				if ("TSARITSYN")
					return "Red Army"
				if ("YELTSIN")
					return "Militia"
				if ("AFRICAN_WARLORDS")
					return "Yellowagwana Wartribe"
				if ("TADOJSVILLE")
					return "United Nations Peacekeepers"
				if ("WHITERUN")
					return "Stormcloaks"
				if ("CAPITOL_HILL")
					return "Rioters"
				if ("WACO")
					return "Branch Davidians"
				if ("MISSIONARY_RIDGE")
					return "Confederates"
				if ("TANTIVEIV")
					return "Rebels"
				if ("RUHR_UPRISING")
					return "Ruhr Red Army"
				if ("MAGISTRAL")
					return "DRA Army"
				if ("BANK_ROBBERY" || "DRUG_BUST")
					return "Police Department"
				if ("LONG_MARCH")
					return "Red Army"
				if ("EFT_FACTORY")
					return "Scavs"
				else
					if (age >= 6)
						return "Civilians"
					else
						return "Colonists"

		if (INDIANS)
			switch(map.ID)
				if ("AFRICAN_WARLORDS")
					return "Blugisi Wartribe"
				if ("TADOJSVILLE")
					return "Mercenary Warbands"
				if ("EAST_LOS_SANTOS")
					return "Ballas"
				else
					return "Native Tribe"

		if (PORTUGUESE)
			return "Portuguese Empire"

		if (SPANISH)
			return "Spanish Empire"

		if (FRENCH)
			if (age >= 4)
				return "French Republic"
			else
				if (map.ID == "TWOTRIBES")
					return "Blue Tribe"
				else
					return "French Empire"

		if (DUTCH)
			if (map.ID == "OPERATION_FALCON")
				return "Dutch Royal Army"
			else
				if (age >= 6)
					return "Dutch Monarchy"
				else
					return "Dutch Republic"

		if (ITALIAN)
			if (age >= 7)
				return "Italian Republic"
			else
				return "Italian Monarchy"

		if (JAPANESE)
			return "Japanese Empire"

		if (RUSSIAN)
			switch(map.ID)
				if ("YELTSIN")
					return "Russian Army"
				if ("GROZNY")
					return "Russian Federal Forces"
				if ("CONSTANTINOPOLI")
					return "Slavo-Russian Imperial Army"
				if ("TSARITSYN")
					return "White Army"
				if ("BANK_ROBBERY")
					return "Robbers"
				if ("DRUG_BUST")
					return "Rednikov Mobsters"
				if ("EFT_FACTORY")
					return "BEAR"
				else
					switch(age)
						if (6 to 7)
							return "Soviet Union"
						if (8)
							return "Russian Federation"
						else
							return "Russian Empire"

		if (ROMAN)
			switch(map.ID)
				if ("WHITERUN") 
					return "Imperial Army"
				if ( "CONSTANTINOPOLI")
					return "Exercitus Latinus Imperialis"
				else
					return "Roman Republic"

		if (CHECHEN)
			return "Chechen Republic of Ichkeria"

		if (FINNISH)
			return "Republic of Finland"

		if (NORWEGIAN)
			if (map.ID == "CLASH")
				return "Bear Clan"
			else
				return "Kingdom of Norway"

		if (SWEDISH)
			return "Kingdom of Sweden"

		if (DANISH)
			if (map.ID == "CLASH")
				return "Raven Clan"
			else
				return "Kingdom of Denmark"

		if (GERMAN)
			if (age == 6)
				return "Third Reich"
			else if (age >= 7)
				return "Federal Republic of Germany"
			else if (map.ID == "RUHR_UPRISING")
				return "Weimar Republic"
			else
				return "German Empire"
		if (GREEK)
			return "Greek States"

		if (ARAB)
			if (age >= 6)
				switch(map.ID)
					if ("ARAB_TOWN")
						return "Hezbollah"
					if ("KANDAHAR" || "HILL_3234" || "MAGISTRAL")
						return "Mujahideen"
					if ("SYRIA")
						return "Syrian Armed Forces"
					else
						return "Insurgents"
			else
				return "Arabic Caliphate"

		if (AMERICAN)
			switch(map.ID)
				if ("ARAB_TOWN")
					return "IDF"
				if ("CAPITOL_HILL")
					return "American Government"
				if ("WACO")
					return "ATF"
				if ("TANTIVEIV")
					return "Imperials"
				if ("EAST_LOS_SANTOS")
					return "Grove Street Families"
				if ("EFT_FACTORY")
					return "USEC"
				if ("SYRIA")
					return "Free Syrian Army"
				else
					return "United States"

		if (VIETNAMESE)
			return "Vietnamese"

		if (POLISH)
			if (map.ID == "WARSAW")
				return "Polish Home Army"
			else
				return "Polish"

		if (CHINESE)
			if (map.ID == "LONG_MARCH")
				return "National Army"
			else
				return "Chinese"

		if (EGYPTIAN)
			return "Egyptian"

		if (KOREAN)
			return "Korean"

		if (IROQUOIS)
			return "Iroquois"
		
		if (SIOUX) 
			return "Sioux Natives"

		if (APACHE) 
			return "Apache Natives"

		if (NAVAJO) 
			return "Navajo Natives"

		if (CHINOOK) 
			return "Chinook Natives"

		if (COMANCHE) 
			return "Comanche Natives"

		if (MAYAN) 
			return "Mayans"

		if (AZTEC)
			return "Aztecs"

		if (HAWAIIAN)
			return "Hawaiians"

		if (FILIPINO)
			return "Filipino"
		
		if (BLUEFACTION)
			return "Blugoslavia"
		
		if (REDFACTION)
			return "Redmenia"
		
		if (CAFR)
			return "Central Asian Federal Republic"
		
		if (TSFSR)
			return "Turkestan SFSR"
