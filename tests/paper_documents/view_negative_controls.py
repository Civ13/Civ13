"""Local causal controls for the read boundary; not automatically selected by CI."""
import argparse
import importlib.util
import io
import json
from pathlib import Path
import unittest
from unittest.mock import patch

spec=importlib.util.spec_from_file_location('paper_view_controls',Path(__file__).with_name('test_views.py'))
tests=importlib.util.module_from_spec(spec);spec.loader.exec_module(tests)
CONTROLS={
 'read-context-write':('writing || !paper','FALSE || !paper','test_every_reader_context_is_incapable_of_mutation'),
 'client-session':('reader.client != control_client','FALSE','test_request_rejects_reconnected_transferred_or_foreign_controller'),
 'container-membership':('P.loc != owner','FALSE','test_membership_container_movement_and_actual_page_identity_rechecked'),
 'selected-page':('B.pages[B.page] != P','FALSE','test_membership_container_movement_and_actual_page_identity_rechecked'),
 'board-distance':('istype(owner, /obj/structure/noticeboard) && owner.Adjacent(reader)','istype(owner, /obj/structure/noticeboard) && TRUE','test_membership_container_movement_and_actual_page_identity_rechecked'),
 'literal-new-text':('var/text = html_encode(section["text"])','var/text = section["text"]','test_known_new_ink_signature_and_literal_markup_render_without_reinterpretation'),
 'error-fallback':('if (result && !result["error"])','if (result)','test_stale_or_malformed_classified_records_never_fall_back_to_raw_cache'),
 'classified-link-cache':('isnull(paper.document_record) ? "[paper.info_links][paper.stamps]" : "[paper.info][paper.stamps]"','"[paper.info_links][paper.stamps]"','test_every_route_redacts_all_unknown_text_in_complete_data_and_html'),
 'title-encode-without-decode':('return html_encode(html_decode(value))','return html_encode(value)','test_title_decodes_once_reencodes_and_preserves_literal_entities_and_markup'),
 'title-recursive-decode':('return html_encode(html_decode(value))','return html_encode(html_decode(html_decode(value)))','test_title_decodes_once_reencodes_and_preserves_literal_entities_and_markup'),
 'crayon-signature-bold':('if (section["tool"] == "crayon")','if (section["tool"] == "crayon" && section["kind"] != "signature")','test_crayon_signature_retains_combined_bold_italic_and_ink'),
}

def run():
 rows=[];original=tests.environment
 for name,(before,after,target) in CONTROLS.items():
  # The legacy write adapter now shares the page predicate. Mutate this
  # original reader boundary alone, retaining the same causal assertion.
  scope=tests.vm.body(tests.SOURCE,'/proc/paper_document_route_access') if name=='selected-page' else tests.SOURCE
  assert scope.count(before)==1,(name,'source anchor drift')
  changed=scope.replace(before,after)
  source=tests.SOURCE.replace(scope,changed,1) if scope!=tests.SOURCE else changed
  stream=io.StringIO()
  with patch.object(tests,'environment',lambda:original(source)):
   result=unittest.TextTestRunner(stream=stream).run(unittest.TestSuite([tests.Views(target)]))
  assert len(result.failures)>=1 and not result.errors,(name,stream.getvalue())
  rows.append(dict(control=name,tests=result.testsRun,failures=len(result.failures),errors=len(result.errors),
                   target=target,result='expected assertion failure',log=stream.getvalue()))
 return dict(status='passed',controls=rows,local_only=True,native_executed=False)

if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--output',required=True,type=Path)
 args=parser.parse_args();result=run();args.output.write_text(json.dumps(result,indent=2)+'\n')
 print('PASS '+str(len(result['controls']))+' causal omission controls; native not executed')
