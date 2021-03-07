#!/bin/sh
# brew install chargepoint/xcparse/xcparse
if [ "$#" -eq 0 ]
then
  targets=('iPhone 8 Plus' 'iPhone 11 Pro Max' 'iPad Pro (12.9-inch) (2nd generation)' 'iPad Pro (12.9-inch) (4th generation)')
else
  targets=("${@}")
fi
dests=''
for target in "${targets[@]}"
do
  dests="$dests -destination 'name=$target'"
  xcrun simctl boot "$target"
  xcrun simctl ui "$target" appearance dark
done
xcparse screenshots --model `sh -c "xcodebuild test -target UITests -scheme Markology $dests" | grep xcresult`
for target in "${targets[@]}"
do
  xcrun simctl ui "$target" appearance light
done
xcparse screenshots --model `sh -c "xcodebuild test -target UITests -scheme Markology $dests" | grep xcresult`
for target in "${targets[@]}"
do
  xcrun simctl shutdown "$target"
done
