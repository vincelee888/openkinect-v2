# Xbox Kinect Camera Troubleshooting Guide

This guide helps resolve issues with using Xbox Kinect v2 as a webcam in Linux.

## SOLVED: Working Solution

The Kinect now works using the `kinect2v4l2` binary in headless mode:

```bash
# Start Kinect
./kinect-webcam-ultimate.sh

# Launch Zoom with Chrome flags
zoom --use-file-for-fake-video-capture=/dev/video2
```

## Common Issues and Solutions

### Service Troubleshooting

**Service won't start**
```bash
# Check service status
sudo systemctl status kinect-webcam

# View detailed logs
sudo journalctl -u kinect-webcam -n 50

# Common fixes:
# 1. Ensure kinect2v4l2 is executable
chmod +x /mnt/raid1/GitHub/black-panther/kinect/kinect2v4l2

# 2. Check USB connection
lsusb | grep Microsoft

# 3. Remove and reload v4l2loopback
sudo modprobe -r v4l2loopback
sudo modprobe v4l2loopback devices=1 video_nr=2 card_label="Xbox Kinect HD" exclusive_caps=0
```

**Service running but no camera in Zoom**
- Restart Zoom after starting the service
- Check if `/dev/video2` exists: `ls -la /dev/video2`
- Try capturing a test frame: `ffmpeg -f v4l2 -i /dev/video2 -frames 1 test.jpg`

## Quick Diagnostics

```bash
# Check if Kinect is detected
lsusb | grep Microsoft
# Expected: Xbox NUI Sensor (045e:02c4)

# Check v4l2loopback status
lsmod | grep v4l2loopback

# Check video devices
ls -la /dev/video*

# Check Kinect-related processes
ps aux | grep -E "kinect2v4l2|Protonect"

# Check if video is streaming
ffmpeg -f v4l2 -i /dev/video2 -frames 1 test.jpg

# Check if libfreenect2 is installed
dpkg -l | grep freenect
```

## Understanding the Setup

### Hardware Requirements
- Xbox Kinect v2 (USB 3.0 version)
- Official Kinect Adapter for Windows (provides proper power)
- USB 3.0 port (blue port, USB 2.0 insufficient)
- Adequate power delivery (Kinect needs 12V/2.67A)

#### Recommended USB Ports for ASUS ROG STRIX B650-A GAMING WIFI
For optimal performance, use one of these USB 3.2 Gen 2 ports (see page 2-22 in the ASUS manual):
- **Port 1**: USB 3.2 Gen 2 Type-A (10Gbps)
- **Port 2**: USB 3.2 Gen 2 Type-A (10Gbps)
- **Port 11**: USB 3.2 Gen 2 Type-A (10Gbps)

Avoid USB 2.0 ports (5, 15, 16, 17) as they lack sufficient bandwidth for Kinect.

### Software Stack
1. **libfreenect2**: Low-level Kinect driver
2. **v4l2loopback**: Creates virtual video devices
3. **kinect2v4l2**: Direct binary that streams Kinect to v4l2 (replaces kinect2pipe)

## Installation Steps

### 1. Install Dependencies

```bash
# Core dependencies
sudo apt update
sudo apt install build-essential cmake pkg-config

# libfreenect2 dependencies
sudo apt install libusb-1.0-0-dev libturbojpeg0-dev libglfw3-dev

# OpenGL dependencies
sudo apt install libgl1-mesa-dev libglu1-mesa-dev

# v4l2loopback
sudo apt install v4l2loopback-dkms v4l2loopback-utils

# Additional tools
sudo apt install libopencv-dev python3-opencv
```

### 2. Build and Install libfreenect2

```bash
# Clone repository
cd /tmp
git clone https://github.com/OpenKinect/libfreenect2.git
cd libfreenect2

# Create build directory
mkdir build && cd build

# Configure with CUDA support (for NVIDIA GPU)
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local \
         -DENABLE_CUDA=ON \
         -DENABLE_OPENCL=OFF

# Build and install
make -j$(nproc)
sudo make install

# Update library cache
sudo ldconfig
```

