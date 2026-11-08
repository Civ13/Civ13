// In-game bug reports (idea from CM-SS13's bug report datum, reimplemented for Civ13).
// This file only turns a report into text: cleaning player input, the GitHub issue body,
// the prefilled "new issue" link and reading the token line. It touches no game state,
// so tests/bug_reports compiles it on its own.

#define BUG_REPORT_TITLE_MAX 80
#define BUG_REPORT_TEXT_MAX 2000
#define BUG_REPORT_CONTEXT_MAX 120
#define BUG_REPORT_PREFILL_MAX 6000 // GitHub refuses very long new-issue links

// Player text: no control characters except line breaks, no carriage returns,
// trimmed and capped. multiline FALSE turns line breaks into spaces (titles).
/proc/bug_report_clean(text, max_length = BUG_REPORT_TEXT_MAX, multiline = TRUE)
	if (!istext(text))
		return ""
	var/list/out = list()
	var/count = 0
	var/size = length_char(text)
	for (var/i = 1, i <= size && count < max_length, i++)
		var/c = text2ascii_char(text, i)
		if (c == 13)
			continue
		if (c == 10)
			out += multiline ? "\n" : " "
		else if (c == 9)
			out += " "
		else if (c < 32 || c == 127)
			continue
		else
			out += ascii2text(c)
		count++
	var/cleaned = jointext(out, "")
	// Trim spaces and line breaks at both ends.
	var/start = 1
	var/finish = length(cleaned)
	while (start <= finish && (text2ascii(cleaned, start) == 32 || text2ascii(cleaned, start) == 10))
		start++
	while (finish >= start && (text2ascii(cleaned, finish) == 32 || text2ascii(cleaned, finish) == 10))
		finish--
	return finish >= start ? copytext(cleaned, start, finish + 1) : ""

// Player text goes into a fenced block, so links, @mentions, #references and markup
// stay inert. A player cannot close the fence early.
/proc/bug_report_fence(text)
	text = replacetext(text, "```", "'''")
	if (!length(text))
		text = "(not given)"
	return "```text\n[text]\n```"

// One table cell: one line, no pipes, backticks or markup that could break the table.
/proc/bug_report_cell(value)
	var/text = bug_report_clean("[value]", BUG_REPORT_CONTEXT_MAX, FALSE)
	for (var/bad in list("|", "`", "<", ">", "\[", "]", "*", "_", "@"))
		text = replacetext(text, bad, " ")
	return length(text) ? text : "-"

// The issue title as filed: one line, capped, with a marker so in-game reports are easy
// to find on GitHub.
/proc/bug_report_issue_title(title)
	title = bug_report_clean(title, BUG_REPORT_TITLE_MAX, FALSE)
	return "\[In-game] [length(title) ? title : "Bug report"]"

// context is an ordered list of label -> value (Server, Map, Round, ...).
/proc/bug_report_issue_body(reporter, what, steps, expected, list/context, admin_note)
	var/list/lines = list()
	lines += "Reported in game by **[bug_report_cell(reporter)]** with Help > Report bug, and approved by a game admin."
	lines += ""
	lines += "### What happened"
	lines += bug_report_fence(what)
	lines += ""
	lines += "### Steps to reproduce"
	lines += bug_report_fence(steps)
	lines += ""
	lines += "### What should have happened"
	lines += bug_report_fence(expected)
	if (length(context))
		lines += ""
		lines += "### Round details"
		lines += "| | |"
		lines += "| --- | --- |"
		for (var/label in context)
			lines += "| [bug_report_cell(label)] | [bug_report_cell(context[label])] |"
	admin_note = bug_report_clean(admin_note)
	if (length(admin_note))
		lines += ""
		lines += "### Admin note"
		lines += bug_report_fence(admin_note)
	return jointext(lines, "\n")

// Owner/name with GitHub's allowed characters only.
/proc/bug_report_repo_valid(repo)
	if (!istext(repo) || length(repo) < 3 || length(repo) > 100)
		return FALSE
	var/slash = findtext(repo, "/")
	if (slash < 2 || slash == length(repo) || findtext(repo, "/", slash + 1))
		return FALSE
	for (var/i = 1, i <= length(repo), i++)
		var/c = text2ascii(repo, i)
		if (i == slash)
			continue
		if (!((c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 45 || c == 46 || c == 95))
			return FALSE
	return TRUE

// The fallback when the server has no token: a link that opens GitHub's new-issue form
// filled in, for the admin to submit with their own account. The body is cut to keep
// the link short enough for GitHub.
/proc/bug_report_prefill_url(repo, title, body, labels)
	if (!bug_report_repo_valid(repo))
		return null
	if (length(body) > BUG_REPORT_PREFILL_MAX)
		body = copytext(body, 1, BUG_REPORT_PREFILL_MAX) + "\n\n(cut to fit the link)"
	var/url = "https://github.com/[repo]/issues/new?title=[url_encode(title)]&body=[url_encode(body)]"
	if (length(labels))
		url += "&labels=[url_encode(labels)]"
	return url

// The token from config lines ("BUG_REPORT_GITHUB_TOKEN value"). The last setting wins,
// "#BUG_REPORT_GITHUB_TOKEN" lines are comments. Only plain token characters count.
/proc/bug_report_token_from_lines(list/lines)
	. = null
	for (var/raw in lines)
		var/line = trim("[raw]")
		var/space = findtext(line, " ")
		if (!space || lowertext(copytext(line, 1, space)) != "bug_report_github_token")
			continue
		var/value = trim(copytext(line, space + 1))
		if (bug_report_token_valid(value))
			. = value

/proc/bug_report_token_valid(value)
	if (!istext(value) || length(value) < 20 || length(value) > 255)
		return FALSE
	for (var/i = 1, i <= length(value), i++)
		var/c = text2ascii(value, i)
		if (!((c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95))
			return FALSE
	return TRUE

// Comma separated labels from config, each cleaned to plain words.
/proc/bug_report_labels(text)
	. = list()
	if (!istext(text))
		return
	for (var/part in splittext(text, ","))
		var/label = bug_report_cell(trim(part))
		if (label != "-" && !(label in .))
			. += label
