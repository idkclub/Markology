#!/bin/sh
# brew install chargepoint/xcparse/xcparse
if [ "$#" -eq 0 ]
then
  targets=('iPhone 8 Plus' 'iPhone 11 Pro Max' 'iPad Pro (12.9-inch) (2nd generation)' 'iPad Pro (12.9-inch) (5th generation)')
else
  targets=("${@}")
fi
time='2021-03-14T06:28:30-04:00'
for target in "${targets[@]}"
do
  xcrun simctl boot "$target"
  xcrun simctl ui "$target" appearance dark
  xcrun simctl status_bar "$target" override --time $time --batteryState charged --batteryLevel 100
  xcparse screenshots --model `sh -c "xcodebuild test -target UITests -scheme Markology -destination 'name=$target'" | grep xcresult`
  xcrun simctl ui "$target" appearance light
  xcrun simctl status_bar "$target" override --time $time
  xcparse screenshots --model `sh -c "xcodebuild test -target UITests -scheme Markology -destination 'name=$target'" | grep xcresult`
  xcrun simctl shutdown "$target"
done
