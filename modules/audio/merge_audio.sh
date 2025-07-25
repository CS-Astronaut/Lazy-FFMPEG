#!/usr/bin/env bash

# Audio Merger - Fixed file path handling

# Check dependencies
if ! command -v gum &> /dev/null; then
    echo "Error: gum not installed. Get it from https://github.com/charmbracelet/gum"
    exit 1
fi

if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg not installed"
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

# Let user select files
SELECTED=$(echo "$AUDIO_FILES" | gum choose --no-limit --header="Select audio files to merge (Enter for current selection):")

# If no selection made but Enter pressed, use the highlighted file
if [[ -z "$SELECTED" ]]; then
    echo "Need at least 2 files to merge"
    exit 1
fi

# Count selected files
FILE_COUNT=$(echo "$SELECTED" | grep -v '^$' | wc -l | tr -d ' ')
if [[ $FILE_COUNT -lt 2 ]]; then
    echo "Need at least 2 files to merge"
    exit 1
fi

# Let user specify output filename
DEFAULT_NAME="merged_output.mp3"
OUTPUT_NAME=$(gum input --placeholder="Output filename" --value="$DEFAULT_NAME")

# Use default if empty
if [[ -z "$OUTPUT_NAME" ]]; then
    OUTPUT_NAME="$DEFAULT_NAME"
fi

# Create temp list file with absolute paths
TEMP_LIST=$(mktemp)
echo "ffconcat version 1.0" > "$TEMP_LIST"

# Add files to concat list with absolute paths
while IFS= read -r FILE; do
    if [[ -n "$FILE" ]]; then
        # Use absolute paths to avoid path issues
        ABS_PATH="$(pwd)/$FILE"
        # Escape single quotes in filenames
        ESCAPED_PATH="${ABS_PATH//\'/\'\\\'\'}"
        printf "file '%s'\n" "$ESCAPED_PATH" >> "$TEMP_LIST"
    fi
done <<< "$(echo "$SELECTED")"

# Determine output format based on filename
OUTPUT_FORMAT="${OUTPUT_NAME##*.}"
if [[ -z "$OUTPUT_FORMAT" ]] || [[ "$OUTPUT_FORMAT" == "$OUTPUT_NAME" ]]; then
    OUTPUT_FORMAT="mp3"
    OUTPUT_NAME="${OUTPUT_NAME%.*}.mp3"
fi

# Build FFmpeg command
FFMPEG_CMD="ffmpeg -f concat -safe 0 -i \"$TEMP_LIST\" -y -hide_banner -loglevel error"

# Add appropriate codec based on output format
case "${OUTPUT_FORMAT,,}" in
    mp3)
        FFMPEG_CMD+=" -c:a libmp3lame -q:a 2"
        ;;
    flac)
        FFMPEG_CMD+=" -c:a flac"
        ;;
    wav)
        FFMPEG_CMD+=" -c:a pcm_s16le"
        ;;
    aac|m4a)
        FFMPEG_CMD+=" -c:a aac -b:a 192k"
        ;;
    ogg)
        FFMPEG_CMD+=" -c:a libvorbis -q:a 6"
        ;;
    *)
        FFMPEG_CMD+=" -c:a libmp3lame -q:a 2"
        OUTPUT_NAME="${OUTPUT_NAME%.*}.mp3"
        ;;
esac

FFMPEG_CMD+=" \"$OUTPUT_NAME\""

# Execute merge
echo "Merging $FILE_COUNT files..."
if eval "$FFMPEG_CMD"; then
    echo "✅ Merge successful: $OUTPUT_NAME"
    echo "Files merged:"
    echo "$SELECTED" | sed 's/^/  • /'
else
    echo "❌ Merge failed"
fi

# Cleanup
rm -f "$TEMP_LIST"