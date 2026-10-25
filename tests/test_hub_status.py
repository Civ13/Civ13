"""Offline source-derived hub fragments; never starts BYOND or contacts a server.

The encoder, URL alphabets and HTML templates come from code/world.dm.
Python supplies string/URL operations; native semantics and public rendering
still require separately authorized acceptance. Run from the repository root.
"""
from pathlib import Path
import re
import unittest
from html.parser import HTMLParser

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "code/world.dm").read_text(encoding="utf-8")
CONFIG = (ROOT / "config/config.txt").read_text(encoding="utf-8")


def proc(name):
    marker = f"/proc/{name}("
    if name == "update_status":
        marker = "/world/proc/update_status("
    start = SOURCE.index(marker)
    end = SOURCE.find("\n/", start + 1)
    return SOURCE[start:] if end < 0 else SOURCE[start:end]


def dm_string(literal):
    # Only the literal escapes used in these production fragments.
    assert literal[0] == literal[-1] == '"', literal
    return re.sub(r'\\(["\\])', r'\1', literal[1:-1])


TEXT = proc("hub_status_text")
LINK = proc("hub_status_link")
STATUS = proc("update_status")
LITERALS = re.findall(r'"(?:\\.|[^"\\])*"', LINK)
ALPHABETS = [dm_string(s) for s in LITERALS if s.startswith('"abcdefghijklmnopqrstuvwxyz')]
LINK_TEMPLATE = dm_string(re.search(r'return ("(?:\\.|[^"\\])*")', LINK[LINK.index("var/target"):])[1])
TARGET = dm_string(re.search(r'target = ("(?:\\.|[^"\\])*")', LINK[LINK.index("if (open_new_window)"):])[1])


def encode(value):
    text = "" if value is None else str(value)
    replacements = re.findall(r'text = replacetext\(text, ("(?:\\.|[^"\\])*"), ("(?:\\.|[^"\\])*")\)', TEXT)
    for old, new in replacements:
        text = text.replace(dm_string(old), dm_string(new))
    return text


def link(url, label, new_window=False):
    if not isinstance(url, str):
        return ""
    # Derive accepted prefixes and 1-based authority positions from production.
    prefixes = re.findall(r'copytext\(url, 1, (\d+)\) == ("(?:\\.|[^"\\])*")', LINK)
    starts = [int(end) - 1 for end, prefix in prefixes if url.startswith(dm_string(prefix))]
    if not starts:
        return ""
    start = starts[0]
    end = url.find("/", start)
    if end < 0:
        end = len(url)
    if start == end:
        return ""
    if any(c.lower() not in ALPHABETS[0] for c in url):
        return ""
    if any(c.lower() not in ALPHABETS[1] for c in url[start:end]):
        return ""
    return (LINK_TEMPLATE.replace("[hub_status_text(url)]", encode(url))
            .replace("[target]", TARGET if new_window else "")
            .replace("[hub_status_text(label)]", encode(label)))


def status_template(prefix, values):
    # Read existing literal HTML from production, never a second copy of it.
    line = next(line.strip() for line in STATUS.splitlines() if line.strip().startswith(prefix))
    literal = line.split("s += ", 1)[1]
    result = dm_string(literal)
    for key, value in values.items():
        result = result.replace("[" + key + "]", value)
    return result


def fragments(name="Civilization 13", discord="https://discord.gg/hBEtg4x",
              website="https://civ13.com/", new_window=True, map_title="Nomads",
              mode="Nomads", duration="1 hour", body="", banner=False):
    title = link(discord, name, new_window) or encode(name)
    parts = [status_template('s += "<center>', {"server_title": title})]
    links = [item for item in (link(discord, "Discord", new_window), link(website, "Website")) if item]
    if links:
        parts.append(status_template('s += "[jointext', {'jointext(community_links, " | ")': " | ".join(links)}))
    if banner:
        parts.append(status_template('s += "<img', {}))
    if map_title is not None:
        parts.append(status_template('s += "<b>Map:', {"hub_status_text(map.title)": encode(map_title),
                                                     "hub_status_text(roundduration2text())": encode(duration)}))
        parts.append(status_template('s += "<b>Gamemode:', {"hub_status_text(map.gamemode)": encode(mode)}))
    parts.append(body.replace("ROUNDTIME", duration.lower().capitalize()))
    return "".join(parts)


class Anchors(HTMLParser):
    def __init__(self, html):
        super().__init__(convert_charrefs=True)
        self.links = []
        self.tags = []
        self.feed(html)

    def handle_starttag(self, tag, attrs):
        self.tags.append(tag)
        if tag == "a":
            self.links.append(dict(attrs))


