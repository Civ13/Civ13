"""Stack recipe prompts are data on /datum/craft_product (craft_products.dm).

produce_recipe() used to ask each product's name, colour and owner inline.
FROZEN below is what each old branch asked and how it treated an empty or
cancelled answer. The test reads the prompt lists from the DM source, runs a
Python mirror of craft_product_answer() and checks the answers match the old
branches, including what a crafting screen gets when it passes options.

PROMPT_CEILING: player_input/WWinput calls left inside produce_recipe() only
go down; new product prompts go on a craft_product.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
PRODUCTS = ROOT / 'code/game/objects/items/stacks/craft_products.dm'
STACK = ROOT / 'code/game/objects/items/stacks/stack.dm'
PROMPT_CEILING = 8

# product: [(field, question, kind, empty answer -> value, cancel -> value)]; ABORT stops the build.
ABORT = object()
FROZEN = {
    'custom_sign': [('name', 'Choose a name for this sign:', 'text', '', 'Sign'),
                    ('desc', 'Choose a description for this sign:', 'text', '', 'An empty sign.')],
    'signpost': [('west', 'Add a West sign? Leave empty to not add one.', 'text', '', ''),
                 ('north', 'Add a North sign? Leave empty to not add one.', 'text', '', ''),
                 ('east', 'Add a East sign? Leave empty to not add one.', 'text', '', ''),
                 ('south', 'Add a South sign? Leave empty to not add one.', 'text', '', '')],
    'locked_door': [('name', 'Choose a name for the door:', 'text', '', 'Locked')],
    'tin_can': [('name', 'Choose a brand for this can:', 'text', '', ''),
                ('color1', 'Choose a main color:', 'color', '#000000', '#000000'),
                ('color2', 'Choose a secondary color:', 'color', '#FFFFFF', '#FFFFFF')],
    'cigarette_pack': [('name', 'Choose a name for this pack:', 'text', 'cigarette pack', 'cigarette pack'),
                       ('color', 'Choose a color:', 'color', ABORT, ABORT)],
    'statue': [('name', 'What name to give to the statue?', 'text', '', ''),
               ('desc', 'What description to add to the statue?', 'text', '', '')],
    'vehicle_frame': [('name', 'Choose a name for this vehicle:', 'text', 'motorcycle', 'motorcycle'),
                      ('color', 'Choose a color:', 'color', ABORT, ABORT)],
    'fuel_pump': [('company', 'Which company will own this %title%?', 'company', ABORT, ABORT),
                  ('name', 'Choose a name for this pump:', 'text', 'fuel pump', 'fuel pump'),
                  ('color', 'Fuel Pump - Choose a color:', 'color', ABORT, ABORT)],
    'holy_book': [('name', 'Choose a title for the holy book:', 'text', '', '')],
    'gravestone': [('name', 'Choose a name to inscribe on this gravestone:', 'text', 'gravestone', 'gravestone'),
                   ('desc', 'Choose an epitaph to inscribe on this gravestone:', 'text',
                    'A gravestone made with polished stone.', 'A gravestone made with polished stone.')],
    'company_stall': [('name', 'Choose a name for this %title%:', 'text', '%title%', '%title%'),
                      ('company', 'Which company will own this %title%?', 'company', ABORT, ABORT)],
}


def value(token):
    token = token.strip()
    if token == 'TRUE':
        return True
    if token == 'FALSE':
        return False
    return token[1:-1] if token.startswith('"') else token


def products():
    text = PRODUCTS.read_text(encoding='utf-8')
    found = {}
    for name, body in re.findall(r'^/datum/craft_product/(\w+)\n((?:\t.*\n|\n)*?)(?=^/|\Z)', text, re.M):
        prompts = []
        for line in re.findall(r'^\t\tlist\((.*)\),$', body, re.M):
            pairs = re.findall(r'"(\w+)" = ("(?:[^"\\]|\\.)*"|\w+)', line)
            prompts.append({k: value(v) for k, v in pairs})
        found[name] = prompts
    return found


def answer(prompt, typed, given=False):
    """Mirror of craft_product_answer(); typed None is Cancel."""
    kind = prompt['kind']
    if kind == 'company':
        return typed if typed in ('Guild',) else ABORT
    if kind == 'color':
        if not (isinstance(typed, str) and re.fullmatch(r'#[0-9a-fA-F]{6}', typed)):
            typed = None
    elif given and typed is not None:
        typed = str(typed)[:int(prompt.get('max_length', 256))]
    fallback = prompt.get('fallback')
    if typed is None or (typed == '' and not prompt.get('blank_ok')):
        if prompt.get('required'):
            return ABORT
        if typed is None or fallback is not None:
            typed = '' if fallback is None else fallback
    return typed


class CraftProductTest(unittest.TestCase):
    def test_prompts_match_the_old_branches(self):
        found = products()
        self.assertEqual(set(found), set(FROZEN))
        for name, rows in FROZEN.items():
            prompts = found[name]
            self.assertEqual([(p['field'], p['question'], p['kind']) for p in prompts],
                             [(f, q, k) for f, q, k, _, _ in rows], name)
            for prompt, (field, _, kind, empty, cancel) in zip(prompts, rows):
                with self.subTest(product=name, field=field):
                    if kind == 'company':
                        self.assertIs(answer(prompt, 'Cancel'), ABORT)
                        self.assertEqual(answer(prompt, 'Guild'), 'Guild')
                        continue
                    self.assertEqual(answer(prompt, '' if kind == 'text' else ''), empty)
                    self.assertEqual(answer(prompt, None), cancel)
                    typed = 'Ada' if kind == 'text' else '#12ab34'
                    self.assertEqual(answer(prompt, typed), typed)

    def test_options_skip_the_prompt_and_are_checked(self):
        found = products()
        sign = found['custom_sign'][0]
        self.assertEqual(answer(sign, 'x' * 300, given=True), 'x' * 256)
        color = found['vehicle_frame'][1]
        self.assertIs(answer(color, 'red', given=True), ABORT)
        source = PRODUCTS.read_text(encoding='utf-8')
        self.assertIn('var/given = options && (field in options)', source)
        self.assertIn('answer = sanitize(copytext(', source)
        self.assertIn('if (!(answer in companies))', source)

    def test_produce_recipe_reads_the_products(self):
        stack = STACK.read_text(encoding='utf-8')
        self.assertIn('/obj/item/stack/proc/produce_recipe(datum/stack_recipe/recipe, var/quantity, mob/user, list/options = null, recheck_source = FALSE)', stack)
        body = stack[stack.index('/obj/item/stack/proc/produce_recipe('):stack.index('/obj/item/stack/proc/crafting_stack_accessible(')]
        self.assertEqual(body.count('craft_product_options(user, recipe, options)'), 12)
        for _, rows in FROZEN.items():
            for _, question, _, _, _ in rows:
                self.assertNotIn(question.replace('%title%', '[recipe.title]'), body)
        prompts = len(re.findall(r'(?<![\w.])(?:player_input|WWinput)\(', body))
        self.assertLessEqual(prompts, PROMPT_CEILING)

    def test_guards_describe_without_building(self):
        source = (ROOT / 'code/game/objects/items/stacks/craft_guards.dm').read_text(encoding='utf-8')
        self.assertIn('/proc/craft_recipe_requirements(mob/living/human/H, datum/stack_recipe/R, obj/item/stack/paying = null)', source)
        describe = source[source.index('/datum/craft_guard/proc/describe('):source.index('/proc/craft_recipe_requirements(')]
        self.assertIn('refusal(H, R, CRAFT_GUARD_START)', describe)
        self.assertIn('"met" = FALSE', describe)


if __name__ == '__main__':
    unittest.main()
