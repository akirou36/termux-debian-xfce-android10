# termux-debian-xfce.android-10

A practical **Debian 13 + XFCE desktop setup for Android 10**, running through **Termux, PRoot and Termux:X11**.

This repository documents my complete working setup, including the original Debian installation, custom startup scripts, PulseAudio, Termux:X11, KGSL/Freedreno GPU acceleration experiments, native Termux Firefox integration, and the fixes required to make Firefox stable and fast.

> Built and tested on an Android 10 ARM64 device.

---

## Overview

```text
Android 10
    │
    └── Termux
         │
         ├── Termux:X11
         │      │
         │      └── Debian 13 / XFCE
         │
         ├── PulseAudio
         │
         ├── Native Termux applications
         │      └── Firefox
         │
         └── PRoot
                │
                └── Debian 13 (Trixie)
                     │
                     └── XFCE
```

The desktop itself runs inside Debian/PRoot, while some applications can run directly from Termux and display inside the same X11 session.

This is useful for applications such as Firefox, where running the native Termux build avoids a noticeable amount of PRoot overhead.

---

# Base Installation

The original Debian environment was installed using:

**[01101010110/proot-distro-scripts](https://github.com/01101010110/proot-distro-scripts)**

The installer used was:

```text
debian-x11-app.sh
```

That script created the initial Debian + XFCE + Termux:X11 environment.

This repository does **not** replace the upstream project.

Instead, it documents the Android 10-specific modifications and fixes applied afterwards.

---

# Tested Environment

```text
Android        : 10
Architecture   : aarch64 / ARM64
Debian         : Debian 13 (Trixie)
Desktop        : XFCE
Display        : Termux:X11
Display ID     : :1
Audio          : PulseAudio
Container      : PRoot
GPU API        : KGSL
Mesa Driver    : Freedreno
GPU Renderer   : FD512
```

The GPU configuration is device-specific and should not be assumed to work on every Android device.

---

# Main Startup Flow

The final startup sequence is:

```text
~/debian.sh
      │
      ├── Start PulseAudio
      │
      ├── Load PulseAudio TCP module
      │
      ├── Start Termux:X11 on :1
      │
      ├── Open Termux:X11 Android activity
      │
      ├── Start native Firefox bridge
      │
      └── Launch Debian
             │
             └── dbus-launch
                    │
                    └── XFCE
```

The complete desktop can be started from Termux with:

```bash
~/debian.sh
```

---

# PulseAudio

PulseAudio runs on the **Termux side**.

The startup script starts PulseAudio and exposes it to Debian using:

```bash
PULSE_SERVER=127.0.0.1
```

The TCP module is loaded using:

```bash
pactl load-module module-native-protocol-tcp \
    auth-ip-acl=127.0.0.1 \
    auth-anonymous=1
```

Debian then uses:

```bash
export PULSE_SERVER=127.0.0.1
```

This allows applications inside Debian to output sound through Android.

---

# Termux:X11

The graphical desktop uses Termux:X11 instead of VNC.

The display is:

```bash
export DISPLAY=:1
```

Termux:X11 is started with:

```bash
termux-x11 :1 -ac
```

The Android activity can be opened from Termux using:

```bash
am start \
    --user 0 \
    -n com.termux.x11/com.termux.x11.MainActivity
```

XFCE is then launched inside Debian on the same display.

---

# Debian / XFCE Launch

The Debian container is started through `proot-distro`.

Example:

```bash
proot-distro login debian \
    --user akirou \
    --shared-tmp
```

Inside Debian:

```bash
export DISPLAY=:1
export PULSE_SERVER=127.0.0.1
unset WAYLAND_DISPLAY
```

XFCE is launched with its own D-Bus session:

```bash
dbus-launch --exit-with-session startxfce4
```

---

# Why `--shared-tmp` Matters

Termux:X11 and applications inside Debian need access to compatible shared temporary files and sockets.

Using:

```bash
--shared-tmp
```

allows the Debian environment to share Termux's temporary directory.

Without it, X11 and other IPC-based components may fail to communicate correctly.

---

# KGSL / Freedreno GPU Acceleration

The device exposes:

```text
/dev/kgsl-3d0
```

which can be used by Mesa's Freedreno stack on compatible Qualcomm GPUs.

The accelerated configuration successfully reported:

```text
Vendor       : Mesa
Renderer     : FD512
Accelerated  : yes
```

Compared with software rendering:

```text
llvmpipe
Accelerated: no
```

the Freedreno path provided dramatically better OpenGL performance.

During testing:

```text
llvmpipe glmark2  : ~16-29
Freedreno / KGSL  : ~143
```

Results depend heavily on the GPU, Mesa version, Android version and KGSL compatibility.

---

## Example KGSL Environment

Some experiments used variables such as:

```bash
export MESA_LOADER_DRIVER_OVERRIDE=kgsl
export FD_FORCE_KGSL=1
```

These should **not** be blindly applied to every application.

The final stable Firefox configuration does not require forcing these variables.

---

# Mesa Notes

The working Mesa/Freedreno setup used a newer Mesa build and successfully detected the FD512 GPU.

One recurring warning was related to modern ION allocation support, after which Mesa could fall back to a legacy ION path.

Because Android GPU stacks differ significantly between devices, this repository treats GPU acceleration as a separate optional layer rather than a requirement for Debian/XFCE itself.

---

# Firefox

Firefox became the most interesting part of this setup.

A native Termux Firefox build performs much better than running the same binary from inside Debian/PRoot.

---

## Firefox Version

The stable rollback build currently used is:

```text
Mozilla Firefox 148.0.2
```

Package version:

```text
149.0+really148.0.2
```

Architecture:

```text
aarch64
```

The package is installed directly in Termux.

---

# Why Native Termux Firefox Is Faster

Launching the Termux Firefox binary from inside Debian still causes the process to inherit the PRoot environment.

Firefox performs a large amount of filesystem and system activity during startup:

```text
open()
stat()
readlink()
mmap()
socket()
clone()
```

PRoot has to intercept and translate many of those operations.

So:

```text
Debian / PRoot
      ↓
Firefox
      ↓
PRoot translation
      ↓
Android
```

is noticeably slower than:

```text
Termux
   ↓
Firefox
   ↓
Android
```

The difference is especially visible during browser startup and page loading.

---

# Firefox Crash Problem

Firefox originally suffered from repeated crashes.

Typical output included:

```text
Exiting due to channel error.
```

and:

```text
CompositorBridgeChild receives IPC close
with reason=AbnormalShutdown
```

The browser often exited with:

```text
143
```

which corresponds to:

```text
SIGTERM
```

---

# Things That Were Tested

The following were tested and did **not** eliminate the crash:

```text
Clean Firefox profile
Sandbox disabled
WebRender disabled
WebGL disabled
Software rendering
Headless mode
Different graphics configurations
```

This showed that the crash was not simply caused by GPU acceleration.

---

# SIGTERM Investigation

A small `LD_PRELOAD` diagnostic library was created to intercept:

```text
raise()
kill()
tgkill()
tkill()
```

The logs revealed that Firefox was internally reaching:

```c
raise(SIGTERM);
```

The important call path included:

```text
GLib
 ↓
GIO
 ↓
GObject
 ↓
GDBusConnection
 ↓
SIGTERM
```

Disassembly of the installed `libgio` showed the crash passing through a:

```text
GDBusConnection::closed
```

signal.

GLib supports an `exit-on-close` mode for D-Bus connections, where losing the associated peer can intentionally terminate the application.

This explained why the final compositor errors were likely a consequence of Firefox shutting down rather than the original cause.

---

# dconf / GSettings Workaround

One major improvement came from running Firefox with:

```bash
export GSETTINGS_BACKEND=memory
```

Before this change, crash traces frequently involved a:

```text
dconf worker
```

thread.

With the memory backend enabled, Firefox became significantly faster and more stable.

The minimal configuration was:

```bash
export DISPLAY=:1
export GSETTINGS_BACKEND=memory

firefox
```

This does not disable Firefox's own profile storage.

Firefox bookmarks, history, extensions and Firefox preferences continue to be stored normally.

The setting only changes the GSettings backend used by that process.

---

# Dedicated Firefox D-Bus Session

Firefox could still crash during heavier activity such as video playback.

The final major stability improvement came from launching Firefox inside a dedicated D-Bus session:

```bash
dbus-run-session -- env \
    DISPLAY=:1 \
    GSETTINGS_BACKEND=memory \
    firefox
```

This configuration survived stress testing with multiple tabs and multiple simultaneous YouTube videos where the previous configuration would crash.

The final stable Firefox stack is therefore:

```text
Termux-native Firefox
        +
GSETTINGS_BACKEND=memory
        +
dbus-run-session
        +
Termux:X11
```

---

# Native Firefox Bridge

Because XFCE runs inside Debian but Firefox should run natively in Termux, the setup uses a lightweight bridge.

The Debian desktop launcher does **not** directly execute the Firefox binary.

Instead:

```text
XFCE desktop icon
       ↓
writes "firefox" into FIFO
       ↓
Termux background bridge
       ↓
native Termux Firefox
       ↓
Termux:X11
```

This keeps Firefox outside PRoot while still allowing it to be launched from the Debian desktop.

No additional Termux terminal tab is required.

The bridge runs silently as a background child of `debian.sh`.

---

# Firefox Package Hold

Because the repository version may be newer than the working rollback build, Firefox can be held to prevent accidental upgrades.

Run in Termux:

```bash
apt-mark hold firefox
```

Check:

```bash
apt-mark showhold
```

---

# Firefox WebGL Notes

Some websites may print messages such as:

```text
FEATURE_FAILURE_WEBGL_EXHAUSTED_DRIVERS
```

or:

```text
WebglAllowWindowsNativeGl:false
```

The current stable setup prioritizes browser stability.

GPU/WebGL acceleration can be experimented with separately, but it should not be mixed into the known-working launcher until tested.

---

# Recommended Rule

Keep one known-working launcher unchanged.

For example:

```text
firefox-fd.sh      → stable configuration
firefox-fd-gpu.sh  → experimental GPU configuration
```

That makes performance experiments easy to compare without destroying the stable setup.

---

# Repository Layout

```text
termux-debian-xfce.android-10/
│
├── README.md
│
├── LICENSE
│
├── scripts/
│   ├── debian.sh
│   ├── stop-debian.sh
│   └── firefox-native.sh
│
├── docs/
│   ├── base-installation.md
│   ├── xfce-termux-x11.md
│   ├── pulseaudio.md
│   ├── kgsl-freedreno.md
│   ├── firefox-148.md
│   ├── firefox-crash-fix.md
│   └── troubleshooting.md
│
└── screenshots/
```

---

# Current Status

| Component | Status |
|---|---|
| Debian 13 | ✅ Working |
| XFCE | ✅ Working |
| Termux:X11 | ✅ Working |
| PulseAudio | ✅ Working |
| Shared storage | ✅ Working |
| Native Firefox | ✅ Working |
| Firefox video playback | ✅ Working |
| Firefox D-Bus fix | ✅ Working |
| Freedreno / KGSL | ✅ Working on tested device |
| WebGL acceleration | ⚠️ Experimental |
| GPU-specific tweaks | ⚠️ Device dependent |

---

# Upstream Credit

The original Debian/XFCE environment was created using:

**01101010110/proot-distro-scripts**

https://github.com/01101010110/proot-distro-scripts

This repository focuses on documenting the modifications, compatibility fixes and performance work applied after the initial installation.

Thanks to the Termux, Termux:X11, Debian, Mesa, Freedreno, Mozilla and GLib projects.

---

# Disclaimer

This setup is highly device-dependent.

It was built around:

```text
Android 10
ARM64
Qualcomm / Adreno
Termux
PRoot
Debian 13
XFCE
Termux:X11
```

Different Android versions, GPUs, Mesa packages or Termux versions may behave differently.

Back up important data before replacing packages or experimenting with GPU libraries.

---

## Final Setup

```text
Android 10
   ↓
Termux
   ├── PulseAudio
   ├── Termux:X11
   ├── Native Firefox + dedicated D-Bus
   └── PRoot
        ↓
      Debian 13
        ↓
       XFCE
        ↓
KGSL / Freedreno where supported
```

A surprisingly usable Linux desktop on a phone. ☝🏻🤓
