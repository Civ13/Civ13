# Paper in envelopes, bundles and filing cabinets

Writing (`/datum/paper_document_service/proc/has_access`) admits a page:

- held, or on an adjacent turf;
- in a held clipboard or folder;
- in a held, open envelope (`paper_document_envelope_open`);
- that is the open page of a held bundle, or of a bundle in a held folder
  (`paper_document_bundle_page`, `paper_document_held_folder`).

The authoring session pins the container's holder for envelopes and bundles
as it already did for clipboards and folders, so handing the container away
ends the session. Turning a bundle's page also stops writing on the old page.
Closed envelopes, other bundle pages and noticeboards refuse. Before this,
a written (canonical) page inside an envelope or bundle could not be written
on at all, because the editor never fell back to the old writer for it.

Filing cabinets list their contents sorted by name. Papers have a Read link
that opens them in place through the "filing" reader route (adjacent, not
incapacitated), and retrieving checks the same.

Envelopes save the wax colour (`wax_colour`) and redraw the seal overlay in
`after_load`; only the six offered colours are drawn.

Checks: `tests/paper_documents/test_authoring.py`
(`test_held_containers_and_turf_use_actual_access_without_broadening`) and the
native probe `python3 tests/ecology_spawning/run_linux.py .
tests/paper_documents/containers_probe.dm`.
