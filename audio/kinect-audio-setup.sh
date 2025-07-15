#!/bin/bash
# Setup and test Kinect v2 microphone array on Linux

echo "=== Kinect v2 Audio Setup ==="
echo ""

# Check if Kinect is detected
if ! arecord -l | grep -q "Xbox NUI Sensor"; then
    echo "❌ Error: Kinect audio device not found!"
    echo "Make sure the Kinect is connected via USB 3.0"
    exit 1
fi

echo "✓ Kinect audio device detected"
echo ""

# Get the card number
CARD_NUM=$(arecord -l | grep "Xbox NUI Sensor" | sed -n 's/card \([0-9]\+\):.*/\1/p')
echo "Found Kinect on ALSA card: $CARD_NUM"

# Show device info
echo ""
echo "=== Device Information ==="
cat /proc/asound/card$CARD_NUM/stream0 | grep -E "Channels:|Format:|Rates:"
echo ""

# Check PipeWire/PulseAudio
if command -v pw-cli &> /dev/null; then
    echo "=== PipeWire Configuration ==="
    NODE_NAME=$(pw-cli list-objects | grep -B5 "Xbox NUI Sensor" | grep "node.name" | grep "alsa_input" | cut -d'"' -f2)
    if [ -n "$NODE_NAME" ]; then
        echo "✓ PipeWire node: $NODE_NAME"
    else
        echo "⚠️  Kinect not found in PipeWire"
    fi
elif command -v pactl &> /dev/null; then
    echo "=== PulseAudio Configuration ==="
    SOURCE_NAME=$(pactl list sources | grep -B2 "Xbox NUI Sensor" | grep "Name:" | cut -d' ' -f2)
    if [ -n "$SOURCE_NAME" ]; then
        echo "✓ PulseAudio source: $SOURCE_NAME"
    else
        echo "⚠️  Kinect not found in PulseAudio"
    fi
fi

echo ""
echo "=== Audio Specifications ==="
echo "• 4 channels (FL, FR, FC, LFE)"
echo "• 32-bit signed samples (S32_LE)"
echo "• 16 kHz sampling rate"
echo "• Designed for beamforming and noise cancellation"
echo ""

echo "=== Known Limitations on Linux ==="
echo "• No access to hardware beamforming (Windows-only)"
echo "• Raw audio only - no built-in noise cancellation"
echo "• Volume may be ~20dB lower than Windows"
echo "• Requires custom software for directional audio"
echo ""

echo "=== Testing Audio Capture ==="
echo "Press Ctrl+C to stop recording"
echo ""

# Create test directory
mkdir -p audio-tests

# Test 1: Simple recording
echo "Test 1: Recording 5 seconds of audio..."
arecord -D hw:$CARD_NUM,0 -f S32_LE -c 4 -r 16000 -d 5 audio-tests/kinect-raw-4ch.wav 2>/dev/null

if [ -f "audio-tests/kinect-raw-4ch.wav" ]; then
    echo "✓ Raw 4-channel recording saved to audio-tests/kinect-raw-4ch.wav"
    echo "  File info:"
    file audio-tests/kinect-raw-4ch.wav
    echo ""
else
    echo "❌ Recording failed"
fi

# Test 2: Convert to mono for easier playback
echo "Test 2: Converting to mono..."
if command -v ffmpeg &> /dev/null; then
    ffmpeg -i audio-tests/kinect-raw-4ch.wav -ac 1 audio-tests/kinect-mono.wav -y 2>/dev/null
    echo "✓ Mono version saved to audio-tests/kinect-mono.wav"
else
    echo "⚠️  ffmpeg not installed - skipping mono conversion"
fi

echo ""
echo "=== Next Steps ==="
echo "1. Play the recordings to check audio quality:"
echo "   aplay audio-tests/kinect-mono.wav"
echo ""
echo "2. If volume is too low, try amplifying:"
echo "   ffmpeg -i audio-tests/kinect-raw-4ch.wav -af 'volume=10dB' audio-tests/kinect-amplified.wav"
echo ""
echo "3. For advanced beamforming, consider:"
echo "   • PipeWire's beamforming modules"
echo "   • Custom DSP implementation"
echo "   • Alternative hardware (ReSpeaker, etc.)"
echo ""