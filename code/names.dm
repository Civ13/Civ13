
var/list/first_names_male = file2list("config/names/first_male.txt")
var/list/first_names_female = file2list("config/names/first_female.txt")
var/list/last_names = file2list("config/names/last.txt")

var/list/first_names_male_pirate = file2list("config/names/first_male_pirate.txt")
var/list/first_names_female_pirate = file2list("config/names/first_female_pirate.txt")
var/list/last_names_pirate = file2list("config/names/last_pirate.txt")

var/list/first_names_male_english = file2list("config/names/first_male_english.txt")
var/list/first_names_female_english = file2list("config/names/first_female_english.txt")
var/list/last_names_english = file2list("config/names/last_english.txt")

var/list/first_names_male_french = file2list("config/names/first_male_french.txt")
var/list/first_names_female_french = file2list("config/names/first_female_french.txt")
var/list/last_names_french = file2list("config/names/last_french.txt")

var/list/first_names_male_portuguese = file2list("config/names/first_male_portuguese.txt")
var/list/first_names_female_portuguese = file2list("config/names/first_female_portuguese.txt")
var/list/last_names_portuguese = file2list("config/names/last_portuguese.txt")

var/list/first_names_male_spanish = file2list("config/names/first_male_spanish.txt")
var/list/first_names_female_spanish = file2list("config/names/first_female_spanish.txt")
var/list/last_names_spanish = file2list("config/names/last_spanish.txt")

var/list/first_names_male_carib = file2list("config/names/first_carib.txt")
var/list/first_names_female_carib = file2list("config/names/first_carib.txt")
var/list/last_names_carib = file2list("config/names/last_carib.txt")

var/list/verbs = file2list("config/names/verbs.txt")
var/list/adjectives = file2list("config/names/adjectives.txt")
//loaded on startup because of "
//would include in rsc if ' was used