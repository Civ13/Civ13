"""Shared projections of the read-only window base (code/modules/nano/tgui_reader.dm).

Source projections only; no DM execution. Per-window tests use these instead of
copying the guard into every window."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
BASE = (ROOT / 'code/modules/nano/tgui_reader.dm').read_text()


def proc(source, signature):
    """The body of one top-level proc: its indented lines up to the next top-level line."""
    assert signature in source, f'Missing proc {signature}'
    lines = source.split(signature, 1)[1].split('\n')[1:]
    body = []
    for line in lines:
        if line and not line[0].isspace():
            break
        body.append(line)
    return '\n'.join(body)


def load(source):
    """Projects the base from `source`. Omission controls call this with an edited copy; nothing on disk changes."""
    global BASE, STATE, UPDATE, GET_HTML, CLOSE, OPEN_READER
    BASE = source
    STATE = proc(BASE, '/datum/topic_state/reader/can_use_topic(var/src_object, var/mob/user)')
    UPDATE = proc(BASE, '/datum/nanoui/tgui/snapshot/update(var/force_open = FALSE)')
    GET_HTML = proc(BASE, '/datum/nanoui/tgui/snapshot/get_html()')
    CLOSE = proc(BASE, '/datum/nanoui/tgui/snapshot/close()')
    OPEN_READER = proc(BASE, '/proc/open_reader_ui(mob/user, datum/subject, ui_key, ui_type, state_type)')


load(BASE)


def allowed(subject, src_object, user, reader, connected=True, rule=True):
    """Evaluates the production guard with synthetic values. `rule` stands for the window's reader_allowed()."""
    guard = re.search(r'if \((.+)\)\n\t\treturn STATUS_CLOSE', STATE).group(1)
    expression = (guard.replace('!reader_allowed(user)', 'not rule').replace('!user.client', 'not connected')
                  .replace('!subject', 'not subject').replace('!user', 'not user').replace('||', 'or').replace(' != ', ' is not '))
    return not eval(expression, {'__builtins__': {}}, dict(subject=subject, src_object=src_object, user=user, reader=reader, connected=connected, rule=rule))


def rule(source, type_name):
    """The return expression of a window's reader_allowed(), or None when it adds no rule."""
    signature = f'/datum/topic_state/reader/{type_name}/reader_allowed(mob/user)'
    if signature not in source:
        return None
    match = re.search(r'^\treturn (.+)$', proc(source, signature), re.M)
    assert match, f'{signature} has no single return'
    return match.group(1)
