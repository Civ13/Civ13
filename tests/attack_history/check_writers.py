"""Guard direct history mutations and the exact expressions in the migration."""
from collections import Counter
import hashlib
import json
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[2]
HELPER = 'code/modules/admin/admin_attack_log.dm'
ALLOWED = {
    (HELPER, '/mob/var/attack_log = list()'),
    (HELPER, 'attack_log = list()'),
    (HELPER, 'attack_log += entry'),
    (HELPER, 'attack_log.Cut(1, archive_count + 1)'),
    ('code/game/mob/observer/ghost/ghost.dm', 'attack_log = body.attack_log'),
    ('code/global.dm', 'var/attack_log\t\t  = null'),
    ('code/world.dm', 'attack_log = file("data/logs/attack/[time2text(world.realtime,"YYYY-MM-DD-(hh-mm-ss)")]-attack.log")'),
}
MUTATION = re.compile(r'\battack_log\s*(?:\+=|-=|\|=|&=|=(?!=)|\[[^\n]*\]\s*=|\.(?:Add|Insert|Remove|Cut|Swap|Splice)\s*\()')
APPEND = re.compile(r'^\s*((?:\w+\.)?)append_attack_log\((.*)\)\s*$')


def inspect_sources(sources, inventory):
    violations = []
    migrated = []
    allowed_counts = Counter()
    for path, source in sources.items():
        for number, line in enumerate(source.splitlines(), 1):
            statement = line.split('//', 1)[0].strip()
            if MUTATION.search(statement):
                if (path, statement) not in ALLOWED:
                    violations.append(f'{path}:{number}: unowned history mutation')
                else:
                    allowed_counts[path, statement] += 1
            match = APPEND.fullmatch(line)
            if match:
                owner, expression = match.groups()
                migrated.append((path, owner, hashlib.sha256(expression.encode()).hexdigest()))
    expected = Counter((row['path'], row['owner'], row['expression_sha256'])
                       for row in inventory['writers'])
    if Counter(migrated) != expected:
        violations.append('Migrated writer expressions or multiplicities changed')
    if allowed_counts != Counter({key: 1 for key in ALLOWED}):
        violations.append('Central history ownership or initialization changed')
    ghost = sources.get('code/game/mob/observer/ghost/ghost.dm', '')
    if ghost.count('attack_log = body.attack_log\t') != 1:
        violations.append('Ghost history must retain its shared list')
    return violations


def check(root=ROOT):
    sources = {path.relative_to(root).as_posix(): path.read_text(encoding='utf-8')
               for path in (root / 'code').rglob('*.dm')}
    inventory = json.loads((root / 'tests/attack_history/writer-migration.json').read_text())
    violations = inspect_sources(sources, inventory)
    if violations:
        raise ValueError('\n'.join(violations))
    return len(inventory['writers']), len({row['path'] for row in inventory['writers']})


if __name__ == '__main__':
    writers, files = check()
    print(f'PASS {writers} migrated expressions in {files} files; no bypass mutation')
