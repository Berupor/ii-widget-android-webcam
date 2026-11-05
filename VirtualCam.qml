pragma Singleton
pragma ComponentBehavior: Bound

/** The virtual camera behind the Android webcam widget, driven through openeffectsctl.
 *
 * openeffectsd publishes a PipeWire node and nothing else, so openeffects-v4l2.service
 * bridges it into /dev/video10 for everything that wants a v4l2 device. That bridge is
 * also the daemon's only consumer: it opens the phone on start and releases it on stop,
 * which is why the unit alone is the switch here.
 *
 * `blurOn`, `imageOn` and `selected` are the daemon's own state, seeded from
 * `openeffectsctl effects` and then followed over `openeffectsctl watch`, so the popup
 * and the OpenEffects GUI cannot disagree about what the camera is doing.
 *
 * The stack is optional: `installed` is false until openeffectsctl, openeffectsd and the
 * unit are there, and the widget is a plain indicator meanwhile.
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

    property bool active: false // openeffects-v4l2.service is-active
    property bool blurOn: false
    property bool imageOn: false
    readonly property string mode: root.imageOn ? "image" : root.blurOn ? "blur" : "off"
    property var backgrounds: []
    property string selected: ""

    function expandHome(path) {
        return path.startsWith("~") ? Quickshell.env("HOME") + path.slice(1) : path;
    }

    Component.onCompleted: root.probeHost()
    onWantedChanged: if (root.wanted) root.probeHost()
    onReadyChanged: {
        if (root.ready) {
            root.rescanBackgrounds();
            root.poll();
            root.autoStartUnit();
        } else {
            stateWatch.running = false;
        }
    }
    onBackgroundDirChanged: root.rescanBackgrounds()

    /// Not a Manifest dependency on purpose: a missing openeffects must not switch the widget off
    function probeHost(): void {
        hostProbe.running = true;
    }

    Process {
        id: hostProbe
        command: ["bash", "-c", `command -v openeffectsctl >/dev/null || echo openeffectsctl
command -v openeffectsd >/dev/null || echo openeffectsd
{ systemctl --user cat openeffects-v4l2.service >/dev/null 2>&1 && [ -e /dev/video10 ]; } || echo setup`]
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
            if (!root.ready)
                return;
            if (AndroidWebcam.active)
                root.autoStartUnit();
            // Unplugged: the phone was the only source, the bridge would publish a frozen
            // frame and keep the segmentation running. Stopped whatever started it
            else if (root.active)
                root.stop();
        }
    }

    function autoStartUnit(): void {
        if (root.autoStart && root.ready && AndroidWebcam.active && !root.active)
            root.start();
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.wanted
        triggeredOnStart: true
        // Not ready yet: what to watch for is setup.sh, not the unit
        onTriggered: root.ready ? root.poll() : root.probeHost()
    }

    function poll(): void {
        if (!root.ready)
            return;
        unitPoll.running = true;
        if (root.active && !stateWatch.running)
            root.followState(); // first pass, or the daemon dropped the stream
    }

    Process {
        id: unitPoll
        command: ["systemctl", "--user", "is-active", "openeffects-v4l2.service"]
        stdout: StdioCollector {
            id: unitCollector
            onStreamFinished: root.active = ["active", "activating"].includes(unitCollector.text.trim())
        }
    }

    onActiveChanged: {
        if (root.active)
            root.followState();
        else
            stateWatch.running = false;
    }

    function start(): void {
        if (!root.ready)
            return;
        // openeffectsd autodetects a camera, and on a laptop that is the built-in one
        const path = AndroidWebcam.devices[0]?.path ?? "";
        const select = path !== "" ? 'openeffectsctl camera select "$1"; ' : "";
        Quickshell.execDetached(["bash", "-c", `${select}systemctl --user start openeffects-v4l2.service`, "_", path]);
        root.active = true; // optimistic, the poll above corrects it within 5s
    }

    function stop(): void {
        Quickshell.execDetached(["systemctl", "--user", "stop", "openeffects-v4l2.service"]);
        root.active = false;
    }

    function toggle(): void {
        root.active ? root.stop() : root.start();
    }

    function followState(): void {
        stateRead.running = true;
        stateWatch.running = true;
    }

    Process {
        id: stateRead
        command: ["bash", "-c", "openeffectsctl effects; openeffectsctl background"]
        stdout: StdioCollector {
            id: stateCollector
            onStreamFinished: {
                const text = stateCollector.text;
                root.blurOn = /\[on\s*\] portrait_blur/.test(text);
                root.imageOn = /\[on\s*\] bg_replace/.test(text);
                const line = /^bg_replace: (.*)$/m.exec(text);
                if (line)
                    root.selected = root.pathField(line[1]);
            }
        }
    }

    Process {
        id: stateWatch
        command: ["openeffectsctl", "watch"]
        stdout: SplitParser {
            onRead: line => root.applyChange(line)
        }
    }

    /// One line of `watch`: an effect id, a tab, then `key=value` fields
    function applyChange(line): void {
        const cut = line.indexOf("\t");
        if (cut < 0)
            return;
        const fields = line.slice(cut + 1);
        const on = /(?:^| )enabled=true(?: |$)/.test(fields);
        const name = line.slice(0, cut);
        if (name === "portrait_blur") {
            root.blurOn = on;
        } else if (name === "bg_replace") {
            root.imageOn = on;
            const path = root.pathField(fields);
            if (path !== "")
                root.selected = path;
        }
    }

    /// A picture path can hold spaces, so it is cut at the next field name and not at whitespace
    function pathField(fields): string {
        const found = /(?:^| )background=(.*?)(?: (?:enabled|strength)=|$)/.exec(fields);
        return found ? found[1] : "";
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

    /// One place for the openeffectsctl invocation shape. Effect names are kebab-case in
    /// what the commands take and snake_case in what `effects` and `watch` print
    function ctl(args): void {
        Quickshell.execDetached(["openeffectsctl", ...args]);
    }

    function setMode(newMode): void {
        if (!root.ready)
            return;
        root.imageOn = newMode === "image" && root.selected !== ""; // optimistic, `watch` corrects both in a moment
        root.blurOn = newMode === "blur";
        if (newMode === "image" && root.selected !== "")
            root.ctl(["background", root.selected]);
        else
            root.ctl(["background", "--off"]); // keeps the stored picture for the next time
        root.ctl([newMode === "blur" ? "enable" : "disable", "portrait-blur"]);
    }

    function pick(path): void {
        root.selected = path;
        root.setMode("image");
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
}
