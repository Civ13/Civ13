"""Local lifecycle guard omissions; count behavioral assertions, never errors."""
import importlib.util,io,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('lifecycle_control_fixture',Path(__file__).with_name('test_lifecycle.py'))
tests=importlib.util.module_from_spec(spec);spec.loader.exec_module(tests)

def omit(source,signature,old,new):
 fragment=tests.vm.body(source,signature);assert fragment.count(old)==1,(signature,old)
 return source.replace(fragment,fragment.replace(old,new),1)

def run():
 cases=[
  ('peer retirement','/decl/observ/paper_authoring/proc/notify','if (session != exempt)','if (FALSE)','test_logout_snapshot_dispatch_retires_multiple_sessions_and_owned_windows'),
  ('close noninterference','/datum/paper_document_authoring/proc/bind_ui','ui.use_on_close_logic(FALSE)','ui.use_on_close_logic(TRUE)','test_ui_close_idempotence_and_machine_noninterference'),
  ('direct unsubscribe','/datum/paper_document_authoring/proc/unwatch_movement','GLOB.moved_event.unregister(source, src, /datum/paper_document_authoring/proc/lifecycle_moved)','return','test_inactive_open_cancel_and_no_observer_residue'),
  ('captured forwarding cleanup','/datum/paper_document_authoring/proc/stop_lifecycle','if (!GLOB.moved_event.has_listeners(mover))','if (FALSE)','test_raw_relocation_and_lost_floor_range_are_sticky'),
  ('nested custody return','/datum/paper_document_authoring/proc/lifecycle_moved','if (old_loc != new_loc)','if (FALSE)','test_paper_pen_and_container_departure_return_cannot_revive_lease'),
  ('destruction retirement','/datum/paper_document_authoring/proc/lifecycle_destroyed','retire()','return','test_destroyed_subject_and_destroyed_window_cleanup'),
  ('raw relocation check','/datum/paper_document_authoring/proc/lifecycle_signal','if (!lifecycle_physical_current())','if (FALSE)','test_raw_relocation_and_lost_floor_range_are_sticky'),
  ('peer failure isolation','/decl/observ/paper_authoring/proc/notify','error(e.desc)','return FALSE','test_close_failure_cannot_stop_other_retirement_or_retain_authority'),
 ]
 original=tests.environment;rows=[]
 try:
  for name,signature,old,new,test in cases:
   changed=omit(tests.SOURCE,signature,old,new)
   tests.environment=lambda changed=changed:original(changed)
   stream=io.StringIO();result=unittest.TextTestRunner(stream=stream,verbosity=2).run(tests.Lifecycle(test));log=stream.getvalue()
   assert result.failures and not result.errors,(name,log)
   assert not any(x in log for x in ('ast.parse','Unsupported statement','Unknown call boundary')),(name,log)
   rows.append(dict(control=name,test=test,failures=len(result.failures),errors=len(result.errors),log=log))
 finally:tests.environment=original
 return dict(status='passed',local_only=True,native_executed=False,controls=rows)
if __name__=='__main__':print(json.dumps(run(),indent=2))
