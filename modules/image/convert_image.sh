#!/usr/bin/env bash

# Image Converter - Fixed for spaces and improved UX

# Check dependencies
if ! command -v gum &> /dev/null; then
    echo "Error: gum not installed. Get it from https://github.com/charmbracelet/gum"
    exit 1
fi

if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg not installed"
    exit 1
fi

# Find image files
IMAGE_FILES=$(find . -maxdepth 1 -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.webp" -o -name "*.bmp" -o -name "*.tiff" -o -name "*.gif" \) -print0 | \
    xargs -0 -I {} basename {} | sort)

# Check if any image files found
if [[ -z "$IMAGE_FILES" ]]; then
    echo "No image files found in current directory"
    exit 1
fi

# Let user select files
SELECTED=$(echo "$IMAGE_FILES" | gum choose --no-limit --header="Select images to convert (Enter for current selection):")

# If no selection made but Enter pressed, use the highlighted file
if [[ -z "$SELECTED" ]]; then
    # Get the first file as default selection
    SELECTED=$(echo "$IMAGE_FILES" | head -1)
    if [[ -z "$SELECTED" ]]; then
        echo "No files selected"
        exit 1
    fi
fi

# Let user select output format
FORMAT=$(gum choose --header="Select output format:" "jpg" "png" "webp" "bmp" "tiff")

# Quality settings for different formats
case "$FORMAT" in
    jpg|jpeg)
        QUALITY=$(gum input --placeholder="JPEG quality (1-100)" --value="90")
        [[ ! "$QUALITY" =~ ^[0-9]+$ ]] || [[ "$QUALITY" -lt 1 ]] || [[ "$QUALITY" -gt 100 ]] && QUALITY=90
        ;;
    webp)
        QUALITY=$(gum input --placeholder="WebP quality (1-100)" --value="90")
        [[ ! "$QUALITY" =~ ^[0-9]+$ ]] || [[ "$QUALITY" -lt 1 ]] || [[ "$QUALITY" -gt 100 ]] && QUALITY=90
        ;;
    png)
        COMPRESSION=$(gum input --placeholder="PNG compression (0-9)" --value="6")
        [[ ! "$COMPRESSION" =~ ^[0-9]+$ ]] || [[ "$COMPRESSION" -lt 0 ]] || [[ "$COMPRESSION" -gt 9 ]] && COMPRESSION=6
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
        jpg|jpeg)
            ffmpeg_cmd+=" -q:v $QUALITY"
            ;;
        webp)
            ffmpeg_cmd+=" -q:v $QUALITY"
            ;;
        png)
            ffmpeg_cmd+=" -compression_level $COMPRESSION"
            ;;
        bmp)
            ffmpeg_cmd+=" -c:v bmp"
            ;;
        tiff)
            ffmpeg_cmd+=" -c:v tiff"
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

echo "Converting images..."

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