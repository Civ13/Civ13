"""Extract lobby-channel production decisions with injected sound/client effects."""
import hashlib
import re


def generate(root, control=None):
    hashes = {}

    def read(relative):
        path = root / relative
        hashes[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
        return path.read_text(encoding='utf-8')

    sounds = read('code/modules/client/sound.dm')
    sounds = sounds.replace('/client/proc/', '/datum/music_fixture_client/proc/')
    sounds = sounds.replace('src << sound(', 'fixture_sound(')
    sounds = sounds.replace('for(var/client/C in clients)',
                            'for(var/datum/music_fixture_client/C in music_fixture_clients)')
    if control == 'music-lobby':
        marker = '\tif (ticker.current_state != GAME_STATE_PREGAME) return\n'
        if sounds.count(marker) != 1:
            raise RuntimeError('Lobby play guard changed')
        sounds = sounds.replace(marker, '', 1)
    if control == 'music-round':
        marker = '\t\tC.stoptitlemusic()\n'
        if sounds.count(marker) != 1:
            raise RuntimeError('Round music mutation changed')
        sounds = sounds.replace(marker, '\t\tif(C) continue\n', 1)
    login = read('code/game/mob/living/login.dm')
    login = login.replace('/mob/living/Login()', '/mob/living/proc/fixture_music_login()')
    login = login.replace('..()', 'fixture_music_parent()')
    login = re.sub(r'\bclient\b', 'music_fixture_client', login)
    if control == 'music-body':
        marker = '\tif(music_fixture_client) music_fixture_client.stoptitlemusic()\n'
        if login.count(marker) != 1:
            raise RuntimeError('Body music mutation changed')
        login = login.replace(marker, '', 1)
    return sounds + '\n' + login, hashes
