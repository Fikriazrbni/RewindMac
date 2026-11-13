#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
toolchain_bin="$(dirname "$(xcrun --find swift)")"
testing_plugins="$toolchain_bin/../lib/swift/host/plugins/testing"
if [[ -d "$testing_plugins" ]]; then
    swift test --disable-sandbox --disable-xctest --enable-swift-testing -Xswiftc -plugin-path -Xswiftc "$testing_plugins" "$@"
else
    swift test --disable-sandbox --disable-xctest --enable-swift-testing "$@"
fi
