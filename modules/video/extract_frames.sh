#!/usr/bin/env bash

# Video Frame Extractor - Fixed for spaces and improved UX

# Check dependencies
if ! command -v gum &> /dev/null; then
    echo "Error: gum not installed. Get it from https://github.com/charmbracelet/gum"
    exit 1
fi

if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg not installed"
    exit 1
fi

# Find video files
VIDEO_FILES=$(find . -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.mov" -o -name "*.avi" -o -name "*.webm" -o -name "*.flv" \) -print0 | \
    xargs -0 -I {} basename {} | sort)

# Check if any video files found
if [[ -z "$VIDEO_FILES" ]]; then
    echo "No video files found in current directory"
    exit 1
fi

# Let user select file
SELECTED=$(echo "$VIDEO_FILES" | gum choose --header="Select video file to extract frames from:")

# Check if user selected a file
if [[ -z "$SELECTED" ]]; then
    echo "No file selected"
    exit 1
fi

# Extraction method selection
METHOD=$(gum choose --header "Extraction method:" \
    "Single frame (first frame)" \
    "Multiple frames (every N seconds)" \
    "Multiple frames (total count)" \
    "Specific timestamp")

# Create output directory
OUTPUT_DIR="frames_${SELECTED%.*}"
mkdir -p "$OUTPUT_DIR"

# Build FFmpeg command based on method
FFMPEG_CMD="ffmpeg -i \"$SELECTED\" -y -hide_banner -loglevel error"

case "$METHOD" in
    "Single frame (first frame)")
        FFMPEG_CMD+=" -vf \"select=eq(n\\,0)\" -vframes 1"
        OUTPUT_PATTERN="$OUTPUT_DIR/${SELECTED%.*}_frame_%03d.jpg"
        ;;
        
    "Multiple frames (every N seconds)")
        INTERVAL=$(gum input --placeholder "Extract frame every N seconds (e.g., 5)" --value "5")
        [[ ! "$INTERVAL" =~ ^[0-9]+$ ]] || [[ "$INTERVAL" -lt 1 ]] && INTERVAL=5
        FFMPEG_CMD+=" -vf \"fps=1/$INTERVAL\""
        OUTPUT_PATTERN="$OUTPUT_DIR/${SELECTED%.*}_frame_%05d.jpg"
        ;;
        
    "Multiple frames (total count)")
        COUNT=$(gum input --placeholder "Total number of frames to extract (e.g., 10)" --value "10")
        [[ ! "$COUNT" =~ ^[0-9]+$ ]] || [[ "$COUNT" -lt 1 ]] && COUNT=10
        FFMPEG_CMD+=" -vframes $COUNT"
        OUTPUT_PATTERN="$OUTPUT_DIR/${SELECTED%.*}_frame_%05d.jpg"
        ;;
        
    "Specific timestamp")
        TIMESTAMP=$(gum input --placeholder "Timestamp (HH:MM:SS or seconds, e.g., 00:01:30 or 90)" --value "00:00:01")
        [[ -z "$TIMESTAMP" ]] && TIMESTAMP="00:00:01"
        FFMPEG_CMD+=" -ss $TIMESTAMP -vframes 1"
        OUTPUT_PATTERN="$OUTPUT_DIR/${SELECTED%.*}_frame_${TIMESTAMP//:/-}.jpg"
        ;;
esac

# Image format and quality options
FORMAT=$(gum choose --header "Output format:" "jpg" "png" "webp")
case "$FORMAT" in
    jpg)
        QUALITY=$(gum input --placeholder "JPEG quality (1-100)" --value "90")
        [[ ! "$QUALITY" =~ ^[0-9]+$ ]] || [[ "$QUALITY" -lt 1 ]] || [[ "$QUALITY" -gt 100 ]] && QUALITY=90
        FFMPEG_CMD+=" -q:v $QUALITY"
        OUTPUT_PATTERN="${OUTPUT_PATTERN%.*}.$FORMAT"
        ;;
    png)
        COMPRESSION=$(gum input --placeholder "PNG compression (0-9)" --value "6")
        [[ ! "$COMPRESSION" =~ ^[0-9]+$ ]] || [[ "$COMPRESSION" -lt 0 ]] || [[ "$COMPRESSION" -gt 9 ]] && COMPRESSION=6
        FFMPEG_CMD+=" -compression_level $COMPRESSION"
        OUTPUT_PATTERN="${OUTPUT_PATTERN%.*}.$FORMAT"
        ;;
    webp)
        QUALITY=$(gum input --placeholder "WebP quality (1-100)" --value "90")
        [[ ! "$QUALITY" =~ ^[0-9]+$ ]] || [[ "$QUALITY" -lt 1 ]] || [[ "$QUALITY" -gt 100 ]] && QUALITY=90
        FFMPEG_CMD+=" -q:v $QUALITY"
        OUTPUT_PATTERN="${OUTPUT_PATTERN%.*}.$FORMAT"
        ;;
esac

FFMPEG_CMD+=" \"$OUTPUT_PATTERN\""

# Show extraction details
echo "Extracting frames from: $SELECTED"
echo "Method: $METHOD"
echo "Output format: $FORMAT"
echo "Output directory: $OUTPUT_DIR/"

# Confirm extraction
if gum confirm "Proceed with frame extraction?"; then
    echo "Extracting frames..."
    if eval "$FFMPEG_CMD"; then
        FRAME_COUNT=$(find "$OUTPUT_DIR" -name "$(basename "${OUTPUT_PATTERN%.*}").*" | wc -l)
        echo "✅ Frame extraction successful: $FRAME_COUNT frames saved in ./$OUTPUT_DIR/"
    else
        echo "❌ Frame extraction failed"
    fi
else
    echo "Frame extraction cancelled"
    rm -rf "$OUTPUT_DIR" 2>/dev/null
    exit 0
fi