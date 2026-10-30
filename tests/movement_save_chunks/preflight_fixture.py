"""Exact copied-source preflight baseline, with no native execution or I/O."""
START = '/datum/moving_save_preflight\n'
END = '/datum/moving_save_capture\n'


def split_preflight(source):
    if source.count(START) != 1 or source.count(END) != 1:
        raise ValueError('Preflight declaration boundaries changed')
    before, remainder = source.split(START)
    body, after = remainder.split(END)
    return before, body, after


def restore_preflight_reference_keys(source):
    """Change exactly two key expressions inside the original preflight body."""
    before, body, after = split_preflight(source)
    for old, new in (('\t\t\tvar/key = L\n', '\t\t\tvar/key = "\\ref[L]"\n'),
                     ('\t\tvar/key = exporter.save_entry_identity(D)\n', '\t\tvar/key = "\\ref[D]"\n')):
        if body.count(old) != 1: raise ValueError('Preflight key anchor changed: ' + old.strip())
        body = body.replace(old, new)
    return before + START + body + END + after


def reference_preflight_definition(source):
    restored = restore_preflight_reference_keys(source)
    _, body, _ = split_preflight(restored)
    if '/datum/moving_save_preflight_reference' in source:
        raise ValueError('Reference type already present')
    return '/datum/moving_save_preflight_reference\n' + body
