#!/bin/bash

XRAY_CONFIG="/app/xray.json"
BLOCKY_CONFIG="/app/blocky.yml"

# Check Config files
if [ ! -f "$XRAY_CONFIG" ]; then
    echo "[xray] ERROR: Config file '$XRAY_CONFIG' missing!" >&2
else
    echo "[xray] Starting with config $XRAY_CONFIG"
    /usr/local/bin/xray -config "$XRAY_CONFIG" \
        2> >(tee -a /var/log/xray.err.log >&2) \
        > >(tee -a /var/log/xray.out.log) &
fi

if [ ! -f "$BLOCKY_CONFIG" ]; then
    echo "[blocky] ERROR: Config file '$BLOCKY_CONFIG' missing!" >&2
else
    echo "[blocky] Starting with config $BLOCKY_CONFIG"
    /usr/local/bin/blocky --config "$BLOCKY_CONFIG" \
        2> >(tee -a /var/log/blocky.err.log >&2) \
        > >(tee -a /var/log/blocky.out.log) &
fi

# Wait for background processes to finish
wait
