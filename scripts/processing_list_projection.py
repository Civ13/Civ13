"""Project the scheduler priorities required by the isolated fixture."""
import re


def project_priorities(source):
    lines = []
    for name in ("PROCESS_PRIORITY_VERY_HIGH", "PROCESS_PRIORITY_MEDIUM"):
        matches = re.findall(r"^#define[ \t]+" + name + r"[ \t]+[^\r\n]+$", source, re.MULTILINE)
        if len(matches) != 1:
            raise ValueError(f"Expected exactly one definition of {name}, found {len(matches)}")
        lines.append(matches[0])
    return "\n".join(lines) + "\n"
