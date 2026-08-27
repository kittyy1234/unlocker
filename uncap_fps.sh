#!/bin/bash

printf '#!/bin/bash\nexec "/Applications/Roblox.app/Contents/MacOS/RobloxPlayer" --disable-vsync --force-gles-renderer\n' > launch_unlocked.sh
chmod +x launch_unlocked.sh

./launch_unlocked.sh
