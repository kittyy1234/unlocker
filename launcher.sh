#!/bin/bash

./main.sh &
ENGINE_PID=$!

while true; do
    if pgrep -x "RobloxPlayer" > /dev/null; then
        ./uncap_fps.sh
        break
    fi
    sleep 1
done

wait $ENGINE_PID
