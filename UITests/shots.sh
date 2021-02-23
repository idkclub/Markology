#!/bin/sh
# brew install chargepoint/xcparse/xcparse
xcrun simctl boot "iPhone 8 Plus"
xcrun simctl boot "iPhone 11 Pro Max"
xcrun simctl ui "iPhone 8 Plus" appearance dark
xcrun simctl ui "iPhone 11 Pro Max" appearance dark
xcparse screenshots --model `xcodebuild test -target UITests -scheme Markology -destination "name=iPhone 8 Plus" -destination "name=iPhone 11 Pro Max" | grep xcresult` dark
xcrun simctl ui "iPhone 8 Plus" appearance light
xcrun simctl ui "iPhone 11 Pro Max" appearance light
xcparse screenshots --model `xcodebuild test -target UITests -scheme Markology -destination "name=iPhone 8 Plus" -destination "name=iPhone 11 Pro Max" | grep xcresult` light
xcrun simctl shutdown "iPhone 8 Plus"
xcrun simctl shutdown "iPhone 11 Pro Max"
