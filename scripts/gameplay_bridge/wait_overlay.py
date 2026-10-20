"""Print the explicit one-use gather helper diff; never edit shared source."""
import argparse
import difflib
import hashlib
from pathlib import Path
from gather_context import FEATURE, MARKER, PATHS, DISABLED_SHA256, project
PUBLIC_BASE_SHA256 = DISABLED_SHA256[PATHS[0]]

def only(text):
    return '#ifdef '+FEATURE+'\n'+text+'#endif\n'

def choose(old, new):
    assert old.endswith('\n') and new.endswith('\n')
    return '#ifdef '+FEATURE+'\n'+new+'#else\n'+old+'#endif\n'

def change(source, old, new):
    assert source.count(old) == 1, old[:100]
    return source.replace(old, choose(old, new), 1)

def guarded_source(source):
    if hashlib.sha256(source.encode()).hexdigest() != PUBLIC_BASE_SHA256:
        raise ValueError("production do_after changed; review integration again")
    s=source
    signature=next(line for line in s.splitlines(True) if line.startswith('/proc/do_after('))
    s=change(s,signature,signature.rstrip()[:-1]+', datum/gameplay_action_lease/gameplay_context = null)\n')
    # Insert only in do_after, preserving do_mob and all outside text.
    start=s.index('#ifdef '+FEATURE+'\n/proc/do_after(');end=s.index('//Returns a list of all mobs',start)
    body=s[start:end]
    capture=('\tif (!isnull(gameplay_context) && !isnull(mining_context))\n\t\treturn FALSE\n'
             '\tvar/datum/gameplay_action_lease/gameplay_lease\n'
             '\tif (!isnull(gameplay_context))\n'
             '\t\tif (!istype(gameplay_context, /datum/gameplay_action_lease))\n\t\t\treturn FALSE\n'
             '\t\tgameplay_lease = gameplay_context\n'
             '\t\tif (!gameplay_lease.claim_gather_wait(user, target))\n\t\t\treturn FALSE\n')
    entry='\tif (!isnull(mining_context) && (!istype(mining_context, /datum/pickaxe_mining_action) || !mining_context.claim(user, target)))\n'
    assert body.count(entry)==1
    body=body.replace(entry,only(capture)+entry,1)
    body=body.replace('\t\tsleep(0.1)\n','\t\tsleep(0.1)\n'+only('\t\tif (gameplay_lease && !gameplay_lease.valid())\n\t\t\t. = FALSE\n\t\t\tbreak\n'),1)
    body=body.replace('\tif (progbar)\n\t\tqdel(progbar)\n','\tif (progbar)\n\t\tqdel(progbar)\n'+only('\tif (gameplay_lease && !gameplay_lease.valid())\n\t\t. = FALSE\n'),1)
    return s[:start]+only('#define '+MARKER+'\n')+body+s[end:]


def unguarded_source(source):
    """Verify exact reviewed guards and recover the unchanged disabled helper."""
    baseline = project(source, set())[0]
    if guarded_source(baseline) != source:
        raise ValueError("explicit gameplay guards drift")
    return baseline


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    relative = PATHS[0]
    source = (Path(__file__).resolve().parents[2] / relative).read_text(encoding="utf-8")
    baseline = unguarded_source(source)
    diff = "".join(difflib.unified_diff(baseline.splitlines(True), source.splitlines(True),
                                     fromfile="a/"+relative, tofile="b/"+relative))
    if args.output:
        args.output.write_text(diff, encoding="utf-8", newline="\n")
    else:
        print(diff, end="")

if __name__ == "__main__":
    main()
