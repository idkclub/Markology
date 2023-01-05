#!/bin/sh

mkdir -p Screenshots

# TODO: `xcrun simctl create $target $target` if missing.
if [ "$#" -eq 0 ]
then
  targets=('iPhone 14 Plus' 'iPhone 8 Plus' 'iPad Pro (12.9-inch) (6th generation)' 'iPad Pro (12.9-inch) (2nd generation)' 'macOS')
else
  targets=("${@}")
fi

time='2021-03-14T11:23:58-04:00'
for target in "${targets[@]}"
do
  if [ 'macOS' = "$target" ]
  then
    xcparse screenshots --model `sh -c "xcodebuild test -parallel-testing-enabled NO -scheme MarkologyUITests -destination 'platform=macOS'" | grep xcresult` Screenshots
  else
    xcrun simctl bootstatus "$target" -b
    xcrun simctl status_bar "$target" override --time $time --batteryState charged --batteryLevel 100 --operatorName idk --cellularBars 4 --dataNetwork 'hide'
    xcrun simctl ui "$target" appearance dark
    xcrun simctl io "$target" recordVideo --codec=h264 "Screenshots/$target.mp4" &
    RECORD_PID=$!
    xcparse screenshots --model `sh -c "xcodebuild test -parallel-testing-enabled NO -scheme MarkologyUITests -destination 'name=$target'" | grep xcresult` Screenshots
    kill -INT $RECORD_PID
  fi
done
