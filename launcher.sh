#!/bin/bash

./main &
ENGINE_PID=$!

while true; do
    if pgrep -x "RobloxPlayer" > /dev/null; then
        ./uncap_fps.sh
        break
    fi
    sleep 1
done

wait $ENGINE_PID
