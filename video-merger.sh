#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Header
header() {
    clear
    echo -e "${GREEN}"
    echo "=============================================="
    echo "          TERMUX ADVANCED VIDEO MERGER        "
    echo "=============================================="
    echo -e "${NC}"
}

# Check FFmpeg
check_ffmpeg() {
    if ! command -v ffmpeg >/dev/null || ! command -v ffprobe >/dev/null; then
        echo -e "${RED}FFmpeg or ffprobe is not installed.${NC}"
        read -p "Install FFmpeg now? (y/n): " confirm
        if [[ "$confirm" == "y" ]]; then
            pkg install ffmpeg -y
        else
            echo -e "${RED}This tool cannot work without FFmpeg. Exiting...${NC}"
            exit 1
        fi
    fi
}

# Merge by time
merge_by_time() {
    local VIDEO_DIR="."
    local OUTPUT_FILE="merged_output_$(date +%Y%m%d_%H%M%S).mp4"
    local TMP_LIST="merge_list.txt"
    > "$TMP_LIST"

    echo -e "${BLUE}🔍 Scanning for video files in: $VIDEO_DIR${NC}"
    find "$VIDEO_DIR" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" -o -iname "*.avi" -o -iname "*.flv" \) | while read -r file; do
        ctime=$(ffprobe -v quiet -show_entries format_tags=creation_time -of default=nw=1:nk=1 "$file" 2>/dev/null)
        if [ -z "$ctime" ]; then
            ctime=$(stat -c %Y "$file")
        else
            ctime=$(date -d "$ctime" +%s 2>/dev/null)
        fi
        echo "$ctime|$file"
    done | sort -n | cut -d'|' -f2 | while read -r sorted_file; do
        echo "file '$sorted_file'" >> "$TMP_LIST"
    done

    echo -e "${YELLOW}🧩 Merging sorted files...${NC}"
    ffmpeg -f concat -safe 0 -i "$TMP_LIST" -c copy "$OUTPUT_FILE" && \
    echo -e "${GREEN}✅ Merge complete! File saved as: $OUTPUT_FILE${NC}"
    rm -f "$TMP_LIST"
    read -p "Press Enter to continue..."
}