### 3. Set Up udev Rules

```bash
# Create udev rules for Kinect
sudo tee /etc/udev/rules.d/90-kinect2.rules << 'EOF'
# Xbox One Kinect
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="02c4", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="02d8", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="045e", ATTR{idProduct}=="02d9", MODE="0666"
EOF

# Reload udev rules
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### 4. Test libfreenect2

```bash
# Test if Kinect is working
/usr/local/bin/Protonect

# If working, you should see:
# - Depth image
# - IR image  
# - Color image
# - Kinect lights should turn on
```

## Setting Up v4l2loopback

### 1. Configure v4l2loopback Modules

```bash
# Create module configuration
sudo tee /etc/modprobe.d/v4l2loopback.conf << 'EOF'
options v4l2loopback devices=2 video_nr=10,11 card_label="Kinect_Color,Kinect_Depth" exclusive_caps=1
EOF

# Load modules
sudo modprobe -r v4l2loopback  # Remove if loaded
sudo modprobe v4l2loopback

# Verify devices created
ls -la /dev/video*
```

### 2. Install kinect2-bridge (Python Option)

```bash
# Install Python dependencies
pip3 install numpy opencv-python pylibfreenect2

# Create kinect2-v4l2.py script
cat > ~/kinect2-v4l2.py << 'EOF'
#!/usr/bin/env python3
import cv2
import numpy as np
from pylibfreenect2 import Freenect2, SyncMultiFrameListener
from pylibfreenect2 import FrameType, Registration, Frame
import subprocess
import time

def main():
    # Initialize Kinect
    fn = Freenect2()
    device = fn.openDefaultDevice()
    
    if device is None:
        print("No Kinect detected!")
        return
    
    # Create listeners
    types = FrameType.Color | FrameType.Depth
    listener = SyncMultiFrameListener(types)
    device.setColorFrameListener(listener)
    device.setIrAndDepthFrameListener(listener)
    
    # Start device
    device.start()
    
    # Open v4l2loopback device
    width, height = 1920, 1080
    fps = 30
    
    # Create video writer for /dev/video10
    fourcc = cv2.VideoWriter_fourcc(*'YUYV')
    out = cv2.VideoWriter('/dev/video10', fourcc, fps, (width, height))
    
    print("Streaming Kinect to /dev/video10...")
    print("Press Ctrl+C to stop")
    
    try:
        while True:
            frames = listener.waitForNewFrame()
            color = frames["color"]
            
            # Convert to OpenCV format
            color_array = color.asarray()
            color_bgr = cv2.cvtColor(color_array, cv2.COLOR_RGBA2BGR)
            
            # Resize if needed
            if color_bgr.shape[:2] != (height, width):
                color_bgr = cv2.resize(color_bgr, (width, height))
            
            # Write to v4l2loopback
            out.write(color_bgr)
            
            listener.release(frames)
            
    except KeyboardInterrupt:
        pass
    finally:
        device.stop()
        device.close()
        out.release()

if __name__ == "__main__":
    main()
EOF

chmod +x ~/kinect2-v4l2.py
```

### 3. Create systemd Service (Optional)

```bash
# Create service file
sudo tee /etc/systemd/system/kinect-camera.service << 'EOF'
[Unit]
Description=Kinect v2 Camera Bridge
After=multi-user.target

