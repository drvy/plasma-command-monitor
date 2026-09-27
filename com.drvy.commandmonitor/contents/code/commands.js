.pragma library

// Command entry schema:
// {
//   id: string (uuid),
//   name: string,
//   command: string,
//   intervalMs: number (clamped to [MIN_INTERVAL_MS, MAX_INTERVAL_MS]),
//   enabled: bool,
//   showInPanel: bool (include this command's first output line in the panel text),
//   colorRules: [ { pattern: string, color: string } ],
//   icon: string (icon name shown before the output; "" = no icon),
//   labelColor: string (hex color shared by both the icon tint -- only
//                       visible on recolorable/symbolic icons -- and the
//                       name, which is displayed as the label; "" = theme default),
//   labelBold: bool (default true), labelItalic: bool (default false),
//   outputBold: bool (default false), outputItalic: bool (default false),
//   clickCommand: string (fire-and-forget command run on click; "" = none,
//                         in which case clicking copies the output instead),
//   hideWhenEmpty: bool (hide this command entirely, in the panel and the
//                        popup list, whenever its current output is empty)
// }

var MIN_INTERVAL_MS = 1000;
var MAX_INTERVAL_MS = 86400000; // 24h

function clampInterval(ms) {
    var n = Number(ms);
    if (isNaN(n)) {
        return MIN_INTERVAL_MS;
    }
    return Math.min(MAX_INTERVAL_MS, Math.max(MIN_INTERVAL_MS, Math.round(n)));
}

function makeId() {
    // RFC4122-ish v4 id, good enough for a local config key
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
        var r = Math.random() * 16 | 0;
        var v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

function createDefaultEntry() {
    return {
        id: makeId(),
        name: "New command",
        command: "",
        intervalMs: 5000,
        enabled: true,
        showInPanel: true,
        colorRules: [],
        icon: "",
        labelColor: "",
        labelBold: true,
        labelItalic: false,
        outputBold: false,
        outputItalic: false,
        clickCommand: "",
        hideWhenEmpty: false
    };
}

function parseCommands(json) {
    var list;
    try {
        list = JSON.parse(json);
    } catch (e) {
        return [];
    }
    if (!Array.isArray(list)) {
        return [];
    }
    return list.map(function (entry) {
        return {
            id: entry.id || makeId(),
            name: entry.name || "",
            command: entry.command || "",
            intervalMs: clampInterval(entry.intervalMs),
            enabled: entry.enabled !== false,
            showInPanel: entry.showInPanel !== false,
            colorRules: Array.isArray(entry.colorRules) ? entry.colorRules : [],
            icon: entry.icon || "",
            labelColor: entry.labelColor || "",
            labelBold: entry.labelBold !== false,
            labelItalic: entry.labelItalic === true,
            outputBold: entry.outputBold === true,
            outputItalic: entry.outputItalic === true,
            clickCommand: entry.clickCommand || "",
            hideWhenEmpty: entry.hideWhenEmpty === true
        };
    });
}

function serializeCommands(list) {
    return JSON.stringify(list);
}

// Returns the list of command texts (engine source names) that appear more
// than once, so the config UI can warn the user: the executable engine keys
// its sources by the literal command string, so duplicate commands share
// one underlying source/timer.
function findDuplicateCommandTexts(list) {
    var seen = {};
    var duplicates = {};
    list.forEach(function (entry) {
        if (!entry.command) {
            return;
        }
        if (seen[entry.command]) {
            duplicates[entry.command] = true;
        }
        seen[entry.command] = true;
    });
    return Object.keys(duplicates);
}
