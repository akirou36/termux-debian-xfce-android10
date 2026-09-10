echo ""
echo "🚀 Starting Debian XFCE..."                                 echo ""
                                                                  # ─────────────────────────────
# 🔊 PulseAudio                                                   # ─────────────────────────────

echo "🔊 Starting PulseAudio..."
                                                                  unset PULSE_SERVER
pulseaudio --kill 2>/dev/null                                     sleep 0.5
                                                                  rm -f "$HOME/pulse.log"
                                                                  pulseaudio \
    --exit-idle-time=-1 \
    --log-target=file:$HOME/pulse.log \
    --log-level=info &

PULSE_PID=$!
                                                                  echo "   PulseAudio PID: $PULSE_PID"
                                                                  sleep 1

MODULE_ID=$(pactl load-module module-native-protocol-tcp \            auth-ip-acl=127.0.0.1 \
    auth-anonymous=1)

export PULSE_SERVER=127.0.0.1

echo "✅ PulseAudio TCP module: $MODULE_ID"

# ─────────────────────────────
# 🖥️ Termux:X11
# ─────────────────────────────

echo "🖥️ Starting Termux:X11..."

export DISPLAY=:1

termux-x11 :1 -ac >/dev/null 2>&1 &

sleep 3

am start \
    --user 0 \
    -n com.termux.x11/com.termux.x11.MainActivity \
    >/dev/null 2>&1

sleep 1

# ─────────────────────────────
# 🦊 Native Firefox bridge
# ─────────────────────────────

echo "🦊 Starting native Firefox bridge..."

FF_PIPE="$HOME/.ff-launch.pipe"
FF_PIDFILE="$HOME/.ff-launch-bridge.pid"

# Stop old bridge if one exists
if [ -f "$FF_PIDFILE" ]; then
    OLD_PID="$(cat "$FF_PIDFILE" 2>/dev/null)"
    kill "$OLD_PID" 2>/dev/null || true
fi

rm -f "$FF_PIPE"
mkfifo "$FF_PIPE"

(
    while true; do
        if IFS= read -r action < "$FF_PIPE"; then
            case "$action" in
                firefox)
                    dbus-run-session -- env \
                        DISPLAY=:1 \
                        GSETTINGS_BACKEND=memory \
                        PULSE_SERVER=127.0.0.1 \
                        /data/data/com.termux/files/usr/bin/firefox \
                        --no-remote \
                        >/dev/null 2>&1 &
                    ;;
            esac
        fi
    done
) &

FF_BRIDGE_PID=$!
echo "$FF_BRIDGE_PID" > "$FF_PIDFILE"

echo "✅ Firefox bridge PID: $FF_BRIDGE_PID"

# ─────────────────────────────
# 🐧 Debian + XFCE
# ─────────────────────────────

echo "🐧 Launching Debian XFCE..."

proot-distro login debian \
    --user akirou \
    --shared-tmp \
    -- bash -lc '
        export DISPLAY=:1
        export PULSE_SERVER=127.0.0.1

        unset WAYLAND_DISPLAY

        exec dbus-launch --exit-with-session startxfce4
    '
