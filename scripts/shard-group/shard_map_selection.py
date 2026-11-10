"""Selected-map block transformation shared by shard build entrypoints."""
import re


MAP_BLOCK = re.compile(r'// BEGIN_SELECTED_MAP\r?\n.*?// END_SELECTED_MAP', re.S)


def select_map_block(dme_text, include, source):
    if not MAP_BLOCK.search(dme_text):
        raise RuntimeError(source + ' has no selected-map block')
    newline = '\r\n' if '\r\n' in dme_text else '\n'
    block = '// BEGIN_SELECTED_MAP' + newline + '#include "' + include + '"' + newline + '// END_SELECTED_MAP'
    return MAP_BLOCK.sub(lambda _: block, dme_text, count=1)
