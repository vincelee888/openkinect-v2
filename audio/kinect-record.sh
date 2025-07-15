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
