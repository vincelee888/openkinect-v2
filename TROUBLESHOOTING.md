# Troubleshooting Guide

## Common Issues and Solutions

### 🔴 Kinect Not Detected

#### Symptoms
- `lsusb` doesn't show Microsoft devices
- No `/dev/video*` device created
- Error: "No Kinect devices found"

#### Solutions
1. **Check Hardware Connections**
   ```bash
   # Verify USB devices
   lsusb | grep Microsoft
   # Should show: Bus xxx Device xxx: ID 045e:02c4 Microsoft Corp. Xbox NUI Sensor
   ```

2. **Verify Adapter Power**
   - White LED on adapter should be solid (not blinking)
   - Try different power outlet
   - Check all cable connections

3. **USB 3.0 Issues**
   ```bash
   # Check USB controller
   lspci | grep USB
   
   # Verify USB 3.0 speed
   lsusb -t | grep "5000M"
   ```

4. **Permission Issues**
   ```bash
   # Add user to video group
   sudo usermod -a -G video $USER
   
   # Update udev rules
   sudo cp 90-kinect2.rules /etc/udev/rules.d/
   sudo udevadm control --reload-rules
   sudo udevadm trigger
   ```

### 🟡 Green Screen in Applications

#### Symptoms
- Solid green video in Zoom/Chrome
- Video works in some apps but not others
- Flickering or corrupted video

#### Solutions
1. **Check if Kinect is Streaming**
   ```bash
   # Test direct capture
   ffmpeg -f v4l2 -i /dev/video2 -frames 1 test.jpg
   
   # Check process
   ps aux | grep kinect
   ```

2. **Application-Specific Fixes**
   
   **Zoom:**
   ```bash
   # Launch with fake video device
   zoom --use-file-for-fake-video-capture=/dev/video2
   ```
   
   **Chrome/Chromium:**
   ```bash
   # With video device flag
   google-chrome --use-fake-device-for-media-stream --use-file-for-fake-video-capture=/dev/video2
   ```

3. **Format Issues**
   ```bash
   # Check video format
   v4l2-ctl -d /dev/video2 --list-formats
   
   # Set to YUYV if needed
   v4l2-ctl -d /dev/video2 --set-fmt-video=width=1920,height=1080,pixelformat=YUYV
   ```

### 🔵 Poor Performance

#### Symptoms
- Low framerate
- High CPU usage
- Laggy video
- System freezing

#### Solutions
1. **Check USB Bandwidth**
   ```bash
   # Monitor USB errors
   dmesg -w | grep -i usb
   
   # Check for bandwidth issues
   cat /sys/kernel/debug/usb/devices | grep "Kinect" -A 10
   ```

2. **Reduce Resolution**
   ```bash
   # Use 720p instead of 1080p
   v4l2-ctl -d /dev/video2 --set-fmt-video=width=1280,height=720
   ```

3. **CPU Optimization**
   ```bash
   # Check CPU usage
   htop
   
   # Set process priority
   sudo nice -n -10 kinect2v4l2
   ```

### 🎤 Audio Issues

#### Symptoms
- No audio device detected
- Very quiet microphone
- Distorted audio
- Only one channel working

#### Solutions
1. **Check Audio Detection**
   ```bash
   # List audio devices
   arecord -l | grep Xbox
   
   # Check PulseAudio
   pactl list sources | grep -A 10 Xbox
   ```

2. **Boost Audio Levels**
   ```bash
   # Set maximum gain in PulseAudio
   pactl set-source-volume @DEFAULT_SOURCE@ 150%
   
   # Or use alsamixer
   alsamixer -c 3  # where 3 is the Kinect card number
   ```

3. **Fix Channel Issues**
   ```bash
   # Test all 4 channels
   arecord -D hw:3,0 -f S32_LE -c 4 -r 16000 test.wav
   
   # Monitor levels
   arecord -D hw:3,0 -f S32_LE -c 4 -r 16000 -V stereo /dev/null
   ```

### ⚡ Service Issues

#### Symptoms
- Service won't start
- Service crashes repeatedly
- Auto-start not working

#### Solutions
1. **Check Service Status**
   ```bash
   sudo systemctl status openkinect-v2
   sudo journalctl -u openkinect-v2 -f
   ```

2. **Debug Service Failures**
   ```bash
   # Run manually to see errors
   sudo /usr/local/bin/kinect2v4l2
   
   # Check permissions
   ls -la /dev/video*
   ls -la /dev/bus/usb/*/*
   ```

3. **Fix Module Loading**
   ```bash
   # Load v4l2loopback manually
   sudo modprobe v4l2loopback video_nr=2 card_label="Xbox Kinect"
   
   # Check if loaded
   lsmod | grep v4l2loopback
   ```

### 🔧 Installation Problems

#### Symptoms
- Build errors
- Missing dependencies
- Module won't compile

#### Solutions
1. **Install Build Dependencies**
   ```bash
   sudo apt update
   sudo apt install build-essential cmake pkg-config
   sudo apt install libusb-1.0-0-dev libturbojpeg0-dev libglfw3-dev
   sudo apt install libva-dev libjpeg-dev libopenni2-dev
   ```

2. **Fix libfreenect2 Issues**
   ```bash
   # Clean and rebuild
   cd libfreenect2/build
   rm -rf *
   cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
   make -j$(nproc)
   sudo make install
   ```

3. **Kernel Module Issues**
   ```bash
   # Install kernel headers
   sudo apt install linux-headers-$(uname -r)
   
   # Rebuild v4l2loopback
   sudo dkms remove v4l2loopback/0.12.5 --all
   sudo dkms install v4l2loopback/0.12.5
   ```

## Platform-Specific Issues

### Ubuntu 22.04+
- May need to disable Secure Boot for v4l2loopback
- Wayland can cause issues - try X11 session

### Fedora
```bash
# Different package names
sudo dnf install libusbx-devel turbojpeg-devel
```

### Arch Linux
```bash
# Install from AUR
yay -S libfreenect2-git v4l2loopback-dkms
```

## Advanced Debugging

### Enable Debug Logging
```bash
# libfreenect2 debug
export LIBFREENECT2_LOGGER_LEVEL=Debug

# Kernel USB debug
echo 1 | sudo tee /sys/module/usbcore/parameters/usbfs_snoop
```

### USB Analysis
```bash
# Detailed USB info
sudo lsusb -v -d 045e:02c4

# USB bandwidth usage
sudo cat /sys/kernel/debug/usb/devices
```

### Check Kernel Support
```bash
# Verify USB 3.0 XHCI
dmesg | grep xhci

# Check for errors
dmesg | grep -E "kinect|freenect|usb.*error"
```

## When All Else Fails

1. **Complete Reset**
   ```bash
   # Stop everything
   sudo systemctl stop openkinect-v2
   sudo pkill kinect
   sudo modprobe -r v4l2loopback
   
   # Unplug Kinect for 30 seconds
   
   # Start fresh
   sudo modprobe v4l2loopback
   sudo systemctl start openkinect-v2
   ```

2. **Try Different Hardware**
   - Different USB port
   - Different USB cable
   - Powered USB 3.0 hub (as last resort)
   - Different computer

3. **Report Issues**
   When reporting issues, include:
   - Output of `lsusb | grep Microsoft`
   - Output of `dmesg | tail -50`
   - Output of `sudo systemctl status openkinect-v2`
   - Your hardware specs (motherboard, USB controller)