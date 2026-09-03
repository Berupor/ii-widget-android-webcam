pragma Singleton
pragma ComponentBehavior: Bound

/** The OBS-backed virtual camera behind the Android webcam widget.
 *
 * Fixed contract with obs-vcam.service: scene "Webcam" holding camera input
 * "Camera" and image input "Background", filters "Cutout"/"Blur" on "Camera".
 * obs-cmd has no verb to read any of that back, so `mode` is this widget's own
 * memory of what it last asked for, not a mirror of OBS state. The background
 * picture is not set through obs-websocket either (`input settings --set` is a
 * no-op in obs-cmd) but by copying the file over ~/.cache/obs-vcam/background.png,
 * which the scene's Background source is pinned to and OBS reloads on mtime change.
 *
 * The stack is optional: `installed` is false until obs-cmd, OBS and the unit are there,
 * and the widget is a plain indicator meanwhile.
 */

import qs.modules.widgets
import qs.services
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: root

    readonly property bool enabled: WidgetCatalog.isEnabled("androidWebcam")

    function opt(key) {
        return WidgetCatalog.option("androidWebcam", key);
    }

    readonly property bool wanted: root.enabled && (root.opt("virtualCam") ?? true)

    property bool probed: false
    property var missing: [] // What the host lacks: binary names, plus "setup" for the unit
    readonly property bool installed: root.probed && root.missing.length === 0
    readonly property bool ready: root.wanted && root.installed
    /// Empty when there is nothing to say: effects off, or working
    readonly property string hint: root.wanted && root.probed && !root.installed ? root.hintFor(root.missing) : ""

    readonly property string backgroundDir: root.expandHome(root.opt("backgroundDir") || "~/Pictures/webcam-backgrounds")
    readonly property bool autoStart: root.enabled && (root.opt("autoStart") ?? false)

    property bool active: false // obs-vcam.service is-active
    property string mode: "off" // "off" | "image" | "blur"
    property var backgrounds: []
    property string selected: ""
    property string password: ""

    function expandHome(path) {
        return path.startsWith("~") ? Quickshell.env("HOME") + path.slice(1) : path;
    }

    Component.onCompleted: root.probeHost()
    onWantedChanged: if (root.wanted) root.probeHost()
    onReadyChanged: if (root.ready) {
        root.rescanBackgrounds();
        root.pollUnit();
        root.readPassword();
        root.syncAutoStart();
    }
    onBackgroundDirChanged: root.rescanBackgrounds()

    /// Not a Manifest dependency on purpose: a missing OBS must not switch the widget off
    function probeHost(): void {
        hostProbe.running = true;
    }

    Process {
        id: hostProbe
        command: ["bash", "-c", `command -v obs-cmd >/dev/null || echo obs-cmd
[ -x /usr/bin/obs ] || echo obs-studio
systemctl --user cat obs-vcam.service >/dev/null 2>&1 || echo setup`]
        stdout: StdioCollector {
            id: hostCollector
            onStreamFinished: {
                root.missing = hostCollector.text.trim() ? hostCollector.text.trim().split("\n") : [];
                root.probed = true;
            }
        }
    }

    /// One line under the card title. Pure, so a demo scene draws it too
    function hintFor(missing): string {
        const binaries = missing.filter(m => m !== "setup");
        if (binaries.length > 0)
            return Translation.tr("Install %1, then run setup.sh").arg(binaries.join(", "));
        return Translation.tr("Run setup.sh in the widget folder");
    }

    // Rides AndroidWebcam.active instead of running its own phone detection
    Connections {
        target: AndroidWebcam
        function onActiveChanged() {
            root.syncAutoStart();
        }
    }

    function syncAutoStart(): void {
        if (!root.autoStart || !root.ready)
            return;
        if (AndroidWebcam.active && !root.active)
            root.start();
        else if (!AndroidWebcam.active && root.active)
            root.stop();
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.wanted
        triggeredOnStart: true
        // Not ready yet: what to watch for is setup.sh, not the unit
        onTriggered: root.ready ? root.pollUnit() : root.probeHost()
    }

    function pollUnit(): void {
        if (root.ready)
            unitPoll.running = true;
    }

    Process {
        id: unitPoll
        command: ["systemctl", "--user", "is-active", "obs-vcam.service"]
        stdout: StdioCollector {
            id: unitCollector
            onStreamFinished: root.active = unitCollector.text.trim() === "active"
        }
    }

    function start(): void {
        if (!root.ready)
            return;
        Quickshell.execDetached(["systemctl", "--user", "start", "obs-vcam.service"]);
        root.active = true; // optimistic, the poll above corrects it within 5s
    }

    function stop(): void {
        Quickshell.execDetached(["systemctl", "--user", "stop", "obs-vcam.service"]);
        root.active = false;
    }

    function toggle(): void {
        root.active ? root.stop() : root.start();
    }

    function readPassword(): void {
        if (root.ready)
            passwordProc.running = true;
    }

    Process {
        id: passwordProc
        command: ["bash", "-c", "grep -o '\"server_password\"[[:space:]]*:[[:space:]]*\"[^\"]*\"' ~/.config/obs-studio/plugin_config/obs-websocket/config.json 2>/dev/null | sed -E 's/.*:[[:space:]]*\"([^\"]*)\"/\\1/'"]
        stdout: StdioCollector {
            id: passwordCollector
            onStreamFinished: root.password = passwordCollector.text.trim()
        }
    }

    function rescanBackgrounds(): void {
        if (!root.ready)
            return;
        bgScan.command = ["bash", "-c", `cd "${root.backgroundDir}" 2>/dev/null || exit 0; shopt -s nullglob; for f in *.jpg *.jpeg *.png *.webp; do printf '%s\\n' "$PWD/$f"; done`];
        bgScan.running = true;
    }

    Process {
        id: bgScan
        stdout: StdioCollector {
            id: bgCollector
            onStreamFinished: {
                const found = bgCollector.text.trim() ? bgCollector.text.trim().split("\n").sort() : [];
                root.backgrounds = found;
                if (root.selected !== "" && !found.includes(root.selected))
                    root.selected = "";
            }
        }
    }

    function wsUrl() {
        return `obsws://localhost:4455/${root.password}`;
    }

    /// One place for the obs-cmd invocation shape
    function obsCmd(args): void {
        Quickshell.execDetached(["obs-cmd", "--websocket", root.wsUrl(), ...args]);
    }

    /// Not obs-websocket: OBS reloads Background from this fixed path on mtime change
    function applyBackground(path): void {
        Quickshell.execDetached(["cp", path, `${Quickshell.env("HOME")}/.cache/obs-vcam/background.png`]);
    }

    function setMode(newMode): void {
        if (!root.ready)
            return;
        root.mode = newMode;
        if (newMode === "image" && root.selected !== "")
            root.applyBackground(root.selected); // before flipping the filter, OBS needs ~1s to pick up the file
        root.obsCmd(["filter", newMode === "image" ? "enable" : "disable", "Camera", "Cutout"]);
        root.obsCmd(["filter", newMode === "blur" ? "enable" : "disable", "Camera", "Blur"]);
        root.obsCmd(["scene-item", newMode === "image" ? "enable" : "disable", "Webcam", "Background"]);
    }

    /// A picture from anywhere: copied into backgroundDir, so it stays a tile afterwards
    function addPicture(): void {
        addProc.running = true;
    }

    Process {
        id: addProc
        command: ["bash", "-c", `set -e
        filter='*.jpg *.jpeg *.png *.webp'
        if command -v kdialog >/dev/null; then
            f=$(kdialog --getopenfilename "$HOME/Pictures" "Images ($filter)" 2>/dev/null) || exit 0
        elif command -v zenity >/dev/null; then
            f=$(zenity --file-selection --title="Background picture" --file-filter="Images | $filter" 2>/dev/null) || exit 0
        else
            xdg-open "${root.backgroundDir}" >/dev/null 2>&1 || true
            exit 0
        fi
        [ -n "$f" ] || exit 0
        mkdir -p "${root.backgroundDir}"
        cp -n "$f" "${root.backgroundDir}/" 2>/dev/null || true
        printf '%s/%s\\n' "${root.backgroundDir}" "$(basename "$f")"`]
        stdout: StdioCollector {
            id: addCollector
            onStreamFinished: {
                const added = addCollector.text.trim();
                root.rescanBackgrounds();
                if (added !== "")
                    root.pick(added);
            }
        }
    }

    function pick(path): void {
        root.selected = path;
        if (root.mode === "image")
            root.applyBackground(path); // setMode would redo it, avoid the duplicate
        else
            root.setMode("image");
    }
}
