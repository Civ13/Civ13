"""In-memory source omission controls; no source edits or native process."""
import io,json,unittest
import reader_base
import test_character_flavor as contract
source=contract.SOURCE
base=reader_base.BASE
BASE_CONTROLS=('owner','cached_html_owner_guard','close_idempotence') # guards the shared reader base owns
controls=[
 ('owner',' || user != reader','', 'test_exact_reader_target_lease_allows_ghost_dead_and_disconnected_subject'),
 ('admission',' || !(src in view(viewer))','', 'test_admission_precedes_capture_and_canonical_budget_fallback_is_complete'),
 ('canonical_roundtrip',' && html_encode(html_decode(flavor_text)) == flavor_text','', 'test_admission_precedes_capture_and_canonical_budget_fallback_is_complete'),
 ('complete_fallback','\t\tui.legacy_renderer = TRUE\n','', 'test_admission_precedes_capture_and_canonical_budget_fallback_is_complete'),
 ('cached_html_owner_guard','\tif (!state || state.can_use_topic(src_object, user) == STATUS_CLOSE)\n\t\treturn ""\n','', 'test_cached_html_owner_guard_no_polling_domain_actions_or_close_side_effect'),
 ('close_idempotence','\tif (reader_closed)\n\t\treturn\n','', 'test_cached_html_owner_guard_no_polling_domain_actions_or_close_side_effect'),
]
results=[]
for name,before,after,method in controls:
 if name in BASE_CONTROLS:
  assert base.count(before)==1,(name,'ambiguous preimage');reader_base.load(base.replace(before,after,1))
 else:
  assert source.count(before)==1,(name,'ambiguous preimage');contract.SOURCE=source.replace(before,after,1)
 out=io.StringIO()
 result=unittest.TextTestRunner(stream=out,verbosity=2).run(unittest.TestSuite([contract.CharacterFlavorContract(method)]))
 contract.SOURCE=source;reader_base.load(base)
 results.append(dict(control=name,tests=result.testsRun,failures=len(result.failures),errors=len(result.errors),caught=bool(result.failures) and not result.errors,details=out.getvalue()))
contract.SOURCE=source
print(json.dumps(results,ensure_ascii=True,indent=2));assert all(x['caught'] for x in results)
