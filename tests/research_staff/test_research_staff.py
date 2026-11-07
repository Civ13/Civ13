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


class TierUpgradeWithoutSubject(unittest.TestCase):
    """A fresh tier-0 bench must accept coins before it has a subject.

    Once every tier-0 node is done (e.g. persistent Gaia with a high baseline
    era), a new bench could not be assigned anything (tier too low) and coins
    were refused with "Assign this bench a research subject first" -- a
    softlock reported by Nomads players.
    """

    def setUp(self):
        self.text = BENCH.read_text(encoding='utf-8')
        self.attackby = proc_body(
            self.text, '/obj/structure/research_bench/attackby(')

    def test_coins_are_taken_before_the_subject_check(self):
        coin = self.attackby.index('if (!assigned_node && is_upgrade_coin(W))')
        subject = self.attackby.index('Assign this bench a research subject first')
        self.assertLess(coin, subject)
        self.assertIn('try_feed_coins(W, user)', self.attackby[coin:subject])

    def test_feed_coins_does_not_require_a_subject(self):
        body = proc_body(
            self.text, '/obj/structure/research_bench/proc/try_feed_coins(')
        self.assertNotIn('assigned_node', body)
        self.assertIn('era_max_tier()', body)
        self.assertIn('is_upgrade_coin(W)', body)
        self.assertIn('tier++', body)

    def test_only_metal_coins_upgrade(self):
        body = proc_body(
            self.text, '/obj/structure/research_bench/proc/is_upgrade_coin(')
        for coin in ('coppercoin', 'silvercoin', 'goldcoin'):
            self.assertIn(f'/obj/item/stack/money/{coin}', body)
        self.assertNotIn('istype(W, /obj/item/stack/money)', body)


if __name__ == '__main__':
    unittest.main()
