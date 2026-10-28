#!/bin/zsh
# Captures App Store screenshots on one simulator, one language at a time, into
# fastlane/screenshots/<folder>/<simulator name>-*.png, using the snapshot UI test.
#
# Why not snapshot itself: it reinstalls the app while the simulator is shut down between
# languages, which removes nothing, so the sample data reopened on the person viewed in the
# previous run. And the iPhone Duo boots folded, which a UI test can't undo. So for each
# language this boots the simulator, unfolds a Duo with duoctl (brew install skarol/tap/duoctl)
# and keeps it open, uninstalls the app while the simulator is running, and hands
# SnapshotHelper the language the way snapshot would.
#
# usage: device-screenshots.sh "<simulator name>" <language>:<locale>:<folder> ...
#   e.g. device-screenshots.sh "iPhone Duo" en:en-GB:en-GB de:de-DE:de-DE
set -u
cd "${0:A:h}/.."

device=$1; shift
scheme="GEDCOM Viewer"
bundle_id="com.lewisdeveloping.GEDCOM-Viewer"
cache="$HOME/Library/Caches/tools.fastlane"
derived="${TMPDIR:-/tmp}/gedcom-screenshots/$device"
udid=$(xcrun simctl list devices available | grep -F "    $device (" | sed -nE 's/.*\(([0-9A-F-]{36})\).*/\1/p' | head -1)
[[ -n $udid ]] || { print -u2 "No simulator named \"$device\"."; exit 1; }
[[ $device == "iPhone Duo" ]] && is_duo=1 || is_duo=0
(( is_duo )) && ! command -v duoctl >/dev/null && { print -u2 "The iPhone Duo needs duoctl: brew install skarol/tap/duoctl"; exit 1; }

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
  print "== $device $folder"
  for attempt in 1 2; do
    xcrun simctl boot $udid 2>/dev/null; xcrun simctl bootstatus $udid -b >/dev/null 2>&1
    # A Duo sometimes won't unfold after a long idle; a reboot brings it back.
    if (( is_duo )) && ! open_portrait; then
      xcrun simctl shutdown $udid 2>/dev/null; xcrun simctl boot $udid; xcrun simctl bootstatus $udid -b >/dev/null 2>&1
      open_portrait || { print -u2 "could not unfold the Duo"; continue; }
    fi
    xcrun simctl uninstall $udid $bundle_id 2>/dev/null
    xcrun simctl status_bar $udid override --time 9:41 --dataNetwork wifi --wifiMode active \
      --wifiBars 3 --cellularMode active --cellularBars 4 --batteryState discharging --batteryLevel 100
    mkdir -p "$cache/screenshots"; rm -f "$cache/screenshots/"*.png(N)
    print -n $language > "$cache/language.txt"
    print -n $locale > "$cache/locale.txt"
    print -n "" > "$cache/snapshot-launch_arguments.txt"

    # The test run can fold the Duo again as it starts, so keep unfolding until it ends.
    keeper=0
    if (( is_duo )); then
      stop=$(mktemp -u); ( while [[ ! -e $stop ]]; do open_portrait >/dev/null; sleep 1; done ) &
      keeper=$!
    fi
    xcodebuild test-without-building -project "$scheme.xcodeproj" -scheme "$scheme" \
      -destination "id=$udid" -derivedDataPath "$derived" -parallel-testing-enabled NO \
      -only-testing:"${scheme}UITests" > "$derived/test-$folder.log" 2>&1
    result=$?
    (( keeper )) && { touch $stop; wait $keeper; rm -f $stop; }

    shots=("$cache/screenshots/$device"-*.png(N))
    if (( result == 0 && ${#shots} > 0 )); then
      mkdir -p "fastlane/screenshots/$folder"
      rm -f "fastlane/screenshots/$folder/$device"-*.png(N)
      cp "${shots[@]}" "fastlane/screenshots/$folder/"
      print "   ${#shots} screenshots"
      break
    fi
    print -u2 "   attempt $attempt failed (log: $derived/test-$folder.log)"
    (( attempt == 2 )) && failed+=$folder
  done
done

(( ${#failed} == 0 )) || { print -u2 "Failed on $device: ${failed[*]}"; exit 1; }
