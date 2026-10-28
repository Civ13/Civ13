"""Focused source regression, not a replacement for BYOND compilation."""
import hashlib,re,unittest
from pathlib import Path

HERE=Path(__file__).resolve().parent
BEFORE_SHA='71d1259d2c97753d8a25961810cf6d953f23c27ca3850d3b336ef4f8396deaf7'
OLD=b'"cargo_bound" = intro_crate in intro_carriage.ontop_o'
NEW=b'"cargo_bound" = (intro_crate in intro_carriage.ontop_o)'

SCAFFOLD_REPLACEMENTS=[(b'\tfor (var/fixture_verb in verbs.Copy())\n\t\tverbs -= fixture_verb\n\t..()\n', b'\tfor (var/fixture_verb in verbs.Copy())\n\t\tverbs -= fixture_verb\n\tintro_check(!verbs.len, "client verbs empty before native New")\n\t..()\n\tintro_check(!verbs.len, "client verbs empty after native New")\n\tintro_check(istype(mob, /mob/intro_observer) && !mob.verbs.len, "observer verbs empty before capture")\n'), (b'/mob/intro_observer/Login()\n\tloc = locate(8, 8, 1)\n\tverbs = list()\n', b'/mob/intro_observer/Login()\n\tloc = locate(8, 8, 1)\n\t// Mutate the native special list; do not replace it or remove procs.\n\tfor (var/fixture_verb in verbs.Copy())\n\t\tverbs -= fixture_verb\n\tintro_check(!verbs.len, "observer verbs empty after Login")\n')]
SCAFFOLD_REPLACEMENTS += [(b'var/mob/living/human/intro_driver\n', b'var/mob/living/human/intro_actor/intro_driver\n'), (b'/world\n', b'// Scripted headless actor, not a connected player. Keep inherited Life and status checks.\n/mob/living/human/intro_actor/ssd_check()\n\treturn FALSE // Match existing core_boot_actor and game_loop_actor fixtures.\n\n/world\n')]
MANUAL_DIMENSIONS=b'\tmaxx = 15\n\tmaxy = 15\n\tmaxz = 1\n'
MAP_DRIVEN=b'\t// The authored DMM supplies dimensions; exact runtime size is asserted below.\n'
DIAGNOSTIC=b'\t\ttext2file(json_encode(list("schema" = 1, "phase" = "before_crop_guard", "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz, "map_file" = "filming/carriage.dmm", "expected_map_sha256" = "b756ef691c45fa80124a12f7310a10bea76c90a0f7192b1606344e228640220b", "game_source" = "5260b60f0efef2c0af70fae204b1180106ef50b3")), "intro-checks.txt")\n'
GUARD=b'\t\tintro_check(maxx == 15 && maxy == 15 && maxz == 1, "exact 225-cell crop")\n'

def cargo_value(source):
    rows=re.findall(rb'"cargo_bound"\s*=\s*(.*?),\s*"items"\s*=',source)
    if len(rows)!=1 or not re.fullmatch(rb'\(\s*intro_crate\s+in\s+intro_carriage\.ontop_o\s*\)',rows[0]):
        raise ValueError('Cargo membership list value must retain explicit grouping and operand order')

