#!/bin/bash
# Service wrapper for Kinect webcam - runs kinect2v4l2 in background

# Add library path for libfreenect2
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Kill any existing processes
pkill -f kinect2v4l2 2>/dev/null
pkill -f Protonect 2>/dev/null

# Setup v4l2loopback
modprobe -r v4l2loopback 2>/dev/null
sleep 1
modprobe v4l2loopback devices=1 video_nr=2 card_label="Xbox Kinect HD" exclusive_caps=0
chmod 666 /dev/video2 2>/dev/null

# Start kinect2v4l2
echo "Starting Kinect direct streaming service..."
cd /mnt/raid1/GitHub/black-panther/kinect
exec ./kinect2v4l2 /dev/video2