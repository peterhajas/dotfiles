#!/usr/bin/env python3

# This grabs the latest MDI and makes a JSON file mapping MDI icon names
# to their Unicode codepoints (without the surrounding \u{____})
#
# It should only be run to update icons, and only when MDI's TTF is
# installed. I got mine from Home Assistant's iOS
# `BuildMaterialDesignIconsFont.sh` script:
#
# https://github.com/home-assistant/iOS/blob/master/Tools/BuildMaterialDesignIconsFont.sh

import urllib.request
import json
import os
import pathlib

with urllib.request.urlopen('https://raw.githubusercontent.com/Templarian/MaterialDesign-SVG/master/meta.json') as url:
    icons = json.loads(url.read().decode())
    out = { }
    # For each icon, generate a dictionary (key = name, value = unicode)
    for icon in icons:
        out[icon['name']] = icon['codepoint']

    scriptPathString = os.path.realpath(__file__)
    scriptPath = pathlib.Path(scriptPathString)
    outputPath = scriptPath.parent / 'mdi.json'
    outputJSON = json.dumps(out)
    outputPath.touch()
    outputPath.write_text(outputJSON)


