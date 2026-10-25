#!/usr/bin/env bash
# Runs the YiyuCore test suite. With only the Command Line Tools installed,
# Swift Testing lives outside the default search paths, so point the build at it.
set -euo pipefail
cd "$(dirname "$0")/.."

DEV=/Library/Developer/CommandLineTools/Library/Developer
EXTRA=()
if [ -d "$DEV/Frameworks/Testing.framework" ] && ! xcode-select -p | grep -q "Xcode.app"; then
  EXTRA=(
    -Xswiftc -F -Xswiftc "$DEV/Frameworks"
    -Xlinker -F -Xlinker "$DEV/Frameworks"
    -Xlinker -rpath -Xlinker "$DEV/Frameworks"
    -Xlinker -rpath -Xlinker "$DEV/usr/lib"
  )
fi

swift test ${EXTRA[@]+"${EXTRA[@]}"} "$@"
