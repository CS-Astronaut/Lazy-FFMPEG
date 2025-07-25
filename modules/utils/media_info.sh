#!/usr/bin/env bash

# Media Information Viewer - Fixed for spaces and improved UX

# Check dependencies
if ! command -v gum &> /dev/null; then
    echo "Error: gum not installed. Get it from https://github.com/charmbracelet/gum"
    exit 1
fi

if ! command -v ffprobe &> /dev/null; then
    echo "Error: ffprobe not installed (usually comes with ffmpeg)"
    exit 1
fi

# Find media files
MEDIA_FILES=$(find . -maxdepth 1 -type f \( \
    -name "*.mp4" -o -name "*.mkv" -o -name "*.mov" -o -name "*.avi" -o -name "*.webm" -o -name "*.flv" -o -name "*.wmv" -o \
    -name "*.mp3" -o -name "*.wav" -o -name "*.flac" -o -name "*.aac" -o -name "*.ogg" -o -name "*.m4a" -o -name "*.wma" -o \
    -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.gif" -o -name "*.webp" -o -name "*.bmp" \
    \) -print0 | xargs -0 -I {} basename {} | sort)

# Check if any media files found
if [[ -z "$MEDIA_FILES" ]]; then
    echo "No media files found in current directory"
    exit 1
fi

# Let user select file
SELECTED_FILE=$(echo "$MEDIA_FILES" | gum choose --header="Select media file to analyze:")

# Check if user selected a file
if [[ -z "$SELECTED_FILE" ]]; then
    echo "No file selected"
    exit 1
fi

# Information detail level
DETAIL_LEVEL=$(gum choose --header "Information detail level:" \
    "Basic (format and streams summary)" \
    "Detailed (full format and streams info)" \
    "Everything (all available metadata)")

# Build ffprobe command based on detail level
FFPROBE_CMD="ffprobe -v error"

case "$DETAIL_LEVEL" in
    "Basic (format and streams summary)")
        FFPROBE_CMD+=" -show_entries format=filename,duration,size,bit_rate,format_name -show_entries stream=codec_name,codec_type,width,height,r_frame_rate,sample_rate,channels"
        FFPROBE_CMD+=" -of compact=p=0:nk=1"
        ;;
    "Detailed (full format and streams info)")
        FFPROBE_CMD+=" -show_format -show_streams"
        FFPROBE_CMD+=" -of ini"
        ;;
    "Everything (all available metadata)")
        FFPROBE_CMD+=" -show_format -show_streams -show_chapters -show_programs -show_private_data"
        FFPROBE_CMD+=" -print_format json"
        ;;
esac

FFPROBE_CMD+=" \"$SELECTED_FILE\""

# Show file info
echo "Analyzing: $SELECTED_FILE"
echo "Detail level: $(echo "$DETAIL_LEVEL" | cut -d'(' -f1)"
echo "---"

# Execute ffprobe and display results
if eval "$FFPROBE_CMD" | gum pager; then
    echo "✅ Analysis complete"
else
    echo "❌ Analysis failed"
fi