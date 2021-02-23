#!/bin/sh
# brew install jq librsvg
jq -r < Contents.json '.images[]|select(.idiom != "mac")|."expected-size"' | xargs -n1 -I % bash -c 'rsvg-convert -b black markology.svg -h % > %.png'
jq -r < Contents.json '.images[]|select(.idiom == "mac")|."expected-size"' | xargs -n1 -I % bash -c 'rsvg-convert markology.svg -h % > %.png'
rsvg-convert -b black markology.svg -h 1024 > 1024.ios.png
