#!/bin/sh

if [ "$#" -eq 0 ]
then
  targets=('iPhone 14 Plus')
else
  targets=("${@}")
fi

time='2021-03-14T11:23:58-04:00'
for target in "${targets[@]}"
do
  xcrun simctl bootstatus "$target" -b
  xcrun simctl ui "$target" appearance dark
  xcrun simctl io "$target" recordVideo --codec=h264 "$target.mp4" &
  RECORD_PID=$!
  xcparse screenshots --model `sh -c "xcodebuild test -parallel-testing-enabled NO -target MarkologyUITests -scheme Markology -destination 'name=$target'" | grep xcresult` .
  kill -INT $RECORD_PID
done
