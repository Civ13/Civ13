"""Bounded in-memory omission controls; never edits repository source."""
import io,json,unittest
import notes_projection as projection
import test_character_notes as contract

original=contract.SOURCE
parser=projection.parser
controls=[
 ('depth','\t\t\tif (tags.len >= budget.max_depth)\n\t\t\t\treturn null\n','',contract.NotesParser,'test_depth_node_and_full_unicode_boundaries_never_truncate'),
 ('balance','\tif (tags.len)\n\t\treturn null\n','',contract.NotesParser,'test_mixed_malformed_unsupported_entities_and_controls_fallback_whole'),
 ('entities_and_run_budget','\t\t\tif (!character_notes_entities_safe(chunk) || budget.nodes_left <= 0)\n\t\t\t\treturn null\n','',contract.NotesParser,'test_mixed_malformed_unsupported_entities_and_controls_fallback_whole'),
 ('owner',' || user != reader','',contract.NotesOwnership,'test_owner_wrong_source_logout_ghost_and_real_transfer_order'),
 ('cache','\tui.legacy_snapshot = legacy_snapshot\n','',contract.NotesOwnership,'test_complete_cached_snapshot_guarded_fallback_and_close_noninterference'),
 ('close_idempotence','\tif (reader_closed)\n\t\treturn\n','',contract.NotesOwnership,'test_complete_cached_snapshot_guarded_fallback_and_close_noninterference'),
 ('complete_fallback','\t\tui.legacy_renderer = TRUE\n','',contract.NotesOwnership,'test_complete_cached_snapshot_guarded_fallback_and_close_noninterference'),
]
results=[]
for name,before,after,cls,method in controls:
 assert original.count(before)==1,(name,'ambiguous preimage')
 changed=original.replace(before,after,1)
 contract.SOURCE=changed
 contract.parser=lambda *args,**kwargs:parser(source=changed,*args,**kwargs)
 output=io.StringIO()
 result=unittest.TextTestRunner(stream=output,verbosity=2).run(unittest.TestSuite([cls(method)]))
 results.append(dict(control=name,tests=result.testsRun,failures=len(result.failures),errors=len(result.errors),caught=len(result.failures)>0 and not result.errors,details=output.getvalue()))
contract.SOURCE=original;contract.parser=parser
print(json.dumps(results,ensure_ascii=True,indent=2))
assert all(result['caught'] for result in results),'An omission did not cause a clean assertion failure'