# Merge by marking
merge_by_marking() {
    echo -e "${YELLOW}🎯 Merge by Marking Videos${NC}"
    videos=($(ls *.mp4 *.mkv *.avi *.mov *.flv 2>/dev/null | sort))
    if [ ${#videos[@]} -eq 0 ]; then
        echo -e "${RED}No video files found in current directory!${NC}"
        read -p "Press Enter to return..."
        return
    fi

    declare -A marked_videos
    current_selection=0

    read_char() {
        IFS= read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 -t 0.01 rest
            key+="$rest"
        fi
        echo "$key"
    }

    while true; do
        header
        echo -e "${YELLOW}Mark videos for merging (arrow keys, space to mark, enter to finish)${NC}"
        for i in "${!videos[@]}"; do
            marker=" "
            [ "$i" -eq "$current_selection" ] && marker=">"
            if [ -n "${marked_videos[$i]}" ]; then
                echo -e "$marker $(($i+1)). ${videos[$i]} ✅ [${marked_videos[$i]}]"
            else
                echo -e "$marker $(($i+1)). ${videos[$i]}"
            fi
        done
        echo -e "\n${BLUE}↑/↓ to navigate  |  Space: Mark/Unmark  |  Enter: Confirm${NC}"

        key=$(read_char)
        case "$key" in
            $'\e[A') ((current_selection > 0)) && ((current_selection--)) ;;
            $'\e[B') ((current_selection < ${#videos[@]} - 1)) && ((current_selection++)) ;;
            " ")
                if [ -n "${marked_videos[$current_selection]}" ]; then
                    unset marked_videos[$current_selection]
                else
                    next=1
                    while printf '%s\n' "${marked_videos[@]}" | grep -qx "$next"; do ((next++)); done
                    marked_videos[$current_selection]=$next
                fi ;;
            "") 
                if [ ${#marked_videos[@]} -eq 0 ]; then
                    echo -e "${RED}Please mark at least one video.${NC}"
                    sleep 1
                else
                    break
                fi ;;
        esac
    done

    sorted_keys=$(for k in "${!marked_videos[@]}"; do echo "${marked_videos[$k]} $k"; done | sort -n | cut -d' ' -f2)
    > concat_list.txt
    for idx in $sorted_keys; do
        echo "file '${videos[$idx]}'" >> concat_list.txt
        echo -e "${GREEN}+ ${videos[$idx]} (Position: ${marked_videos[$idx]})${NC}"
    done

    output_file="merged_manual_$(date +%Y%m%d_%H%M%S).mp4"
    echo -e "${YELLOW}🔧 Merging selected files...${NC}"
    ffmpeg -f concat -safe 0 -i concat_list.txt -c copy "$output_file"
    rm -f concat_list.txt

    echo -e "${GREEN}✅ Merged file saved as: $output_file${NC}"
    read -p "Press Enter to continue..."
}

# Audio mix into video
audio_mix_video() {
    if ! command -v ffmpeg &> /dev/null; then
        echo -e "${RED}[ERROR] FFmpeg is not installed. Run: pkg install ffmpeg${NC}"
        exit 1
    fi

    VIDEO_EXTS=("mp4" "mov" "mkv")
    AUDIO_EXTS=("mp3" "aac" "ogg" "opus" "m4a" "wav")
    video_files=()
    audio_files=()

    for ext in "${VIDEO_EXTS[@]}"; do
        for file in *."$ext"; do
            [ -e "$file" ] && video_files+=("$file")
        done
    done

    for ext in "${AUDIO_EXTS[@]}"; do
        for file in *."$ext"; do
            [ -e "$file" ] && audio_files+=("$file")
        done
    done

    if [ "${#video_files[@]}" -ne 1 ] || [ "${#audio_files[@]}" -ne 1 ]; then
        echo -e "${RED}[ERROR] Only one video and one audio file should exist in the folder.${NC}"
        read -p "Press Enter to return..."
        return
    fi

    VIDEO="${video_files[0]}"
    AUDIO="${audio_files[0]}"
    OUTPUT="output_final.mp4"

    echo -e "${YELLOW}Enter gap duration (in seconds) between overlays:${NC}"
    read -r GAP_SECONDS

    VIDEO_DURATION=$(ffprobe -v error -show_entries format=duration -of default=nokey=1:noprint_wrappers=1 "$VIDEO")
    AUDIO_DURATION=$(ffprobe -v error -show_entries format=duration -of default=nokey=1:noprint_wrappers=1 "$AUDIO")

    VIDEO_SECONDS=${VIDEO_DURATION%.*}
    AUDIO_SECONDS=${AUDIO_DURATION%.*}

    if [ "$AUDIO_SECONDS" -ge "$VIDEO_SECONDS" ]; then
        echo -e "${RED}[ERROR] Audio is longer than or equal to video.${NC}"
        read -p "Press Enter to return..."
        return
    fi

    mkdir -p temp_audio_layers
    rm -f temp_audio_layers/*

    ffmpeg -i "$VIDEO" -q:a 0 -map a temp_audio_layers/original.wav -y

    INDEX=0
    DELAY_MS=0
    INPUTS="-i temp_audio_layers/original.wav"
    FILTERS=""
    MAPS="[0:a]"

    while [ "$((DELAY_MS / 1000 + AUDIO_SECONDS))" -le "$VIDEO_SECONDS" ]; do
        cp "$AUDIO" "temp_audio_layers/audio$INDEX.${AUDIO##*.}"
        INPUTS="$INPUTS -i temp_audio_layers/audio$INDEX.${AUDIO##*.}"
        FILTERS="${FILTERS}[$((INDEX+1))]adelay=${DELAY_MS}|${DELAY_MS}[a$INDEX];"
        MAPS="${MAPS}[a$INDEX]"
        INDEX=$((INDEX + 1))
        DELAY_MS=$((INDEX * (AUDIO_SECONDS + GAP_SECONDS) * 1000))
    done

    FILTER_COMPLEX="${FILTERS}${MAPS}amix=inputs=$((INDEX+1)):duration=longest[mixout]"
    ffmpeg $INPUTS -filter_complex "$FILTER_COMPLEX" -map "[mixout]" -y temp_audio_layers/final.wav
    ffmpeg -i "$VIDEO" -i temp_audio_layers/final.wav -c:v copy -map 0:v:0 -map 1:a:0 -y "$OUTPUT"
    rm -rf temp_audio_layers

    echo -e "${GREEN}[✅ DONE] Final output saved to $OUTPUT${NC}"
    read -p "Press Enter to continue..."
}

#volume booster 
volume_booster() { 

EXTENSIONS=("mp3" "aac" "opus" "wav" "m4a")

# Find audio files
FILES=()
for ext in "${EXTENSIONS[@]}"; do
  while IFS= read -r -d $'\0' file; do
    FILES+=("$file")
  done < <(find . -maxdepth 1 -iname "*.$ext" -print0)
done

COUNT=${#FILES[@]}

if [ "$COUNT" -eq 0 ]; then
  echo "No audio files found in the current directory."
  exit 1
elif [ "$COUNT" -eq 1 ]; then
  FILE="${FILES[0]}"
  echo "Found one audio file: $FILE"
  read -p "How much do you want to increase the volume (1.0 - 5.0)? " VOLUME
  if [[ "$VOLUME" =~ ^[1-5](\.[0-9]+)?$ ]]; then
    OUT="${FILE%.*}_loud.${FILE##*.}"
    ffmpeg -i "$FILE" -filter:a "volume=$VOLUME" "$OUT"
    echo "Volume increased. Output file: $OUT"
  else
    echo "Invalid volume value. Must be between 1.0 and 5.0"
  fi
else
  echo "Multiple audio files found:"
  for i in "${!FILES[@]}"; do
    printf "%2d. %s\n" "$((i+1))" "${FILES[$i]}"
  done

  read -p "Enter the numbers of the files you want to boost (e.g. 1 3 5): " -a CHOICES
  read -p "How much do you want to increase the volume (1.0 - 5.0)? " VOLUME

  if [[ "$VOLUME" =~ ^[1-5](\.[0-9]+)?$ ]]; then
    for index in "${CHOICES[@]}"; do
      real_index=$((index-1))
      FILE="${FILES[$real_index]}"
      OUT="${FILE%.*}_loud.${FILE##*.}"
      ffmpeg -i "$FILE" -filter:a "volume=$VOLUME" "$OUT"
      echo "Volume increased for: $FILE --> $OUT"
    done
  else
    echo "Invalid volume value. Must be between 1.0 and 5.0"
  fi
fi

}
# Main Menu
main_menu() {
    while true; do
        header
        echo -e "${YELLOW}Main Menu${NC}"
        echo "----------"
        echo "1. Auto merge by time"
        echo "2. Merge by marking videos"
        echo "3. Audio Mix in Video"
        echo "4. Volume Booster"
        echo "5. Exit"
        echo ""
        read -p "Choose an option (1-5): " choice
        case "$choice" in
            1) merge_by_time ;;
            2) merge_by_marking ;;
            3) audio_mix_video ;;
            4) volume_booster ;;
            5) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option. Try again.${NC}"; sleep 1 ;;
        esac
    done
}

# Start
check_ffmpeg
main_menu
