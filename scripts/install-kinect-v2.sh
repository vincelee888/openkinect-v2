#!/bin/bash
# Install Xbox One Kinect (v2) drivers on Ubuntu
# This builds libfreenect2 from source since it's not in default repositories

set -e

echo "Installing Xbox One Kinect (v2) drivers..."
echo "========================================"

# Install dependencies
echo "Installing build dependencies..."
sudo apt update
sudo apt install -y \
    cmake \
    pkg-config \
    libusb-1.0-0-dev \
    libturbojpeg0-dev \
    libglfw3-dev \
    build-essential \
    git

# Create temporary build directory
BUILD_DIR=$(mktemp -d)
cd "$BUILD_DIR"

# Clone libfreenect2
echo "Cloning libfreenect2 repository..."
git clone https://github.com/OpenKinect/libfreenect2.git
cd libfreenect2

# Create build directory
mkdir build && cd build

# Configure build
echo "Configuring build..."
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local

# Build with all available cores
echo "Building libfreenect2 (this may take a few minutes)..."
make -j$(nproc)

# Install
echo "Installing libfreenect2..."
sudo make install

# Install Protonect binary
if [ -f ../bin/Protonect ]; then
    echo "Installing Protonect test program..."
    sudo cp ../bin/Protonect /usr/local/bin/
    sudo chmod +x /usr/local/bin/Protonect
fi

# Update library cache
sudo ldconfig

# Install udev rules for device permissions
echo "Installing udev rules..."
sudo cp ../platform/linux/udev/90-kinect2.rules /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger

# Clean up build directory
cd /
rm -rf "$BUILD_DIR"

echo ""
echo "Installation complete!"
echo "====================="
echo ""
echo "You may need to unplug and replug your Kinect for the changes to take effect."
echo ""
echo "To test your Kinect v2, run:"
echo "  /usr/local/bin/Protonect"
echo ""
echo "This will open windows showing RGB camera, depth, and IR feeds."