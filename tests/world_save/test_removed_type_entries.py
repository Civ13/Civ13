"""A saved object whose type was removed from the code is left out on load.

North America's save held fishing spots (/obj/structure/fish) that #5620 removed;
the new build refused the whole save ("Invalid saved type at entry 137:") and the
region could not update (2026-11-16). BYOND reads a removed path back as null,
with the "type" entry still present, which is what the loader keys on.
"""
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LOADING = ROOT / 'code/modules/persistence/loading.dm'


def load_entry_source():
    text = LOADING.read_text(encoding='utf-8')
    start = text.index('/map_storage/proc/Load_Entry(')
    return text[start:text.index('\n/map_storage/proc/', start + 1)]


class RemovedTypeEntryTests(unittest.TestCase):
    def test_an_object_of_a_removed_type_is_left_out(self):
        source = load_entry_source()
        guard = source.index('if(isnull(type) && ("type" in savefile.dir) && !old_turf && !saved_turfs["[ind]"])')
        refusal = source.index('throw EXCEPTION("Invalid saved type at entry [ind]: [type]")')
        self.assertLess(guard, refusal, 'the removed-type skip runs before the refusal')
        self.assertIn('return null', source[guard:refusal])

    def test_a_turf_or_damaged_entry_still_refuses(self):
        source = load_entry_source()
        # Only a null type with its entry present is skipped: a missing entry,
        # a non-path value or a turf tile keeps the refusal.
        self.assertIn('!old_turf && !saved_turfs["[ind]"]', source)
        self.assertIn('("type" in savefile.dir)', source)

    @unittest.skipUnless(shutil.which('DreamMaker') and shutil.which('DreamDaemon'), 'needs BYOND')
    def test_byond_reads_a_removed_path_as_null_with_its_entry_present(self):
        with tempfile.TemporaryDirectory() as work:
            work = Path(work)
            (work / 'a.dme').write_text('/obj/gone\n/world/New()\n\tvar/savefile/S = new("t.sav")\n\tS.cd = "/e/1"\n'
                                        '\tS["type"] << /obj/gone\n\tdel(world)\n')
            (work / 'b.dme').write_text('/world/New()\n\tvar/savefile/S = new("t.sav")\n\tS.cd = "/e/1"\n\tvar/type = S["type"]\n'
                                        '\tworld.log << "RESULT [isnull(type)] [("type" in S.dir)]"\n'
                                        '\tS.cd = "/e/2"\n\tworld.log << "MISSING [("type" in S.dir)]"\n\tdel(world)\n')
            for name in ('a', 'b'):
                subprocess.run(['DreamMaker', name + '.dme'], cwd=work, check=True, capture_output=True, timeout=120)
            subprocess.run(['DreamDaemon', 'a.dmb', '-trusted'], cwd=work, capture_output=True, timeout=60)
            out = subprocess.run(['DreamDaemon', 'b.dmb', '-trusted'], cwd=work, capture_output=True, text=True, timeout=60)
            log = out.stdout + out.stderr
            self.assertIn('RESULT 1 1', log)
            self.assertIn('MISSING 0', log)


if __name__ == '__main__':
    unittest.main()
