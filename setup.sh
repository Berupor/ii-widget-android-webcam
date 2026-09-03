#!/usr/bin/env bash
# Host side of the virtual camera: OBS scene collection, profile, websocket, systemd unit.
# The widget itself only switches things; everything this touches has to exist first.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
obs_cfg="${XDG_CONFIG_HOME:-$HOME/.config}/obs-studio"
units="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
force=0
[[ "${1:-}" == "--force" ]] && force=1

say() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# OBS writes the scene collection back on shutdown, so editing it under a live OBS is a no-op
if systemctl --user is-active --quiet obs-vcam.service; then
    die "obs-vcam.service is running; stop it first (systemctl --user stop obs-vcam.service)"
fi

[[ -x /usr/bin/obs ]] || die "OBS Studio not found at /usr/bin/obs"
command -v obs-cmd >/dev/null || die "obs-cmd not found; the widget drives OBS through it"
[[ -f /usr/lib/obs-plugins/obs-backgroundremoval.so ]] ||
    warn "obs-backgroundremoval not installed; the Cutout and Blur filters will be dead"

if ! modinfo v4l2loopback >/dev/null 2>&1; then
    warn "no v4l2loopback module: OBS will have nowhere to publish the camera"
elif [[ ! -e /dev/video10 ]]; then
    say ""
    say "v4l2loopback is not loaded with the expected node. As root, once:"
    say "  echo 'options v4l2loopback video_nr=10 card_label=\"Virtual Cam\" exclusive_caps=1' > /etc/modprobe.d/v4l2loopback.conf"
    say "  echo v4l2loopback > /etc/modules-load.d/v4l2loopback.conf"
    say "  modprobe v4l2loopback"
    say ""
fi

mkdir -p "$obs_cfg/basic/scenes" "$obs_cfg/basic/profiles/AndroidWebcam" \
         "$obs_cfg/plugin_config/obs-websocket" "$units" \
         "$HOME/.cache/obs-vcam" "$HOME/Pictures/webcam-backgrounds"

collection="$obs_cfg/basic/scenes/AndroidWebcam.json"
if [[ -e "$collection" && $force -eq 0 ]]; then
    say "kept existing $collection (--force to replace)"
else
    sed "s|__HOME__|$HOME|g" "$here/obs/AndroidWebcam.json" > "$collection"
    say "installed scene collection AndroidWebcam"
fi

profile="$obs_cfg/basic/profiles/AndroidWebcam/basic.ini"
if [[ -e "$profile" && $force -eq 0 ]]; then
    say "kept existing $profile (--force to replace)"
else
    cp "$here/obs/basic.ini" "$profile"
    say "installed profile AndroidWebcam"
fi

# The unit passes --profile/--collection, so the active collection in user.ini stays as it was
ws="$obs_cfg/plugin_config/obs-websocket/config.json"
if [[ -e "$ws" ]]; then
    python3 - "$ws" <<'PY'
import json, sys, pathlib
p = pathlib.Path(sys.argv[1])
d = json.loads(p.read_text())
if d.get("server_enabled"):
    print("obs-websocket already enabled on port", d.get("server_port", 4455))
else:
    d["server_enabled"] = True
    p.write_text(json.dumps(d, indent=2) + "\n")
    print("enabled obs-websocket on port", d.get("server_port", 4455))
PY
else
    python3 - "$ws" <<'PY'
import json, secrets, string, sys, pathlib
alphabet = string.ascii_letters + string.digits
d = {"alerts_enabled": False, "auth_required": True, "first_load": False,
     "server_enabled": True, "server_port": 4455,
     "server_password": "".join(secrets.choice(alphabet) for _ in range(16))}
pathlib.Path(sys.argv[1]).write_text(json.dumps(d, indent=2) + "\n")
print("created obs-websocket config with a fresh password")
PY
fi

# Keeping OBS out of the way is global, not per-profile, so an existing install only gets told
user_ini="$obs_cfg/user.ini"
if [[ -e "$user_ini" ]]; then
    say ""
    say "You already use OBS. These keys keep it windowless and cheap, but they are global:"
    say "  [BasicWindow] SysTrayEnabled=true SysTrayWhenStarted=true PreviewEnabled=false"
    say "Without them OBS opens a window and renders a preview: about ten times the CPU."
    say ""
else
    cat > "$user_ini" <<'INI'
[General]
FirstRun=true

[BasicWindow]
PreviewEnabled=false
SysTrayEnabled=true
SysTrayWhenStarted=true
INI
    say "wrote $user_ini (no window, no preview, tray icon only)"
fi

ln -sf "$here/systemd/obs-vcam.service" "$units/obs-vcam.service"
systemctl --user daemon-reload
say "linked obs-vcam.service"

say ""
say "Done. Enable the widget in Settings -> Widgets; it notices this within five"
say "seconds. Backgrounds go into ~/Pictures/webcam-backgrounds, or through Add in the"
say "popup. Start the camera by hand with:"
say "  systemctl --user start obs-vcam.service"
