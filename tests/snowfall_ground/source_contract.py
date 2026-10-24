"""Restrict historical parity comparisons to the deliberately removed snow loops."""
import re


def without_season_snow(text):
    lines = text.splitlines(keepends=True)
    result, removed, i = [], [], 0
    while i < len(lines):
        line = lines[i]
        if line.lstrip().startswith('for (var/turf/floor/'):
            depth = len(line) - len(line.lstrip('\t'))
            end = i + 1
            while end < len(lines) and (not lines[end].strip() or len(lines[end]) - len(lines[end].lstrip('\t')) > depth):
                end += 1
            block = ''.join(lines[i:end])
            if '/winter/' in line or '/winter/' in block or re.search(r'ChangeTurf\(/turf/floor/(?:dirt/)?winter\)', block) or re.search(r'for \(var/turf/floor/(?:dirt/)?winter[/ ]', line):
                removed.append(block)
                i = end
                continue
        result.append(line)
        i += 1
    return ''.join(result), removed
