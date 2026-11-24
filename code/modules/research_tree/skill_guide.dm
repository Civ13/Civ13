// "How do I raise this?" for every skill (chat feedback, 2026-11-17): one
// window listing each body skill and, on book-research worlds, each
// discipline, with the viewer's level, what raises it and what comes next.
// Opened from IC > Skills Guide; the Status and Scholarship tabs point at it.

// skill => list(what it does, what raises it). Magic is left out on purpose.
var/global/list/skill_guide_rows = skill_guide_rows_table()
/proc/skill_guide_rows_table()
	return list(
	"strength" = list("Melee damage, mining and woodcutting speed.", "Mining, woodcutting, melee fights and exercise equipment."),
	"crafting" = list("Which recipes and workbenches you can use, crafting speed and the quality of weapons you make.", "Making anything. Things you have not made before teach far more than repeats."),
	"dexterity" = list("Dodging melee attacks and movement speed.", "Melee fights, dodging and exercise equipment."),
	"stamina" = list("How long you can run, fight and work before tiring.", "Running, hard work and exercise equipment."),
	"swords" = list("Damage with swords.", "Sword fights with people and training dummies."),
	"bows" = list("Chance to hit with a bow.", "Shooting targets with arrows."),
	"rifle" = list("Chance to hit with a rifle.", "Shooting targets with a rifle."),
	"pistol" = list("Chance to hit with a pistol.", "Shooting targets with a pistol."),
	"machinegun" = list("Chance to hit with a machine gun.", "Shooting targets with a machine gun."),
	"throwing" = list("Chance to hit with thrown weapons.", "Throwing weapons made for throwing."),
	"medical" = list("Healing from bandages and medicine, and whether surgery succeeds.", "Surgery, treating wounds and butchering."),
	"farming" = list("Ploughing speed, checking a plant's water, and seeds and crops per harvest.", "Planting, ploughing and harvesting."),
	"hunting" = list("Meat and fat from butchering.", "Butchering dead animals."),
	"swimming" = list("How well you cross deep and rough water.", "Swimming. New kinds of water teach more."),
	"unarmed" = list("Damage with your fists.", "Landing punches in real fights, and conditioning your hands on a makiwara post, a gravel pail or bare rock."),
	"philosophy" = list("Founding a religion and writing language books and holy books.", "Studying a chapter you had not studied before, tutoring someone through one, writing or copying a chapter and comparing notes."))

// discipline => what raises it, beyond bench work on its own subjects.
var/global/list/discipline_guide_rows = discipline_guide_rows_table()
/proc/discipline_guide_rows_table()
	return list(
	"mathematics" = "Half of everything you learn in any other discipline also goes here. Mastering Philosophy adds to it.",
	"engineering" = "Research, study and writing of building, tool and machine subjects, prototypes, and mastering Crafting.",
	"natural_science" = "Practise with a specimen box up to 24. From 24 to 36, hold two different ores, two open containers with different water, or matching unfired and fired pottery. Use IC &gt; Investigate Samples. From 36 to 60, compare an ore with its smelted product or sand with a glass sheet, or use Investigate Reaction at a laboratory reaction bench after securing its inputs. New comparisons teach more than repeats. No research bench, active chapter or Swimming skill is required. Recording finds, chapter fieldwork and mastering Swimming are separate ways to learn.",
	"medicine" = "Research, study and writing of medical subjects, surgery written into a book, and mastering Medical.",
	"agriculture" = "Research, study and writing of farming subjects, foraging and butchering written into a book, and mastering Farming or Hunting.",
	"military" = "Research, study and writing of weapon subjects, shooting written into a book, and mastering a weapon skill.")

// The next recipe level above `have` for a skill: list(level as 0-250, names), or null.
/proc/skill_guide_next_recipes(statname, have)
	var/next_level = null
	var/list/names = list()
	for (var/list/entry in recipe_skill_table)
		if (entry[1] != statname || entry[2] <= have)
			continue
		if (isnull(next_level) || entry[2] < next_level)
			next_level = entry[2]
			names = list()
		if (entry[2] == next_level)
			for (var/match in entry[3])
				if (names.len >= 5)
					break
				if (istext(match))
					names += match
				else if (islist(match))
					names += jointext(match, " ")
				else if (ispath(match, /atom))
					var/atom/product = match
					names += initial(product.name)
	return isnull(next_level) ? null : list(round(next_level * 100, 1), names)

/mob/living/human/proc/skill_guide_html()
	var/list/html = list("<html><head><title>Skills Guide</title><style>body{font-family:Verdana,sans-serif;font-size:12px;background:#1b1b1b;color:#ddd}h2{color:#e8c26a;margin:10px 0 4px}table{border-collapse:collapse;width:100%}td{border-top:1px solid #444;padding:4px;vertical-align:top}.lvl{color:#9fd08a;font-weight:bold;white-space:nowrap}.dim{color:#aaa}</style></head><body>")
	html += "<h2>Body skills</h2><div class='dim'>Everyone starts near 100. A skill stops at 250. A good mood raises every skill and a bad mood lowers it.</div><table>"
	var/book_world = learning_by_doing_enabled()
	for (var/statname in skill_guide_rows)
		if (!islist(stats[statname]))
			continue
		var/list/row = skill_guide_rows[statname]
		var/level = round(getStatCoeff(statname) * 100, 1)
		var/list/next_lines = list()
		var/list/recipes = skill_guide_next_recipes(statname, getStatCoeff(statname))
		if (recipes)
			var/list/recipe_names = recipes[2]
			next_lines += "At [recipes[1]] you can make: [recipe_names.len ? html_encode(jointext(recipe_names, ", ")) : "more recipes"]."
		var/discipline = skill_mastery_disciplines[statname]
		if (book_world && discipline)
			for (var/list/M in skill_mastery_milestones)
				if (stats[statname][1] < M[1] - 0.01)
					next_lines += "At [M[1]] you become [M[3]] and gain [M[2]] levels of [scholar_disciplines[discipline]]."
					break
		html += "<tr><td><b>[capitalize(statname == "machinegun" ? "machine gun" : statname)]</b><br><span class='lvl'>[level]</span></td><td>[row[1]]<br><b>Raise it by:</b> [row[2]][next_lines.len ? "<br><span class='dim'>[jointext(next_lines, " ")]</span>" : ""]</td></tr>"
	html += "</table>"
	html += "<div class='dim'>Working within 2 tiles of someone at least a quarter better than you at a skill teaches you double.</div>"
	if (book_world)
		html += "<h2>Scholarship</h2><div class='dim'>Disciplines run from 0 to 100. Each age after the Stone Age needs 12 more levels in a chapter's discipline and half that in Basic Mathematics. All of them grow by working at a research bench, studying chapters, writing them and hands-on work written into a book.</div><table>"
		for (var/discipline in scholar_disciplines)
			html += "<tr><td><b>[scholar_disciplines[discipline]]</b><br><span class='lvl'>[round(scholar_level(discipline))]</span></td><td><b>Also raised by:</b> [discipline_guide_rows[discipline]]</td></tr>"
		html += "</table>"
	html += "</body></html>"
	return jointext(html, "")

/mob/living/human/verb/skills_guide()
	set name = "Skills Guide"
	set desc = "See every skill, your level, what raises it and what comes next."
	set category = "IC"
	show_browse(src, skill_guide_html(), "window=skills_guide;size=620x640")
