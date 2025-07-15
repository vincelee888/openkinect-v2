#!/bin/bash
# Kinect webcam without visible windows - using virtual display

export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Kill existing processes
pkill -f Protonect
pkill -f ffmpeg
pkill -f Xvfb

# Setup v4l2loopback
sudo modprobe -r v4l2loopback 2>/dev/null
sleep 1
sudo modprobe v4l2loopback devices=1 video_nr=2 card_label="Xbox Kinect HD" exclusive_caps=0
sudo chmod 666 /dev/video2

# Install xvfb if not present
if ! command -v Xvfb &> /dev/null; then
    echo "Installing Xvfb for virtual display..."
    sudo apt-get install -y xvfb
fi

echo "Starting Kinect in virtual display (no window visible)..."

# Start virtual display on :99
Xvfb :99 -screen 0 1920x1080x24 &
XVFB_PID=$!
sleep 2

# Start Protonect on virtual display
DISPLAY=:99 /usr/local/bin/Protonect &
PROTONECT_PID=$!
sleep 5

# Capture from virtual display and stream to v4l2loopback
# We capture a specific region where the RGB window appears
DISPLAY=:99 ffmpeg -f x11grab -r 30 -video_size 640x480 -i :99.0+640,50 \
    -vf "format=yuv420p" \
    -f v4l2 -pix_fmt yuv420p /dev/video2 &
FFMPEG_PID=$!

echo "✓ Kinect is now streaming to /dev/video2"
echo "✓ No windows visible - running completely headless!"
echo ""
echo "Use in Zoom: zoom --use-file-for-fake-video-capture=/dev/video2"
echo "Press Ctrl+C to stop"

# Cleanup on exit
trap "kill $XVFB_PID $PROTONECT_PID $FFMPEG_PID 2>/dev/null; pkill Xvfb" EXIT

# Keep running
wait