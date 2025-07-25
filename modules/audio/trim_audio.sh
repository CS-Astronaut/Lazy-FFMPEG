#!/usr/bin/env bash

# Audio Trimmer - Fixed for spaces and improved UX

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

# Find audio files
AUDIO_FILES=$(find . -maxdepth 1 -type f \( -name "*.mp3" -o -name "*.wav" -o -name "*.flac" -o -name "*.aac" -o -name "*.ogg" -o -name "*.m4a" -o -name "*.wma" \) -print0 | \
    xargs -0 -I {} basename {} | sort)

# Check if any audio files found
if [[ -z "$AUDIO_FILES" ]]; then
    echo "No audio files found in current directory"
    exit 1
fi

# Let user select file to trim
SELECTED_FILE=$(echo "$AUDIO_FILES" | gum choose --header="Select audio file to trim:")

# Check if user selected a file
if [[ -z "$SELECTED_FILE" ]]; then
    echo "No file selected"
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
echo "Duration: $FORMATTED_DURATION "

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
DEFAULT_NAME="${SELECTED_FILE%.*}_trimmed.${SELECTED_FILE##*.}"
OUTPUT_NAME=$(gum input --placeholder="Output filename" --value="$DEFAULT_NAME")

# Use default if empty
if [[ -z "$OUTPUT_NAME" ]]; then
    OUTPUT_NAME="$DEFAULT_NAME"
fi

# Build FFmpeg command
FFMPEG_CMD="ffmpeg -i \"$SELECTED_FILE\" -ss $START_TIME"

# Add end time if specified and not the full duration
if [[ "$END_TIME" != "$FORMATTED_DURATION" ]]; then
    FFMPEG_CMD+=" -to $END_TIME"
fi

FFMPEG_CMD+=" -y -hide_banner -loglevel error -c copy \"$OUTPUT_NAME\""

# Show trim details
echo "Trimming: $SELECTED_FILE"
echo "From: $START_TIME"
echo "To: $END_TIME"
echo "Output: $OUTPUT_NAME"

# Confirm trim
if gum confirm "Proceed with trim?"; then
    echo "Trimming audio..."
    if eval "$FFMPEG_CMD"; then
        echo "✅ Trim successful: $OUTPUT_NAME"
    else
        echo "❌ Trim failed"
    fi
else
    echo "Trim cancelled"
    exit 0
fi