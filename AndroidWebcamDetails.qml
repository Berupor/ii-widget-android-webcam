pragma ComponentBehavior: Bound

import qs.modules.ii.bar
import qs.services
import QtQuick
import QtQuick.Layouts

/** Which phone is the webcam, and which /dev/video* node it took. */
Item {
    id: root

    /// The attached phones, unless a demo scene hands the view made-up ones
    property var devices: AndroidWebcam.devices

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    Column {
        id: column
        anchors.centerIn: parent
        spacing: 8

        StyledPopupHeaderRow {
            icon: "smartphone"
            label: AndroidWebcam.modelOf(root.devices) !== "" ? AndroidWebcam.modelOf(root.devices) : Translation.tr("Android phone")
        }

        // ColumnLayout, not Column: rows stretch to the widest one so values right-align
        ColumnLayout {
            spacing: 4

            StyledPopupValueRow {
                Layout.fillWidth: true
                icon: "videocam"
                label: Translation.tr("Mode:")
                value: Translation.tr("USB webcam")
            }
            StyledPopupValueRow {
                Layout.fillWidth: true
                icon: "cable"
                label: root.devices.length > 1 ? Translation.tr("Nodes:") : Translation.tr("Node:")
                value: AndroidWebcam.pathsOf(root.devices)
            }
        }
    }
}
