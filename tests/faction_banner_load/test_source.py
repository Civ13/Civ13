"""Faction banner load: source contract checks.

    python3 tests/faction_banner_load/test_source.py
Native probe: python3 tests/ecology_spawning/run_linux.py . tests/faction_banner_load/probe.dm
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/mob/groups/factions.dm'


class FactionBannerLoadSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        text = SOURCE.read_text(encoding='utf-8')
        start = text.index('/obj/structure/banner/faction/New()')
        cls.new = text[start:text.index('/obj/structure/banner/faction/attackby(', start)]

    def test_banner_never_indexes_custom_civs_directly(self):
        # custom_civs is empty while a level loads; indexing a missing row was a
        # "cannot read from list" runtime for every restored faction banner.
        self.assertNotIn('map.custom_civs[faction][', self.new)
        self.assertIn('faction_banner_civ_data(faction)', self.new)

    def test_waits_for_the_whole_load(self):
        # Drawn symbols are restored after custom_civs, so wait for the load.
        self.assertRegex(self.new, r'while \(persistence_active_operation && world\.time < until\)\n\t\tsleep\(50\)')
        self.assertIn('islist(row) && row.len >= 6', self.new)

    def test_symbol_overlay_is_optional(self):
        self.assertIn('if (overs)\n\t\t\t\toverlays += overs', self.new)


    def test_player_banner_wall_tools_dispatch_before_ripping(self):
        sources = {'faction': SOURCE, 'religious': SOURCE.with_name('religions.dm')}
        for kind, path in sources.items():
            with self.subTest(kind=kind):
                source = path.read_text(encoding='utf-8')
                body = re.search(rf'^/obj/structure/banner/{kind}/attackby\([^\n]*\)\n((?:\t[^\n]*\n|\n)+)', source, re.M).group(1)
                self.assertRegex(body, r'(?m)^\tif \(banner_wall_tool\(W, user\)\)\n\t\treturn\s*$')
                self.assertLess(body.index('banner_wall_tool(W, user)'), body.index('W.sharp'))
                self.assertIn('qdel(src)', body)

    def test_wall_placement_preserves_banner_art_and_identity(self):
        source = SOURCE.read_text(encoding='utf-8')
        core = source.split('/obj/structure/banner/proc/banner_mount(', 1)[1]
        core = core.split('/obj/structure/banner/faction\n', 1)[0]
        self.assertNotRegex(core, r'(?m)\b(?:overlays|icon_state|bstyle|faction|loc)\s*=')
        self.assertNotIn('qdel(', core)
        self.assertNotIn('forceMove(', core)
        self.assertIn('anchored = banner_was_anchored', core)
        self.assertIn('banner_mount_dir = 0', core)

    def test_wall_placement_checks_target_and_existing_wall_art(self):
        source = SOURCE.read_text(encoding='utf-8')
        mount = source.split('/obj/structure/banner/proc/banner_mount(', 1)[1]
        self.assertLess(mount.index('painting_is_wall_turf'), mount.index('banner_mount_dir = facing'))
        self.assertLess(mount.index('banner_wall_occupied(T, facing)'), mount.index('banner_mount_dir = facing'))
        self.assertIn('B.board_mount_dir == facing', mount)
        self.assertIn('F.dir == NORTH && C && C.wide_hang', mount)

    def test_other_wall_art_respects_a_hung_banner(self):
        root = ROOT
        painting = (root / 'code/modules/paintings/paintings.dm').read_text(encoding='utf-8')
        hang = painting.split('/proc/painting_hang(', 1)[1].split('/proc/painting_is_wall_turf(', 1)[0]
        self.assertIn('for (var/obj/structure/banner/B in spot)\n\t\t\tif (B.banner_mount_dir == dir)', hang)
        self.assertLess(hang.index('banner_mount_dir == dir'), hang.index('new(T)'))
        board = (root / 'code/game/objects/structures/noticeboard.dm').read_text(encoding='utf-8')
        mount = board.split('/obj/structure/noticeboard/proc/noticeboard_mount(', 1)[1].split('\n/obj/', 1)[0]
        self.assertIn('for (var/obj/structure/banner/B in T)\n\t\tif (B.banner_mount_dir == facing)', mount)
        self.assertLess(mount.index('banner_mount_dir == facing'), mount.index('board_mount_dir = facing'))


if __name__ == '__main__':
    unittest.main()
