//#define TESTING
#if DM_VERSION < 506
#warn This compiler is out of date. You may experience issues with projectile animations.
#endif

//var/list/init_lights = list()


//var/global/list/global_map = null



var/diary               = null
var/attack_log          = null
var/href_logfile        = null
var/station_name        = null//"CEV Eris"
//var/station_short       = "Eris"
//var/const/dock_name     = "N.A.S. Crescent"
//var/const/boss_name     = "Central Command"
//var/const/boss_short    = "Centcomm"
//var/const/company_name  = "NanoTrasen"
//var/const/company_short = "NT"
var/game_version        = "WW13"
var/changelog_hash      = ""
//var/game_year           = (text2num(time2text(world.realtime, "YYYY")) + 544)

var/round_progressing = TRUE
//var/master_mode       = "WW2" // "extended"
//var/secret_force_mode = "WW2"   // if this is anything but "secret", the secret rotation will forceably choose this mode.

//var/host = null //only here until check @ code\modules\ghosttrap\trap.dm:112 is fixed


//var/list/bombers       = list()
//var/list/lastsignalers = list() // Keeps last 100 signals here in format: "[src] used \ref[src] @ location [loc]: [freq]/[code]"
//var/list/lawchanges    = list() // Stores who uploaded laws to which silicon-based lifeform, and what the law was.

//var/list/monkeystart     = list()
//var/list/wizardstart     = list()


//var/list/latejoin_gateway = list()
//var/list/latejoin_cryo    = list()
//var/list/latejoin_cyborg  = list()

//var/list/prisonwarp         = list() // Prisoners go to these
//var/list/holdingfacility    = list() // Captured people go here
//var/list/xeno_spawn         = list() // Aliens spawn at at these.
//var/list/tdome1             = list()
//var/list/tdome2             = list()
//var/list/tdomeobserve       = list()
//var/list/tdomeadmin         = list()
//var/list/prisonsecuritywarp = list() // Prison security goes to these.
//var/list/prisonwarped       = list() // List of players already warped.


var/datum/configuration/config      = null
//var/datum/sun/sun                   = null
/*
var/list/combatlog = list()
var/list/IClog     = list()
var/list/OOClog    = list()
var/list/adminlog  = list()
*/
//var/list/powernets = list()

var/Debug2 = FALSE
var/datum/debug/debugobj

//var/datum/moduletypes/mods = new()

//var/gravity_is_on = TRUE

var/join_motd = null

var/datum/nanomanager/nanomanager		= new() // NanoManager, the manager for Nano UIs.

//var/list/awaydestinations = list() // Away missions. A list of landmarks that the warpgate can take you to.

var/season = "SPRING"

/proc/get_weather()
	. = get_weather_default(weather)
	if (. == "none")
		return "Clear skies"
	return "It's [lowertext(.)]ing"

/proc/get_season()
	return capitalize(lowertext(season))
/*
// MySQL configuration
var/sqladdress = "localhost"
var/sqlport    = "3306"
var/sqldb      = "tgstation"
var/sqllogin   = "root"
var/sqlpass    = ""

// Feedback gathering sql connection
var/sqlfdbkdb    = "test"
var/sqlfdbklogin = "root"
var/sqlfdbkpass  = ""
var/sqllogging   = FALSE // Should we log deaths, population stats, etc.?

// Forum MySQL configuration. (for use with forum account/key authentication)
// These are all default values that will load should the forumdbconfig.txt file fail to read for whatever reason.
var/forumsqladdress = "localhost"
var/forumsqlport    = "3306"
var/forumsqldb      = "tgstation"
var/forumsqllogin   = "root"
var/forumsqlpass    = ""
var/forum_activated_group     = "2"
var/forum_authenticated_group = "10"
*/
// For FTP requests. (i.e. downloading runtime logs.)
// However it'd be ok to use for accessing attack logs and such too, which are even laggier.
var/fileaccess_timer = 0
var/custom_event_msg = null

/*
// Database connections. A connection is established on world creation.
// Ideally, the connection dies when the server restarts (After feedback logging.).
var/DBConnection/dbcon     = new() // Feedback    database (New database)
var/DBConnection/dbcon_old = new() // /tg/station database (Old database) -- see the files in the SQL folder for information on what goes where.
*/
/*

// Reference list for disposal sort junctions. Filled up by sorting junction's New()
/var/list/tagger_locations = list()

// Used by robots and robot preferences.
var/list/robot_module_types = list(
	"Standard", "Engineering", "Surgeon",  "Crisis",
	"Miner",    "Janitor",     "Service",      "Clerical", "Security",
	"Research"
)

// Some scary sounds.
var/static/list/scarySounds = list(
	'sound/weapons/thudswoosh.ogg',
	'sound/weapons/Taser.ogg',
	'sound/weapons/armbomb.ogg',
	'sound/voice/hiss1.ogg',
	'sound/voice/hiss2.ogg',
	'sound/voice/hiss3.ogg',
	'sound/voice/hiss4.ogg',
	'sound/voice/hiss5.ogg',
	'sound/voice/hiss6.ogg',
	'sound/effects/Glassbr1.ogg',
	'sound/effects/Glassbr2.ogg',
	'sound/effects/Glassbr3.ogg',
	'sound/items/Welder.ogg',
	'sound/items/Welder2.ogg',
	'sound/machines/airlock.ogg',
	'sound/effects/clownstep1.ogg',
	'sound/effects/clownstep2.ogg'
)
*/
// Bomb cap!
var/max_explosion_range = 14

