#!/bin/sh
exec "$(dirname "$0")/../hooks/python" -m UpdatePaths "$@"
