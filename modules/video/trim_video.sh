#!/usr/bin/env bash

# Video Trimmer - Fixed for spaces and improved UX

# Check dependencies
if ! command -v gum &> /dev/null; then
    echo "Error: gum not installed. Get it from https://github.com/charmbracelet/gum"
    exit 1
fi

if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg not installed"
    exit 1
fi

if ! command -v ffprobe &> /dev/null; then
    echo "Error: ffprobe not installed (usually comes with ffmpeg)"
    exit 1
fi

# Find video files
VIDEO_FILES=$(find . -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.mov" -o -name "*.avi" -o -name "*.webm" -o -name "*.flv" -o -name "*.wmv" \) -print0 | \
    xargs -0 -I {} basename {} | sort)

# Check if any video files found
if [[ -z "$VIDEO_FILES" ]]; then
    echo "No video files found in current directory"
    exit 1
fi

# Let user select file
SELECTED_FILE=$(echo "$VIDEO_FILES" | gum choose --header="Select video file to trim:")

# Check if user selected a file
if [[ -z "$SELECTED_FILE" ]]; then
    echo "No file selected"
    exit 1
fi

# Check if file has video streams
VIDEO_STREAMS=$(ffprobe -v error -show_entries stream=codec_type -of default=nw=1 "$SELECTED_FILE" 2>/dev/null | grep -c "video")

if [[ "$VIDEO_STREAMS" -eq 0 ]]; then
    echo "No video streams detected in $SELECTED_FILE"
    echo "This file may be corrupted or use unsupported codecs"
    exit 1
fi

# Get file duration using ffprobe
DURATION=$(ffprobe -v error -show_entries format=duration -of default=nw=1 "$SELECTED_FILE" 2>/dev/null | head -1)

if [[ -z "$DURATION" ]]; then
    echo "Could not determine file duration"
    exit 1
fi

FORMATTED_DURATION=$(printf "%02d:%02d:%02d" $(( ${DURATION%.*} / 3600 )) $(( (${DURATION%.*} / 60) % 60 )) $(( ${DURATION%.*} % 60 )))

echo "File: $SELECTED_FILE"
echo "Duration: $FORMATTED_DURATION ($DURATION seconds)"
echo "Video streams detected: $VIDEO_STREAMS"

# Get start time
START_TIME=$(gum input --placeholder="Start time (HH:MM:SS or seconds)" --value="00:00:00")

# Validate start time
if [[ -z "$START_TIME" ]]; then
    START_TIME="00:00:00"
fi

# Get end time
END_TIME=$(gum input --placeholder="End time (HH:MM:SS or seconds, or press Enter for end)" --value="$FORMATTED_DURATION")

# If end time is empty, use full duration
if [[ -z "$END_TIME" ]]; then
    END_TIME="$FORMATTED_DURATION"
fi

# Let user specify output filename
DEFAULT_NAME="${SELECTED_FILE%.*}_trimmed${SELECTED_FILE##*.}"
OUTPUT_NAME=$(gum input --placeholder="Output filename" --value="$DEFAULT_NAME")

# Use default if empty
if [[ -z "$OUTPUT_NAME" ]]; then
    OUTPUT_NAME="$DEFAULT_NAME"
fi

# Trim mode selection with better descriptions
TRIM_MODE=$(gum choose --header "Trim mode:" \
    "Fast copy (quick, may not align perfectly with timestamps)" \
    "Smart re-encode (slower, precise timing, smaller file)" \
    "Lossless re-encode (very slow, exact copy)")

# Build FFmpeg command
FFMPEG_CMD="ffmpeg -i \"$SELECTED_FILE\""

# Position of -ss matters for different modes
if [[ "$TRIM_MODE" == "Fast copy (quick, may not align perfectly with timestamps)" ]]; then
    # For fast copy, put -ss before -i for input seeking
    FFMPEG_CMD="ffmpeg -ss $START_TIME -i \"$SELECTED_FILE\""
else
    # For re-encoding, put -ss after -i for precise seeking
    FFMPEG_CMD="ffmpeg -i \"$SELECTED_FILE\" -ss $START_TIME"
fi

# Add end time if specified and not the full duration
if [[ "$END_TIME" != "$FORMATTED_DURATION" ]]; then
    FFMPEG_CMD+=" -to $END_TIME"
fi

FFMPEG_CMD+=" -y -hide_banner -loglevel error"

# Add mode-specific options
case "$TRIM_MODE" in
    "Fast copy (quick, may not align perfectly with timestamps)")
        FFMPEG_CMD+=" -c copy"
        ;;
    "Smart re-encode (slower, precise timing, smaller file)")
        FFMPEG_CMD+=" -c:v libx264 -preset medium -crf 23 -c:a aac -b:a 128k"
        ;;
    "Lossless re-encode (very slow, exact copy)")
        FFMPEG_CMD+=" -c:v libx264 -preset ultrafast -crf 0 -c:a copy"
        ;;
esac

FFMPEG_CMD+=" \"$OUTPUT_NAME\""

# Show trim details
echo "Trimming: $SELECTED_FILE"
echo "From: $START_TIME"
echo "To: $END_TIME"
echo "Mode: $(echo "$TRIM_MODE" | cut -d'(' -f1)"
echo "Output: $OUTPUT_NAME"

# Confirm trim
if gum confirm "Proceed with trim?"; then
    echo "Trimming video..."
    if eval "$FFMPEG_CMD"; then
        if [[ -f "$OUTPUT_NAME" ]] && [[ -s "$OUTPUT_NAME" ]]; then
            echo "✅ Trim successful: $OUTPUT_NAME"
        else
            echo "❌ Trim failed: Output file not created or is empty"
        fi
    else
        echo "❌ Trim failed: FFmpeg error occurred"
    fi
else
    echo "Trim cancelled"
    exit 0
fi