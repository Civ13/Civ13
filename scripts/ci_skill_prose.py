"""Shared classification of reviewed skill prose for CI selection."""


def skill_prose(path):
    parts = path.split('/')
    return (len(parts) >= 4 and parts[:2] == ['.agents', 'skills']
            and all(part not in ('', '.', '..') for part in parts)
            and (parts[-1] == 'SKILL.md'
                 or ('references' in parts[3:-1] and parts[-1].endswith('.md'))))
