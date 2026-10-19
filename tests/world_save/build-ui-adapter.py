"""Extract production Login/Logout and HUD decisions, adapting external effects only."""
import hashlib
import re


def generate(root, control=None):
    hashes = {}

    def proc(relative, marker):
        path = root / relative
        text = path.read_text(encoding='utf-8')
        hashes[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
        if text.count(marker) != 1:
            raise RuntimeError(f'UI adapter marker changed: {marker}')
        start = text.index(marker)
        end = text.find('\n/', start + len(marker))
        return text[start:end if end >= 0 else len(text)]

    login = proc('code/game/mob/living/carbon/human/update_icons.dm', '/mob/living/human/Login()')
    logout = proc('code/game/mob/living/logout.dm', '/mob/living/human/Logout()')
    hud = proc('code/game/mob/living/carbon/human/human_hud.dm', '/mob/living/human/check_HUD()')
    update = proc('code/game/mob/living/carbon/human/human_hud.dm', '/mob/living/human/update_hud()')
    login = login.replace('/Login()', '/proc/fixture_ui_login()').replace('..()', 'fixture_ui_parent()').replace('if(client)', 'if(fixture_client)')
    logout = logout.replace('/Logout()', '/proc/fixture_ui_logout()').replace('..()', 'fixture_ui_parent()')
    hud = hud.replace('/human/check_HUD()', '/human/proc/check_HUD()', 1).replace('H.client', 'H.fixture_client')
    update = update.replace('/human/update_hud()', '/human/proc/update_hud()', 1)
    update = re.sub(r'\bclient\b', 'fixture_client', update)
    if control == 'registry':
        marker = '\tif(fixture_client)\n\t\thuman_clients_mob_list |= src\n'
        if login.count(marker) != 1:
            raise RuntimeError('Registry mutation target changed')
        login = login.replace(marker, '', 1)
    if control == 'hud':
        marker = '\tif (!H.HUDinventory.len || !H.HUDneed.len)\n\t\trecreate_flag = TRUE\n'
        if hud.count(marker) != 1:
            raise RuntimeError('HUD rebuild mutation target changed')
        hud = hud.replace(marker, '', 1)
    return '\n'.join((login, logout, hud, update)), hashes
