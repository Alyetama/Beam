Beam is a clean, native macOS remote-desktop client for Ubuntu — a from-scratch
VNC (RFB) client in Swift, optionally tunnelled over SSH.

**Download:** `Beam.dmg` below · macOS 14+ · Apple Silicon

---

### Opening Beam the first time

Beam is open source but isn’t signed with a paid Apple Developer ID, so macOS
Gatekeeper blocks it on first launch. This is a **one-time** step:

1. Open `Beam.dmg` and drag **Beam** into your **Applications** folder.
2. In Applications, **right-click** (or Control-click) **Beam** → choose **Open**.
3. Click **Open** again in the dialog. macOS remembers your choice from then on.

If macOS 15 (Sequoia) still blocks it:

- Open Beam once, then go to **System Settings → Privacy & Security**, scroll
  down, and click **Open Anyway** next to “Beam was blocked”; **or**
- Remove the quarantine flag in Terminal, then open Beam normally:

  ```bash
  xattr -dr com.apple.quarantine /Applications/Beam.app
  ```

---

### Setting up the Ubuntu side

Run `remote-setup.sh` on the Ubuntu machine to install `x11vnc`, then add a
connection in Beam (machine IP / Tailscale name, display `0`, your VNC password).
See the [README](https://github.com/Alyetama/beam#readme) for details.
