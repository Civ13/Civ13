import json, unittest
from lifecycle_result import classify_control,validate_positive,SOURCE,EXPECTED,REQUIRED_COUNTS
class Results(unittest.TestCase):
 def test_each_expected_omission_is_distinct_from_infrastructure_failure(self):
  for variant,label in EXPECTED.items():
   good=dict(compiler_ok=True,native_runtime_errors=0,timed_out=False,cleanup_confirmed=True,stop_reason=('preparation failed: ' if variant=='omit_moved_release' else 'take failed: ')+label,positive_completed=False)
   self.assertEqual(classify_control(variant,**good)['status'],'EXPECTED_OMISSION_ASSERTION_OBSERVED')
   for key,value in [('compiler_ok',False),('native_runtime_errors',1),('timed_out',True),('cleanup_confirmed',False),('stop_reason','bounded scene timeout'),('positive_completed',True)]:
    with self.subTest(variant=variant,key=key),self.assertRaises(ValueError):classify_control(variant,**{**good,key:value})
 def test_source_and_coverage_and_cadence_required(self):
  labels=[label for label,count in REQUIRED_COUNTS.items() for _ in range(count)]
  log='\n'.join(json.dumps(dict(probe='production_lease_v1',check=x,**{'pass':1},tick=200)) for x in labels)
  result=dict(probe='production_lease_v1',source=SOURCE,complete=1,assertions=len(labels),legs=[190,211])
  self.assertFalse(validate_positive(result,log)['accepted_for_marketing'])
  for change in [dict(source='wrong'),dict(legs=[190,212]),dict(assertions=21),dict(complete=0)]:
   with self.assertRaises(ValueError):validate_positive({**result,**change},log)
  with self.assertRaises(ValueError):validate_positive(result,log.replace('real qdel removes member registrations','missing'))
if __name__=='__main__':unittest.main()
