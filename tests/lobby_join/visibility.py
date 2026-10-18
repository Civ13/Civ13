"""Native verb metadata coverage and an invisible-command negative control."""
from test_source import procedure


def visibility_verbs(source):
    # Preserve production metadata and body. The offline fixture inspects the
    # compiled verb; actual connected-client dispatch is separate acceptance.
    verb = procedure(source, "/mob/new_player/verb/Join()")
    assert verb.count("set invisibility = 0") == 1
    unsafe = verb.replace("/mob/new_player/verb/Join()", "/mob/new_player/verb/UnsafeJoin()", 1)
    unsafe = unsafe.replace('set name = "Join"', 'set name = "UnsafeJoin"')
    unsafe = unsafe.replace("set invisibility = 0", "set invisibility = 101")
    return verb + "\n" + unsafe
