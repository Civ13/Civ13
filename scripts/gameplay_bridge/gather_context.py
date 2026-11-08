"""Reviewed first-gather conditional source projection; never executes DM.

Restricted to two known conditional symbols. Not a general DM preprocessor.
Whole-file disabled hashes bind master10d264e5 plus the explicit physical
stationary-wait change, grass busy-admission guard and call-local mining work
images. The helper/bridge/mechanics projections stay unchanged. Mining waits
are unchanged; independent mining ore yields are now separately verified. These
are source, not native checks.
"""
import hashlib
import re

FEATURE = "CIV13_GAMEPLAY_BRIDGE"
MARKER = "CIV13_GAMEPLAY_WAIT_GUARDS"
PATHS = ("code/_helpers/mobs.dm", "code/game/turfs/floor_attackby.dm",
         "code/modules/gameplay_bridge/bridge.dm", "code/modules/gameplay_bridge/mechanics.dm")
DISABLED_SHA256 = {
 PATHS[0]: "65300bd76e9f96a461eb0a7faf486239d78deeedb27df183c2f0447dee365904",
 PATHS[1]: "a7643f66b77f8e342eb0140105152b52dc2b6410455710fa91b23053dde2bcf6",
 PATHS[2]: "03d24a6cfbdbce40b25d1d085f5eea5871970b64365579dc40d8dddad85ba37d",
 PATHS[3]: "0864eee5ae079c6d3f98bfc50fec6388e499168e21a0ec09a6b0df45edd7ea4b",
}
CLIENT_FILES = ("code/modules/client/client_procs.dm", "code/modules/client/movement.dm")


def isolate_client_new(source):
    """Remove one actual entry method; the fixture supplies one denied New."""
    pattern = r"(?ms)^/client/New\([^\n]*\)\n.*?(?=^/(?!/)|\Z)"
    if len(re.findall(r"(?m)^/client/New\(", source)) != 1:
        raise ValueError("client entry isolation drift")
    result, count = re.subn(pattern, "", source, count=1)
    if count != 1 or re.search(r"(?m)^/client/New\(", result):
        raise ValueError("client entry removal failed")
    return result

def project(source, symbols):
    """Restricted conditional projector, NOT DM/macro expansion or includes.

    Only two known object symbols/ifdef/ifndef/else/endif are interpreted.
    Nonconditional text, includes and unrelated defines remain byte-for-byte.
    Unsupported conditional syntax fails rather than guessing.
    """
    defined = set(symbols); stack = []; active = True; output = []
    for line in source.splitlines(True):
        op = line.strip().split()
        if op and op[0] in ('#ifdef', '#ifndef'):
            if len(op) != 2 or op[1] not in (FEATURE, MARKER): raise ValueError('unknown condition')
            condition = op[1] in defined
            if op[0] == '#ifndef': condition = not condition
            stack.append((active, condition, False)); active = active and condition
        elif op and op[0] == '#else':
            if len(op)!=1 or not stack or stack[-1][2]: raise ValueError('invalid else')
            parent, condition, _ = stack[-1];stack[-1]=(parent,condition,True)
            active = parent and not condition
        elif op and op[0] == '#endif':
            if len(op)!=1 or not stack: raise ValueError('invalid endif')
            active = stack.pop()[0]
        elif op and op[0] in ('#if', '#elif', '#undef'):
            raise ValueError('unsupported directive')
        elif op and op[0] == '#define' and len(op)>1 and op[1] in (FEATURE, MARKER):
            if len(op)!=2: raise ValueError('valued feature macro')
            if active: defined.add(op[1])
        elif active:
            output.append(line)
    if stack: raise ValueError('unclosed condition')
    return ''.join(output), defined

def verify_disabled(files):
    for path, expected in DISABLED_SHA256.items():
        actual = hashlib.sha256(project(files[path], set())[0].encode()).hexdigest()
        if actual != expected:
            raise ValueError("disabled whole-file projection drift: " + path)
