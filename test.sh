#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build/module-cache
xcrun swiftc -module-cache-path build/module-cache Sources/Settings.swift Sources/Schedule.swift Sources/WindowPlacement.swift \
  Tests/main.swift -o build/core-tests
build/core-tests
