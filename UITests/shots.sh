#!/bin/sh
# brew install chargepoint/xcparse/xcparse

cwd=$(dirname "$0")
mkdir -p /tmp/shots

if [ "$#" -eq 0 ]
then
  targets=('iPhone 8 Plus' 'iPhone 11 Pro Max' 'iPad Pro (12.9-inch) (2nd generation)' 'iPad Pro (12.9-inch) (5th generation)', 'macOS')
else
  targets=("${@}")
fi
time='2021-03-14T06:28:30-04:00'
for target in "${targets[@]}"
do
  if [ 'macOS' = "$target" ]
  then
    xcparse screenshots --model `sh -c "xcodebuild test -target UITests -scheme Markology -destination 'platform=macOS'" | grep xcresult` /tmp/shots
    find "/tmp/shots/MacBook Pro/" | grep _ | sed "s/\(\([^_]*\).*\)/mv '\1' '\2-dark.png'/" | sh
    osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to not dark mode'
    xcparse screenshots --model `sh -c "xcodebuild test -target UITests -scheme Markology -destination 'platform=macOS'" | grep xcresult` /tmp/shots
    find "/tmp/shots/MacBook Pro/" | grep _ | sed "s/\(\([^_]*\).*\)/mv '\1' '\2-light.png'/" | sh
    osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to not dark mode'
  else
    xcrun simctl boot "$target"
    xcrun simctl ui "$target" appearance dark
    xcrun simctl status_bar "$target" override --time $time --batteryState charged --batteryLevel 100 --operatorName idk --cellularBars 4 --dataNetwork 'hide'
    xcparse screenshots --model `sh -c "xcodebuild test -target UITests -scheme Markology -destination 'name=$target'" | grep xcresult` /tmp/shots
    find "/tmp/shots/$target/" | grep _ | sed "s/\(\([^_]*\).*\)/mv '\1' '\2-dark.png'/" | sh
    xcrun simctl ui "$target" appearance light
    xcrun simctl status_bar "$target" override --time $time
    xcparse screenshots --model `sh -c "xcodebuild test -target UITests -scheme Markology -destination 'name=$target'" | grep xcresult` /tmp/shots
    find "/tmp/shots/$target/" | grep _ | sed "s/\(\([^_]*\).*\)/mv '\1' '\2-light.png'/" | sh
    xcrun simctl shutdown "$target"
  fi
done

exiftool -all= /tmp/shots/*/*.png

sed 's/viewBox=".*"/viewBox="0 0 2048 2732"/' $cwd/ipad.svg > /tmp/shots/ipad-5-1.svg
sed 's/viewBox=".*"/viewBox="2148 0 2048 2732"/' $cwd/ipad.svg > /tmp/shots/ipad-5-2.svg
sed 's/viewBox=".*"/viewBox="4296 0 2048 2732"/' $cwd/ipad.svg > /tmp/shots/ipad-5-3.svg

sed 's/viewBox=".*"/viewBox="0 0 2048 2732"/;s/(5th generation)/(2nd generation)/' $cwd/ipad.svg > /tmp/shots/ipad-2-1.svg
sed 's/viewBox=".*"/viewBox="2148 0 2048 2732"/;s/(5th generation)/(2nd generation)/' $cwd/ipad.svg > /tmp/shots/ipad-2-2.svg
sed 's/viewBox=".*"/viewBox="4296 0 2048 2732"/;s/(5th generation)/(2nd generation)/' $cwd/ipad.svg > /tmp/shots/ipad-2-3.svg

sed 's/viewBox=".*"/viewBox="0 0 1242 2688"/' $cwd/iphone-11.svg > /tmp/shots/iphone-11-1.svg
sed 's/viewBox=".*"/viewBox="1342 0 1242 2688"/' $cwd/iphone-11.svg > /tmp/shots/iphone-11-2.svg
sed 's/viewBox=".*"/viewBox="2684 0 1242 2688"/' $cwd/iphone-11.svg > /tmp/shots/iphone-11-3.svg

sed 's/viewBox=".*"/viewBox="0 0 1242 2208"/' $cwd/iphone-8.svg > /tmp/shots/iphone-8-1.svg
sed 's/viewBox=".*"/viewBox="1342 0 1242 2208"/' $cwd/iphone-8.svg > /tmp/shots/iphone-8-2.svg
sed 's/viewBox=".*"/viewBox="2684 0 1242 2208"/' $cwd/iphone-8.svg > /tmp/shots/iphone-8-3.svg

sed 's/viewBox=".*"/viewBox="0 0 2560 1600"/' $cwd/mac.svg > /tmp/shots/mac-1.svg
sed 's/viewBox=".*"/viewBox="2660 0 2560 1600"/' $cwd/mac.svg > /tmp/shots/mac-2.svg
sed 's/viewBox=".*"/viewBox="5320 0 2560 1600"/' $cwd/mac.svg > /tmp/shots/mac-3.svg

find "/tmp/shots" | grep svg | sed "s/\(\([^_]*\).svg\)/rsvg-convert '\1' > '\2.png'/" | sh
