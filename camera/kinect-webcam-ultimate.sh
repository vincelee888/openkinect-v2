#!/bin/bash
# Ultimate Kinect webcam - no windows, direct streaming

export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Build if not exists
if [ ! -f /usr/local/bin/kinect2v4l2 ]; then
    echo "Building kinect2v4l2..."
    chmod +x build-kinect2v4l2.sh
    ./build-kinect2v4l2.sh
fi

# Kill any existing
pkill -f kinect2v4l2
pkill -f Protonect

# Setup v4l2loopback
sudo modprobe -r v4l2loopback 2>/dev/null
sleep 1
sudo modprobe v4l2loopback devices=1 video_nr=2 card_label="Xbox Kinect HD" exclusive_caps=0
sudo chmod 666 /dev/video2

echo "Starting Kinect direct streaming (no windows!)..."
echo ""

# Run our direct bridge
exec /usr/local/bin/kinect2v4l2 /dev/video2