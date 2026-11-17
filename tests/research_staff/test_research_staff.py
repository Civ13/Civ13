"""Research bench staff appointments: director title prompt and reassignment.

Source contracts over production DM; no BYOND runtime. WWinput without a
type argument is a plain alert() that returns TRUE, which used to rename the
Research Director role to "1" on every appointment or rename.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
BENCH = ROOT / 'code/modules/research_tree/research_bench.dm'
FACTION = ROOT / 'code/modules/research_tree/research_faction.dm'
WWINPUT = ROOT / 'code/_helpers/WWinput.dm'


def proc_body(text, signature):
    start = text.index(signature)
    rest = text[start + len(signature):]
    end = re.search(r'^(?:/|// )', rest, re.M)
    return rest[:end.start()] if end else rest


def call_args(call):
    """Top-level comma-separated arguments of a single call string."""
    inner = call[call.index('(') + 1:]
    depth, quote, args, current = 0, False, [], ''
    for ch in inner:
        if ch == '"':
            quote = not quote
        if not quote:
            if ch in '([':
                depth += 1
            elif ch in ')]':
                if depth == 0:
                    args.append(current.strip())
                    return args
                depth -= 1
            elif ch == ',' and depth == 0:
                args.append(current.strip())
                current = ''
                continue
        current += ch
    raise ValueError('Unterminated call: ' + call)


class WWinputContract(unittest.TestCase):
    def test_untyped_wwinput_is_an_alert_returning_true(self):
        # The failure mode this suite guards: no toc1/toc2 means alert(), TRUE.
        source = WWINPUT.read_text(encoding='utf-8')
        self.assertIn('if (!toc1 && !toc2)\n\t\talert(C, message, title, "Continue")\n\t\t. = TRUE', source)


class DirectorTitle(unittest.TestCase):
    def setUp(self):
        self.bench = BENCH.read_text(encoding='utf-8')
        self.faction = FACTION.read_text(encoding='utf-8')

    def test_every_value_returning_bench_prompt_is_typed(self):
        for line in self.bench.splitlines():
            match = re.search(r'=\s*WWinput\(.*', line)
            if match:
                args = call_args(match.group(0)[match.group(0).index('WWinput'):])
                self.assertGreaterEqual(len(args), 5, 'untyped WWinput returns TRUE: ' + line.strip())

    def test_title_prompt_asks_for_text_and_sanitizes(self):
        body = proc_body(self.bench, '/obj/structure/research_bench/proc/prompt_director_title(')
        call = body[body.index('WWinput('):]
        self.assertEqual(call_args(call)[4], '"text"')
        self.assertIn('istext(raw)', body)
        self.assertIn('sanitize(raw, MAX_NAME_LEN, FALSE)', body)

    def test_rename_and_first_appointment_use_the_typed_prompt(self):
        for proc in ('appoint_director(', 'set_director_title('):
            body = proc_body(self.bench, '/obj/structure/research_bench/proc/' + proc)
            self.assertIn('prompt_director_title(H,', body, proc)
            self.assertNotIn('WWinput(', body, proc)

    def test_reassignment_keeps_the_chosen_title(self):
        body = proc_body(self.bench, '/obj/structure/research_bench/proc/appoint_director(')
        # The only title write sits under the first-appointment branch.
        writes = [m.start() for m in re.finditer(r'faction_director_title\[faction\] =', body)]
        self.assertEqual(len(writes), 1)
        branch = body.index('if (!old_director)')
        prompt = body.index('prompt_director_title(', branch)
        self.assertTrue(branch < prompt < writes[0])
        self.assertNotIn('"Research Director"', body)

    def test_reassignment_rechecks_and_notifies_the_replaced_director(self):
        body = proc_body(self.bench, '/obj/structure/research_bench/proc/appoint_director(')
        self.assertIn('target.civilization != faction', body)
        self.assertIn('You have been replaced as', body)
        self.assertIn('is already your', body)

    def test_stale_numeric_title_falls_back(self):
        body = proc_body(self.faction, '/obj/map_metadata/proc/get_director_title(')
        self.assertIn('istext(t)', body)

    def test_director_must_still_belong_to_the_faction(self):
        body = proc_body(self.faction, '/obj/map_metadata/proc/is_research_director(')
        self.assertIn('H.civilization == faction', body)


class BenchTierFollowsEra(unittest.TestCase):
    """Bench tiers rise with the era and never cost coins.

    Coins once raised a bench's tier, but minting needs the faction's leader
    and the trading posts are closed, so a faction could be stuck below its
    own era. Every bench now works at the current era's tier on its own.
    """

    FILES = ('research_bench.dm', 'book_research.dm', 'book_interface.dm',
             '_research_tree_defines.dm')

    def setUp(self):
        self.text = BENCH.read_text(encoding='utf-8')
        self.sources = {name: (BENCH.parent / name).read_text(encoding='utf-8')
                        for name in self.FILES}

    def test_bench_tier_is_the_era_tier(self):
        body = proc_body(self.text, '/obj/structure/research_bench/proc/bench_tier(')
        self.assertIn('return max(tier, era_max_tier())', body)

    def test_no_coin_upgrade_path_remains(self):
        for name, text in self.sources.items():
            for gone in ('try_feed_coins', 'is_upgrade_coin', 'BENCH_TIER_UPGRADE_COST',
                         'tier_progress', '/obj/item/stack/money'):
                self.assertNotIn(gone, text, (name, gone))

    def test_tier_gates_read_the_era_tier(self):
        for name, text in self.sources.items():
            code = '\n'.join(line.split('//', 1)[0] for line in text.splitlines())
            raw = re.findall(r'(?<![\w.])tier\s*[<>]=?\s*N\.min_bench_tier'
                             r'|N\.min_bench_tier\s*[<>]=?\s*tier(?![\w(])', code)
            self.assertEqual(raw, [], name)


class AnyoneBuildsBench(unittest.TestCase):
    """Anyone may build a research bench (Val, 2026-11-17).

    A faction member's bench belongs to their faction and counts toward its
    cap; a factionless builder, or anyone under book research (where benches
    belong to nobody), builds an unowned bench that counts toward no cap.
    """

    def setUp(self):
        self.stack = (ROOT / 'code/game/objects/items/stacks/stack.dm').read_text(encoding='utf-8')
        faction = FACTION.read_text(encoding='utf-8')
        body = proc_body(faction, '/obj/map_metadata/proc/bench_owner_faction(mob/living/human/H)\n')
        code = [line.strip() for line in body.splitlines() if line.strip()]
        self.assertEqual(code, [
            'if (!istype(H) || !H.civilization || H.civilization == "none" || book_research_enabled())',
            'return null',
            'return H.civilization'])

    @staticmethod
    def owner(civilization, book, human=True):
        # Direct evaluation of the three lines asserted in setUp.
        if not human or not civilization or civilization == 'none' or book:
            return None
        return civilization

    def test_owner_rules(self):
        self.assertEqual(self.owner('Rome', False), 'Rome')
        for civ in (None, '', 'none'):
            self.assertIsNone(self.owner(civ, False))
        self.assertIsNone(self.owner('Rome', True))
        self.assertIsNone(self.owner('Rome', False, human=False))

    def test_build_has_no_faction_refusal(self):
        self.assertNotIn('Only members of a faction can build a research bench', self.stack)
        start = self.stack.index('else if (recipe.result_type == /obj/structure/research_bench)')
        pre = self.stack[start:self.stack.index('\n\telse if', start + 10)]
        self.assertIn('map.bench_owner_faction(H)', pre)
        self.assertNotIn('H.civilization', pre)

    def test_only_owned_benches_meet_the_cap(self):
        start = self.stack.index('else if (istype(O, /obj/structure/research_bench))')
        post = self.stack[start:self.stack.index('RBN.faction = owner_faction', start)]
        self.assertIn('var/owner_faction = map ? map.bench_owner_faction(H) : null', post)
        self.assertIn('if (owner_faction)', post)
        self.assertIn('map.count_faction_benches(owner_faction) >= map.get_bench_cap(owner_faction)', post)


if __name__ == '__main__':
    unittest.main()
