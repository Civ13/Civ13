"""Shared map metadata procs keep the behaviour of the copies they replaced.

Fixtures freeze the pre-refactor bodies:
- campaign_base_body.dm.txt / campaign_timer_tsfsr_body.dm.txt: the Campaign
  update_win_condition on the base type and on the four maps that copied it with
  the two victory messages swapped (1b, 2a, 3b, 4a).
- close_area_original.dm.txt: the six-branch Battle Royale close_area that the
  table-driven shared close_area replaces.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MAPS = ROOT / 'code/game/objects/map_metadata'
HERE = Path(__file__).resolve().parent
TIMER_SUBTYPES = ('campaign1b', 'campaign2a', 'campaign3b', 'campaign4a')


def body(source, header):
    match = re.search(r'(?m)^' + re.escape(header) + r'.*\n((?:\t.*\n|[ \t]*\n)*)', source)
    return match.group(1).rstrip('\n') + '\n' if match else None


def render_campaign(source, tsfsr):
    """Resolve each `timer_victor_is_tsfsr ? a : b` to the branch a map would take."""
    live = body(source, '/obj/map_metadata/campaign_new/update_win_condition()')
    if live is None:
        return None
    pattern = re.compile(r'timer_victor_is_tsfsr \? (SPAN_\w+\(".*?"\)) : (SPAN_\w+\(".*?"\))$', re.M)
    return pattern.sub(lambda m: m.group(1) if tsfsr else m.group(2), live)


def campaign_errors(source):
    errors = []
    for tsfsr, fixture in ((False, 'campaign_base_body.dm.txt'), (True, 'campaign_timer_tsfsr_body.dm.txt')):
        if render_campaign(source, tsfsr) != (HERE / fixture).read_text(encoding='utf-8'):
            errors.append(f'campaign win condition differs for timer_victor_is_tsfsr={tsfsr}')
    for sub in TIMER_SUBTYPES:
        if f'/obj/map_metadata/campaign_new/{sub}/update_win_condition(' in source:
            errors.append(f'{sub} copies update_win_condition again')
        block = re.search(r'(?m)^/obj/map_metadata/campaign_new/' + sub + r'\n((?:\t.*\n)*)', source)
        if not block or '\ttimer_victor_is_tsfsr = TRUE\n' not in block.group(1):
            errors.append(f'{sub} must set timer_victor_is_tsfsr')
    return errors


def original_zones():
    text = (HERE / 'close_area_original.dm.txt').read_text(encoding='utf-8')
    zones = {}
    for artc, branch in re.findall(r'(?m)^\t\tif \("(\w+)"\)\n((?:\t\t\t.*\n)+)', text):
        name = re.search(r'A\.name == "(.*) Area"', branch).group(1)
        closed = re.search(r'<b>(.*)</b> Area has been closed', branch).group(1)
        paths = set(re.findall(r'/area/caribbean/no_mans_land/battleroyale/[\w/]+', branch))
        expected = {f'/area/caribbean/no_mans_land/battleroyale/{artc}{tail}'
                    for tail in ('', '/inside', '/border', '/border/inside')}
        zones[artc] = (name, closed, paths == expected, f'closed_areas += list("{artc}")' in branch)
    return zones


def zone_errors(shared, maps):
    errors = []
    table = dict(re.findall(r'^\t"(\w+)"\s*= "([\w-]+)",$', shared, re.M))
    zones = original_zones()
    if len(zones) != 6:
        errors.append('fixture must hold the six original close_area branches')
    for artc, (name, closed, template, records) in zones.items():
        if not (template and records and name == closed):
            errors.append(f'original branch {artc} does not follow the shared template')
        if table.get(artc) != name:
            errors.append(f'zone {artc} must be named {name}')
    if len(table) != 6:
        errors.append('zone table must list exactly the six original zones')
    for needle in ('"[zone_path]/border"', '"[zone_path]/border/inside"', '"[zone_path]/inside"',
                   'A.name == "[area_name] Area"', '<b>[area_name]</b> Area has been closed!',
                   'closed_areas += list(artc)'):
        if needle not in shared:
            errors.append(f'shared close_area lost {needle}')
    for name, source in maps.items():
        for proc in ('closing_areas', 'warn_closing_areas', 'close_area'):
            if f'/proc/{proc}(' in source:
                errors.append(f'{name} copies {proc} again')
    if 'zone_first_close = 1800' not in maps['hungergames.dm'] or 'zone_recheck_delay = 300' not in maps['hungergames.dm']:
        errors.append('Hunger Games must keep its 3 minute first close')
    return errors


class MapMetadataDedupe(unittest.TestCase):
    def setUp(self):
        self.campaign = (MAPS / 'campaign_new.dm').read_text(encoding='utf-8')
        self.shared = (MAPS / 'shrinking_zone.dm').read_text(encoding='utf-8')
        self.maps = {name: (MAPS / name).read_text(encoding='utf-8') for name in ('battleroyale.dm', 'hungergames.dm')}

    def test_campaign_win_condition_matches_both_frozen_copies(self):
        self.assertEqual(campaign_errors(self.campaign), [])

    def test_campaign_detects_swapped_message(self):
        altered = self.campaign.replace('SPAN_BLUE("The <b>CAFR</b>', 'SPAN_RED("The <b>CAFR</b>', 1)
        self.assertTrue(campaign_errors(altered))

    def test_shrinking_zone_table_matches_original_branches(self):
        self.assertEqual(zone_errors(self.shared, self.maps), [])

    def test_shrinking_zone_detects_renamed_zone(self):
        altered = self.shared.replace('"Western"', '"West"', 1)
        self.assertTrue(zone_errors(altered, self.maps))


if __name__ == '__main__':
    unittest.main()
