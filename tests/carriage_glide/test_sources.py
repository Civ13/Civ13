"""Source contracts and omission controls only; never native/visual acceptance."""
import re,unittest,hashlib
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
TRANSPORT=ROOT/'code/game/objects/structures/transports.dm'
HUMAN=ROOT/'code/game/mob/living/carbon/human/subtile_movement.dm'
SAVER=ROOT/'code/modules/persistence/functions.dm'

def proc(source,path):
    start=source.index(path+'(')
    end=source.find('\n/',start+1)
    return source[start:end if end!=-1 else None]

def contracts(s,h,p):
    release=proc(s,'/atom/movable/proc/release_carriage_glide')
    assert release.index('carriage_glide_owner = null')<release.index('if (glide_size == carriage_glide_applied)')<release.index('glide_size = carriage_glide_previous')
    assert 'lease.members -= src' in release
    for event in ('moved','destroyed'):assert f'GLOB.{event}_event.unregister(src, lease,' in release
    retired=proc(s,'/datum/carriage_glide_lease/proc/release')
    assert retired.index('carriage = null')<retired.index('A.release_carriage_glide()')
    assert 'C.carriage_glide == src' in retired and 'A.carriage_glide_owner == src' in retired
    moved=proc(s,'/datum/carriage_glide_lease/proc/moved')
    assert 'if (!carriage || !A || A.carriage_glide_owner != src)' in moved
    assert moved.index('A.carriage_glide_step = null')<moved.index('if (expected && old_loc == expected[1] && new_loc == expected[2])')
    claim=proc(s,'/datum/carriage_glide_lease/proc/claim')
    assert 'isDeleted(A) || A.loc != carriage.loc' in claim
    assert claim.index('human_subtile_release_visuals()')<claim.index('H.human_subtile_release_glide()')<claim.index('A.carriage_glide_previous = A.glide_size')
    assert '32 * world.tick_lag / max(interval, world.tick_lag)' in claim
    assert '!(A.appearance_flags & LONG_GLIDE)' in claim and '*= ROOT2_FAST' in claim
    for event in ('moved','destroyed'):assert f'GLOB.{event}_event.register(A, src,' in claim
    assert 'release_carriage_glide()' in proc(h,'/mob/living/human/proc/human_subtile_update_visuals')
    persistence=proc(p,'/atom/movable/persistence_runtime_var')
    for key in ('original_target','carriage_glide_owner','carriage_glide_previous','carriage_glide_applied','carriage_glide_step'):assert '"'+key+'"' in persistence
    assert 'key == "glide_size" && ("carriage_glide_owner" in vars) && vars["carriage_glide_owner"]' in persistence
    assert 'key == "carriage_glide" || ..()' in s
    assert '/datum/carriage_glide_lease\n\tshould_save = FALSE' in s

