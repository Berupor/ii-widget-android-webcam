#!/usr/bin/env bash
# Host side of the virtual camera: the v4l2 bridge unit and the checks around it.
# The widget itself only switches things; everything this touches has to exist first.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
units="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"

say() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v openeffectsd >/dev/null ||
    die "openeffectsd not found; packages are at https://github.com/funinkina/openeffects/releases"
command -v openeffectsctl >/dev/null || die "openeffectsctl not found; the widget drives the camera through it"
command -v gst-launch-1.0 >/dev/null || die "gst-launch-1.0 not found; install gstreamer"

for element in pipewiresrc v4l2sink; do
    gst-inspect-1.0 "$element" >/dev/null 2>&1 ||
        warn "no GStreamer element $element; the bridge into /dev/video10 will not start"
done

# The node, not modinfo: a module inserted for an older kernel keeps working and stops
# being findable, and it is the node the bridge writes to that has to be there
if [[ ! -e /dev/video10 ]]; then
    if modinfo v4l2loopback >/dev/null 2>&1; then
        say ""
        say "v4l2loopback is not loaded with the expected node. As root, once:"
        say "  echo 'options v4l2loopback video_nr=10 card_label=\"Virtual Cam\" exclusive_caps=1' > /etc/modprobe.d/v4l2loopback.conf"
        say "  echo v4l2loopback > /etc/modules-load.d/v4l2loopback.conf"
        say "  modprobe v4l2loopback"
        say ""
    else
        warn "no v4l2loopback module: the camera would have nowhere to go but PipeWire"
    fi
fi

mkdir -p "$units" "$HOME/Pictures/webcam-backgrounds"

old="$units/obs-vcam.service"
if [[ -L "$old" ]]; then
    systemctl --user stop obs-vcam.service 2>/dev/null || true
    rm -f "$old"
    say "removed the old obs-vcam.service link"
fi

ln -sf "$here/systemd/openeffects-v4l2.service" "$units/openeffects-v4l2.service"
systemctl --user daemon-reload
say "linked openeffects-v4l2.service"

# Reason in the file itself. WirePlumber only reads it at startup, so a fresh link
# means a restart; audio routing blinks once and settles on the same devices
wp_conf="${XDG_CONFIG_HOME:-$HOME/.config}/wireplumber/wireplumber.conf.d"
mkdir -p "$wp_conf"
if [[ -L "$wp_conf/51-android-webcam.conf" ]]; then
    say "kept the WirePlumber rule"
else
    ln -sf "$here/wireplumber/51-android-webcam.conf" "$wp_conf/51-android-webcam.conf"
    systemctl --user restart wireplumber
    say "linked the WirePlumber rule and restarted wireplumber"
fi

say ""
say "Done. Enable the widget in Settings -> Widgets; it notices this within five"
say "seconds. Backgrounds go into ~/Pictures/webcam-backgrounds, or through Add in the"
say "popup. Start the camera by hand with:"
say "  systemctl --user start openeffects-v4l2.service"
