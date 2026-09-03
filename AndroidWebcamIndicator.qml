pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import QtQuick

/** Phone-as-webcam indicator: one icon, zero width while no phone is attached. */
MouseArea {
    id: root

    /// The attached phones, unless a demo scene hands the view made-up ones
    property var devices: AndroidWebcam.devices
    property bool shown: root.devices.length > 0

    /// Whether the virtual cam is running, unless a demo scene hands the view a made-up state
    property bool camActive: VirtualCam.active
    readonly property real iconFill: icon.fill // Exposed for the demo checks

    visible: root.shown
    implicitWidth: visible ? Math.max(icon.implicitWidth, 26) : 0 // Util button width, keeps the bar icon rhythm
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow
    cursorShape: VirtualCam.ready ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: VirtualCam.toggle()

    MaterialSymbol {
        id: icon
        anchors.centerIn: parent
        fill: root.camActive ? 1 : 0
        text: "mobile_camera"
        iconSize: Appearance.font.pixelSize.larger
        color: root.camActive ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1
    }

    AndroidWebcamPopup {
        hoverTarget: root
        devices: root.devices
    }
}