class SceneSyntax(unittest.TestCase):
    def test_scene_preserves_original_bytes_except_reviewed_fix_and_diagnostic(self):
        source=(HERE/'changed-source/filming/scene.dm').read_bytes()
        self.assertEqual(source.count(DIAGNOSTIC+GUARD),1)
        source=source.replace(DIAGNOSTIC,b'')
        source=source.replace(b'intro_fast_prepare()',b'intro_lease_preroll()').replace(b'action.carriage_fast_collision(intro_carriage, intro_driver, intro_crate)',b'action.carriage_straight(intro_carriage, intro_driver, intro_crate)')
        anchor=b'\t\taction.carriage_straight(intro_carriage, intro_driver, intro_crate)\n'
        source=source.replace(anchor,anchor+b'\t\tintro_check(intro_driver.health == driver_health && intro_horse.health == horse_health && intro_carriage.health == carriage_health, \"no collision injury during short drive\")\n')
        source=source.replace(b'\t\tworld.log << "CARRIAGE_LEASE_LOG_SOURCE=5260b60f0efef2c0af70fae204b1180106ef50b3"\n',b'')
        source=source.replace(b'\t\tintro_lease_settled()\n',b'').replace(b'\tintro_lease_preroll()\n',b'')
        source=source.replace(b'5260b60f0efef2c0af70fae204b1180106ef50b3',b'58404f5bd16e3fed80f1d9844c5db3edd144942c')
        self.assertEqual(source.count(MAP_DRIVEN),1)
        self.assertNotRegex(source,rb'(?m)^\tmax[xyz]\s*=')
        source=source.replace(MAP_DRIVEN,MANUAL_DIMENSIONS)
        for old,new in SCAFFOLD_REPLACEMENTS:
            self.assertEqual(source.count(new),1)
            source=source.replace(new,old)
        cargo_value(source)
        self.assertEqual(source.count(NEW),1)
        self.assertEqual(hashlib.sha256(source.replace(NEW,OLD)).hexdigest(),BEFORE_SHA)
    def test_diagnostic_is_scalar_and_reuses_existing_bounded_log(self):
        self.assertLess(len(DIAGNOSTIC),1024)
        for field in (b'"maxx" = world.maxx',b'"maxy" = world.maxy',b'"maxz" = world.maxz'):
            self.assertEqual(DIAGNOSTIC.count(field),1)
        self.assertTrue(DIAGNOSTIC.endswith(b', "intro-checks.txt")\n'))
        self.assertNotIn(b'world.maxx =',DIAGNOSTIC)
        self.assertNotIn(b'world.maxy =',DIAGNOSTIC)
        self.assertNotIn(b'world.maxz =',DIAGNOSTIC)
    def test_map_driven_dimensions_reject_reintroduced_manual_defaults(self):
        source=(HERE/'changed-source/filming/scene.dm').read_bytes()
        def validate_dimensions(value):
            if re.search(rb'(?m)^\tmax[xyz]\s*=',value):
                raise ValueError('Manual world dimensions reintroduced')
        validate_dimensions(source)
        for old_line in MANUAL_DIMENSIONS.splitlines(keepends=True):
            with self.subTest(line=old_line), self.assertRaises(ValueError):
                validate_dimensions(source.replace(MAP_DRIVEN,MAP_DRIVEN+old_line))
        self.assertEqual(source.count(DIAGNOSTIC+GUARD),1)
        dme=(HERE/'changed-source/civ13.dme').read_bytes()
        maps=re.findall(rb'#include "([^"\n]+\.dmm)"',dme)
        self.assertEqual(maps,[b'filming\\carriage.dmm'])
        crop=(HERE/'changed-source/filming/carriage.dmm').read_bytes()
        self.assertEqual(hashlib.sha256(crop).hexdigest(),'b756ef691c45fa80124a12f7310a10bea76c90a0f7192b1606344e228640220b')
    def test_original_failed_expression_is_rejected(self):
        with self.assertRaises(ValueError):cargo_value(OLD+b', "items" = items')
    def test_grouped_value_allows_whitespace(self):
        cargo_value(b'"cargo_bound" = ( intro_crate  in  intro_carriage.ontop_o ), "items" = items')
    def test_reversed_membership_is_rejected(self):
        with self.assertRaises(ValueError):cargo_value(b'"cargo_bound" = (intro_carriage.ontop_o in intro_crate), "items" = items')
    def test_missing_or_duplicate_cargo_witness_is_rejected(self):
        for source in [b'',(NEW+b', "items" = items')*2]:
            with self.subTest(source=source),self.assertRaises(ValueError):cargo_value(source)

if __name__=='__main__':unittest.main()
