"""Local causal mutations with assertion failures; no production writes/native."""
import argparse,importlib.util,io,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('mutation_contract_controls',Path(__file__).with_name('test_mutations.py'))
tests=importlib.util.module_from_spec(spec);spec.loader.exec_module(tests)
targets={'model':(tests.vm,'SOURCE'),'view':(tests.views,'SOURCE'),'paper':(tests,'PAPER')}
controls=[
 ('record-identity','model','P.document_record != current || ','',1,'test_equal_content_record_replacement_is_stale_by_dm_list_identity'),
 ('canonical-snapshot','model',' || json_encode(current) != edit["canonical_json"]','',1,'test_canonical_inplace_change_legacy_drift_and_deletion_reject'),
 ('next-revision','model','next["revision"] != edit["revision"] + 1 || ','',1,'test_commit_requires_one_revision_and_is_once_only'),
 ('section-sequence','model',' || next["next_section"] < current["next_section"]','',1,'test_invalid_candidate_or_identity_fails_without_partial_legacy_write'),
 ('physical-snapshot','model','!legacy || json_encode(legacy) != edit["legacy_json"]','!legacy',1,'test_canonical_inplace_change_legacy_drift_and_deletion_reject'),
 ('classified-erasure','paper','\t\tnext["sections"] = list()\n','',1,'test_erasure_clears_all_languages_without_minting_new_document_or_reusing_ids'),
 ('editor-after-prompt','paper','if (!t || usr != writer || !paper_document_legacy_edit_allowed(src, writer, writer_client, writing_pen))','if (!t)',1,'test_topic_guard_dominates_prompt_and_commit_and_chemistry_reports_success_only'),
 ('control-session','view','actor.client != expected_client || expected_client.mob != actor || ','',1,'test_legacy_guard_rejects_classification_logout_transfer_state_and_tool_change'),
 ('actual-active-pen','view',' || actor.get_active_hand() != pen','',1,'test_legacy_guard_rejects_classification_logout_transfer_state_and_tool_change'),
 ('closed-envelope','view','E.opened && ','',1,'test_legacy_guard_validates_container_page_and_open_envelope'),
 ('canonical-ownership','model','var/list/committed = paper_document_copy(next, budget)','var/list/committed = next',1,'test_commit_does_not_alias_candidate_or_physical_legacy_lists'),
 ('physical-ownership','model','var/list/physical = paper_document_copy(committed["legacy"], budget)','var/list/physical = committed["legacy"]',1,'test_commit_does_not_alias_candidate_or_physical_legacy_lists'),
 ('physical-budget','model','budget = new()\n\tvar/list/physical','budget = new /datum/paper_document_budget/record()\n\tvar/list/physical',1,'test_commit_preserves_the_1024_node_physical_legacy_budget'),
]
def run():
 rows=[]
 for name,key,before,after,count,method in controls:
  target,field=targets[key];original=getattr(target,field);assert original.count(before)==count,(name,'anchor drift')
  setattr(target,field,original.replace(before,after))
  try:
   stream=io.StringIO();result=unittest.TextTestRunner(stream=stream,verbosity=2).run(unittest.TestSuite([tests.Mutations(method)]))
   rows.append(dict(control=name,tests=result.testsRun,failures=len(result.failures),errors=len(result.errors),log=stream.getvalue()))
  finally:setattr(target,field,original)
 assert all(x['failures'] and not x['errors'] for x in rows),rows
 return dict(status='passed',controls=rows,local_only=True,native_executed=False)
if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
 result=run();args.output.write_text(json.dumps(result,indent=2)+'\n');print('PASS '+str(len(result['controls']))+' causal controls; native not executed')
