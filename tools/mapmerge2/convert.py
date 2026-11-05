#!/usr/bin/env python3
# Ported from CM-SS13 (https://github.com/cmss13-devs/cmss13, commit b782b5a, tools/mapmerge2/convert.py),
# AGPL-3.0; the tool originates in /tg/station. Civ13 changes are marked "Civ13".
from . import frontend, dmm

if __name__ == '__main__':
    settings = frontend.read_settings()
    for fname in frontend.process(settings, "convert"):
        dmm.DMM.from_file(fname).to_file(fname, tgm = settings.tgm)
