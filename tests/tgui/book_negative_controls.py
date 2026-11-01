"""Causal source omission controls, in memory; no native runtime or writes."""
import io,json,unittest
import test_book_reader as contract
source=contract.SOURCE
controls=[
 ('owner',' || user != reader','','test_detached_owner_lifecycle_and_close_noninterference'),
 ('client',' || user.client != reader_client','','test_detached_owner_lifecycle_and_close_noninterference'),
 ('close_side_effect','\t\tui.use_on_close_logic(FALSE)\n','','test_detached_owner_lifecycle_and_close_noninterference'),
 ('cached_html_guard','\tif (!istype(reader_state) || reader_state.can_use_topic(src_object, user) == STATUS_CLOSE)\n\t\treturn ""\n','','test_detached_owner_lifecycle_and_close_noninterference'),
 ('complete_fallback','\t\tui.legacy_renderer = TRUE\n','','test_metadata_rejects_whole_view'),
 ('metadata_admission','book_page_metadata(title_snapshot) && book_page_metadata(name_snapshot)','book_page_metadata(title_snapshot)','test_metadata_rejects_whole_view'),
 ('close_idempotence','\tif (reader_closed)\n\t\treturn\n','','test_detached_owner_lifecycle_and_close_noninterference'),
]
results=[]
for name,before,after,method in controls:
 assert source.count(before)==1,(name,'ambiguous control preimage')
 contract.SOURCE=source.replace(before,after,1);out=io.StringIO()
 result=unittest.TextTestRunner(stream=out,verbosity=2).run(unittest.TestSuite([contract.BookReaderContract(method)]))
 results.append(dict(control=name,tests=result.testsRun,failures=len(result.failures),errors=len(result.errors),caught=bool(result.failures) and not result.errors,details=out.getvalue()))
contract.SOURCE=source
print(json.dumps(results,indent=2));assert all(x['caught'] for x in results)
