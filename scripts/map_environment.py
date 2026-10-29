"""Pure map-include rewrite shared by the legacy launcher and offline checks."""
import re

BEGIN = '// BEGIN_SELECTED_MAP'
END = '// END_SELECTED_MAP'


def select_map(source: str, map_path: str) -> str:
    if not map_path or any(char in map_path for char in ('"', '\n', '\r')) or not map_path.lower().endswith('.dmm'):
        raise ValueError('Invalid map include')
    include = f'#include "{map_path}"\n'
    if BEGIN in source or END in source:
        if source.count(BEGIN) != 1 or source.count(END) != 1:
            raise ValueError('Ambiguous selected-map block')
        start = source.index(BEGIN) + len(BEGIN)
        end = source.index(END)
        if end <= start:
            raise ValueError('Invalid selected-map block')
        return source[:start] + '\n' + include + source[end:]
    # Historical environments have a flat include list. Conditional map blocks
    # require explicit markers rather than guessing their preprocessing scope.
    lines = source.splitlines(keepends=True)
    matching = [i for i, line in enumerate(lines) if re.match(r'^\s*#include\s+"[^"\n]+\.dmm"\s*$', line)]
    if not matching or any(re.match(r'^\s*#(?:if|else|endif)', line) for line in lines[matching[0]:matching[-1] + 1]):
        raise ValueError('Unmarked conditional map environment')
    result = []
    depth = 0
    for i, line in enumerate(lines):
        if re.match(r'^\s*#if', line):
            depth += 1
        if i in matching:
            if depth:
                raise ValueError('Unmarked conditional map include')
            if i == matching[0]:
                result.append(include)
        else:
            result.append(line)
        if re.match(r'^\s*#endif', line):
            depth -= 1
    return ''.join(result)
