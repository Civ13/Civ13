"""Source contracts for Help! links; these checks do not run a BYOND client."""
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]
CLIENT_VERBS = ROOT / 'code/modules/client/client_verbs.dm'


def verb_body(source, name):
    start = source.index(f'/client/verb/{name}()')
    end = source.find('\n/client/verb/', start + 1)
    return source[start:end if end != -1 else None]


class HelpLinkTests(unittest.TestCase):
    def test_existing_wiki_verb_is_available_in_help(self):
        body = verb_body(CLIENT_VERBS.read_text(encoding='utf-8'), 'open_embed_wiki')
        self.assertIn('set category = "Help!"', body)
        self.assertIn('set name = "Open Wiki"', body)
        self.assertIn('https://civ13.github.io/civ13-wiki/', body)
        self.assertIn('browse(htmlfile', body)
        self.assertNotIn('player_help_service', body)

    def test_web_atlas_verb_opens_public_atlas_without_ai(self):
        body = verb_body(CLIENT_VERBS.read_text(encoding='utf-8'), 'open_web_crafting_atlas')
        self.assertIn('set category = "Help!"', body)
        self.assertIn('set name = "Open Web Crafting Atlas"', body)
        self.assertIn('src << link("https://civ13.github.io/Civ13/crafting/")', body)
        self.assertNotIn('player_help_service', body)

    def test_existing_in_game_atlas_remains_available(self):
        text = (ROOT / 'code/game/mob/crafting_atlas.dm').read_text(encoding='utf-8')
        self.assertIn('/mob/verb/crafting_atlas()', text)
        self.assertIn('crafting_atlas_reference.show(src)', text)


if __name__ == '__main__':
    unittest.main()
