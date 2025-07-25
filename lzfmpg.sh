#!/usr/bin/env bash

# Lazy FFmpeg - Main Menu
# Updated with proper module paths and multi-file support

# Check dependencies
if ! command -v gum &> /dev/null; then
    echo "Error: gum not installed. Get it from https://github.com/charmbracelet/gum"
    exit 1
fi

if ! command -v ffmpeg &> /dev/null; then
    echo "Error: ffmpeg not installed"
    exit 1
fi

# Base directory
BASE_DIR=$(dirname "$(readlink -f "$0")")

# Main Menu
function show_menu() {
    clear
    gum style --border double --padding "1 2" --margin "1 2" --border-foreground 212 \
        "LAZY FFMPEG" "The lazy way to media processing"
    
    CHOICE=$(gum choose --height 15 --cursor "> " --header="Select operation type:" \
        "🔊 Audio Operations" \
        "🎬 Video Operations" \
        "🖼️ Image Operations" \
        "⚙️ Utilities" \
        "❌ Exit")
    
    case "$CHOICE" in
        *"Audio"*) audio_menu ;;
        *"Video"*) video_menu ;;
        *"Image"*) image_menu ;;
        *"Utilities"*) utilities_menu ;;
        *"Exit"*) exit 0 ;;
        *) show_menu ;;
    esac
}

# Audio Menu
function audio_menu() {
    CHOICE=$(gum choose --height 15 --cursor "> " --header="Audio Operations:" \
        "🔀 Convert Format" \
        "✂️ Trim Audio" \
        "➕ Merge Files" \
        "⬅️ Back")
    
    case "$CHOICE" in
        *"Convert"*) "$BASE_DIR/modules/audio/convert_audio.sh" ;;
        *"Trim"*) "$BASE_DIR/modules/audio/trim_audio.sh" ;;
        *"Merge"*) "$BASE_DIR/modules/audio/merge_audio.sh" ;;
        *) show_menu ;;
    esac
}

# Video Menu
function video_menu() {
    CHOICE=$(gum choose --height 15 --cursor "> " --header="Video Operations:" \
        "🔀 Convert Format" \
        "✂️ Trim Video" \
        "🖼️ Extract Frames" \
        "🔊 Extract Audio" \
        "⬅️ Back")
    
    case "$CHOICE" in
        *"Convert"*) "$BASE_DIR/modules/video/convert_video.sh" ;;
        *"Trim"*) "$BASE_DIR/modules/video/trim_video.sh" ;;
        *"Frames"*) "$BASE_DIR/modules/video/extract_frames.sh" ;;
        *"Audio"*) "$BASE_DIR/modules/video/extract_audio.sh" ;;
        *"Resize"*) "$BASE_DIR/modules/video/resize_video.sh" ;;
        *) show_menu ;;
    esac
}

# Image Menu
function image_menu() {
    CHOICE=$(gum choose --height 15 --cursor "> " --header="Image Operations:" \
        "🔀 Convert Format" \
        "⬅️ Back")
    
    case "$CHOICE" in
        *"Convert"*) "$BASE_DIR/modules/image/convert_image.sh" ;;

        *) show_menu ;;
    esac
}

# Utilities Menu
function utilities_menu() {
    CHOICE=$(gum choose --height 15 --cursor "> " --header="Utilities:" \
        "ℹ️ Media Info" \
        "⬅️ Back")
    
    case "$CHOICE" in
        *"Clean"*) "$BASE_DIR/modules/utils/clean_temp.sh" ;;
        *"Info"*) "$BASE_DIR/modules/utils/media_info.sh" ;;
        *) show_menu ;;
    esac
}

# Initialize
show_menu
