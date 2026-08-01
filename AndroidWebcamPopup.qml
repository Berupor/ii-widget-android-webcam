// Popup frame, body in AndroidWebcamDetails.qml so a scene can draw it: StyledPopup
// is a LazyLoader over a PanelWindow and only lives while the bar item is hovered.

import qs.modules.ii.bar
import QtQuick

StyledPopup {
    id: root

    property var devices: AndroidWebcam.devices

    AndroidWebcamDetails {
        anchors.centerIn: parent
        devices: root.devices
    }
}
