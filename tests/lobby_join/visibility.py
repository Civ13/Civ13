"""Native verb metadata coverage and an invisible-command negative control."""
from test_source import procedure


def visibility_verbs(source):
    # Preserve production metadata and body. The offline fixture inspects the
    # compiled verb; actual connected-client dispatch is separate acceptance.
    verb = procedure(source, "/client/verb/Join()")
    assert verb.count("set invisibility = 0") == 1
    unsafe = verb.replace("/client/verb/Join()", "/client/verb/UnsafeJoin()", 1)
    unsafe = unsafe.replace('set name = "Join"', 'set name = "UnsafeJoin"')
    unsafe = unsafe.replace("set invisibility = 0", "set invisibility = 101")
    inherited = verb.replace("/client/verb/Join()", "/client/verb/InheritedJoin()", 1)
    inherited = inherited.replace('set name = "Join"', 'set name = "InheritedJoin"')
    inherited = inherited.replace("\tset invisibility = 0\n", "")
    return verb + "\n" + unsafe + "\n" + inherited


def client_route(source):
    """Explicit own-client/actor adapter, with no connected client constructed."""
    import re
    fields = procedure(source, '/client\n')
    route = procedure(source, '/client/verb/Join()')
    route = route.replace('/client/verb/Join()', '/datum/mock_client/proc/invoke_native_join()', 1)
    route = re.sub(r'^\s*set .*\n', '', route, flags=re.M)
    route = route.replace('usr.client', 'test_actor.test_client')
    route = re.sub(r'\busr\b', 'test_actor', route)
    return fields + '\n' + fields.replace('/client\n', '/datum/mock_client\n', 1) + '\n' + route
