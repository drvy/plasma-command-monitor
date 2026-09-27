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
    echo "Usage: $0 [install|upgrade|preview]"
    echo "  install  - install the widget for the first time (kpackagetool6 -i)"
    echo "  upgrade  - reinstall an already-installed widget (kpackagetool6 -u)"
    echo "  preview  - run it standalone with plasmoidviewer, no install needed"
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
    *)
        usage
        ;;
esac
