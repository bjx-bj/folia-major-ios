#!/usr/bin/env bash
# 在真实 iOS/WKWebView 中验证插件注册、QQ/微信出码和 QQ 刷新。
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p ios/App/output
xcrun simctl list devices available -j > ios/App/output/simulator-devices.json
device="$(node --input-type=commonjs -e 'const f=require("fs");const all=JSON.parse(f.readFileSync("ios/App/output/simulator-devices.json","utf8"));for(const [runtime,devices] of Object.entries(all.devices)){if(!runtime.includes("iOS"))continue;const d=devices.find(v=>v.isAvailable&&v.name.startsWith("iPhone"));if(d){console.log(d.udid);process.exit(0)}}process.exit(1)')"
trap 'xcrun simctl shutdown "$device" >/dev/null 2>&1 || true' EXIT
xcrun simctl boot "$device" || true
xcrun simctl bootstatus "$device" -b
xcodebuild -project ios/App/App.xcodeproj -scheme App -configuration Release \
  -destination "platform=iOS Simulator,id=$device" -derivedDataPath ios/SimulatorData \
  CODE_SIGNING_ALLOWED=NO build > ios/App/output/simulator-build.log 2>&1
xcrun simctl install "$device" ios/SimulatorData/Build/Products/Release-iphonesimulator/App.app
xcrun simctl launch --terminate-running-process "$device" top.izuna.foliamajor --folia-qq-probe
container="$(xcrun simctl get_app_container "$device" top.izuna.foliamajor data)"
result="$container/Documents/FoliaQQProbe.json"
for attempt in $(seq 1 90); do
  if [ -f "$result" ]; then
    cp "$result" ios/App/output/qq-simulator-result.json
    cat ios/App/output/qq-simulator-result.json
    xcrun simctl io "$device" screenshot ios/App/output/qq-simulator-screen.png
    node --input-type=commonjs -e 'const r=require("./ios/App/output/qq-simulator-result.json");if(r.done!==true||r.success!==true)process.exit(1)'
    exit 0
  fi
  sleep 2
done
xcrun simctl io "$device" screenshot ios/App/output/qq-simulator-screen.png || true
echo "WKWebView QQ runtime probe did not finish" >&2
exit 1
