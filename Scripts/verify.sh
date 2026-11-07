#!/bin/zsh
set -euo pipefail
project_root="${0:A:h:h}"
cd "$project_root"
if [[ $# -eq 0 ]]; then
  print 'Usage : Scripts/verify.sh IDENTIFIANT_DU_SIMULATEUR_IPAD'
  print 'Les identifiants sont listés par : xcrun simctl list devices available'
  exit 1
fi
result_path="TestResults/Verification-$(date +%Y%m%d-%H%M%S).xcresult"
xcodebuild -project musiquePapa.xcodeproj -scheme musiquePapa \
  -destination "platform=iOS Simulator,id=$1" -derivedDataPath build \
  -resultBundlePath "$result_path" -collect-test-diagnostics never \
  -parallel-testing-enabled NO -test-timeouts-enabled YES -maximum-test-execution-time-allowance 120 \
  CODE_SIGNING_ALLOWED=NO test
