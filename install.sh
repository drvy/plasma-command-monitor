#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Dragomir Yordanov <dyordanov@drvy.net>
# SPDX-License-Identifier: MIT
#
# Install/upgrade helper for the Command Monitor Plasma 6 widget.
set -euo pipefail

PLASMOID_ID="com.drvy.commandmonitor"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLASMOID_DIR="${SCRIPT_DIR}/${PLASMOID_ID}"

usage() {
    echo "Usage: $0 [install|upgrade|preview|package]"
    echo "  install  - install the widget for the first time (kpackagetool6 -i)"
    echo "  upgrade  - reinstall an already-installed widget (kpackagetool6 -u)"
    echo "  preview  - run it standalone with plasmoidviewer, no install needed"
    echo "  package  - build dist/${PLASMOID_ID}-<version>.plasmoid for release"
    exit 1
}

case "${1:-}" in
    install)
        kpackagetool6 -t Plasma/Applet -i "${PLASMOID_DIR}"
        ;;
    upgrade)
        kpackagetool6 -t Plasma/Applet -u "${PLASMOID_DIR}"
        ;;
    preview)
        plasmoidviewer -a "${PLASMOID_DIR}"
        ;;
    package)
        version="$(grep -m1 '"Version"' "${PLASMOID_DIR}/metadata.json" | sed -E 's/.*: *"([^"]+)".*/\1/')"
        mkdir -p "${SCRIPT_DIR}/dist"
        out="${SCRIPT_DIR}/dist/${PLASMOID_ID}-${version}.plasmoid"
        rm -f "${out}"
        python3 - "${PLASMOID_DIR}" "${out}" <<'PY'
import os, sys, zipfile
src, out = sys.argv[1:3]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(src):
        for f in sorted(files):
            if not f.endswith((".qmlc", ".jsc")):
                path = os.path.join(root, f)
                z.write(path, os.path.relpath(path, src))
PY
        echo "Built ${out}"
        ;;
    *)
        usage
        ;;
esac
