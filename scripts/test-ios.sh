#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Override to test a specific iPad/iPhone. Never use a connected physical device by default.
if [[ -z "${DESTINATION:-}" ]]; then
    simulator_id=$(xcrun simctl list devices available -j | python3 -c 'import json,sys; d=json.load(sys.stdin); phones=[x for devices in d["devices"].values() for x in devices if x["name"].startswith("iPhone")]; print(phones[-1]["udid"] if phones else "")')
    [[ -n "$simulator_id" ]] || { printf 'No iPhone Simulator is installed. Add an iOS runtime in Xcode.\n' >&2; exit 1; }
    DESTINATION="platform=iOS Simulator,id=$simulator_id"
fi
xcodebuild -project iOS/MacPulse.xcodeproj -scheme MacPulse-iOS -configuration Debug \
    -destination "$DESTINATION" -derivedDataPath .build/ios \
    -parallel-testing-enabled NO test
