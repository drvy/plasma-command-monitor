.pragma library
// SPDX-FileCopyrightText: 2026 Dragomir Yordanov <dyordanov@drvy.net>
// SPDX-License-Identifier: MIT

// Converts raw command output (which may contain ANSI SGR escape codes)
// into HTML suitable for a QML Text element with textFormat: Text.RichText,
// and additionally applies user-defined plain-text color rules per line.
//
// Two things this file is careful about:
// 1. HTML-escaping happens before anything else, so arbitrary command
//    output can never inject markup into the RichText renderer.
// 2. User color rules are applied at whole-line granularity (wrapping the
//    already ANSI-converted line in one extra <span>), rather than trying
//    to merge overlapping sub-string spans with the ANSI-derived ones.

var BASE_COLORS = {
    30: "#000000", 31: "#e06c75", 32: "#98c379", 33: "#e5c07b",
    34: "#61afef", 35: "#c678dd", 36: "#56b6c2", 37: "#abb2bf",
    90: "#5c6370", 91: "#e06c75", 92: "#98c379", 93: "#e5c07b",
    94: "#61afef", 95: "#c678dd", 96: "#56b6c2", 97: "#ffffff"
};

var CUBE_STEPS = [0, 95, 135, 175, 215, 255];

function escapeHtml(text) {
    return text
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;");
}

function stripAnsi(text) {
    return text.replace(/\x1B\[[0-9;]*m/g, "");
}

function ansi256ToHex(index) {
    if (index < 16) {
        return BASE_COLORS[index < 8 ? 30 + index : 82 + index] || "#ffffff";
    }
    if (index >= 232) {
        var gray = 8 + (index - 232) * 10;
        var hex = gray.toString(16).padStart(2, "0");
        return "#" + hex + hex + hex;
    }
    var i = index - 16;
    var r = CUBE_STEPS[Math.floor(i / 36) % 6];
    var g = CUBE_STEPS[Math.floor(i / 6) % 6];
    var b = CUBE_STEPS[i % 6];
    return "#" + [r, g, b].map(function (c) {
        return c.toString(16).padStart(2, "0");
    }).join("");
}

function applySgrCodes(codesStr, state) {
    var codes = codesStr.split(";").filter(function (c) { return c !== ""; });
    if (codes.length === 0) {
        codes = ["0"];
    }
    for (var i = 0; i < codes.length; i++) {
        var code = parseInt(codes[i], 10);
        if (code === 0) {
            state.fg = null;
            state.bold = false;
        } else if (code === 1) {
            state.bold = true;
        } else if (code === 22) {
            state.bold = false;
        } else if (code === 39) {
            state.fg = null;
        } else if (BASE_COLORS[code] !== undefined) {
            state.fg = BASE_COLORS[code];
        } else if (code === 38) {
            var mode = parseInt(codes[i + 1], 10);
            if (mode === 5) {
                state.fg = ansi256ToHex(parseInt(codes[i + 2], 10));
                i += 2;
            } else if (mode === 2) {
                state.fg = "rgb(" + codes[i + 2] + "," + codes[i + 3] + "," + codes[i + 4] + ")";
                i += 4;
            }
        }
        // 40-49 background codes and other SGR attributes are ignored on
        // purpose: keeping the widget's own background legible matters
        // more than exactly reproducing the terminal's colors.
    }
}

function spanStyle(state) {
    var styles = [];
    if (state.fg) {
        styles.push("color:" + state.fg);
    }
    if (state.bold) {
        styles.push("font-weight:bold");
    }
    return styles.join(";");
}

// Converts a single line (no embedded newlines) to HTML, carrying SGR
// state in/out via the mutable `state` object so it persists across lines.
function convertLineAnsi(line, state) {
    var result = "";
    var re = /\x1B\[([0-9;]*)m/g;
    var lastIndex = 0;
    var match;
    var spanOpen = false;

    function openSpan() {
        var style = spanStyle(state);
        if (style) {
            result += '<span style="' + style + '">';
            spanOpen = true;
        }
    }
    function closeSpan() {
        if (spanOpen) {
            result += "</span>";
            spanOpen = false;
        }
    }

    openSpan();
    while ((match = re.exec(line)) !== null) {
        result += escapeHtml(line.slice(lastIndex, match.index));
        lastIndex = re.lastIndex;
        closeSpan();
        applySgrCodes(match[1], state);
        openSpan();
    }
    result += escapeHtml(line.slice(lastIndex));
    closeSpan();
    return result;
}

function matchColorRule(plainLine, colorRules) {
    if (!colorRules || colorRules.length === 0) {
        return null;
    }
    for (var i = 0; i < colorRules.length; i++) {
        var rule = colorRules[i];
        if (!rule.pattern) {
            continue;
        }
        try {
            var re = new RegExp(rule.pattern);
            if (re.test(plainLine)) {
                return rule.color;
            }
        } catch (e) {
            // Invalid user-supplied regex: skip the rule instead of breaking rendering.
        }
    }
    return null;
}

// Main entry point: raw stdout/stderr text -> rich text HTML.
function toRichText(rawText, colorRules) {
    if (!rawText) {
        return "";
    }
    var lines = rawText.replace(/\r\n/g, "\n").split("\n");
    var state = { fg: null, bold: false };
    var htmlLines = lines.map(function (line) {
        var plain = stripAnsi(line);
        var html = convertLineAnsi(line, state);
        var ruleColor = matchColorRule(plain, colorRules);
        if (ruleColor) {
            html = '<span style="color:' + ruleColor + ';">' + html + "</span>";
        }
        return html;
    });
    return htmlLines.join("<br/>");
}
