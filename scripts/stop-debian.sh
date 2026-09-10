echo "💀 Stopping X11..."

PIDS=$(pgrep -f '^termux-x11 com\.termux\.x11 :1')

if [ -n "$PIDS" ]; then
    for pid in $PIDS; do
        echo "Killing X11 PID $pid"
        kill -9 "$pid" 2>/dev/null
    done
else
    echo "X11 already stopped"
fi

sleep 0.5

# Clean socket only AFTER X11 is dead
if ! pgrep -f '^termux-x11 com\.termux\.x11 :1' >/dev/null; then
    rm -f "$TMPDIR/.X11-unix/X1"
    rm -f "$TMPDIR/.X1-lock"
    echo "✅ X11 disconnected"
else
    echo "❌ X11 somehow still alive"
    pgrep -af termux-x11
fi
