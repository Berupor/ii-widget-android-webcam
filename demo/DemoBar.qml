//@ probe
/** The indicator with a phone attached, and the nothing the bar gets without one. */
import ".."
import QtQuick

Item {
    id: root

    // Centered, so the shot has the same air on both sides of the icon
    implicitWidth: attached.implicitWidth
    implicitHeight: attached.implicitHeight

    function checks() {
        return [
            {
                // `visible` reads as false while the scene hangs off no window yet,
                // so the icon that stays is checked by its size instead
                "name": "an attached phone is one icon in the bar",
                "got": attached.implicitWidth > 0,
                "want": true
            },
            {
                "name": "and nothing at all takes no width",
                "got": [none.implicitWidth, none.visible],
                "want": [0, false]
            }
        ];
    }

    AndroidWebcamIndicator {
        id: attached
        anchors.centerIn: parent
        devices: [
            {
                "path": "/dev/video0",
                "model": "Pixel 6 Pro"
            }
        ]
    }

    AndroidWebcamIndicator {
        id: none
        devices: []
    }
}
