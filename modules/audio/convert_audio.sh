#!/usr/bin/env bash

# Audio Converter - Fixed counting and warnings

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
SELECTED=$(echo "$AUDIO_FILES" | gum choose --no-limit --header="Select audio files to convert (Enter for current selection):")

# If no selection made but Enter pressed, use the highlighted file
if [[ -z "$SELECTED" ]]; then
    # Get the first file as default selection
    SELECTED=$(echo "$AUDIO_FILES" | head -1)
    if [[ -z "$SELECTED" ]]; then
        echo "No files selected"
        exit 1
    fi
fi

# Let user select output format
FORMAT=$(gum choose --header="Select output format:" "mp3" "flac" "wav" "aac" "ogg" "m4a")

# Function to convert file with appropriate settings
convert_file() {
    local input_file="$1"
    local output_format="$2"
    local output_file="${input_file%.*}.${output_format}"
    
    # Handle existing files
    local counter=1
    local original_output="$output_file"
    while [[ -f "$output_file" ]]; do
        output_file="${original_output%.*}_${counter}.${output_format}"
        ((counter++))
    done
    
    # Build FFmpeg command based on format
    local ffmpeg_cmd="ffmpeg -i \"$input_file\" -y -hide_banner -loglevel error"
    
    case "$output_format" in
        mp3)
            ffmpeg_cmd+=" -c:a libmp3lame -q:a 2"
            ;;
        flac)
            ffmpeg_cmd+=" -c:a flac -compression_level 8"
            ;;
        wav)
            ffmpeg_cmd+=" -c:a pcm_s16le"
            ;;
        aac)
            ffmpeg_cmd+=" -c:a aac -b:a 192k"
            ;;
        ogg)
            ffmpeg_cmd+=" -c:a libvorbis -q:a 6"
            ;;
        m4a)
            ffmpeg_cmd+=" -c:a aac -b:a 192k"
            ;;
    esac
    
    ffmpeg_cmd+=" \"$output_file\""
    
    # Execute conversion
    if eval "$ffmpeg_cmd"; then
        echo "SUCCESS: $(basename "$input_file") → $(basename "$output_file")"
        return 0
    else
        echo "FAIL: $(basename "$input_file")"
        return 1
    fi
}

# Convert all selected files
SUCCESS=0
FAIL=0

echo "Converting files..."

# Process each selected file and count results properly
while IFS= read -r FILE; do
    if [[ -n "$FILE" ]]; then
        if convert_file "$FILE" "$FORMAT"; then
            ((SUCCESS++))
        else
            ((FAIL++))
        fi
    fi
done <<< "$(echo "$SELECTED")"

# Show final summary
echo "Conversion Complete"
echo "✅ Successful: $SUCCESS"
echo "❌ Failed: $FAIL"

# future improvements: add order 