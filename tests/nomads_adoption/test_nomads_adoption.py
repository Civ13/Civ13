"""Offline source contracts for Nomads adoption, without starting BYOND."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATH = 'code/game/mob/living/carbon/human/nomads_adoption.dm'
SOURCE = (ROOT / SOURCE_PATH).read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')


def proc_body(header):
    start = SOURCE.index(header + '(')
    body = []
    for line in SOURCE[start:].splitlines()[1:]:
        if line and not line.startswith('\t'):
            break
        body.append(line)
    return '\n'.join(body)


class NomadsAdoptionTests(unittest.TestCase):
    def test_file_is_compiled_after_the_human_constructor(self):
        include = '#include "code\\game\\mob\\living\\carbon\\human\\nomads_adoption.dm"'
        human = '#include "code\\game\\mob\\living\\carbon\\human\\human.dm"'
        self.assertIn(include, DME)
        self.assertLess(DME.index(human), DME.index(include))

    def test_verbs_exist_only_in_nomads_and_return_after_load(self):
        self.assertIn('return map && map.nomads', proc_body('/proc/adoption_enabled'))
        refresh = proc_body('/mob/living/human/proc/adoption_refresh_verbs')
        self.assertRegex(refresh, r'if \(!adoption_enabled\(\)\)\n\t\tverbs -= /mob/living/human/proc/offer_adoption\n\t\tverbs -= /mob/living/human/proc/unadopt\n\t\treturn')
        self.assertIn('if (adoption_original_name)\n\t\tverbs |= /mob/living/human/proc/unadopt', refresh)
        for header in ('/mob/living/human/New', '/mob/living/human/after_load'):
            body = proc_body(header)
            self.assertIn('..()', body)
            self.assertIn('adoption_refresh_verbs()', body)

    def test_original_name_is_saved_and_offer_guards_are_runtime(self):
        self.assertRegex(SOURCE, r'\n\tvar/adoption_original_name = null\n')
        self.assertIn('var/tmp/adoption_offer_pending = FALSE', SOURCE)
        self.assertIn('var/tmp/adoption_offer_next = 0', SOURCE)
        # tmp alone does not keep a var out of the custom saver.
        body = proc_body('/mob/living/human/persistence_runtime_var')
        self.assertIn('if (key == "adoption_offer_pending" || key == "adoption_offer_next")\n\t\treturn TRUE', body)
        self.assertIn('return ..()', body)
        self.assertNotIn('adoption_original_name', body)

    def test_offer_requires_consent_and_rechecks_after_the_prompt(self):
        body = proc_body('/mob/living/human/proc/offer_adoption')
        self.assertIn('set src in view(1)', body)
        prompt = body.index('WWinput(src,')
        accepted = body.index('if (answer != "Yes")')
        recheck = body.index('get_dist(user, src) > 1')
        rename = body.index('adoption_rename(adoption_apply_surname(original, surname))')
        store = body.index('adoption_original_name = original')
        self.assertLess(prompt, accepted)
        self.assertLess(accepted, recheck)
        self.assertLess(recheck, rename)
        self.assertLess(rename, store)
        # An already-adopted target keeps its first original name.
        self.assertLess(body.index('if (adoption_original_name)'), prompt)
        self.assertIn('adoption_original_name)', body[recheck - 200:recheck + 120])

    def test_post_prompt_recheck_matches_the_initial_gate(self):
        body = proc_body('/mob/living/human/proc/offer_adoption')
        prompt = body.index('WWinput(src,')
        before, after = body[:prompt], body[prompt:]
        self.assertIn('user.restrained()', before)
        recheck = next(line for line in after.splitlines() if 'get_dist(user, src) > 1' in line)
        for guard in ('user.stat', 'user.restrained()', 'adoption_can_respond()', 'adoption_original_name'):
            self.assertIn(guard, recheck)

    def test_rename_during_prompt_cannot_change_the_accepted_surname(self):
        body = proc_body('/mob/living/human/proc/offer_adoption')
        prompt = body.index('WWinput(src,')
        after = body[prompt:]
        # The offered surname is captured before the prompt and never reassigned after it.
        self.assertIn('var/surname = adoption_surname(user.real_name)', body[:prompt])
        self.assertIn('[surname] family. Your last name will become [surname].', body[prompt:prompt + 200])
        self.assertNotRegex(after, r'\n\t*surname = ')
        guard = after.index('if (adoption_surname(user.real_name) != surname')
        self.assertLess(guard, after.index('adoption_rename(adoption_apply_surname(original, surname))'))
        self.assertIn('return', after[guard:guard + 300])

    def test_rename_keeps_name_records_together(self):
        body = proc_body('/mob/living/human/proc/adoption_rename')
        self.assertIn('fully_replace_character_name(real_name, new_name)', body)
        helper = (ROOT / 'code/_helpers/unsorted.dm').read_text(encoding='utf-8')
        start = helper.index('/mob/proc/fully_replace_character_name')
        helper = helper[start:helper.index('\n/*', start)]
        for field in ('real_name = newname', 'name = newname', 'mind.name = newname', 'dna.real_name = real_name'):
            self.assertIn(field, helper)

    def test_unadopt_is_self_only_and_restores_the_original(self):
        body = proc_body('/mob/living/human/proc/unadopt')
        self.assertIn('if (usr != src)\n\t\treturn', body)
        self.assertNotIn('set src in', body)
        restore = body.index('adoption_rename(original)')
        clear = body.index('adoption_original_name = null')
        self.assertLess(restore, clear)
        self.assertLess(clear, body.index('adoption_refresh_verbs()', clear))

    def test_surname_helpers_replace_only_the_last_word(self):
        # Independent model of the two DM helpers, pinned to their bodies.
        surname = proc_body('/proc/adoption_surname')
        self.assertIn('if (parts.len < 2)\n\t\treturn null', surname)
        self.assertIn('return parts[parts.len]', surname)
        apply = proc_body('/proc/adoption_apply_surname')
        self.assertIn('return "[trim(full_name)] [surname]"', apply)
        self.assertIn('parts[parts.len] = surname', apply)

        def model_surname(name):
            parts = name.strip().split(' ')
            return parts[-1] if len(parts) >= 2 else None

        def model_apply(name, new):
            parts = name.strip().split(' ')
            if len(parts) < 2:
                return f'{name.strip()} {new}'
            parts[-1] = new
            return ' '.join(parts)

        self.assertEqual(model_surname('Ada Brennan'), 'Brennan')
        self.assertIsNone(model_surname('Ugg'))
        self.assertEqual(model_apply('Gaius Julius Caesar', 'Brennan'), 'Gaius Julius Brennan')
        self.assertEqual(model_apply('Ugg', 'Brennan'), 'Ugg Brennan')


if __name__ == '__main__':
    unittest.main()
