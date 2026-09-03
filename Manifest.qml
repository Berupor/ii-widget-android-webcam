import qs.modules.widgets
import qs.services

WidgetManifest {
    widgetId: "androidWebcam"
    name: Translation.tr("Android webcam")
    description: Translation.tr("A phone attached as a USB webcam, with optional OBS background effects")
    icon: "mobile_camera"
    version: "1.2"
    author: "Berupor"
    minShellVersion: "1.1" // textField option
    slots: ({ "barIndicator": "AndroidWebcamIndicator.qml" })
    options: [
        {
            key: "autoSwitch",
            type: "switch",
            label: Translation.tr("Put a plugged phone in webcam mode"),
            icon: "usb",
            default: false
        },
        {
            key: "model",
            type: "textField",
            label: Translation.tr("Only this phone"),
            icon: "smartphone",
            placeholder: Translation.tr("Any adb device"),
            default: ""
        },
        {
            key: "pollSeconds",
            type: "spinBox",
            label: Translation.tr("Look for it every, s"),
            icon: "timer",
            min: 2,
            max: 60,
            default: 5
        },
        {
            key: "notify",
            type: "switch",
            label: Translation.tr("Notify when switched"),
            icon: "notifications",
            default: true
        },
        {
            key: "virtualCam",
            type: "switch",
            label: Translation.tr("Background effects through OBS"),
            icon: "auto_awesome",
            default: true
        },
        {
            key: "autoStart",
            type: "switch",
            label: Translation.tr("Start the virtual camera with the phone"),
            icon: "cast",
            default: false
        },
        {
            key: "backgroundDir",
            type: "textField",
            label: Translation.tr("Background pictures folder"),
            icon: "folder",
            placeholder: "~/Pictures/webcam-backgrounds",
            default: "~/Pictures/webcam-backgrounds"
        }
    ]
}
