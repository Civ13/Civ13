"""Reviewed first-gather conditional source projection; never executes DM.

Restricted to two known conditional symbols. Not a general DM preprocessor.
Pinned whole-file disabled hashes bind the public 670 source without Git objects.
"""
import hashlib

FEATURE = "CIV13_GAMEPLAY_BRIDGE"
MARKER = "CIV13_GAMEPLAY_WAIT_GUARDS"
PATHS = ("code/_helpers/mobs.dm", "code/game/turfs/floor_attackby.dm",
         "code/modules/gameplay_bridge/bridge.dm", "code/modules/gameplay_bridge/mechanics.dm")
DISABLED_SHA256 = {
 PATHS[0]: "31002a014453dc9240b3dc39933d2d30a012b2769ee8ed704bd2057e2c1b2214",
 PATHS[1]: "2dd5710c82a07635608f29825eb30d3d15e47fc9ba9fdc50e22bf8b46ce2a9a7",
 PATHS[2]: "0e51dfc52f32c5729cff3a8cb18c4a21746f66968a5f5b9a37838f67e0ac3912",
 PATHS[3]: "d9dcfdf9d56086b86ec8a88db95c9f30bd84099567b9cb7bcefef188857ac73f",
}

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
