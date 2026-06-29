#!/usr/bin/env bash
#
# Ubuntu-side setup for the Remote macOS client.
#
# Installs x11vnc and attaches it to your *existing* desktop session (display
# :0) so the Mac app shows the real screen and can control it. By default the
# VNC server only listens on localhost, so reach it by tunnelling over SSH
# (enable "Tunnel over SSH" in the Mac app).
#
# Usage:
#   ./remote-setup.sh                 # install + set a VNC password
#   ./remote-setup.sh --service       # also install a systemd user service
#
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}▸${NC} $*"; }
warn()  { echo -e "${YELLOW}!${NC} $*"; }
err()   { echo -e "${RED}✗${NC} $*"; }

# --- Session sanity check -----------------------------------------------------
if [ "${XDG_SESSION_TYPE:-}" = "wayland" ]; then
    warn "You are running a Wayland session. x11vnc needs Xorg."
    warn "Either log out and pick 'Ubuntu on Xorg' at the login screen,"
    warn "or use GNOME Settings → Sharing → Remote Desktop instead."
    echo
fi

# --- Install x11vnc -----------------------------------------------------------
if ! command -v x11vnc >/dev/null 2>&1; then
    info "Installing x11vnc…"
    sudo apt-get update -qq
    sudo apt-get install -y x11vnc
else
    info "x11vnc already installed."
fi

# --- VNC password -------------------------------------------------------------
if [ ! -f "$HOME/.vnc/passwd" ]; then
    info "Setting a VNC password (used by the Mac app)…"
    mkdir -p "$HOME/.vnc"
    x11vnc -storepasswd "$HOME/.vnc/passwd"
else
    info "Existing VNC password found at ~/.vnc/passwd"
fi

# --- Detect the active X display + its auth file ------------------------------
# `-auth guess` is unreliable (needs net-tools), so read the auth path straight
# from the running Xorg process.
DISP=$(ls /tmp/.X11-unix/ 2>/dev/null | sed 's/X/:/' | head -1)
XAUTH=$(ps -wwo args= -C Xorg 2>/dev/null | grep -oP '(?<=-auth )\S+' | head -1)
if [ -z "$DISP" ] || [ -z "$XAUTH" ]; then
    warn "Could not find a running Xorg display."
    warn "If this machine is on Wayland, switch to 'Ubuntu on Xorg' at the login screen and rerun."
    DISP="${DISP:-:0}"
    XAUTH="${XAUTH:-$HOME/.Xauthority}"
fi
info "Using display $DISP with auth $XAUTH"

# No -localhost: bind all interfaces so it's reachable directly (e.g. over
# Tailscale). SSH tunnelling still works, since localhost is included.
RUN_CMD="x11vnc -display $DISP -auth $XAUTH -rfbauth $HOME/.vnc/passwd -forever -shared -noxdamage -repeat -rfbport 5900"

# --- Optional systemd user service -------------------------------------------
if [ "${1:-}" = "--service" ]; then
    info "Installing systemd user service 'x11vnc'…"
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/x11vnc.service" <<EOF
[Unit]
Description=x11vnc server for Remote
After=graphical-session.target

[Service]
ExecStart=$(command -v x11vnc) -display $DISP -auth $XAUTH -rfbauth $HOME/.vnc/passwd -forever -shared -noxdamage -repeat -rfbport 5900
Restart=on-failure

[Install]
WantedBy=default.target
EOF
    systemctl --user daemon-reload
    systemctl --user enable --now x11vnc.service
    info "Service started. Check status with: systemctl --user status x11vnc"
else
    echo
    info "Setup complete. Start the VNC server with:"
    echo
    echo "    $RUN_CMD"
    echo
    info "Tip: pass --service to install it as a background systemd service."
fi

echo
info "In the Mac app, create a connection:"
echo "    • Tunnel over SSH:  OFF over Tailscale (already encrypted), or ON for plain SSH"
echo "    • VNC Host:         this machine's Tailscale IP / name  (or LAN IP)"
echo "    • Display:          0"
echo "    • VNC Password:     the password you set"
