#!/bin/bash
set -e

XRAY_CONFIG="/app/xray.json"
BLOCKY_CONFIG="/app/blocky.yml"

echo "[xrocky-entrypoint] Initializing..."

# Check Config files
if [ ! -f "$XRAY_CONFIG" ]; then
    echo "[xray] ERROR: Config file '$XRAY_CONFIG' missing!" >&2
    exit 1
fi
echo "[xray] Config found: $XRAY_CONFIG"

if [ ! -f "$BLOCKY_CONFIG" ]; then
    echo "[blocky] ERROR: Config file '$BLOCKY_CONFIG' missing!" >&2
    exit 1
fi
echo "[blocky] Config found: $BLOCKY_CONFIG"

echo "[xrocky-entrypoint] Initialization complete, handing off to CMD..."

# Execute CMD (supervisord)
exec "$@"
