#!/bin/bash
# WORKING Kinect webcam solution

export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Stop everything
sudo systemctl stop kinect-webcam.service
pkill -f kinect2pipe
pkill -f Protonect
pkill -f gst-launch

# Setup v4l2loopback with known working parameters
sudo modprobe -r v4l2loopback
sleep 1
sudo modprobe v4l2loopback devices=1 video_nr=2 card_label="Kinect Camera" exclusive_caps=0
sudo chmod 666 /dev/video2

echo "Testing with simple pattern first..."
# Use a test pattern to verify v4l2loopback works
gst-launch-1.0 videotestsrc pattern=ball ! \
    video/x-raw,format=I420,width=640,height=480,framerate=30/1 ! \
    v4l2sink device=/dev/video2 &

GSTPID=$!
sleep 3

echo ""
echo "CHECK NOW: Open Zoom and look for 'Kinect Camera'"
echo "You should see a moving ball pattern."
echo ""
echo "If you see it in Zoom, v4l2loopback is working!"
echo "Press Enter to try the real Kinect..."
read

kill $GSTPID 2>/dev/null

# Now let's use the Protonect window capture method
echo "Starting Kinect with window capture (most reliable method)..."

# Start Protonect
/usr/local/bin/Protonect &
PROPID=$!
sleep 5

# Find and capture the RGB window
echo "Capturing Kinect RGB window..."

# Method 1: Specific window capture
WINDOW_ID=$(xdotool search --name "rgb" 2>/dev/null | head -1)

if [ -n "$WINDOW_ID" ]; then
    eval $(xdotool getwindowgeometry --shell $WINDOW_ID 2>/dev/null || true)
    if [ -n "$WIDTH" ]; then
        echo "Found RGB window: ${WIDTH}x${HEIGHT} at ${X},${Y}"
        ffmpeg -f x11grab -r 30 -s ${WIDTH}x${HEIGHT} -i :0.0+${X},${Y} \
            -vf "format=yuv420p,scale=640:480" \
            -f v4l2 -pix_fmt yuv420p /dev/video2
    fi
else
    # Method 2: Capture general area
    echo "Capturing screen area where Kinect window appears..."
    ffmpeg -f x11grab -r 30 -video_size 1920x1080 -i :0.0 \
        -vf "crop=640:480:100:100,format=yuv420p" \
        -f v4l2 -pix_fmt yuv420p /dev/video2
fi

# Cleanup on exit
trap "kill $PROPID 2>/dev/null; pkill Protonect" EXIT