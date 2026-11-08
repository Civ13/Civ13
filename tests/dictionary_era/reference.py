"""Python models of the speech dictionary, written apart from the DM code.

`legacy_apply` is the frozen pre-rework loop (ordered replacetext rows plus
`phrase` rows). `apply` is the single-pass whole-word matcher. The DM fixture
records both engines' output in corpus.json, and the tests check that these
models reproduce it.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
ERAS = [None, *range(9)]

# --- Speech prefixes (code/_helpers/text.dm) ---------------------------------

ENTITIES = {'&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&#34;', "'": '&#39;'}


def html_encode(text):
    return ''.join(ENTITIES.get(c, c) for c in text)


def sanitize(text, max_length=4096):
    text = text[:max_length - 1].replace('\n', ' ').replace('\t', ' ')
    return trim(html_encode(text))


def trim(text):
    # trim() drops every character up to space (code 32) at both ends.
    return text.strip(''.join(map(chr, range(33))))


def capitalize(text):
    return text[:1].upper() + text[1:]


def say_prefix(text):
    return capitalize(sanitize(text))


# --- Casing, as BYOND replacetext() applies it -------------------------------

def match_case(typed, source, replacement):
    if source != ascii_lower(source):
        return replacement
    if not typed or not 'A' <= typed[0] <= 'Z':
        return replacement
    if len(typed) >= 2 and 'A' <= typed[1] <= 'Z':
        return replacement.upper()
    return replacement[:1].upper() + replacement[1:]


def ascii_lower(text):
    return ''.join(c.lower() if c.isascii() else c for c in text)


# --- Legacy: ordered rows, literal substrings, opt-in phrase rows ------------

LEGACY_BOUNDARIES = {9, 10, 11, 12, 13, 32, 33, 34, 40, 41, 44, 46, 58, 59, 63, 91, 93, 123, 125}


def legacy_rows(text):
    rows = []
    for line in text.split('\n'):
        if ',' not in line:
            continue
        row = line.split(',')
        if len(row) not in (2, 3, 4):
            continue
        if len(row) >= 3:
            if row[2].strip() not in list('012345678'):
                continue
            row[2] = int(row[2].strip())
        if len(row) == 4:
            if row[3].strip() != 'phrase' or not row[0] or row[0] != row[0].strip() or not row[0].isascii():
                continue
            row[3] = 'phrase'
        rows.append(row)
    return rows


def _find(message, source, start):
    return ascii_lower(message).find(ascii_lower(source), start)


def legacy_replacetext(message, source, replacement):
    out, at = [], 0
    while (found := _find(message, source, at)) >= 0:
        out.append(message[at:found])
        out.append(match_case(message[found:found + len(source)], source, replacement))
        at = found + len(source)
    return ''.join(out) + message[at:]


def legacy_phrase(message, source, replacement):
    def boundary(position):
        return position < 0 or position >= len(message) or ord(message[position]) in LEGACY_BOUNDARIES
    out, copied, search = [], 0, 0
    while (found := _find(message, source, search)) >= 0:
        if boundary(found - 1) and boundary(found + len(source)):
            out += [message[copied:found], replacement]
            copied = search = found + len(source)
        else:
            search = found + 1
    return ''.join(out) + message[copied:]


def legacy_apply(message, rows, era):
    for row in rows:
        if len(row) >= 3 and (era is None or row[2] != era):
            continue
        if len(row) == 4:
            message = legacy_phrase(message, row[0], row[1])
        else:
            message = legacy_replacetext(message, row[0], row[1])
    return message


# --- New: one pass, leftmost-longest, whole words ----------------------------

SEPARATORS = set(' \t\n\r\x0b\x0c!"(),.:;?[]{}&#')
RESERVED = '\x01\x02\x03'


def is_word(character):
    return character not in SEPARATORS


def valid_text(text):
    return bool(text) and text == trim(text) and all(32 <= ord(c) <= 126 for c in text)


def parse(lines):
    """Rows of (source, replacement, era or None); None for each skipped line."""
    rows, seen, accepted = [], set(), []
    for line in lines:
        if line.endswith('\r'):
            line = line[:-1]
        if ',' not in line or line.startswith('#'):
            continue
        fields = line.split(',')
        row = None
        if len(fields) in (2, 3):
            era = None
            ok = True
            if len(fields) == 3:
                ok = fields[2].strip() in list('012345678')
                era = int(fields[2].strip()) if ok else None
            ok = ok and valid_text(fields[0]) and valid_text(fields[1])
            identity = (ascii_lower(fields[0]), era)
            if ok and identity not in seen:
                seen.add(identity)
                row = (fields[0], fields[1], era)
        accepted.append(row)
        if row:
            rows.append(row)
    return rows, accepted


def table(rows, era):
    selected = [row for row in rows if row[2] is not None and row[2] == era]
    restricted = {ascii_lower(row[0]) for row in selected}
    selected += [row for row in rows if row[2] is None and ascii_lower(row[0]) not in restricted]
    return [(html_encode(source), replacement) for source, replacement, _ in selected]


def apply(message, rows, era):
    """The rework, written from docs/dictionary.md rather than from the DM."""
    entries = table(rows, era if era in range(9) else None)
    for character in RESERVED:
        message = message.replace(character, '')
    lowered = ascii_lower(message)
    out, at, length = [], 0, len(message)

    def whole(start, end):
        left = start == 0 or not is_word(message[start - 1]) or not is_word(message[start])
        right = end == length or not is_word(message[end]) or not is_word(message[end - 1])
        return left and right

    position = 0
    while position < length:
        best = None
        for source, replacement in entries:
            end = position + len(source)
            if lowered.startswith(ascii_lower(source), position) and whole(position, end):
                if best is None or len(source) > len(best[0]):
                    best = (source, replacement)
        if best is None:
            position += 1
            continue
        out += [message[at:position], match_case(message[position:position + len(best[0])], best[0], best[1])]
        position = at = position + len(best[0])
    return ''.join(out) + message[at:]


def load(path):
    return (ROOT / path).read_text(encoding='utf-8')


def current_rows():
    return parse(load('config/dictionary.txt').split('\n'))[0]


def frozen_legacy_rows():
    return legacy_rows((HERE / 'legacy' / 'dictionary.txt').read_text(encoding='utf-8'))
