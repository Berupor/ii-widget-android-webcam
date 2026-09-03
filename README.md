# Android webcam widget

An icon in the bar while a phone is plugged in as a USB webcam, and a popup with
which phone it is and which `/dev/video*` node it took. It can do the switching
too: a phone visible over adb is put in UVC mode, instead of typing that on
every plug. A widget for the
[illogical-impulse extensions fork](https://github.com/Berupor/dots-hyprland-extensions).

With OBS set up, the same icon fronts a virtual camera: the click starts and
stops it, the popup swaps the background between raw, blurred and a picture.
Without OBS the popup says so in one line and stays an indicator.

| In the bar | The popup | Without OBS |
|---|---|---|
| ![The bar indicator](docs/bar.png) | ![The popup](docs/popup.png) | ![The popup without OBS](docs/popup-plain.png) |

No phone was plugged in for the pictures: the scenes in `demo/` hand the views
made-up video nodes, which is how the tests run too.

## Install

Settings → Widgets → Install a widget, paste:

```
https://github.com/Berupor/ii-widget-android-webcam.git
```

Detection needs nothing installed. The kernel names such a node
`<model>: Android Webcam` and that is all the widget looks for, so a phone you
switched over yourself shows up the same way.

Switching needs `adb` (`android-tools`) and a phone that trusts this computer; it
runs `svc usb setFunctions uvc` there. Off by default, since it takes over the
phone's USB mode. Its options are which phone (any adb device, or one by model),
how often to look, and whether to say a word when it happens. Android refuses on
a locked screen, so a connection is tried three times and then left alone until
the phone is replugged.

## Virtual camera

Optional, and not in the widget's `dependencies` on purpose: a missing OBS costs
the effects, not the widget. The popup draws its effects half once `obs-cmd`, OBS
and `obs-vcam.service` are all there, and names what is missing until then. It
looks again every five seconds, so the switch appears by itself after `setup.sh`
runs. The `Background effects through OBS` option hides that half for good.

Run `./setup.sh` once: it installs an `AndroidWebcam` profile and scene
collection from `obs/`, turns on obs-websocket, links
`systemd/obs-vcam.service` into `~/.config/systemd/user/` and makes the folders.
It refuses to run while the unit is up, because OBS writes its scene collection
back on shutdown and would undo the install. The unit starts OBS with
`--profile`/`--collection`, so the collection you normally open stays as it was.

Needs OBS Studio, `obs-cmd` to drive it, `obs-backgroundremoval` for the
segmentation and `v4l2loopback` for the node OBS publishes to. `setup.sh` names
which of them is missing and prints the two root commands v4l2loopback needs.
OBS runs with no window: `SysTrayEnabled` and `SysTrayWhenStarted` put it in the
tray, where clicking the icon still opens the full UI for tuning filters by hand.
Keep `PreviewEnabled=false` unless you also use OBS interactively - a preview
nobody looks at costs about ten times the CPU.

The switch in the popup, and a click on the bar icon, start and stop the unit.
Backgrounds are one grid: `None` is the raw feed, `Blur` the filter, and every
other cell a picture from `backgroundDir` (`~/Pictures/webcam-backgrounds` by
default, `.jpg`, `.jpeg`, `.png`, `.webp`). `Add` opens `kdialog` or `zenity`,
whichever is around, else just the folder, and copies what you pick into it.
Picking a cell copies the file over the path the `Background` source is pinned
to; OBS polls that path, so expect about a second of lag. Unplugging the phone
stops the unit whatever started it, since what it published had no other source.
`autoStart` is the other direction: the unit comes up by itself once a phone
attaches.

The websocket password is read out of OBS's own
`plugin_config/obs-websocket/config.json`, never asked for or stored here.

## Hacking

With the fork checked out next door, the scenes are both the tests and the pictures:

```sh
tests/qml-cases.sh    -x ~/.config/illogical-impulse/widgets/androidWebcam
tests/widget-shots.sh -x ~/.config/illogical-impulse/widgets/androidWebcam
```

`git config core.hooksPath .githooks` runs them on push. GPL-3.0.
