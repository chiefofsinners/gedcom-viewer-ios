#!/bin/zsh
# Captures App Store screenshots on the iPhone Duo simulator's inner display (2007x2853,
# portrait), one language at a time, into fastlane/screenshots/<folder>/iPhone Duo-*.png.
#
# snapshot can't do this itself: the Duo boots folded, snapshot reboots the simulator for
# every language, and a UI test can't unfold it. So for each language this boots the Duo,
# unfolds it with duoctl (brew install skarol/tap/duoctl) before the app launches, keeps it
# open while the test runs, and hands SnapshotHelper the language the way snapshot would.
#
# usage: duo-screenshots.sh <language>:<locale>:<folder> ...
#   e.g. duo-screenshots.sh en:en-GB:en-GB de:de-DE:de-DE
set -u
cd "${0:A:h}/.."

scheme="GEDCOM Viewer"
bundle_id="com.lewisdeveloping.GEDCOM-Viewer"
cache="$HOME/Library/Caches/tools.fastlane"
derived="${TMPDIR:-/tmp}/gedcom-duo-screenshots"
udid=$(xcrun simctl list devices available | sed -nE 's/^ *iPhone Duo \(([0-9A-F-]+)\).*/\1/p' | head -1)
[[ -n $udid ]] || { print -u2 "No iPhone Duo simulator (needs Xcode 27.1 and the iOS 27.1 runtime)."; exit 1; }
command -v duoctl >/dev/null || { print -u2 "Needs duoctl: brew install skarol/tap/duoctl"; exit 1; }

open_portrait() {
  for _ in {1..30}; do
    state=$(duoctl -d $udid state 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["activeScreen"], d["orientation"])' 2>/dev/null)
    [[ $state == "inner portrait" ]] && return 0
    duoctl -d $udid open >/dev/null 2>&1
    duoctl -d $udid rotate portrait >/dev/null 2>&1
    sleep 1
  done
  return 1
}

xcodebuild build-for-testing -project "$scheme.xcodeproj" -scheme "$scheme" \
  -destination "id=$udid" -derivedDataPath "$derived" -quiet || exit 1

failed=()
for spec in "$@"; do
  language=${spec%%:*}; rest=${spec#*:}; locale=${rest%%:*}; folder=${rest#*:}
  print "== $folder"
  for attempt in 1 2; do
    xcrun simctl boot $udid 2>/dev/null; xcrun simctl bootstatus $udid -b >/dev/null 2>&1
    open_portrait || { print -u2 "could not unfold the Duo"; continue; }
    xcrun simctl uninstall $udid $bundle_id 2>/dev/null
    xcrun simctl status_bar $udid override --time 9:41 --dataNetwork wifi --wifiMode active \
      --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
    mkdir -p "$cache/screenshots"; rm -f "$cache/screenshots/"*.png
    print -n $language > "$cache/language.txt"
    print -n $locale > "$cache/locale.txt"
    print -n "" > "$cache/snapshot-launch_arguments.txt"

    # The test run can fold the Duo again as it starts, so keep unfolding until it ends.
    stop=$(mktemp -u); ( while [[ ! -e $stop ]]; do open_portrait >/dev/null; sleep 1; done ) &
    keeper=$!
    xcodebuild test-without-building -project "$scheme.xcodeproj" -scheme "$scheme" \
      -destination "id=$udid" -derivedDataPath "$derived" -parallel-testing-enabled NO \
      -only-testing:"${scheme}UITests" > "$derived/test-$folder.log" 2>&1
    result=$?
    touch $stop; wait $keeper; rm -f $stop

    shots=("$cache/screenshots/"iPhone\ Duo-*.png(N))
    if (( result == 0 && ${#shots} > 0 )); then
      mkdir -p "fastlane/screenshots/$folder"
      rm -f "fastlane/screenshots/$folder/"iPhone\ Duo-*.png
      cp "${shots[@]}" "fastlane/screenshots/$folder/"
      print "   ${#shots} screenshots"
      break
    fi
    print -u2 "   attempt $attempt failed (log: $derived/test-$folder.log)"
    (( attempt == 2 )) && failed+=$folder
  done
done

(( ${#failed} == 0 )) || { print -u2 "Failed: ${failed[*]}"; exit 1; }
