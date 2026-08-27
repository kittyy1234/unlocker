#!/bin/bash

osascript -e '
tell application "System Events"
    try
        set displayConfig to {Width:1920, Height:1080, RefreshRate:360, IsVirtual:true, MirrorMaster:true}
    end try
end tell
' 2>/dev/null || true

while true; do
    sleep 3600
done
