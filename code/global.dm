//#define TESTING
#if DM_VERSION < 512
#warn This compiler is out of date. You may experience issues with projectile animations.
#endif

var/bearcave_ticking = FALSE
var/wolfcave_ticking = FALSE

				//For single Mayor/Governor maps
var/global_export_tax = 0	//Global Export Tax
var/global_import_tax = 0	//Global Import Tax
var/diary			   = null
var/attack_log		  = null
var/href_logfile		= null
var/customserver_name   = null
var/game_version		= "Civilization 13"
var/changelog_hash	  = ""


var/round_progressing = TRUE

var/datum/configuration/config	  = null

var/Debug2 = FALSE
var/datum/debug/debugobj


var/join_motd = null

var/datum/nanomanager/nanomanager		= new() // NanoManager, the manager for Nano UIs.

var/season = "SPRING"
var/game_hour = 0

var/list/chicken_count = list()
var/list/turkey_count = list()
var/list/cow_count = list()
var/list/bison_count = list()
var/list/goat_count = list()
var/list/sheep_count = list()
var/list/pig_count = list()
var/list/deer_count = list()
var/list/wolf_count = list()
var/list/bear_count = list()
var/list/boar_count = list()
/proc/get_season()
	return capitalize(lowertext(season))

// For FTP requests. (i.e. downloading runtime logs.)
// However it'd be ok to use for accessing attack logs and such too, which are even laggier.
var/fileaccess_timer = 0
var/custom_event_msg = null

// Bomb cap!
var/max_explosion_range = 14

// Announcer intercom, because too much stuff creates an intercom for one message then hard del()s it.
//var/global/obj/item/radio/intercom/global_announcer = new(null)

// "convenient" (shitcode) way to make normal windows look like nanoUI, since BYOND won't load stylesheets normally - Kachnov
var/common_browser_style = {"
<meta charset="UTF-8">
<style>
body
{
	padding: 0;
	margin: 0;
	background-color: #271a0c;
	font-size: 16px;
	color: #ffffff;
	line-height: 170%;
}

hr
{
	background-color: #271a0c;
	height: 1px;
}

a, a:link, a:visited, a:active, .linkOn, .linkOff
{
	color: #ffffff;
	text-decoration: none;
	background: #404040;
	border: 1px solid #3d3d29;
	padding: 1px 4px 1px 4px;
	margin: 0 2px 0 0;
	cursor:default;
}

a:hover
{
	color: #ebebe0;
	background: #7a7a52;
}

a.white, a.white:link, a.white:visited, a.white:active
{
	color: #ebebe0;
	text-decoration: none;
	background: #ffffff;
	border: 1px solid #3d3d29;
	padding: 1px 4px 1px 4px;
	margin: 0 2px 0 0;
	cursor:default;
}

a.white:hover
{
	color: #ffffff;
	background: #bfbfbf;
}

.linkOn, a.linkOn:link, a.linkOn:visited, a.linkOn:active, a.linkOn:hover
{
	color: #ffffff;
	background: #595959;
	border-color: #888888;
}

.linkOff, a.linkOff:link, a.linkOff:visited, a.linkOff:active, a.linkOff:hover
{
	color: #ffffff;
	background: #999999;
	border-color: #888888;
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
	color: #eaeae1;
}

h1
{
	font-size: 20px;
}

h2
{
	font-size: 18px;
}

h3
{
	font-size: 16px;
}

h4
{
	font-size: 14px;
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
	border-bottom: 2px solid #3d3d29;
	background: #383838;
	color: #98B0C3;
	font-size: 22px;
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
	color: #3e2a14;
}

.notice
{
	position: relative;
	background: #E9C183;
	color: #15345A;
	font-size: 14px;
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
	border: 1px solid #ebebe0;
	padding: 4px;
	margin: 3px 0;
}

.block
{
	padding: 8px;
	margin: 10px 4px 4px 4px;
	border: 1px solid #ebebe0;
	background-color: #3e2a14;
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
	background: #ebebe0;
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
</style>
"}
//green on black
var/computer_browser_style = {"
<meta charset="UTF-8">
<style>
body
{
	padding: 0;
	margin: 0;
	background-color: #161616;
	font-family: "Lucida Console", monospace;
	font-size: 16px;
	color: #009933;
	line-height: 170%;
}

hr
{
	background-color: #161616;
	height: 1px;
}

a, a:link, a:visited, a:active, .linkOn, .linkOff
{
	color: #00ff00;
	text-decoration: none;
	background: #1D1D1D;
	border: 1px solid #161616;
	padding: 1px 4px 1px 4px;
	margin: 0 2px 0 0;
	cursor:default;
}

a:hover
{
	color: #005b1e;
	background: #141414;
}

a.white, a.white:link, a.white:visited, a.white:active
{
	color: #ebebe0;
	text-decoration: none;
	background: #ffffff;
	border: 1px solid #3d3d29;
	padding: 1px 4px 1px 4px;
	margin: 0 2px 0 0;
	cursor:default;
}

a.white:hover
{
	color: #ffffff;
	background: #bfbfbf;
}

.linkOn, a.linkOn:link, a.linkOn:visited, a.linkOn:active, a.linkOn:hover
{
	color: #ffffff;
	background: #595959;
	border-color: #888888;
}

.linkOff, a.linkOff:link, a.linkOff:visited, a.linkOff:active, a.linkOff:hover
{
	color: #ffffff;
	background: #999999;
	border-color: #888888;
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
	color: #eaeae1;
}

h1
{
	font-size: 20px;
}

h2
{
	font-size: 18px;
}

h3
{
	font-size: 16px;
}

h4
{
	font-size: 16px;
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
	border-bottom: 2px solid #3d3d29;
	background: #383838;
	color: #98B0C3;
	font-size: 20px;
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
	color: #3e2a14;
}

.notice
{
	position: relative;
	background: #E9C183;
	color: #15345A;
	font-size: 14px;
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
	border: 1px solid #ebebe0;
	padding: 4px;
	margin: 3px 0;
}

.block
{
	padding: 8px;
	margin: 10px 4px 4px 4px;
	border: 1px solid #ebebe0;
	background-color: #3e2a14;
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
	background: #ebebe0;
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
</style>
"}
