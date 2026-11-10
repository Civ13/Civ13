"""Preserve legacy fixtures' guarded global-controller startup isolation."""


def isolate_global_initialization(source):
    marker = '/datum/controller/global_vars/New()\n'
    if source.count(marker) != 1:
        raise RuntimeError('Global isolation marker changed')
    return source.replace(marker, marker + '\treturn\n')
