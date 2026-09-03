// Popup frame, body in AndroidWebcamDetails.qml so a scene can draw it: StyledPopup
// is a LazyLoader over a PanelWindow and only lives while the bar item is hovered.

import qs.modules.ii.bar
import QtQuick

StyledPopup {
    id: root

    property var devices: AndroidWebcam.devices

    readonly property bool pointerInside: (root.hoverTarget?.containsMouse ?? false) || hover.hovered

    // Clickable cells: the popup has to outlive the pointer leaving the bar item, and the
    // grace period covers the gap between bar and popup mask.
    active: root.pointerInside || grace.running
    onPointerInsideChanged: if (!root.pointerInside) grace.restart()

    AndroidWebcamDetails {
        anchors.centerIn: parent
        devices: root.devices

        HoverHandler {
            id: hover
        }

        // Lives here, not next to `active`: StyledPopup takes one Item child and nothing else
        Timer {
            id: grace
            interval: 250
        }
    }
}
