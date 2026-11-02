"""Local causal controls. Every omitted guard must cause behavioral assertions.
Never count preparation/parser exceptions or test errors as causal success.
"""
import importlib.util, io, json, unittest
from pathlib import Path

spec=importlib.util.spec_from_file_location('authoring_controls_fixture',Path(__file__).with_name('test_authoring.py'))
fixture=importlib.util.module_from_spec(spec);spec.loader.exec_module(fixture)

def replace(source,old,new,count=1):
 assert source.count(old)==count,(old,source.count(old),count)
 return source.replace(old,new)

def run():
 original=fixture.SOURCE
 cases=[
 ('constructor readiness',lambda s:replace(s,' || !paper.document_capacity_ready','',2),
   'test_pending_constructor_capacity_refuses_editor_until_callback_finishes'),
 ('lease',lambda s:replace(replace(s,'!expected_lease || expected_lease != session_lease || ',''),
   ' || expected_lease != session_lease',''),'test_atomic_first_append_and_existing_append_rotate_lease_once'),
 ('language',lambda s:replace(s,'!paper_knows_written_language(actor, language_id)','FALSE',3),
   'test_removed_language_after_snapshot_and_unknown_ids_reject'),
 ('custody',lambda s:replace(s,' || paper.loc != context_owner',''),
   'test_custody_context_is_pinned_but_walking_with_held_paper_is_allowed'),
 ('record identity',lambda s:replace(s,' || paper.document_record != expected_record',''),
   'test_existing_record_callback_and_equal_replacement_are_stale'),
 ('fingerprint',lambda s:replace(s,'json_encode(paper.document_record) == expected_record_json && json_encode(paper_document_legacy_snapshot(paper)) == expected_legacy_json','TRUE'),
   'test_record_or_legacy_in_place_mutation_invalidates_unchanged_revision'),
 ('bound pen',lambda s:replace(s,'pen == writing_pen && state_current()','state_current()'),
   'test_actual_active_replacement_pen_cannot_reuse_session'),
 ('pen signature',lambda s:replace(s,'value = pen.get_signature(actor)','value = value'),
   'test_signature_uses_actual_forgery_and_ink_not_client_text'),
 ('projection boundary',lambda s:replace(s,'var/list/view = projection_reader.project(actor)','var/list/view = paper.document_record'),
   'test_all_unknown_text_kinds_are_absent_from_whole_editor_payload'),
 ]
 receipts=[]
 real_environment=fixture.environment
 try:
  for name,mutate,test in cases:
   changed=mutate(original)
   fixture.environment=lambda changed=changed:real_environment(changed)
   output=io.StringIO()
   result=unittest.TextTestRunner(stream=output,verbosity=2).run(fixture.Authoring(test))
   log=output.getvalue()
   # Preparation errors are not an observation of the omitted behavior.
   assert not result.errors,(name,log)
   assert result.failures,(name,'omission survived',log)
   assert not any(x in log for x in ('ast.parse','Unsupported statement','Unknown call boundary')),(name,log)
   receipts.append(dict(control=name,test=test,failures=len(result.failures),errors=len(result.errors),log=log))
 finally:
  fixture.environment=real_environment
 return receipts

if __name__=='__main__':
 print(json.dumps(run(),indent=2))
