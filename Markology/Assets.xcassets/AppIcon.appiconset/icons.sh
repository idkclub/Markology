#!/bin/sh
jq -r < Contents.json '.images[]|."expected-size"' | xargs -n1 -I % bash -c 'rsvg-convert -b black markology.svg -h % > %.png'
jq -r < Contents.json '.images[]|select(.idiom == "mac")|."expected-size"' | xargs -n1 -I % bash -c 'rsvg-convert markology.svg -h % > %.png'
