#!/bin/sh
# brew install chargepoint/xcparse/xcparse
xcrun simctl boot "iPhone 8 Plus"
xcrun simctl boot "iPhone 11 Pro Max"
xcrun simctl boot "iPad Pro (12.9-inch) (2nd generation)"
xcrun simctl boot "iPad Pro (12.9-inch) (4th generation)"
xcrun simctl ui "iPhone 8 Plus" appearance dark
xcrun simctl ui "iPhone 11 Pro Max" appearance dark
xcrun simctl ui "iPad Pro (12.9-inch) (2nd generation)" appearance dark
xcrun simctl ui "iPad Pro (12.9-inch) (4th generation)" appearance dark
xcparse screenshots --model `xcodebuild test -target UITests -scheme Markology -destination "name=iPhone 8 Plus" -destination "name=iPhone 11 Pro Max" -destination "name=iPad Pro (12.9-inch) (2nd generation)" -destination "name=iPad Pro (12.9-inch) (4th generation)" | grep xcresult`
xcrun simctl ui "iPhone 8 Plus" appearance light
xcrun simctl ui "iPhone 11 Pro Max" appearance light
xcrun simctl ui "iPad Pro (12.9-inch) (2nd generation)" appearance light
xcrun simctl ui "iPad Pro (12.9-inch) (4th generation)" appearance light
xcparse screenshots --model `xcodebuild test -target UITests -scheme Markology -destination "name=iPhone 8 Plus" -destination "name=iPhone 11 Pro Max" -destination "name=iPad Pro (12.9-inch) (2nd generation)" -destination "name=iPad Pro (12.9-inch) (4th generation)" | grep xcresult`
xcrun simctl shutdown "iPhone 8 Plus"
xcrun simctl shutdown "iPhone 11 Pro Max"
xcrun simctl shutdown "iPad Pro (12.9-inch) (2nd generation)"
xcrun simctl shutdown "iPad Pro (12.9-inch) (4th generation)"
