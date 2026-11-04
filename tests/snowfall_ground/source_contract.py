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
    projected = ''.join(result)
    # Keep callbacks/deadlines but remove locals made unused by snow-only loops.
    for phase in (8, 9):
        signature = '/obj/map_metadata/proc/season_phase_' + str(phase) + '(var/epoch)'
        if signature in projected:
            start = projected.index(signature)
            end = projected.find('\n/', start + 1)
            block = projected[start:end]
            projected = projected[:start] + block.replace('\n\tvar/season_work = 0', '') + projected[end:]
    projected = projected.replace('\t\t\tspawn(1200)\n/obj/map_metadata/colonia/cross_message',
                                  '\t\t\tspawn(1200)\n\t\t\t\treturn\n\n/obj/map_metadata/colonia/cross_message')
    return projected, removed


def without_later_master_changes(text):
    """Undo reviewed, unrelated master edits made after the historical baselines.

    Season readout (#3552), durable Nomads scheduling (#3577), the typo sweep
    (#3515), save-pointer exclusion (#3409) and the tgui migration (#3427)
    touched files these parity checks freeze. Each projection is exact so any
    other drift still fails.
    """
    text = re.sub(r'(?m)^\t+season_note_next_change\([^\n]*\)\n', '', text)
    text = re.sub(r'(?m)^\tif\(uses_durable_metadata\(\)\) return durable_nomads_seasons\([^\n]*\)\n', '', text)
    text = text.replace('\tif(!durable_schedule("nomads_initial_climate", 1800))\n'
                        '\t\tspawn(1800)\n'
                        '\t\t\tif (season == "SPRING") //fixes game setting the season as spring\n'
                        '\t\t\t\tseason = "Wet Season"\n',
                        '\tspawn(1800)\n'
                        '\t\tif (season == "SPRING") //fixes game setting the season as spring\n'
                        '\t\t\tseason = "Wet Season"\n')
    text = text.replace("'good'>Successfully ", "'good'>Sucessfully ")
    text = text.replace('\t// Constructor/Life-owned UI graphs must not be overwritten by the null\n'
                        '\t// references used for unsaved /datum/action entries, including legacy saves.\n'
                        '\tif (key == "actions" || key == "action")\n'
                        '\t\treturn TRUE\n', '')
    text = text.replace('ui = new /datum/nanoui/tgui(user, src, ui_key, "warehouse_book.tmpl"',
                        'ui = new(user, src, ui_key, "warehouse_book.tmpl"')
    return text
