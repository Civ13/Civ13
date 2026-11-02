"""Local causal editor guard omissions, not native dispatch acceptance."""
import importlib.util,io,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('editor_control_fixture',Path(__file__).with_name('test_editor.py'))
tests=importlib.util.module_from_spec(spec);spec.loader.exec_module(tests)
def replace_body(source,signature,old,new):
 fragment=tests.vm.body(source,signature);assert fragment.count(old)==1,(signature,old)
 return source.replace(fragment,fragment.replace(old,new),1)
def run():
 cases=[
 ('acknowledged transport','/datum/nanoui/tgui/paper_editor/consume_topic','!frontend_acknowledged','FALSE','test_ready_ack_status_owner_legacy_state_and_binding_guards'),
 ('actual caller','/datum/nanoui/tgui/paper_editor/consume_topic','usr != user','FALSE','test_ready_ack_status_owner_legacy_state_and_binding_guards'),
 ('fresh viewer projection','/datum/nanoui/tgui/paper_editor/push_data','var/list/current = editor_data()','var/list/current = isnull(data) ? editor_data() : data','test_every_push_reprojects_knowledge_and_ignores_cached_payload'),
 ('whole legacy fallback','/proc/paper_editor_modern_supported','if (!islist(view) || view["legacy_body_html"] != "")','if (!islist(view))','test_whole_legacy_and_crayon_views_select_readonly_fallback_before_open'),
 ('early closed preparation retirement','/proc/paper_editor_open','if (ui.editor_closed || !ui.state || !session.bind_ui(actor, session.session_lease, ui))\n\t\t\tsession.retire()','if (ui.editor_closed || !ui.state || !session.bind_ui(actor, session.session_lease, ui))','test_constructor_custody_transfer_early_close_and_failure_release_session'),
 ]
 original=tests.environment;original_nano=tests.NANO;rows=[]
 try:
  for name,signature,old,new,test in cases:
   changed=replace_body(tests.SOURCE,signature,old,new)
   tests.environment=lambda changed=changed:original(changed)
   stream=io.StringIO();result=unittest.TextTestRunner(stream=stream,verbosity=2).run(tests.Editor(test));log=stream.getvalue()
   assert result.failures and not result.errors,(name,log)
   assert not any(x in log for x in ('Unsupported statement','Missing procedure','ast.parse','Unknown call boundary')),(name,log)
   rows.append(dict(control=name,test=test,failures=len(result.failures),errors=len(result.errors),log=log))
  tests.environment=original
  tests.NANO=replace_body(original_nano,'/datum/nanoui/proc/consume_topic','return FALSE','return TRUE')
  stream=io.StringIO()
  test='test_original_nano_topic_dispatches_default_once_and_consumes_only_owned_path'
  result=unittest.TextTestRunner(stream=stream,verbosity=2).run(tests.Editor(test));log=stream.getvalue()
  assert result.failures and not result.errors,('legacy default dispatch',log)
  assert not any(x in log for x in ('Unsupported statement','Missing procedure','ast.parse','Unknown call boundary')),log
  rows.append(dict(control='legacy default dispatch',test=test,failures=len(result.failures),errors=len(result.errors),log=log))
 finally:
  tests.environment=original
  tests.NANO=original_nano
 return dict(status='passed',controls=rows,local_only=True,native_executed=False)
if __name__=='__main__':print(json.dumps(run(),indent=2))
