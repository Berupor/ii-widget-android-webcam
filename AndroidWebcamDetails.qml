pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.bar
import qs.services
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts

/** Which phone is the webcam, and what the OBS virtual camera does with it.
 *  Modes and pictures are one grid: picking a background is picking a cell. */
Item {
    id: root

    property var devices: AndroidWebcam.devices
    property bool camActive: VirtualCam.active
    property string camMode: VirtualCam.mode
    property var backgrounds: VirtualCam.backgrounds
    property string selectedBackground: VirtualCam.selected
    property string backgroundDir: VirtualCam.backgroundDir
    property bool effectsReady: VirtualCam.ready
    property string effectsHint: VirtualCam.hint

    readonly property bool showsEffects: root.effectsReady
    readonly property bool showsHint: !root.effectsReady && root.effectsHint !== ""
    readonly property bool showsEmptyNotice: root.effectsReady && root.backgrounds.length === 0
    readonly property int backgroundCount: bgRepeater.count
    readonly property real nodesRowWidth: supporting.implicitWidth

    readonly property int tileHeight: 58
    // Two columns of 16:9 tiles need more than the text alone asks for
    readonly property int minWidth: 240

    implicitWidth: Math.max(column.implicitWidth, root.minWidth)
    implicitHeight: column.implicitHeight

    // One cell of the grid: the ring lives outside the content, so selecting never crops it
    component Tile: Rectangle {
        id: tile
        property bool picked: false
        default property alias content: hole.data

        Layout.fillWidth: true
        Layout.preferredHeight: root.tileHeight
        radius: Appearance.rounding.small
        color: Appearance.colors.colSurfaceContainerHighest
        border.width: tile.picked ? 2 : 1
        border.color: tile.picked ? Appearance.colors.colPrimary : Appearance.colors.colOutlineVariant
        opacity: root.camActive ? 1 : 0.5

        Item {
            id: hole
            anchors.fill: parent
            anchors.margins: tile.border.width
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: hole.width
                    height: hole.height
                    radius: tile.radius - tile.border.width
                }
            }
        }

        Rectangle {
            anchors {
                right: parent.right
                top: parent.top
                rightMargin: 5
                topMargin: 5
            }
            visible: tile.picked
            implicitWidth: 20
            implicitHeight: 20
            radius: Appearance.rounding.full
            color: Appearance.colors.colPrimary

            MaterialSymbol {
                anchors.centerIn: parent
                text: "check"
                iconSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnPrimary
            }
        }
    }

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Rectangle {
                implicitWidth: 36
                implicitHeight: 36
                radius: Appearance.rounding.full
                color: Appearance.colors.colSecondaryContainer

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "smartphone"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnSecondaryContainer
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    text: AndroidWebcam.modelOf(root.devices) !== "" ? AndroidWebcam.modelOf(root.devices) : Translation.tr("Android phone")
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSurface
                }
                StyledText {
                    id: supporting
                    text: Translation.tr("USB webcam · %1").arg(AndroidWebcam.pathsOf(root.devices))
                    font.pixelSize: Appearance.font.pixelSize.smallie
                    color: Appearance.colors.colOnSurfaceVariant
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            visible: root.effectsReady
            implicitHeight: 44
            radius: Appearance.rounding.small
            color: Appearance.colors.colSurfaceContainerHigh

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 8
                }
                spacing: 10

                MaterialSymbol {
                    text: "cast"
                    iconSize: Appearance.font.pixelSize.larger
                    color: root.camActive ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Translation.tr("Virtual camera")
                    color: Appearance.colors.colOnSurface
                }
                StyledSwitch {
                    checked: root.camActive
                    onToggled: VirtualCam.toggle()
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.effectsReady
            text: Translation.tr("Background")
            font.pixelSize: Appearance.font.pixelSize.smallie
            color: Appearance.colors.colOnSurfaceVariant
        }

        GridLayout {
            Layout.fillWidth: true
            visible: root.effectsReady
            columns: 2
            columnSpacing: 8
            rowSpacing: 8

            Tile {
                picked: root.camMode === "off"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "videocam_off"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("None")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.camActive
                    onClicked: VirtualCam.setMode("off")
                }
            }

            Tile {
                picked: root.camMode === "blur"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "blur_on"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("Blur")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnSurfaceVariant
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.camActive
                    onClicked: VirtualCam.setMode("blur")
                }
            }

            Repeater {
                id: bgRepeater
                model: root.backgrounds

                delegate: Tile {
                    id: pic
                    required property string modelData
                    picked: root.camMode === "image" && pic.modelData === root.selectedBackground

                    StyledImage {
                        anchors.fill: parent
                        source: `file://${pic.modelData}`
                        fillMode: Image.PreserveAspectCrop
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.camActive
                        onClicked: VirtualCam.pick(pic.modelData)
                    }
                }
            }
            Tile {
                color: "transparent"
                border.width: 1
                border.color: Appearance.colors.colOutline

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 0

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "add_photo_alternate"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colPrimary
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("Add")
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colPrimary
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: VirtualCam.addPicture()
                }
            }
        }

        NoticeBox {
            Layout.fillWidth: true
            visible: root.showsEmptyNotice
            materialIcon: "image_not_supported"
            text: Translation.tr("Drop pictures into %1").arg(root.backgroundDir)
        }

        // Takes the place of the switch card on a host without OBS
        Rectangle {
            Layout.fillWidth: true
            // A wrapped Text reports the wrapped width, so the natural one comes from a metric
            Layout.preferredWidth: Math.ceil(hintIcon.implicitWidth + hintRow.spacing + hintMetrics.width) + 32
            Layout.maximumWidth: 300
            visible: root.showsHint
            implicitHeight: hintRow.implicitHeight + 20
            radius: Appearance.rounding.small
            color: Appearance.colors.colSurfaceContainerHigh

            RowLayout {
                id: hintRow
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                }
                spacing: 10

                MaterialSymbol {
                    id: hintIcon
                    Layout.alignment: Qt.AlignVCenter
                    text: "auto_awesome"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnSurfaceVariant
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Background effects")
                        color: Appearance.colors.colOnSurface
                    }
                    StyledText {
                        id: hintText
                        Layout.fillWidth: true
                        text: root.effectsHint
                        font.pixelSize: Appearance.font.pixelSize.smallie
                        color: Appearance.colors.colOnSurfaceVariant
                        wrapMode: Text.WordWrap
                    }

                    TextMetrics {
                        id: hintMetrics
                        font: hintText.font
                        text: hintText.text
                    }
                }
            }
        }
    }
}
