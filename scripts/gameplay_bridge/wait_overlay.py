"""Print the reviewable approved do_after diff; never edit shared source.

Historical aeaf hook only. The successor's shared helper is NOT patched.
Current-base integration requires separate source allocation and review.
"""
import difflib
import argparse
import hashlib
from pathlib import Path

BASE_COMMIT = "e5fca75511a924f180f191f8f9fb15849b5ab2ae"
BASE_RAW_SHA256 = "f8184110866f2e77589fd8835c7612aee9641f863e9b81389d50f94cfc117163"


def guarded_source(source):
    start = source.index("/proc/do_after(")
    end = source.index("//Returns a list of all mobs", start)
    body = source[start:end]
    before_wait = "\tif (check_for_repeats)\n"
    after_sleep = "\t\tsleep(0.1)\n"
    final_cleanup = "\tif (progbar)\n\t\tqdel(progbar)\n"
    if any(body.count(anchor) != 1 for anchor in (before_wait, after_sleep, final_cleanup)):
        raise ValueError("production do_after changed; review integration again")
    capture = ("#ifdef CIV13_GAMEPLAY_BRIDGE\n"
               "\tvar/datum/gameplay_action_lease/gameplay_lease = gameplay_bridge.wait_lease(user)\n"
               "\tif (gameplay_lease && !gameplay_lease.valid())\n\t\treturn FALSE\n#endif\n")
    wake = ("#ifdef CIV13_GAMEPLAY_BRIDGE\n"
            "\t\tif (gameplay_lease && !gameplay_lease.valid())\n\t\t\t. = FALSE\n\t\t\tbreak\n#endif\n")
    finish = ("#ifdef CIV13_GAMEPLAY_BRIDGE\n"
              "\tif (gameplay_lease && !gameplay_lease.valid())\n\t\t. = FALSE\n#endif\n")
    body = body.replace(before_wait, capture + before_wait)
    body = body.replace(after_sleep, after_sleep + wake)
    body = body.replace(final_cleanup, final_cleanup + finish)
    marker = "#ifdef CIV13_GAMEPLAY_BRIDGE\n#define CIV13_GAMEPLAY_WAIT_GUARDS\n#endif\n"
    return source[:start] + marker + body + source[end:]


def unguarded_source(source):
    """Strip only our conditional blocks; disabled source must equal baseline."""
    lines, output, removing, blocks = source.splitlines(True), [], False, 0
    for line in lines:
        if line == "#ifdef CIV13_GAMEPLAY_BRIDGE\n":
            if removing:
                raise ValueError("nested gameplay guard")
            removing, blocks = True, blocks + 1
        elif removing and line == "#endif\n":
            removing = False
        elif not removing:
            output.append(line)
    if removing or blocks != 4:
        raise ValueError("missing gameplay guards")
    if source.count("gameplay_bridge.wait_lease(user)") != 1:
        raise ValueError("lease must be captured exactly once")
    baseline = "".join(output)
    if guarded_source(baseline) != source:
        raise ValueError("guard implementation drift")
    return baseline


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    relative = "code/_helpers/mobs.dm"
    source = (root / relative).read_text(encoding="utf-8")
    if "#define CIV13_GAMEPLAY_WAIT_GUARDS" in source:
        source = unguarded_source(source)
    if hashlib.sha256(source.encode()).hexdigest() != BASE_RAW_SHA256:
        raise ValueError("historical wait helper drift; current-base integration not allocated")
    diff = "".join(difflib.unified_diff(source.splitlines(True), guarded_source(source).splitlines(True),
                                     fromfile="a/" + relative, tofile="b/" + relative))
    if args.output:
        with args.output.open("w", encoding="utf-8", newline="\n") as output:
            output.write(diff)
    else:
        print(diff, end="")


if __name__ == "__main__":
    main()
