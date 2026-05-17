/* old settings */

//BODY: {font-family: Verdana, sans-serif;}

// todo: remove message span class from the code

// .info					{color: #E1E1FF;} -> this is removed because it was the same as .notice

client/script = {"<style>
body {
	font-family: "Civ13Custom", "Book Antiqua", "Bookman Old Style", serif;
	font-size: 14px;
	background-color: #392611;
	color: #e1e1d7;
	text-rendering: optimizeLegibility;
	-webkit-font-smoothing: antialiased;
	-moz-osx-font-smoothing: grayscale;
	scrollbar-face-color: #a68b7d;
	scrollbar-shadow-color: #271a0c;
	scrollbar-highlight-color: #e1e1d7;
	scrollbar-3dlight-color: #a68b7d;
	scrollbar-darkshadow-color: #000000;
	scrollbar-track-color: #392611;
	scrollbar-arrow-color: #271a0c;
}

h1, h2, h3, h4, h5, h6	{color: #E1E1FF; font-family: "Book Antiqua", Georgia, Verdana, sans-serif;}

em						{font-style: normal;font-weight: bold;}

.motd					{color: #E1E1FF; font-family: "Civ13Custom", "Book Antiqua", Verdana, sans-serif;}
.motd h1, .motd h2, .motd h3, .motd h4, .motd h5, .motd h6
						{margin-top: 0.2em; margin-bottom: 0.2em; color: #E1E1FF;}
.motd a, .motd a:link, .motd a:visited, .motd a:active, .motd a:hover
						{color: #CD4C6C;}

.prefix					{font-weight: bold;}
.log_message			{color: #A9B6E7;	font-weight: bold;}
.small_message			{color: #E1E1FF;	font-weight: bold; font-size: 0.66em;}

a { color: #a68b7d; text-decoration: underline; }
a:hover { color: #e1e1d7; }

/* OOC */
.ooc					{font-weight: bold;}
.ooc img.text_tag		{width: 32px; height: 10px;}

.ooc .everyone			{color: #1E8CBE;}
.ooc .looc				{color: #75B5B5;}
.ooc .elevated			{color: #2e78d9;}
.ooc .mentor			{color: #2e78d9;}
.ooc .moderator			{color: #2ed9ab;}
.ooc .developer			{color: #a649bf;}
.ooc .admin				{color: #39ac41;}
.ooc .highstaff			{color: #b82e00;}

/* Chat Tags */
.text_tag {
	display: inline-block;
	padding: 1px 4px;
	border-radius: 3px;
	font-size: 10px;
	font-weight: bold;
	text-transform: uppercase;
	margin-right: 4px;
	vertical-align: middle;
	font-family: Arial, sans-serif;
	line-height: 1;
	border: 1px solid rgba(255, 255, 255, 0.1);
}

.tag-ooc { background-color: #1a56f0; color: white; border-color: #0d41bc; }
.tag-looc { background-color: #36b6a6; color: white; border-color: #2a8d81; }
.tag-dead, .tag-lobby { background-color: #6326c0; color: white; border-color: #4a1d8f; }
.tag-asay, .tag-admin, .tag-a-discord { background-color: #a123f0; color: white; border-color: #7b1ab8; }
.tag-mentor { background-color: #3986f0; color: white; border-color: #2b65b6; }
.tag-pm_in { background-color: #f01a1a; color: white; border-color: #b81414; }
.tag-pm_out_alt { background-color: #b04343; color: white; border-color: #8a3434; }
.tag-pm_other { background-color: #5092c0; color: white; border-color: #3d6f92; }
.tag-help { background-color: #ff0000; color: white; border-color: #cc0000; }
.tag-discord, .tag-discord2 { background-color: #00b0f0; color: white; border-color: #0089bc; }
.tag-ping { background-color: #f1c40f; color: #2c3e50; border-color: #f39c12; font-size: 9px; }

/* Admin: Private Messages */
.pm  .howto				{color: #ff0000;	font-weight: bold;		font-size: 200%;}
.pm  .in				{color: #ff0000;}
.pm  .out				{color: #ff0000;}
.pm  .other				{color: #1E8CBE;}

/* Admin: Channels */
.mod_channel			{color: #735638;	font-weight: bold;}
.mod_channel .admin		{color: #b82e00;	font-weight: bold;}
.admin_channel			{color: #9611D4;	font-weight: bold;}

/* Radio: Misc */
.deadsay				{color: #8657C5;}
.radio					{color: #4CA64C;}

/* Radio Channels */
.blueradio				{color: #6A80A9;}
.SSradio				{color: #466194;}
.redradio				{color: #B53232;}
.brownradio				{color: #7E6A46;}

/* Miscellaneous */
.name					{font-weight: bold;}
.say					{}
.alert					{color: #ff0000;}
h1.alert, h2.alert		{color: #ff0000;}
.ghostalert				{color: #5c00e6;	font-style: italic; font-weight: bold;}

.emote					{font-style: italic;}

/* Game Messages */

.attack					{color: #ff0000;}
.moderate				{color: #CC0000;}
.disarm					{color: #990000;}
.passive				{color: #660000;}

.red					{color: #ff3737}
.green					{color: #289120}
.green_bold				{color: #289120; font-weight: bold;}
.danger					{color: #ff3737; font-weight: bold;}
.userdanger				{color: #ff3737; font-weight: bold; font-size: 2.0em;}
.userdanger_yellow		{color: #ffff00; font-weight: bold; font-size: 2.5em;}
.hugedanger				{color: #ff3737; font-weight: bold; font-size: 3.0em;}
.warning				{color: #ff3737; font-style: italic;}
.rose					{color: #ff5050;}
.notice					{color: #5a6d8d;}
.ping					{color: #E1E1FF; font-weight: bold;}

.reflex_shoot			{color: #000099; font-style: italic;}

/* Languages */

.rough					{font-family: "Trebuchet MS", cursive, sans-serif;}
.say_quote				{font-family: Georgia, Verdana, sans-serif;}

.interface				{color: #704C70;}

.good				   {color: #839E69; font-weight: bold;}
.bad					{color: #ff3737; font-weight: bold;}

BIG IMG.icon 			{width: 32px; height: 32px;}

</style>"}