// Announcer intercom, because too much stuff creates an intercom for one message then hard del()s it.
//var/global/obj/item/radio/intercom/global_announcer = new(null)

//var/list/station_departments = list("Command", "Medical", "Engineering", "Science", "Security", "Cargo", "Civilian")


// "convenient" (shitcode) way to make normal windows look like nanoUI, since BYOND won't load stylesheets normally - Kachnov
var/common_browser_style = {"

body
{
	padding: 0;
	margin: 0;
	background-color: #272727;
	font-size: 12px;
	color: #ffffff;
	line-height: 170%;
}

hr
{
	background-color: #40628a;
	height: 1px;
}

a, a:link, a:visited, a:active, .linkOn, .linkOff
{
	color: #ffffff;
	text-decoration: none;
	background: #40628a;
	border: 1px solid #161616;
	padding: 1px 4px 1px 4px;
	margin: 0 2px 0 0;
	cursor:default;
}

a:hover
{
	color: #40628a;
	background: #ffffff;
}

a.white, a.white:link, a.white:visited, a.white:active
{
	color: #40628a;
	text-decoration: none;
	background: #ffffff;
	border: 1px solid #161616;
	padding: 1px 4px 1px 4px;
	margin: 0 2px 0 0;
	cursor:default;
}

a.white:hover
{
	color: #ffffff;
	background: #40628a;
}

.linkOn, a.linkOn:link, a.linkOn:visited, a.linkOn:active, a.linkOn:hover
{
	color: #ffffff;
	background: #2f943c;
	border-color: #24722e;
}

.linkOff, a.linkOff:link, a.linkOff:visited, a.linkOff:active, a.linkOff:hover
{
	color: #ffffff;
	background: #999999;
	border-color: #666666;
}

a.icon, .linkOn.icon, .linkOff.icon
{
	position: relative;
	padding: 1px 4px 2px 20px;
}

a.icon img, .linkOn.icon img
{
	position: absolute;
	top: 0;
	left: 0;
	width: 18px;
	height: 18px;
}

ul
{
	padding: 4px 0 0 10px;
	margin: 0;
	list-style-type: none;
}

li
{
	padding: 0 0 2px 0;
}

img, a img
{
	border-style:none;
}

h1, h2, h3, h4, h5, h6
{
	margin: 0;
	padding: 16px 0 8px 0;
	color: #517087;
}

h1
{
	font-size: 15px;
}

h2
{
	font-size: 14px;
}

h3
{
	font-size: 13px;
}

h4
{
	font-size: 12px;
}

.uiWrapper
{

	width: 100%;
	height: 100%;
	padding-top:32px;
}

.uiTitle
{
	clear: both;
	padding: 6px 8px 6px 8px;
	border-bottom: 2px solid #161616;
	background: #383838;
	color: #98B0C3;
	font-size: 16px;
}

.uiTitleWrapper
 {
 	position:fixed;
 	top:0px;
 	left:0px;
 	right:0px;
 	z-index: 10
 }

 .uiTitleButtons
 {
 	position:fixed;
 	top:0px;
 	right:0px;
 	height:32px;
 	z-index:11;
 }

.uiTitle.icon
{
	padding: 6px 8px 6px 42px;
	background-position: 2px 50%;
	background-repeat: no-repeat;
}

.uiContent
{
	clear: both;
	padding: 8px;
	font-family: Verdana, Geneva, sans-serif;
}

.good
{
	color: #00ff00;
}

.average
{
	color: #d09000;
}

.bad
{
	color: #ff0000;
}

.highlight
{
	color: #8BA5C4;
}

.dark
{
	color: #272727;
}

.notice
{
	position: relative;
	background: #E9C183;
	color: #15345A;
	font-size: 10px;
	font-style: italic;
	padding: 2px 4px 0 4px;
	margin: 4px;
}

.notice.icon
{
	padding: 2px 4px 0 20px;
}

.notice img
{
	position: absolute;
	top: 0;
	left: 0;
	width: 16px;
	height: 16px;
}

div.notice
{
	clear: both;
}

.statusDisplay
{
	background: #000000;
	color: #ffffff;
	border: 1px solid #40628a;
	padding: 4px;
	margin: 3px 0;
}

.block
{
	padding: 8px;
	margin: 10px 4px 4px 4px;
	border: 1px solid #40628a;
	background-color: #202020;
}

.block h3
{
	padding: 0;
}

.progressBar
{
	width: 240px;
	height: 14px;
	border: 1px solid #666666;
	float: left;
	margin: 0 5px;
	overflow: hidden;
}

.progressFill
{
	width: 100%;
	height: 100%;
	background: #40628a;
	overflow: hidden;
}

.progressFill.good
{
	color: #ffffff;
	background: #00ff00;
}

.progressFill.average
{
	color: #ffffff;
	background: #d09000;
}

.progressFill.bad
{
	color: #ffffff;
	background: #ff0000;
}

.progressFill.highlight
{
	color: #ffffff;
	background: #8BA5C4;
}

.clearBoth
{
	clear: both;
}

.clearLeft
{
	clear: left;
}

.clearRight
{
	clear: right;
}

.line
{
	width: 100%;
	clear: both;
}

"}