# Lazy-FFMPEG

FFMPEG for Lazy People ^ ^

<p align="center">
	<img src="assets/logo.png" width=320/>
</p>


## Why Lazy-FFMPEG does Exist?

FFmpeg is an all-in-one tool for multimedia manipulation. But the deeper I dove into it, the more frustrated I became with its endless command options 😴 and honestly, I’m too lazy to memorize them all or lookup for them! So I decided to develop this command-line tool using Bash and gum to create a TUI, designed for lazy people like me who still want to harness the power of this incredibly useful project called FFmpeg.


## Let's Use it!
Install Dependencies:

```bash
# Install gum for TUI
go install github.com/charmbracelet/gum@latest
#or
brew install gum
```

```bash
# Install FFmpeg for Processings
sudo apt update && sudo apt install ffmpeg
```

Give Execution Permission:
```bash
chmod +x modules/*/*.sh
```

Run:
```bash
./lazy_ffmpeg.sh
```


## Project Structure:
```
lazy_ffmpeg/
├── lazy_ffmpeg.sh          # Main menu script
└── modules/
    ├── audio/              # Audio processing scripts
    │   ├── convert_audio.sh
    │   ├── trim_audio.sh
    │   └── merge_audio.sh
    ├── video/              # Video processing scripts
    │   ├── convert_video.sh
    │   ├── trim_video.sh
    │   ├── extract_frames.sh
    │   └── extract_audio.sh
    ├── image/              # Image processing scripts
    │   └── convert_image.sh
    └── utils/              # Utility scripts
        └── media_info.sh
```


Made with ❤️ for lazy people everywhere, because they’re the real geniuses.