[Service]
Type=simple
User=YOUR_USERNAME
ExecStart=/usr/bin/python3 /home/YOUR_USERNAME/kinect2-v4l2.py
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Replace YOUR_USERNAME with actual username
sudo sed -i "s/YOUR_USERNAME/$USER/g" /etc/systemd/system/kinect-camera.service

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable kinect-camera
sudo systemctl start kinect-camera
```

## Troubleshooting Common Issues

### Green Screen in Zoom

**Cause**: v4l2loopback device exists but no data being written

**Solutions**:
1. Check if Kinect is properly initialized:
   ```bash
   sudo /usr/local/bin/Protonect
   ```
   If this works (shows images), the hardware is OK.

2. Check v4l2loopback devices:
   ```bash
   v4l2-ctl --list-devices
   v4l2-ctl -d /dev/video10 --all
   ```

3. Test with simple color bars:
   ```bash
   # Generate test pattern
   gst-launch-1.0 videotestsrc ! v4l2sink device=/dev/video10
   ```

### Kinect Not Detected

**Symptoms**: No lights on Kinect, lsusb doesn't show device

**Solutions**:
1. Check USB 3.0 connection:
   ```bash
   lspci | grep -i usb | grep -i xhci
   lsusb -t  # Should show "5000M" speed for USB 3.0
   ```

2. Try different USB ports (rear panel preferred)
   - For ASUS ROG STRIX B650-A GAMING WIFI, use ports 1, 2, or 11
   - These are USB 3.2 Gen 2 ports with 10Gbps bandwidth
   - Avoid ports 5, 15, 16, 17 (USB 2.0 only)

3. Check power adapter:
   - White LED on adapter should be solid
   - Try unplugging and reconnecting power

4. Check kernel messages:
   ```bash
   sudo dmesg | tail -50
   # Look for USB errors or power issues
   ```

### "Module v4l2loopback is in use"

**Solution**:
```bash
# Find what's using it
sudo lsof /dev/video10 /dev/video11

# Kill Zoom if running
pkill -f zoom

# Force remove
sudo modprobe -rf v4l2loopback
```

### Performance Issues

**Symptoms**: Laggy video, high CPU usage

**Solutions**:
1. Use hardware acceleration:
   ```bash
   # Check CUDA support
   nvidia-smi
   
   # Rebuild libfreenect2 with CUDA
   cmake .. -DENABLE_CUDA=ON
   ```

2. Reduce resolution:
   ```python
   # In kinect2-v4l2.py, change:
   width, height = 1280, 720  # Instead of 1920x1080
   ```

3. Lower framerate:
   ```python
   fps = 15  # Instead of 30
   ```

## Testing the Setup

### 1. Basic Hardware Test
```bash
# Should show Kinect device
lsusb | grep Microsoft

# Should show kernel recognition
dmesg | grep -i kinect
```

### 2. Driver Test
```bash
# Test libfreenect2
/usr/local/bin/Protonect

# Should display:
# - Color stream
# - Depth stream  
# - IR stream
# - Kinect lights should be on
```

### 3. v4l2loopback Test
```bash
# Check devices
v4l2-ctl --list-devices

# Test with VLC
vlc v4l2:///dev/video10

# Test with ffmpeg
ffmpeg -f v4l2 -i /dev/video10 -frames 1 test.jpg
```

### 4. Zoom Test
1. Start the kinect2-v4l2.py script
2. Open Zoom settings
3. Select "Kinect_Color" camera
4. Should see live video instead of green screen

## Alternative Solutions

### Using OBS Studio
1. Install OBS Studio
2. Add Video Capture Device source
3. Select /dev/video10
4. Use OBS Virtual Camera for Zoom

### Using GStreamer Pipeline
```bash
# Create GStreamer pipeline
gst-launch-1.0 \
    libcamerasrc camera-name="kinect" ! \
    video/x-raw,width=1920,height=1080,framerate=30/1 ! \
    videoconvert ! \
    v4l2sink device=/dev/video10
```

## Resources

- [libfreenect2 GitHub](https://github.com/OpenKinect/libfreenect2)
- [OpenKinect Wiki](https://openkinect.org/wiki/Main_Page)
- [v4l2loopback GitHub](https://github.com/umlaeute/v4l2loopback)

## Notes

- Kinect v2 requires USB 3.0 for full functionality
- The official Kinect Adapter provides proper 12V power
- Some USB 3.0 ports may not provide enough power
- Kinect v2 is different from Kinect v1 (360) - uses different drivers