"""Local causal omission controls; no native processes or source writes."""
from pathlib import Path
import importlib.util,io,json,unittest
spec=importlib.util.spec_from_file_location('paper_document_contract',Path(__file__).with_name('test_documents.py'))
contract=importlib.util.module_from_spec(spec);spec.loader.exec_module(contract)
projection=contract.projection;source=projection.SOURCE;lang=projection.LANG
controls=[
 ('language_membership','LANG','known.type == L.type && ','',1,'test_actor_pen_language_capacity_and_field_mutation_guards'),
 ('read_projection','SOURCE','full_legacy && paper_knows_written_language(reader, section["language_id"])','full_legacy',1,'test_every_text_kind_is_projected_without_unknown_originals'),
 ('schema_version','SOURCE','record["schema_version"] != 1 || ','',1,'test_malformed_records_fail_closed_without_repair_or_prefix'),
 ('revision','SOURCE',' || current["revision"] != revision','',2,'test_stale_revision_document_and_legacy_drift_reject_without_changes'),
 ('active_pen','SOURCE',' && actor.get_active_hand() == pen','',1,'test_actor_pen_language_capacity_and_field_mutation_guards'),
 ('runtime_service','SOURCE','/datum/paper_document_service\n\tshould_save = FALSE\n','/datum/paper_document_service\n',1,'test_runtime_service_never_persists_and_old_writer_is_unmodified'),
 ('container_parent','SOURCE',' && container.loc == actor','',1,'test_logout_transfer_deleted_item_and_closed_container_reject'),
 ('record_validation_budget','SOURCE','budget = new /datum/paper_document_budget/record()\n\tpaper_document_copy(record, budget)','budget = new()\n\tpaper_document_copy(record, budget)',1,'test_all_128_sections_append_validate_project_and_copy_then_129_is_atomic'),
 ('append_copy_budget','SOURCE','budget = new /datum/paper_document_budget/record()\n\tvar/list/next =','budget = new()\n\tvar/list/next =',1,'test_all_128_sections_append_validate_project_and_copy_then_129_is_atomic'),
 ('canonical_copy_budget','SOURCE','budget = new /datum/paper_document_budget/record()\n\tvar/list/result =','budget = new()\n\tvar/list/result =',1,'test_all_128_sections_append_validate_project_and_copy_then_129_is_atomic'),
]
rows=[]
for name,target,before,after,count,method in controls:
 original=source if target=='SOURCE' else lang;assert original.count(before)==count,name
 setattr(projection,target,original.replace(before,after));contract.SOURCE=projection.SOURCE
 output=io.StringIO();result=unittest.TextTestRunner(stream=output,verbosity=2).run(unittest.TestSuite([contract.Documents(method)]))
 rows.append(dict(control=name,failures=len(result.failures),errors=len(result.errors),caught=bool(result.failures) and not result.errors,detail=output.getvalue()))
 projection.SOURCE=source;projection.LANG=lang;contract.SOURCE=source
print(json.dumps(rows,indent=2));assert all(r['caught'] for r in rows)
