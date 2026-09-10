export DISPLAY=:1
export GSETTINGS_BACKEND=memory

exec dbus-run-session -- \
  /data/data/com.termux/files/usr/bin/firefox "$@"
