#!/usr/bin/env bash

# Video Converter - Fixed for spaces and improved UX

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
VIDEO_FILES=$(find . -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.mov" -o -name "*.avi" -o -name "*.webm" -o -name "*.flv" -o -name "*.wmv" -o -name "*.gif" \) -print0 | \
    xargs -0 -I {} basename {} | sort)

# Check if any video files found
if [[ -z "$VIDEO_FILES" ]]; then
    echo "No video files found in current directory"
    exit 1
fi

# Let user select files
SELECTED=$(echo "$VIDEO_FILES" | gum choose --no-limit --header="Select videos to convert (Enter for current selection):")

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
FORMAT=$(gum choose --header="Select output format:" "mp4" "mkv" "mov" "webm" "gif")

# Quality settings based on format
case "$FORMAT" in
    mp4|mov)
        QUALITY=$(gum choose --header "Quality preset:" "Fast (larger file)" "Medium" "Slow (smaller file)")
        case "$QUALITY" in
            "Fast (larger file)") PRESET="ultrafast" ;;
            "Medium") PRESET="medium" ;;
            "Slow (smaller file)") PRESET="slow" ;;
        esac
        ;;
    mkv)
        QUALITY=$(gum input --placeholder "Video bitrate (kbps, e.g., 2000)" --value "2000")
        [[ ! "$QUALITY" =~ ^[0-9]+$ ]] || [[ "$QUALITY" -lt 100 ]] && QUALITY=2000
        ;;
    webm)
        QUALITY=$(gum input --placeholder "Video quality (0-63, lower=better)" --value "23")
        [[ ! "$QUALITY" =~ ^[0-9]+$ ]] || [[ "$QUALITY" -lt 0 ]] || [[ "$QUALITY" -gt 63 ]] && QUALITY=23
        ;;
    gif)
        FPS=$(gum input --placeholder "FPS for GIF (e.g., 10)" --value "10")
        [[ ! "$FPS" =~ ^[0-9]+$ ]] || [[ "$FPS" -lt 1 ]] && FPS=10
        SCALE=$(gum input --placeholder "Scale (width, e.g., 480)" --value "480")
        ;;
esac

# Output directory option
USE_SUBDIR=$(gum confirm "Create output directory?" && echo "yes" || echo "no")
if [[ "$USE_SUBDIR" == "yes" ]]; then
    OUTPUT_DIR="converted_${FORMAT}"
    mkdir -p "$OUTPUT_DIR"
else
    OUTPUT_DIR="."
fi

# Function to convert file with appropriate settings
convert_file() {
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
    
    # Add format-specific options
    case "$output_format" in
        mp4|mov)
            ffmpeg_cmd+=" -c:v libx264 -preset $PRESET -crf 23 -c:a aac -b:a 128k"
            [[ "$output_format" == "mov" ]] && ffmpeg_cmd+=" -pix_fmt yuv420p"
            ;;
        mkv)
            ffmpeg_cmd+=" -c:v libx264 -b:v ${QUALITY}k -c:a aac -b:a 128k"
            ;;
        webm)
            ffmpeg_cmd+=" -c:v libvpx-vp9 -crf $QUALITY -b:v 0 -c:a libopus"
            ;;
        gif)
            ffmpeg_cmd+=" -vf \"fps=$FPS,scale=$SCALE:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse\" -loop 0"
            ;;
    esac
    
    ffmpeg_cmd+=" \"$output_file\""
    
    # Execute conversion
    if eval "$ffmpeg_cmd"; then
        echo "✅ $(basename "$input_file") → $(basename "$output_file")"
        return 0
    else
        echo "❌ Failed: $(basename "$input_file")"
        return 1
    fi
}

# Convert all selected files
SUCCESS=0
FAIL=0

echo "Converting videos..."

# Process each selected file
while IFS= read -r FILE; do
    if [[ -n "$FILE" ]]; then
        if convert_file "$FILE" "$FORMAT" "$OUTPUT_DIR"; then
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

if [[ "$USE_SUBDIR" == "yes" ]]; then
    echo "Output directory: $OUTPUT_DIR/"
fi