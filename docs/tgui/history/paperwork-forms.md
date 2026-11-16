# Paper form fields

Written (canonical) documents can hold blanks that anyone with a pen fills in
later. Both halves are ordinary language-tagged sections, so the reader
projection, study, crumpling and faithful copies treat them like other text.

- `field_label`: the blank's caption ("Name", "Date of birth"), at most 128
  characters. Its section id is the blank's stable target.
- `field_answer`: the answer. It has one extra key, `target`, naming the
  label it fills. A record is valid only when every answer targets an earlier
  label and each label has at most one answer
  (`paper_document_record_valid`). `paper_document_field_open` reports
  whether a label is still empty.

Writing: the TGUI editor's Section choice offers "Blank to fill in" and
"Fill in a blank" (with a picker of open blanks). The request carries
`target` only for answers (`paper_editor_request`), and
`/datum/paper_document_authoring/append` rejects an answer to a missing,
filled or non-label section, and a target on any other kind. A paper's first
write cannot be an answer. Answers keep their own writer's language, ink and
pen, and spend paper space like other writing.

Reading: the classic reader and the editor page draw each label as
`Label: answer`, or `Label: ____` while empty; answers are shown on their
label's line rather than in writing order. Projection keeps an answer's
`target` (layout only) while unknown-language text is still redacted.

Legacy `[field]` blanks in old unclassified papers keep the old field editor.

Checks: `python3 -m unittest tests/paper_documents/test_forms.py`, the vitest
cases in `tgui/src/interfaces/PaperEditor.test.tsx`, and the native probe
`python3 tests/ecology_spawning/run_linux.py . tests/paper_documents/forms_probe.dm`.
