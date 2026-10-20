pragma Singleton
pragma ComponentBehavior: Bound

/** A phone attached as a USB webcam (Android UVC gadget mode). */

// Detection is host-side: the kernel names such a node "<model>: Android Webcam".
// Flipping the phone into that mode needs adb and is opt-in, see the autoSwitch option.

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

    // [{ path: "/dev/video0", model: "Pixel 6 Pro" }, ...]
    property var devices: []
    readonly property bool active: root.devices.length > 0

    /// Both derived from a list, not from `devices`: the views hold their own
    function modelOf(devices) {
        return devices.length > 0 ? devices[0].model : "";
    }

    function pathsOf(devices) {
        return devices.map(d => d.path).join(", ");
    }

    function rescan(): void {
        if (root.enabled)
            scanProc.running = true;
    }

    Component.onCompleted: root.rescan()
    onEnabledChanged: root.enabled ? root.rescan() : root.devices = []

    Process {
        id: scanProc
        command: ["bash", "-c", `for n in /sys/class/video4linux/*/name; do [ -r "$n" ] || continue; name=$(cat "$n"); case "$name" in *"Android Webcam"*) printf '%s\\t%s\\n' "$(basename "$(dirname "$n")")" "$name";; esac; done`]
        stdout: StdioCollector {
            id: scanCollector
            onStreamFinished: {
                const found = [];
                for (const line of scanCollector.text.trim().split("\n")) {
                    if (line === "")
                        continue;
                    const [node, name] = line.split("\t");
                    found.push({
                        path: `/dev/${node}`,
                        model: (name ?? "").replace(/:?\s*Android Webcam\s*$/, "").trim()
                    });
                }
                root.devices = found;
            }
        }
    }

    // Event-driven instead of polling. usb too: switching functions re-enumerates the phone
    Process {
        id: udevMonitor
        running: root.enabled
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=video4linux", "--subsystem-match=usb"]
        stdout: SplitParser {
            onRead: debounce.restart() // Nodes land a moment after the event
        }
    }

    Timer {
        id: debounce
        interval: 500
        onTriggered: root.rescan()
    }

    // Fallback for a missing udevadm
    Timer {
        interval: 15000
        repeat: true
        running: root.enabled && !udevMonitor.running
        onTriggered: root.rescan()
    }

    /* Auto-switch: `svc usb setFunctions uvc` over adb, what one would otherwise
       do by hand on every plug. Off by default, it takes over the phone's USB mode. */

    readonly property bool autoSwitch: root.enabled && (root.opt("autoSwitch") ?? false)
    readonly property string wantedModel: root.opt("model") ?? ""
    readonly property bool notifies: root.opt("notify") ?? true
    readonly property int pollSeconds: root.opt("pollSeconds") ?? 5
    readonly property int maxAttempts: 3 // Android refuses on a locked screen, asking forever is noise

    // Keyed by serial: every switch re-enumerates the phone under a new adb transport id.
    // A replug quicker than one poll goes unnoticed and keeps the spent attempts
    property var handled: ({})
    property var attempts: ({})

    property string pendingSerial: ""
    property string pendingModel: ""

    Timer {
        interval: Math.max(2, root.pollSeconds) * 1000
        repeat: true
        triggeredOnStart: true
        running: root.autoSwitch && !root.active && root.pendingSerial === ""
        onTriggered: if (!listProc.running) listProc.running = true
    }

    Process {
        id: listProc
        command: ["adb", "devices", "-l"]
        stdout: StdioCollector {
            id: listCollector
            onStreamFinished: root.onDevicesListed(listCollector.text)
        }
    }

    /// Lines of "serial state ... model:Pixel_6_Pro transport_id:5" under a header
    function listed(text) {
        const found = [];
        for (const line of text.trim().split("\n").slice(1)) {
            const parts = line.trim().split(/\s+/);
            if (parts.length < 2)
                continue;
            const device = {
                serial: parts[0],
                state: parts[1],
                model: "",
                tid: ""
            };
            for (const part of parts.slice(2)) {
                if (part.startsWith("model:"))
                    device.model = part.slice(6).replace(/_/g, " ");
                else if (part.startsWith("transport_id:"))
                    device.tid = part.slice(13);
            }
            found.push(device);
        }
        return found;
    }

    /// Phones we may switch. Anything offline or unauthorized is not one
    function candidates(text, wantedModel) {
        return root.listed(text).filter(d => d.state === "device" && d.tid !== "" && (wantedModel === "" || d.model === wantedModel));
    }

    /// Only a phone missing from the listing is gone: right after re-enumerating it
    /// shows up offline for a moment, and that must not reset its attempts
    function keepListed(map, text) {
        const kept = {};
        for (const device of root.listed(text)) {
            if (map[device.serial] !== undefined)
                kept[device.serial] = map[device.serial];
        }
        return kept;
    }

    function onDevicesListed(text): void {
        root.handled = root.keepListed(root.handled, text);
        root.attempts = root.keepListed(root.attempts, text);

        if (root.pendingSerial !== "" || root.active)
            return;
        const device = root.candidates(text, root.wantedModel).find(d => !root.handled[d.serial] && (root.attempts[d.serial] ?? 0) < root.maxAttempts);
        if (device)
            root.switchOver(device);
    }

    function switchOver(device): void {
        root.attempts[device.serial] = (root.attempts[device.serial] ?? 0) + 1;
        root.pendingSerial = device.serial;
        root.pendingModel = device.model;
        switchProc.command = ["adb", "-t", device.tid, "shell", `getprop ro.usb.uvc.enabled | grep -qx true || exit ${root.noUvcExit}; svc usb setFunctions uvc`];
        switchProc.running = true;
        uvcWait.restart();
    }

    // Firmware without UVC still drops USB on setFunctions uvc and comes back adb-only,
    // so the property is checked first and such a phone is never touched
    readonly property int noUvcExit: 3

    Process {
        id: switchProc
        onExited: code => {
            if (code === root.noUvcExit)
                root.settle("noUvc");
        }
    }

    Timer {
        id: uvcWait
        interval: 10000 // Changing functions drops USB, the node is back a few seconds later
        onTriggered: root.settle("timeout")
    }

    onActiveChanged: if (root.active) root.settle("ok")

    /// outcome: "ok" | "timeout" | "noUvc"
    function settle(outcome): void {
        uvcWait.stop();
        const serial = root.pendingSerial;
        if (serial === "")
            return;
        root.pendingSerial = "";
        const name = root.pendingModel !== "" ? root.pendingModel : Translation.tr("Android phone");
        if (outcome === "ok") {
            root.handled[serial] = true;
            root.notify(Translation.tr("Phone is a webcam"), Translation.tr("%1 switched to USB webcam mode").arg(name));
        } else if (outcome === "noUvc") {
            root.handled[serial] = true;
            root.notify(Translation.tr("No webcam mode"), Translation.tr("%1 firmware has USB webcam mode turned off").arg(name));
        } else if ((root.attempts[serial] ?? 0) >= root.maxAttempts) {
            root.handled[serial] = true;
            root.notify(Translation.tr("Webcam switch failed"), Translation.tr("%1 exposed no UVC device").arg(name));
        }
    }

    function notify(summary, body): void {
        if (!root.notifies)
            return;
        // synchronous hint: a new toast replaces the old one instead of stacking up
        Quickshell.execDetached(["notify-send", "-a", "android-webcam", "-h", "string:x-canonical-private-synchronous:android-webcam", summary, body]);
    }

    // adb is only needed for the switch, so it is no widget dependency. Say it once
    // instead: with the option on and no adb nothing would ever happen
    Process {
        running: root.autoSwitch
        command: ["bash", "-c", "command -v adb >/dev/null"]
        onExited: code => {
            if (code !== 0)
                Quickshell.execDetached(["notify-send", "-a", "android-webcam", Translation.tr("Android webcam"), Translation.tr("Switching needs adb, install android-tools")]);
        }
    }
}
