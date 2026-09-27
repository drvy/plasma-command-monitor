// SPDX-FileCopyrightText: 2026 Dragomir Yordanov <dyordanov@drvy.net>
// SPDX-License-Identifier: MIT

import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "utilities-terminal"
        source: "configGeneral.qml"
    }
}
