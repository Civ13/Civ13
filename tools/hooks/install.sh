#!/bin/sh
exec "$(dirname "$0")/python" -m hooks.install "$@"
