#!/bin/bash
# Monitor Kinect audio levels in real-time

NODE=$(pw-cli list-objects | grep -A5 "Xbox NUI Sensor" | grep "node.name" | grep "alsa_input" | cut -d'"' -f2 | head -1)

if [ -z "$NODE" ]; then
    echo "Error: Kinect audio not found"
    exit 1
fi

echo "Monitoring Kinect audio levels..."
echo "Speak into the Kinect to see levels. Press Ctrl+C to stop."
echo ""

# Use pw-mon to monitor the levels
pw-cat --record --target="$NODE" --rate=16000 --channels=4 --format=s32 - | \
    ffmpeg -f s32le -ar 16000 -ac 4 -i - -filter_complex \
    "[0:a]showvolume=f=0.5:c=gradient:v=0:dm=2:dmc=orange:o=v:s=640x40[v0];\
     [0:a]asplit=4[a0][a1][a2][a3];\
     [a0]showvolume=f=0.5:c=gradient:v=0:dm=2:dmc=red:o=v:s=640x40[v1];\
     [a1]showvolume=f=0.5:c=gradient:v=0:dm=2:dmc=green:o=v:s=640x40[v2];\
     [a2]showvolume=f=0.5:c=gradient:v=0:dm=2:dmc=blue:o=v:s=640x40[v3];\
     [a3]showvolume=f=0.5:c=gradient:v=0:dm=2:dmc=yellow:o=v:s=640x40[v4];\
     [v1][v2][v3][v4]vstack=4" \
    -f sdl2 -window_title "Kinect Audio Levels (FL=Red FR=Green FC=Blue LFE=Yellow)" -
