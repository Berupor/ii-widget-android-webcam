//@ probe
/**
 * The popup drawn from a made-up phone: the views take their video nodes as a
 * property, so nothing is plugged in and neither udev nor adb is asked anything.
 * `-p scenario=two` is the phone that exposes a second node, `-p scenario=nameless`
 * the one the kernel gave no model. `-p effects=false` is a host without the OBS stack,
 * where the widget is a plain indicator.
 *
 * The widget is not named in `//@ probe` on purpose: enabled, its own scan would
 * clear the nodes set here.
 */
import ".." // The widget's own types and its AndroidWebcam singleton, via its qmldir
import qs.modules.common.functions
import QtQuick

Item {
    id: root

    property string scenario: "one"
    property bool effects: true

    /// Hint for a host missing only setup.sh, from the singleton rather than typed here
    readonly property string hint: VirtualCam.hintFor(["setup"])

    function node(path, model) {
        return {
            "path": path,
            "model": model
        };
    }

    readonly property var sets: ({
            "one": [root.node("/dev/video0", "Pixel 6 Pro")],
            "two": [root.node("/dev/video0", "Pixel 6 Pro"), root.node("/dev/video1", "Pixel 6 Pro")],
            "nameless": [root.node("/dev/video2", "")]
        })

    readonly property var devices: root.sets[root.scenario] ?? root.sets.one

    /// What `adb devices -l` prints with four phones on the desk, two of them useless
    readonly property string listing: `List of devices attached
1A2B3C4D               device usb:1-3 product:raven model:Pixel_6_Pro device:raven transport_id:5
9Z8Y7X6W               offline usb:1-4 product:bluejay model:Pixel_6a device:bluejay transport_id:6
FA7700112233           unauthorized usb:1-5 transport_id:8
EMULATOR30             device product:sdk_gphone64 model:sdk_gphone64_x86_64 transport_id:12`

    readonly property var all: AndroidWebcam.candidates(root.listing, "")
    readonly property var filtered: AndroidWebcam.candidates(root.listing, "Pixel 6 Pro")

    implicitWidth: details.implicitWidth
    implicitHeight: details.implicitHeight

    function checks() {
        return [
            {
                // Offline and unauthorized phones cannot be told to do anything
                "name": "only authorized devices are candidates",
                "got": root.all.map(d => d.model),
                "want": ["Pixel 6 Pro", "sdk gphone64 x86 64"]
            },
            {
                // The serial repeats across replugs, the transport id does not
                "name": "keyed by serial and transport id",
                "got": root.all[0]?.key ?? "",
                "want": "1A2B3C4D:5"
            },
            {
                "name": "the model option narrows it to one phone",
                "got": root.filtered.map(d => d.key),
                "want": ["1A2B3C4D:5"]
            },
            {
                "name": "a listing with no phones asks for nothing",
                "got": AndroidWebcam.candidates("List of devices attached\n", "").length,
                "want": 0
            },
            {
                "name": "two nodes read as one phone with both of them",
                "got": [AndroidWebcam.modelOf(root.sets.two), AndroidWebcam.pathsOf(root.sets.two)],
                "want": ["Pixel 6 Pro", "/dev/video0, /dev/video1"]
            },
            {
                "name": "a second node widens the row instead of stacking one",
                "got": [twoNodes.nodesRowWidth > oneNode.nodesRowWidth, twoNodes.implicitHeight === oneNode.implicitHeight],
                "want": [true, true]
            },
            {
                "name": "a phone the kernel named nothing still gets a header",
                "got": nameless.implicitWidth > 0,
                "want": true
            },
            {
                "name": "an empty background folder gets a human notice, not a blank list",
                "got": [noBackgrounds.showsEmptyNotice, noBackgrounds.backgroundCount],
                "want": [true, 0]
            },
            {
                "name": "found pictures list instead, no notice",
                "got": [someBackgrounds.showsEmptyNotice, someBackgrounds.backgroundCount],
                "want": [false, 3]
            },
            {
                // No OBS: the phone header stays, the effects half goes
                "name": "no OBS: one hint instead of the grid",
                "got": [noEffects.showsEffects, noEffects.showsHint, noEffects.showsEmptyNotice],
                "want": [false, true, false]
            },
            {
                "name": "the hint names the missing binary",
                "got": [VirtualCam.hintFor(["obs-cmd", "setup"]).includes("obs-cmd"), VirtualCam.hintFor([]).length > 0],
                "want": [true, true]
            }
        ];
    }

    /// Real files next to this scene, so the thumbnails are pictures and not empty tiles
    readonly property string here: FileUtils.trimFileProtocol(`${Qt.resolvedUrl("pictures")}`)
    readonly property var pictures: ["beach.png", "office.png", "space.png"].map(n => `${root.here}/${n}`)

    AndroidWebcamDetails {
        id: details
        devices: root.devices
        camActive: true
        camMode: "image"
        backgrounds: root.pictures
        selectedBackground: root.pictures[0]
        // Pinned, or the shot would depend on whether this machine has OBS
        effectsReady: root.effects
        effectsHint: root.effects ? "" : root.hint
    }

    // Off-screen, for the checks above: one node against two, and the nameless phone.
    // Effects off, so the header measures the same with OBS and without
    AndroidWebcamDetails {
        id: oneNode
        visible: false
        effectsReady: false
        devices: root.sets.one
    }

    AndroidWebcamDetails {
        id: twoNodes
        visible: false
        effectsReady: false
        devices: root.sets.two
    }

    AndroidWebcamDetails {
        id: nameless
        visible: false
        effectsReady: false
        devices: root.sets.nameless
    }

    // Off-screen, for the background list checks above
    AndroidWebcamDetails {
        id: noBackgrounds
        visible: false
        devices: root.sets.one
        camActive: true
        effectsReady: true
        backgrounds: []
    }

    AndroidWebcamDetails {
        id: someBackgrounds
        visible: false
        devices: root.sets.one
        camActive: true
        effectsReady: true
        backgrounds: root.pictures
    }

    AndroidWebcamDetails {
        id: noEffects
        visible: false
        devices: root.sets.one
        effectsReady: false
        effectsHint: root.hint
        backgrounds: root.pictures
    }
}
