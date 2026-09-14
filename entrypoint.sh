#!/usr/bin/env sh
set -e
uvx hol-guard install claude-code
exec "$@"
