# Android webcam widget

An icon in the bar while a phone is plugged in as a USB webcam, and a popup with
which phone it is and which `/dev/video*` node it took. Optionally it does the
switching too: a phone that shows up over adb is put in UVC mode, the thing one
would otherwise type by hand on every plug. A widget for the
[illogical-impulse extensions fork](https://github.com/Berupor/dots-hyprland-extensions).

| In the bar | The popup |
|---|---|
| ![The bar indicator](docs/bar.png) | ![The popup](docs/popup.png) |

No phone was plugged in for either picture: the scenes in `demo/` hand the views
made-up video nodes, which is also how the tests run.

## Install

Settings → Widgets → Install a widget, paste:

```
https://github.com/Berupor/ii-widget-android-webcam.git
```

Detection needs nothing installed. The kernel names such a node
`<model>: Android Webcam` and that is all the widget looks for, so a phone you
switched over yourself shows up the same way.

Switching needs `adb` (`android-tools`) and a phone that trusts this computer; it
runs `svc usb setFunctions uvc` there. It is off by default - it takes over the
phone's USB mode - and its options are which phone (any adb device, or one by
model), how often to look, and whether to say a word when it happens. Android
refuses on a locked screen, so a connection is tried three times and then left
alone until the phone is replugged.

## Hacking

With the fork checked out next door, the scenes are both the tests and the pictures:

```sh
tests/qml-cases.sh    -x ~/.config/illogical-impulse/widgets/androidWebcam
tests/widget-shots.sh -x ~/.config/illogical-impulse/widgets/androidWebcam
```

`git config core.hooksPath .githooks` runs them on push. GPL-3.0.