class HubStatusTests(unittest.TestCase):
    def test_shared_config_and_renderer_contract(self):
        self.assertIn("DISCORDURL https://discord.gg/hBEtg4x", CONFIG)
        self.assertIn("WEBSITEURL https://civ13.com/", CONFIG)
        for expected in (
            'hub_status_link(config.discordurl, "Discord", config.open_hub_discord_in_new_window)',
            'hub_status_link(config.websiteurl, "Website")',
            "community_links += discord_link", "community_links += website_link",
            "if (discord_link)", "if (website_link)", "if (community_links.len)",
            "hub_status_link(config.discordurl, customserver_name(), config.open_hub_discord_in_new_window)",
            "server_title = hub_status_text(customserver_name())",
            "if (world.port == config.testing_port)\n\t\tvisibility = FALSE",
            'config.hub_body = replacetext(config.hub_body, "ROUNDTIME", capitalize(lowertext(roundduration2text())))',
            "if (config.hub_body)\n\t\ts += config.hub_body", "status = s",
        ):
            self.assertIn(expected, STATUS)
        self.assertNotIn("game_state =", STATUS)
        self.assertNotIn("world.hub =", STATUS)
        self.assertNotIn("clients", STATUS)

    def test_literal_encoding_and_url_guard_contract(self):
        self.assertIn('var/text = "[value]"', TEXT)
        self.assertIn("return text", TEXT)
        for expected in ("if (!istext(url))", "if (!authority_end)", "if (authority_start == authority_end)",
                         "i <= length(url)", "lowertext(copytext(url, i, i + 1))",
                         "if (i >= authority_start && i < authority_end)"):
            self.assertIn(expected, LINK)
        self.assertEqual(2, len(ALPHABETS))
        self.assertEqual(encode('&<>"\''), "&amp;&lt;&gt;&quot;&#39;")
        self.assertEqual(encode(None), "")

    def test_nomads_and_tdm_keep_metadata_and_body(self):
        for mode in ("Nomads", "TDM", "RP", "Persistence", "ALL"):
            with self.subTest(mode=mode):
                output = fragments(name=f"Civ13 {mode}", map_title=f"{mode} map", mode=mode,
                                   body="<br>Existing host notice ROUNDTIME", banner=True)
                parsed = Anchors(output)
                self.assertEqual([x["href"] for x in parsed.links],
                                 ["https://discord.gg/hBEtg4x", "https://discord.gg/hBEtg4x", "https://civ13.com/"])
                self.assertIn(f">Civ13 {mode}</a></b>", output)
                self.assertIn(f"<b>Map:</b> {mode} map (1 hour)<br>", output)
                self.assertIn(f"<b>Gamemode:</b> {mode}<br>Existing host notice 1 hour", output)
                self.assertIn('<img src="https://i.imgur.com/napac0L.png">', output)
                self.assertIn(">Discord</a> | <a ", output)
                self.assertIn(">Website</a><br>", output)

    def test_missing_map_and_empty_urls_have_no_dangling_separator(self):
        output = fragments(discord=None, website="", map_title=None)
        self.assertEqual(output, "<center><b>Civilization 13</b></center><br>")
        self.assertEqual(Anchors(output).links, [])
        output = fragments(discord="", website="https://civ13.com/", map_title=None)
        self.assertEqual(len(Anchors(output).links), 1)
        self.assertNotIn(" | ", output)

    def test_dynamic_labels_are_literal(self):
        output = fragments(name='Civ13 <script>"&</script>', map_title="<img src=x onerror=x>",
                           mode="TDM & <b>bad</b>", duration='1 < 2 & "hours"')
        parsed = Anchors(output)
        self.assertNotIn("script", parsed.tags)
        self.assertNotIn("img", parsed.tags)
        self.assertIn("&lt;script&gt;&quot;&amp;&lt;/script&gt;", output)
        self.assertIn("TDM &amp; &lt;b&gt;bad&lt;/b&gt;", output)

    def test_reject_unsafe_and_malformed_configured_urls(self):
        bad = (None, 123, "", "javascript:alert(1)", "data:text/html,bad", "//discord.gg/hBEtg4x",
               "https://", "https:///empty-host", "https://user@civ13.com/",
               "https://civ13.com/\nnext", "https://civ13.com/\rnext", "https://civ13.com/\tnext",
               'https://civ13.com/" onclick="bad', "https://civ13.com/'", "https://civ13.com/<script>",
               "https://civ13.com/\\bad", " https://civ13.com/", "https://civ13.com/ space")
        for url in bad:
            with self.subTest(url=url):
                self.assertEqual(link(url, "Discord"), "")
                output = fragments(discord=url, website=url, map_title=None)
                self.assertEqual(Anchors(output).links, [])
                self.assertNotIn(" | ", output)

    def test_custom_safe_urls_query_ampersands_and_targets(self):
        url = "https://community.example:8443/invite?a=one&b=%22two%22#help"
        for new_window in (False, True):
            output = link(url, '<Discord "&">', new_window)
            parsed = Anchors(output)
            self.assertEqual(parsed.links[0]["href"], url)
            self.assertIn("?a=one&amp;b=", output)
            self.assertEqual(parsed.links[0].get("target"), "_blank" if new_window else None)
            self.assertEqual(parsed.links[0].get("rel"), "noopener noreferrer" if new_window else None)
        self.assertTrue(link("http://community.example/", "Website"))

    def test_new_window_option_remains_discord_only(self):
        parsed = Anchors(fragments(new_window=True))
        self.assertEqual([item.get("target") for item in parsed.links], ["_blank", "_blank", None])
        self.assertTrue(all("target" not in item for item in Anchors(fragments(new_window=False)).links))


if __name__ == "__main__":
    unittest.main()
