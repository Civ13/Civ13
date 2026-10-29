"""Explicit profile dispatcher; never falls back to another map profile."""
from .configuration import OCEAN_CONFIG_VERSION
from .surface_generator import generate as surface_generate


def generate(config,*,traversal='forward'):
    if isinstance(config,dict) and config.get('schema')==OCEAN_CONFIG_VERSION:
        from .ocean_generator import generate as ocean_generate
        return ocean_generate(config,traversal=traversal)
    return surface_generate(config,traversal=traversal)
