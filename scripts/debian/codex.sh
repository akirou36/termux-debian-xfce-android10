export DISPLAY=:1

exec env \
  -u GALLIUM_DRIVER \
  -u LIBGL_ALWAYS_SOFTWARE \
  MESA_LOADER_DRIVER_OVERRIDE=kgsl \
  chatgpt \
  --no-sandbox \
  --disable-setuid-sandbox \
  --disable-gpu-sandbox \
  --disable-dev-shm-usage \
  --ozone-platform=x11 \
  --use-gl=egl \
  --ignore-gpu-blocklist \
  "$@"
  
