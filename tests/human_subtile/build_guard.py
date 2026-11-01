"""Build only the isolated ordinary-swap candidate; never write a checkout."""
from hashlib import sha1, sha256
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
OLD = HERE / 'bump_guard_preimage.dm'
WALKER = ROOT / 'code/game/mob/living/simple_animal/subtile_movement.dm'
TACTICAL = ROOT / 'code/game/mob/living/simple_animal/hostile/tactical_ai.dm'
OLD_BLOB = '168a0af38060825f46c9456e7898888de3421a0b'
WALKER_BLOB = 'c658aa260cd486f5c8a82dc796e048c321362d54'
TACTICAL_BLOB = 'e83f103f7f014b8e47a3a852eb78c8e5e2c98f1f'
OUT = Path(__file__).with_name('candidate_living.dm')


def blob(raw):
    return sha1(b'blob ' + str(len(raw)).encode() + b'\0' + raw).hexdigest()


def build(old, walker, tactical):
    # Materialized Windows files may use CRLF; git's stored source is LF.
    old, walker, tactical = (x.replace(b'\r\n', b'\n') for x in (old, walker, tactical))
    if (blob(old) != OLD_BLOB or blob(walker) != WALKER_BLOB or
            blob(tactical) != TACTICAL_BLOB):
        raise ValueError('guard or experimental movement source mismatch')
    owners = ('npc_subtile_pursuit', 'npc_subtile_follow', 'npc_subtile_flee',
              'npc_subtile_pet_walk', 'npc_subtile_recovery',
              'npc_subtile_pending_intent', 'npc_subtile_wild_walk')
    declarations = (walker + b'\n' + tactical).decode().splitlines()
    for field in owners:
        if not any(line.strip().startswith('var/tmp/datum/') and
                   line.strip().endswith('/' + field) for line in declarations):
            raise ValueError('owner declaration missing: ' + field)
    needle = b' || subtile_pull_ownership.owners[A])\n'
    if old.count(needle) != 1:
        raise ValueError('guard preimage mismatch')
    human_horse = (b'if (ishuman(src) && istype(other, '
                   b'/mob/living/simple_animal))')
    if old.count(human_horse) != 1:
        raise ValueError('horse direction preimage mismatch')
    old = old.replace(human_horse, human_horse[:-1] +
                      b' && !istype(other, /mob/living/simple_animal/horse))', 1)
    added = b''.join(b' || A.' + name.encode() for name in owners)
    return old.replace(needle, added + needle, 1)


if __name__ == '__main__':
    candidate = build(OLD.read_bytes(), WALKER.read_bytes(), TACTICAL.read_bytes())
    OUT.write_bytes(candidate)
    print('candidate blob', blob(candidate), 'sha256', sha256(candidate).hexdigest())