class Sources(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.s=TRANSPORT.read_text();cls.h=HUMAN.read_text();cls.p=SAVER.read_text()
    def test_ownership_and_custom_save_contracts(self):contracts(self.s,self.h,self.p)
    def test_omission_controls(self):
        mutations=[('carriage_glide_owner = null','// omitted'),('if (glide_size == carriage_glide_applied)','if (TRUE)'),('carriage = null // Retire','// Retire'),('C.carriage_glide == src','TRUE'),('if (!carriage || !A || A.carriage_glide_owner != src)','if (!carriage)'),('A.carriage_glide_step = null // One arrival','// One arrival'),('H.human_subtile_release_glide()','// omitted'),('GLOB.moved_event.unregister(src, lease,','GLOB.moved_event.register(src, lease,'),('32 * world.tick_lag / max(interval, world.tick_lag)','32 / max(interval, world.tick_lag)')]
        for before,after in mutations:
            with self.subTest(before=before),self.assertRaises((AssertionError,ValueError)):contracts(self.s.replace(before,after),self.h,self.p)
    def test_original_force_moves_and_callbacks_stay_in_parent(self):
        body=proc(self.s,'/obj/structure/vehicle/proc/do_move')
        self.assertEqual(body.count('forceMove(get_step(src, m_dir))'),3)
        sub=proc(self.s,'/obj/structure/vehicle/carriage/do_move')
        self.assertEqual(sub.count('\t\t. = ..()'),1)
        self.assertNotIn('forceMove(',sub)
        self.assertIn('lease.release()\n\t\tthrow E',sub)
    def test_interval_is_captured_before_real_step_and_used_by_carriage_wait(self):
        body=proc(self.s,'/obj/structure/vehicle/proc/movementloop')
        self.assertLess(body.index('interval = vehicle_m_delay + 1'),body.index('do_move(driver.dir, interval)'))
        self.assertIn('spawn(istype(src, /obj/structure/vehicle/carriage) ? interval : vehicle_m_delay + 1)',body)
    def test_stop_and_repeated_start_wait_for_existing_wake(self):
        body=proc(self.s,'/obj/structure/vehicle/carriage/movementloop')
        self.assertIn('if (!movement_processes)\n\t\trelease_carriage_glides()',body)
        helpers=self.s.split('// Appearance-only leases.')[1]
        self.assertNotIn('spawn(',helpers);self.assertNotIn('sleep(',helpers)
    def test_explicit_dismount_cargo_and_untie_release_without_needing_arrival(self):
        c=self.s[self.s.index('/obj/structure/vehicle/carriage\n'):]
        for line in re.finditer(r'(?m)^(\t+)(ontop|ontop_o) -= (M|user|driver)$',c):
            prior=c[:line.start()].splitlines()[-1].strip()
            self.assertEqual(prior,line[3]+'.release_carriage_glide()')
    def test_external_movement_and_deletion_retire_carriage_or_member(self):
        for path in ('moved','destroyed'):
            body=proc(self.s,'/datum/carriage_glide_lease/proc/'+path)
            self.assertIn('if (A == carriage)\n\t\trelease()\n\telse\n\t\tA.release_carriage_glide()',body)
    def test_turn_shape_and_pixel_offsets_are_not_written_by_helpers(self):
        s=self.s.split('// Appearance-only leases.')[1]
        for field in ('dir','pixel_x','pixel_y','step_x','step_y','bound_width','bound_height','appearance_flags','movement_mode','fps'):
            self.assertNotRegex(s,rf'\b{field}\s*=(?!=)')
    def test_late_old_listener_cannot_clear_reboarded_lease(self):
        for path in ('moved','destroyed'):
            self.assertIn('if (!carriage || !A || A.carriage_glide_owner != src)',proc(self.s,'/datum/carriage_glide_lease/proc/'+path))
        self.assertIn('if (C && C.carriage_glide == src)',proc(self.s,'/datum/carriage_glide_lease/proc/release'))
    def test_null_callback_arguments_return_before_dereference(self):
        for path in ('moved','destroyed'):
            body=proc(self.s,'/datum/carriage_glide_lease/proc/'+path)
            guard='if (!carriage || !A || A.carriage_glide_owner != src)\n\t\treturn'
            self.assertIn(guard,body)
            self.assertLess(body.index('!A'),body.index('A.carriage_glide_owner'))
    def test_release_unregisters_stale_members_without_restoring_new_owner(self):
        body=proc(self.s,'/datum/carriage_glide_lease/proc/release')
        for event in ('moved','destroyed'):
            self.assertIn(f'\n\t\tGLOB.{event}_event.unregister(A, src, /datum/carriage_glide_lease/proc/{event})',body)
        self.assertIn('if (A.carriage_glide_owner == src)\n\t\t\tA.release_carriage_glide()',body)
        self.assertIn('if (!A)\n\t\t\tcontinue',body)
    def test_shared_force_move_and_destroy_have_no_new_overrides(self):
        self.assertNotIn('/atom/movable/forceMove(',self.s)
        self.assertNotIn('/atom/movable/Destroy(',self.s)
    def test_complete_legacy_transport_projection(self):
        s=self.s.split('// Appearance-only leases.')[0].removesuffix('\n\n')
        s=re.sub(r'(?m)^\t+(M|O|user|driver)\.release_carriage_glide\(\)\n','',s)
        s=s.replace('var/m_dir = null, interval = null','var/m_dir = null')
        s=s.replace('\t\tvar/interval = null\n','').replace('\t\t\tinterval = vehicle_m_delay + 1\n','')
        s=s.replace('do_move(driver.dir, interval)','do_move(driver.dir)')
        s=s.replace('\t\tif (isnull(interval))\n','')
        s=s.replace('\t\t// Other vehicles retain their original scheduling behavior.\n','')
        s=s.replace('spawn(istype(src, /obj/structure/vehicle/carriage) ? interval : vehicle_m_delay + 1)','spawn(vehicle_m_delay+1)')
        s=s.replace('\t// The existing scheduled wake finishes the previous visual leg, including stops.\n\t// A repeated start while that wake is pending must not snap its glide.\n\tif (!movement_processes)\n\t\trelease_carriage_glides()\n','')
        b=s.encode();self.assertEqual(hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest(),'f2200e39b805dc99746b8622ec7ae985d4edac46')
    def test_ci_is_explicit_source_only_and_preserves_mixed_file_fallback(self):
        s=(ROOT/'scripts/ci_baseline.py').read_text()
        self.assertIn("'carriage_glide': {'files': ('tests/carriage_glide/test_sources.py',)",s)
        entry=s.split("'carriage_glide':",1)[1].split('},',1)[0]
        self.assertNotIn('transports.dm',entry)
        self.assertNotIn('probe.dm',entry)

if __name__=='__main__':unittest.main()
