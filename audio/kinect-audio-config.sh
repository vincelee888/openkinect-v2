#!/bin/bash
# Configure Kinect v2 audio for optimal use on Linux

echo "=== Kinect v2 Audio Configuration ==="
echo ""

# Find the Kinect audio node
NODE_NAME=$(pw-cli list-objects | grep -A5 "Xbox NUI Sensor" | grep "node.name" | grep "alsa_input" | cut -d'"' -f2 | head -1)

if [ -z "$NODE_NAME" ]; then
    echo "❌ Kinect audio not found in PipeWire"
    exit 1
fi

echo "✓ Found Kinect audio: $NODE_NAME"
echo ""

# Create PipeWire configuration for Kinect
CONFIG_DIR="$HOME/.config/pipewire/pipewire.conf.d"
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/50-kinect-audio.conf" << EOF
# Kinect v2 Audio Configuration
# Optimizes the Xbox NUI Sensor microphone array for Linux

context.modules = [
    {   name = libpipewire-module-filter-chain
        args = {
            node.name = "kinect_audio_processor"
            node.description = "Kinect Audio Processor"
            filter.graph = {
                nodes = [
                    {
                        name = "mixer"
                        type = "builtin"
                        label = "mixer"
                        control = {
                            "Mix 1" = 0.25  # Front Left
                            "Mix 2" = 0.25  # Front Right
                            "Mix 3" = 0.35  # Front Center (boost center mic)
                            "Mix 4" = 0.15  # LFE/4th mic
                        }
                    }
                    {
                        name = "amp"
                        type = "builtin"
                        label = "amp"
                        control = {
                            "Gain" = 20.0  # +20dB amplification
                        }
                    }
                ]
                links = [
                    { output = "mixer:Out" input = "amp:In" }
                ]
                inputs = [ "mixer:In 1" "mixer:In 2" "mixer:In 3" "mixer:In 4" ]
                outputs = [ "amp:Out" ]
            }
            capture.props = {
                node.passive = true
                media.class = "Audio/Source"
                audio.channels = 4
                audio.position = [ FL FR FC LFE ]
            }
            playback.props = {
                media.class = "Audio/Source"
                audio.channels = 1
                node.name = "kinect_audio_processed"
                node.description = "Kinect Processed Audio (Amplified)"
            }
        }
    }
]

# Boost the raw Kinect input volume
pulse.properties = {
    pulse.default.volume = 0.9  # 90% volume
}
EOF

echo "✓ Created PipeWire configuration"
echo ""

echo "=== Creating Helper Scripts ==="

# Create a simple recording script
cat > kinect-record.sh << 'EOF'
#!/bin/bash
# Record from Kinect microphone array

DURATION=${1:-10}
OUTPUT=${2:-"kinect-recording.wav"}

echo "Recording $DURATION seconds from Kinect..."
echo "Speak loudly and clearly!"
echo ""

NODE=$(pw-cli list-objects | grep -A5 "Xbox NUI Sensor" | grep "node.name" | grep "alsa_input" | cut -d'"' -f2 | head -1)

if [ -z "$NODE" ]; then
    echo "Error: Kinect audio not found"
    exit 1
fi

pw-record --target="$NODE" --rate=16000 --channels=4 --format=s32 "$OUTPUT" &
PID=$!

for i in $(seq $DURATION -1 1); do
    echo -ne "\r$i seconds remaining... "
    sleep 1
done
echo -e "\nDone!"

kill $PID 2>/dev/null

# Auto-amplify
echo "Creating amplified version..."
ffmpeg -i "$OUTPUT" -af "volume=20dB" -ac 1 "${OUTPUT%.wav}-amplified.wav" -y 2>/dev/null
echo "Saved to: ${OUTPUT%.wav}-amplified.wav"
EOF

chmod +x kinect-record.sh

# Create a monitoring script
cat > kinect-audio-monitor.sh << 'EOF'
#!/bin/bash
# Monitor Kinect audio levels in real-time

NODE=$(pw-cli list-objects | grep -A5 "Xbox NUI Sensor" | grep "node.name" | grep "alsa_input" | cut -d'"' -f2 | head -1)

if [ -z "$NODE" ]; then
    echo "Error: Kinect audio not found"
    exit 1
fi

echo "Monitoring Kinect audio levels..."
echo "Speak into the Kinect to see levels. Press Ctrl+C to stop."
echo ""

# Use pw-mon to monitor the levels
pw-cat --record --target="$NODE" --rate=16000 --channels=4 --format=s32 - | \
    ffmpeg -f s32le -ar 16000 -ac 4 -i - -filter_complex \
    "[0:a]showvolume=f=0.5:c=gradient:v=0:dm=2:dmc=orange:o=v:s=640x40[v0];\
     [0:a]asplit=4[a0][a1][a2][a3];\
     [a0]showvolume=f=0.5:c=gradient:v=0:dm=2:dmc=red:o=v:s=640x40[v1];\
     [a1]showvolume=f=0.5:c=gradient:v=0:dm=2:dmc=green:o=v:s=640x40[v2];\
     [a2]showvolume=f=0.5:c=gradient:v=0:dm=2:dmc=blue:o=v:s=640x40[v3];\
     [a3]showvolume=f=0.5:c=gradient:v=0:dm=2:dmc=yellow:o=v:s=640x40[v4];\
     [v1][v2][v3][v4]vstack=4" \
    -f sdl2 -window_title "Kinect Audio Levels (FL=Red FR=Green FC=Blue LFE=Yellow)" -
EOF

chmod +x kinect-audio-monitor.sh

echo "✓ Created helper scripts:"
echo "  • kinect-record.sh [duration] [output.wav] - Record audio"
echo "  • kinect-audio-monitor.sh - Monitor levels in real-time"
echo ""

echo "=== Final Setup Steps ==="
echo ""
echo "1. Restart PipeWire to load new configuration:"
echo "   systemctl --user restart pipewire pipewire-pulse"
echo ""
echo "2. Test recording:"
echo "   ./kinect-record.sh 5 test.wav"
echo ""
echo "3. In applications (Zoom, etc.), look for:"
echo "   • 'Xbox NUI Sensor' (raw 4-channel)"
echo "   • 'Kinect Processed Audio' (if config loaded)"
echo ""
echo "Note: Even with amplification, Kinect audio on Linux is"
echo "significantly quieter than on Windows due to missing DSP."