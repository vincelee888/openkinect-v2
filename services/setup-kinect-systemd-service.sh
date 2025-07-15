#!/bin/bash
# Setup systemd service for Kinect webcam

echo "Setting up Kinect webcam systemd service..."

# Copy service file
sudo cp kinect-webcam.service /etc/systemd/system/
sudo chmod 644 /etc/systemd/system/kinect-webcam.service

# Ensure the wrapper script is executable
chmod +x kinect-webcam-service-wrapper.sh

# Ensure kinect2v4l2 binary is executable
chmod +x kinect2v4l2

# Reload systemd
sudo systemctl daemon-reload

# Enable service
sudo systemctl enable kinect-webcam.service

echo "✓ Service installed and enabled"
echo ""
echo "Commands:"
echo "  Start:   sudo systemctl start kinect-webcam"
echo "  Stop:    sudo systemctl stop kinect-webcam"
echo "  Status:  sudo systemctl status kinect-webcam"
echo "  Logs:    sudo journalctl -u kinect-webcam -f"
echo ""
echo "The service will start automatically on boot."
echo ""
echo "IMPORTANT: You still need to launch Zoom with:"
echo "  zoom --use-file-for-fake-video-capture=/dev/video2"