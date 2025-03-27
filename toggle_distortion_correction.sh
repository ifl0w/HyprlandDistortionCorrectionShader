#!/usr/bin/env sh

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

DISTORION_CORRECTION=$(hyprctl getoption decoration:screen_shader | awk 'NR==1{print $2}')
if [ -z "$DISTORION_CORRECTION" ] || [ "$DISTORION_CORRECTION" == "[[EMPTY]]" ] ; then
    echo "Enable distoriton correction"
    echo "Shader Path: $SCRIPT_DIR/distoriton_correction.glsl"
    hyprctl keyword decoration:screen_shader "$SCRIPT_DIR/distortion_correction.glsl"
else
    echo "Disable distoriton correction"
    hyprctl keyword decoration:screen_shader ""
fi
