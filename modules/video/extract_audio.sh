#!/usr/bin/env bash

# Audio Extractor - Fixed for spaces and improved UX

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
VIDEO_FILES=$(find . -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.mov" -o -name "*.avi" -o -name "*.webm" -o -name "*.flv" -o -name "*.wmv" \) -print0 | \
    xargs -0 -I {} basename {} | sort)

# Check if any video files found
if [[ -z "$VIDEO_FILES" ]]; then
    echo "No video files found in current directory"
    exit 1
fi

# Let user select files
SELECTED=$(echo "$VIDEO_FILES" | gum choose --no-limit --header="Select videos to extract audio from (Enter for current selection):")

# If no selection made but Enter pressed, use the highlighted file
if [[ -z "$SELECTED" ]]; then
    # Get the first file as default selection
    SELECTED=$(echo "$VIDEO_FILES" | head -1)
    if [[ -z "$SELECTED" ]]; then
        echo "No files selected"
        exit 1
    fi
fi

# Let user select output format
FORMAT=$(gum choose --header="Select audio output format:" "mp3" "aac" "flac" "wav" "ogg" "m4a")

# Quality settings based on format
case "$FORMAT" in
    mp3)
        QUALITY=$(gum input --placeholder "MP3 quality (VBR 0-9, lower=better)" --value "2")
        [[ ! "$QUALITY" =~ ^[0-9]+$ ]] || [[ "$QUALITY" -lt 0 ]] || [[ "$QUALITY" -gt 9 ]] && QUALITY=2
        ;;
    aac|m4a)
        BITRATE=$(gum input --placeholder "AAC bitrate (kbps, e.g., 192)" --value "192")
        [[ ! "$BITRATE" =~ ^[0-9]+$ ]] || [[ "$BITRATE" -lt 32 ]] && BITRATE=192
        ;;
    flac)
        COMPRESSION=$(gum input --placeholder "FLAC compression (0-8)" --value "5")
        [[ ! "$COMPRESSION" =~ ^[0-9]+$ ]] || [[ "$COMPRESSION" -lt 0 ]] || [[ "$COMPRESSION" -gt 8 ]] && COMPRESSION=5
        ;;
    ogg)
        QUALITY=$(gum input --placeholder "OGG quality (-1 to 10, 5=160kbps)" --value "5")
        [[ ! "$QUALITY" =~ ^-?[0-9]+$ ]] || [[ "$QUALITY" -lt -1 ]] || [[ "$QUALITY" -gt 10 ]] && QUALITY=5
        ;;
    wav)
        echo "WAV format selected (uncompressed audio)"
        ;;
esac

# Output directory option
USE_SUBDIR=$(gum confirm "Create output directory?" && echo "yes" || echo "no")
if [[ "$USE_SUBDIR" == "yes" ]]; then
    OUTPUT_DIR="extracted_audio"
    mkdir -p "$OUTPUT_DIR"
else
    OUTPUT_DIR="."
fi

# Function to extract audio with appropriate settings
extract_audio() {
    local input_file="$1"
    local output_format="$2"
    local output_dir="$3"
    
    local name="${input_file%.*}"
    local output_file="$output_dir/${name}.${output_format}"
    
    # Handle existing files
    local counter=1
    local original_output="$output_file"
    while [[ -f "$output_file" ]]; do
        output_file="$output_dir/${name}_${counter}.${output_format}"
        ((counter++))
    done
    
    # Build FFmpeg command
    local ffmpeg_cmd="ffmpeg -i \"$input_file\" -y -hide_banner -loglevel error"
    
    # Add audio extraction options
    ffmpeg_cmd+=" -vn"  # Disable video
    
    # Add format-specific options
    case "$output_format" in
        mp3)
            ffmpeg_cmd+=" -c:a libmp3lame -q:a $QUALITY"
            ;;
        aac|m4a)
            ffmpeg_cmd+=" -c:a aac -b:a ${BITRATE}k"
            ;;
        flac)
            ffmpeg_cmd+=" -c:a flac -compression_level $COMPRESSION"
            ;;
        wav)
            ffmpeg_cmd+=" -c:a pcm_s16le"
            ;;
        ogg)
            ffmpeg_cmd+=" -c:a libvorbis -q:a $QUALITY"
            ;;
    esac
    
    ffmpeg_cmd+=" \"$output_file\""
    
    # Execute extraction
    if eval "$ffmpeg_cmd"; then
        echo "✅ $(basename "$input_file") → $(basename "$output_file")"
        return 0
    else
        echo "❌ Failed: $(basename "$input_file")"
        return 1
    fi
}

# Extract audio from all selected files
SUCCESS=0
FAIL=0

echo "Extracting audio..."

# Process each selected file
while IFS= read -r FILE; do
    if [[ -n "$FILE" ]]; then
        if extract_audio "$FILE" "$FORMAT" "$OUTPUT_DIR"; then
            ((SUCCESS++))
        else
            ((FAIL++))
        fi
    fi
done <<< "$(echo "$SELECTED")"

# Show final summary
echo "Audio Extraction Complete"
echo "✅ Successful: $SUCCESS"
echo "❌ Failed: $FAIL"

if [[ "$USE_SUBDIR" == "yes" ]]; then
    echo "Output directory: $OUTPUT_DIR/"
fi