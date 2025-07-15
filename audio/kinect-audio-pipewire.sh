#!/bin/bash
# Test Kinect v2 audio with PipeWire

echo "=== Kinect v2 Audio with PipeWire ==="
echo ""

# Find the Kinect audio node
NODE_NAME=$(pw-cli list-objects | grep -A5 "Xbox NUI Sensor" | grep "node.name" | grep "alsa_input" | cut -d'"' -f2 | head -1)

if [ -z "$NODE_NAME" ]; then
    echo "❌ Kinect audio not found in PipeWire"
    exit 1
fi

echo "✓ Found Kinect audio node: $NODE_NAME"
echo ""

# Create test directory
mkdir -p audio-tests

echo "=== Recording Test ==="
echo "This will record 5 seconds of audio from all 4 Kinect microphones."
echo ""
echo "⚠️  IMPORTANT: The Kinect audio is VERY quiet on Linux!"
echo "Please speak loudly and clearly, close to the Kinect."
echo ""
echo "Press ENTER when ready to start recording..."
read

echo ""
echo "🔴 RECORDING NOW - SPEAK LOUDLY!"
echo "Say something like: 'Testing, testing, one two three, hello Kinect!'"
echo ""

# Record using pw-record
pw-record --target="$NODE_NAME" --rate=16000 --channels=4 --format=s32 audio-tests/kinect-pipewire-4ch.wav &
PW_PID=$!

# Countdown
for i in 5 4 3 2 1; do
    echo -n "$i... "
    sleep 1
done
echo ""

# Stop recording
kill $PW_PID 2>/dev/null

echo "✓ Recording complete"
echo ""

# Check the file
if [ -f "audio-tests/kinect-pipewire-4ch.wav" ]; then
    echo "File details:"
    ls -lh audio-tests/kinect-pipewire-4ch.wav
    file audio-tests/kinect-pipewire-4ch.wav
    
    # Convert to mono for easier playback
    echo ""
    echo "Converting to mono..."
    ffmpeg -i audio-tests/kinect-pipewire-4ch.wav -ac 1 -ar 44100 audio-tests/kinect-mono.wav -y 2>/dev/null
    
    # Amplify the audio (since Kinect is quiet on Linux)
    echo "Creating amplified version (+20dB)..."
    ffmpeg -i audio-tests/kinect-pipewire-4ch.wav -af "volume=20dB" -ac 1 -ar 44100 audio-tests/kinect-amplified.wav -y 2>/dev/null
    
    echo ""
    echo "✓ Created test files:"
    echo "  • audio-tests/kinect-pipewire-4ch.wav (original 4-channel)"
    echo "  • audio-tests/kinect-mono.wav (mono version)"
    echo "  • audio-tests/kinect-amplified.wav (amplified mono)"
    echo ""
    echo "To play back:"
    echo "  pw-play audio-tests/kinect-amplified.wav"
    echo "  # or"
    echo "  aplay audio-tests/kinect-amplified.wav"
else
    echo "❌ Recording failed"
fi

echo ""
echo "=== Channel Information ==="
echo "The 4 channels represent:"
echo "  Channel 1 (FL): Front Left microphone"
echo "  Channel 2 (FR): Front Right microphone"
echo "  Channel 3 (FC): Front Center microphone"
echo "  Channel 4 (LFE): Low Frequency Effects (4th mic)"
echo ""
echo "Note: On Windows, these are processed for beamforming."
echo "On Linux, you get raw unprocessed audio from each mic."