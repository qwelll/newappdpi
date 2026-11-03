#!/bin/sh
set -eu
cd "$(dirname "$0")"

if [ "$#" -eq 0 ]; then
    set -- rootless
elif [ "$#" -eq 1 ] && [ "$1" = all ]; then
    set -- rootful rootless roothide
fi

# Validate every scheme before starting a build.
for scheme in "$@"; do
    case "$scheme" in
        rootful|rootless|roothide) ;;
        *) printf 'Unknown scheme: %s\n' "$scheme" >&2; exit 2 ;;
    esac
done

: "${THEOS:?Set THEOS to a compatible Theos toolchain first}"

# Icons are generated, not committed, so the package always ships a valid PNG.
if command -v python3 >/dev/null 2>&1; then
    python3 assets/generate_icon.py
else
    printf 'python3 not found; keeping existing PreferenceBundle icons\n' >&2
fi

for scheme in "$@"; do
    package_scheme="$scheme"
    if [ "$scheme" = rootful ]; then package_scheme=""; fi
    printf '\nBuilding %s\n' "$scheme"
    make clean THEOS_PACKAGE_SCHEME="$package_scheme"
    make package THEOS_PACKAGE_SCHEME="$package_scheme"
done
