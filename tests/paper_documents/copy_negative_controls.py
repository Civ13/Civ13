"""Local-only causal copy regressions; mutate memory, preserve real assertion logs."""
import argparse, importlib.util, io, json, unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('copy_contract_controls',Path(__file__).with_name('test_copying.py'))
tests=importlib.util.module_from_spec(spec);spec.loader.exec_module(tests)
controls=[
 ('new-document-identity','SOURCE',None,'record["document_id"] = paper_document_mint_id(result)','record["document_id"] = record["document_id"]',1,'test_classified_copy_preserves_canonical_language_identity_and_redacts_view'),
 ('canonical-output-ownership','SOURCE',None,'record = paper_document_copy(snapshot["record"], budget)','record = snapshot["record"]',1,'test_classified_copy_preserves_canonical_language_identity_and_redacts_view'),
 ('physical-output-ownership','SOURCE',None,'var/list/physical = paper_document_copy(snapshot["legacy"], budget)','var/list/physical = snapshot["legacy"]',1,'test_legacy_null_paths_lists_ink_and_capacity_remain_exact_and_unaliased'),
 ('record-identity','SOURCE',None,'if (P.document_record != current)','if (FALSE)',1,'test_stale_identity_content_metadata_location_and_deleted_source_reject'),
 ('canonical-revision-drift','SOURCE',None,'json_encode(current) != snapshot["record_json"] || ','',1,'test_stale_identity_content_metadata_location_and_deleted_source_reject'),
 ('metadata-drift','SOURCE',None,' && json_encode(metadata) == snapshot["metadata_json"]','',1,'test_stale_identity_content_metadata_location_and_deleted_source_reject'),
 ('stock-rechecks','SOURCE',None,' || !paper_document_copy_current(stock_snapshot)','',2,'test_press_constructor_callback_rechecks_stock_and_owns_failed_output'),
 ('actual-control-session','SOURCE',None,'actor.client == expected_client && expected_client.mob == actor && ','',1,'test_cancel_or_stale_press_wait_keeps_inputs_and_resets_busy'),
 ('mail-receiver-location','SOURCE',None,' || checked_receiver.loc != places[check_index]','',1,'test_mail_no_receivers_and_constructor_changes_preserve_original_and_cleanup'),
 ('mail-failed-output-cleanup','SOURCE',None,'\t\t\tqdel(failed_output)\n','\t\t\tfailed_output.loc = null\n',1,'test_mail_no_receivers_and_constructor_changes_preserve_original_and_cleanup'),
 ('factory-reentry-cleanup','SOURCE','/proc/paper_document_create_copy','\t\tqdel(result)\n','',1,'test_constructor_reentry_cleans_unpublished_copy_and_retains_source'),
 ('prompt-stale-no-transfer','SOURCE','/obj/structure/printingpress/proc/insert_copy_paper',' || !paper_document_copy_current(snapshot)','',2,'test_insert_normal_cancel_stale_slot_revision_session_and_drop_callbacks'),
 ('double-capacity-debit','PAPER',None,'!copy_skip_space && isnull(document_record)','isnull(document_record)',1,'test_delayed_constructor_capacity_guard_has_legacy_positive_and_copy_controls'),
 ('classified-teleprinter-refusal','TELE',None,' || !isnull(C.document_record)','',1,'test_teleprinter_legacy_positive_and_classified_deleted_lost_custody_negative'),
 ('void-press-publication','SOURCE',None,'if (!isturf(place))','if (FALSE)',1,'test_press_retirement_during_construction_and_void_publication_cleanup'),
 ('reserved-insertion-rescue','SOURCE','/obj/structure/printingpress/Destroy','if (P && !P.gc_destroyed && (P.loc == src || isnull(P.loc)))','if (FALSE)',1,'test_destruction_during_held_transfer_rescues_reserved_input_before_parent'),
]
def run():
 rows=[]
 for name,field,signature,before,after,count,method in controls:
  original=getattr(tests,field);fragment=tests.vm.body(original,signature) if signature else original
  assert fragment.count(before)==count,(name,'anchor drift')
  # For the prompt control mutate only the first (pre-transfer) check.
  changed=fragment.replace(before,after,1 if name=='prompt-stale-no-transfer' else count)
  setattr(tests,field,original.replace(fragment,changed,1) if signature else changed)
  try:
   stream=io.StringIO();result=unittest.TextTestRunner(stream=stream,verbosity=2).run(unittest.TestSuite([tests.Copies(method)]))
   rows.append(dict(control=name,tests=result.testsRun,failures=len(result.failures),errors=len(result.errors),log=stream.getvalue()))
  finally:setattr(tests,field,original)
 assert all(x['failures'] and not x['errors'] and 'ast.parse' not in x['log'] and 'Unsupported statement' not in x['log'] and 'Unknown call boundary' not in x['log'] for x in rows),rows
 return dict(status='passed',controls=rows,local_only=True,native_executed=False)
if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
 result=run();args.output.write_text(json.dumps(result,indent=2)+'\n');print('PASS '+str(len(result['controls']))+' causal controls; native not executed')
