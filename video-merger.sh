#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'


#check root permission 
check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo -e "\n⚠️ This option requires root permission!"
    echo "Please run this tool as root (su)."
    exit 1
  fi
}

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
smart_audio_mix() {
    echo -e "\e[33m🎬 Scanning current folder for video and audio files...\e[0m"

    files=($(ls *.mp4 *.mkv *.avi *.mov *.flv *.mp3 *.aac *.m4a *.wav *.opus 2>/dev/null | sort))
    if [ ${#files[@]} -eq 0 ]; then
        echo -e "\e[31m❌ No supported media files found in current directory!\e[0m"
        read -p "Press Enter to return..."
        return
    fi

    declare -A marked_files
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
        clear
        echo -e "\e[33m🎯 Select one video and one audio file (arrow keys, space to mark, enter to finish)\e[0m"
        for i in "${!files[@]}"; do
            marker=" "
            [ "$i" -eq "$current_selection" ] && marker=">"
            if [ -n "${marked_files[$i]}" ]; then
                echo -e "$marker $(($i+1)). ${files[$i]} ✅ [${marked_files[$i]}]"
            else
                echo -e "$marker $(($i+1)). ${files[$i]}"
            fi
        done
        echo -e "\n\e[34m↑/↓ to navigate  |  Space: Mark/Unmark  |  Enter: Confirm\e[0m"

        key=$(read_char)
        case "$key" in
            $'\e[A') ((current_selection > 0)) && ((current_selection--)) ;;
            $'\e[B') ((current_selection < ${#files[@]} - 1)) && ((current_selection++)) ;;
            " ")
                if [ -n "${marked_files[$current_selection]}" ]; then
                    unset marked_files[$current_selection]
                else
                    count=${#marked_files[@]}
                    if [ $count -lt 2 ]; then
                        next=$((count + 1))
                        marked_files[$current_selection]=$next
                    fi
                fi ;;
            "")
                if [ ${#marked_files[@]} -ne 2 ]; then
                    echo -e "\e[31m❌ Please mark exactly 2 files (1 video and 1 audio).\e[0m"
                    sleep 1
                else
                    break
                fi ;;
        esac
    done

    sorted_keys=$(for k in "${!marked_files[@]}"; do echo "${marked_files[$k]} $k"; done | sort -n | cut -d' ' -f2)
    marked_list=()
    for idx in $sorted_keys; do
        marked_list+=("${files[$idx]}")
    done

    VIDEO=""
    AUDIO=""

    for file in "${marked_list[@]}"; do
        case "$file" in
            *.mp4|*.mkv|*.avi|*.mov|*.flv) VIDEO="$file" ;;
            *.mp3|*.aac|*.m4a|*.wav|*.opus) AUDIO="$file" ;;
        esac
    done

    if [ -z "$VIDEO" ] || [ -z "$AUDIO" ]; then
        echo -e "\e[31m❌ Invalid selection. One video and one audio file must be selected.\e[0m"
        read -p "Press Enter to return..."
        return
    fi

    echo -e "🎥 Video File: \e[32m$VIDEO\e[0m"
    echo -e "🎧 Audio File: \e[32m$AUDIO\e[0m"

    V_DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO")
    A_DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$AUDIO")

    V_DURATION=${V_DURATION%.*}
    A_DURATION=${A_DURATION%.*}

    if [[ "$A_DURATION" -ge "$V_DURATION" ]]; then
        echo -e "\e[31m❌ Audio is longer than or equal to video. Please use shorter audio.\e[0m"
        return
    fi

    echo -e "\n🎙️ Enter gap duration (in seconds) between voiceover loops:"
    read -r GAP_SECONDS
    [[ -z "$GAP_SECONDS" ]] && GAP_SECONDS=1

    echo -e "\n🔊 Select volume level for original video audio during voiceover:"
    echo -e "\e[34m  - Mute Volume:   0.0\n  - Low Volume:    0.1\n  - Medium Volume: 0.3\n  - High Volume:   0.7\e[0m"
    echo -e "Enter volume (0.0 - 1.0):"
    read -r VIDEO_VOL_DURING_VOICEOVER
    [[ -z "$VIDEO_VOL_DURING_VOICEOVER" ]] && VIDEO_VOL_DURING_VOICEOVER="0.3"

    mkdir -p temp_mix
    cd temp_mix || return

    ffmpeg -i "../$VIDEO" -vn -acodec pcm_s16le original.wav -y

    TOTAL_SEGMENTS=$((V_DURATION / (A_DURATION + GAP_SECONDS)))
    REMAINDER=$((V_DURATION % (A_DURATION + GAP_SECONDS)))

    > segments.txt
    for ((i=0; i<TOTAL_SEGMENTS; i++)); do
        START=$((i * (A_DURATION + GAP_SECONDS)))
        END=$((START + A_DURATION))

        ffmpeg -i original.wav -ss "$START" -t "$A_DURATION" -y part_low_$i.wav
        ffmpeg -i part_low_$i.wav -filter:a "volume=$VIDEO_VOL_DURING_VOICEOVER" -y part_low_vol_$i.wav
        echo "file '$(pwd)/part_low_vol_$i.wav'" >> segments.txt

        GAP_START=$((END))
        ffmpeg -i original.wav -ss "$GAP_START" -t "$GAP_SECONDS" -y part_gap_$i.wav
        echo "file '$(pwd)/part_gap_$i.wav'" >> segments.txt
    done

    if [ "$REMAINDER" -gt 0 ]; then
        LAST_START=$((TOTAL_SEGMENTS * (A_DURATION + GAP_SECONDS)))
        ffmpeg -i original.wav -ss "$LAST_START" -t "$REMAINDER" -y part_tail.wav
        echo "file '$(pwd)/part_tail.wav'" >> segments.txt
    fi

    ffmpeg -f concat -safe 0 -i segments.txt -c copy final_base.wav -y

    > voice_inputs.txt
    INPUT_ARGS="-i final_base.wav"
    FILTERS=""
    MAPS="[0:a]"
    for ((i=0; i<TOTAL_SEGMENTS; i++)); do
        DELAY_MS=$((i * (A_DURATION + GAP_SECONDS) * 1000))
        cp "../$AUDIO" voice_$i.${AUDIO##*.}
        INPUT_ARGS+=" -i voice_$i.${AUDIO##*.}"
        FILTERS+="[$((i+1))]adelay=${DELAY_MS}|${DELAY_MS}[a$i];"
        MAPS+="[a$i]"
    done

    FILTER_COMPLEX="$FILTERS$MAPS amix=inputs=$((TOTAL_SEGMENTS + 1)):duration=longest[mixout]"
    ffmpeg $INPUT_ARGS -filter_complex "$FILTER_COMPLEX" -map "[mixout]" -y mixed_audio.wav

    ffmpeg -i "../$VIDEO" -i mixed_audio.wav -map 0:v -map 1:a -c:v copy -c:a aac -shortest "../output_smart_mix.mp4" -y

    cd ..
    rm -rf temp_mix

    echo -e "\e[32m✅ Done! File saved as: output_smart_mix.mp4\e[0m"
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

# Compress Video 
# Enhanced Video Compression Tool with Interactive Selection and Final Options
compress_video() {
    # Requirements Check
    for cmd in ffmpeg jq; do
        if ! command -v $cmd &> /dev/null; then
            echo "Error: $cmd is not installed. Install it with 'pkg install $cmd'"
            return
        fi
    done

    # Video Extensions
    EXT=("mp4" "mkv" "avi" "webm" "flv")
    videos=()
    for ext in "${EXT[@]}"; do
        while IFS= read -r -d $'\0' f; do
            videos+=("$f")
        done < <(find . -maxdepth 1 -type f -iname "*.$ext" -print0)
    done

    total_videos=${#videos[@]}
    if [[ $total_videos -eq 0 ]]; then
        echo -e "\e[31m❌ No video files found in current directory!\e[0m"
        read -p "Press Enter to return..."
        return
    fi

    # If only one video
    if [[ $total_videos -eq 1 ]]; then
        selected=("${videos[0]}")
    else
        declare -A marked
        selection=0

        read_char() {
            IFS= read -rsn1 key
            if [[ $key == $'\x1b' ]]; then
                read -rsn2 -t 0.01 rest
                key+="$rest"
            fi
            echo "$key"
        }

        while true; do
            clear
            echo -e "\e[33m📼 Select video(s) to compress (Space to mark, Enter to confirm)\e[0m"
            for i in "${!videos[@]}"; do
                marker="  "
                [[ $i -eq $selection ]] && marker="> "
                if [[ -n ${marked[$i]} ]]; then
                    echo -e "$marker$((i+1))) ${videos[$i]} ✅"
                else
                    echo -e "$marker$((i+1))) ${videos[$i]}"
                fi
            done
            echo -e "\n[Press 'a' to select all, 'Enter' to continue]"

            key=$(read_char)
            case "$key" in
                $'\e[A') ((selection > 0)) && ((selection--)) ;;
                $'\e[B') ((selection < total_videos - 1)) && ((selection++)) ;;
                " ")
                    if [[ -n ${marked[$selection]} ]]; then
                        unset marked[$selection]
                    else
                        marked[$selection]=1
                    fi ;;
                "a")
                    for i in "${!videos[@]}"; do
                        marked[$i]=1
                    done ;;
                "")
                    if [[ ${#marked[@]} -eq 0 ]]; then
                        echo "Please select at least one video."
                        sleep 1
                    else
                        break
                    fi ;;
            esac
        done

        sorted=($(for k in "${!marked[@]}"; do echo "$k"; done | sort -n))
        selected=()
        for idx in "${sorted[@]}"; do
            selected+=("${videos[$idx]}")
        done
    fi

    echo -e "\n\e[36m🌀 Starting compression of ${#selected[@]} video(s)...\e[0m\n"
    mkdir -p compressed_temp

    for file in "${selected[@]}"; do
        name=$(basename -- "$file")
        out="compressed_temp/$name"
        orig=$(du -m "$file" | cut -f1)

        echo -e "🔧 Compressing: $name"
        ffmpeg -i "$file" -vcodec libx264 -crf 26 -preset slow -acodec aac -b:a 128k -y -loglevel error "$out"

        new=$(du -m "$out" | cut -f1)
        saved=$((orig - new))

        echo -e "✅ Done: $name"
        echo -e "   Original size : ${orig}MB"
        echo -e "   Compressed size: ${new}MB"
        echo -e "   Saved: ${saved}MB\n"
    done

    # Ask to move
    while true; do
        echo -ne "📂 Move compressed videos to /sdcard/DCIM/Compressed? (y/n): "
        read -r move_reply
        case $move_reply in
            y|Y)
                target="/sdcard/DCIM/Compressed"
                idx=1
                while [[ -d "$target" ]]; do
                    [[ $idx -eq 1 ]] && target="/sdcard/DCIM/Compressed_1" || target="/sdcard/DCIM/Compressed_$idx"
                    ((idx++))
                done
                mkdir -p "$target"
                mv compressed_temp/* "$target/"
                rmdir compressed_temp
                echo -e "✅ Videos moved to: $target"

                echo -ne "🗑️ Delete original uncompressed files? (y/n): "
                read -r del_reply
                if [[ $del_reply == "y" || $del_reply == "Y" ]]; then
                    for file in "${selected[@]}"; do
                        rm -f "$file"
                    done
                    echo "✅ Original files deleted."
                else
                    echo "ℹ️ Original files kept."
                fi
                break ;;
            n|N)
                echo "ℹ️ Compressed videos are in: ./compressed_temp"
                break ;;
            *) echo "Invalid input. Enter y or n." ;;
        esac
    done

    read -p "Press Enter to return..."
}

# Low Quality Video Compressor with Audio Preservation
compress_low_quality() {
    for cmd in ffmpeg; do
        if ! command -v $cmd &> /dev/null; then
            echo "Error: $cmd is not installed. Install it with 'pkg install $cmd'"
            return
        fi
    done

    echo -e "${YELLOW}📼 Compress (Low Quality, Keep Audio)${NC}"
    videos=($(ls *.mp4 *.mkv *.avi *.mov *.flv 2>/dev/null | sort))
    
    if [ ${#videos[@]} -eq 0 ]; then
        echo -e "${RED}No video files found in the current directory!${NC}"
        read -p "Press Enter to return..."
        return
    fi

    if [ ${#videos[@]} -eq 1 ]; then
        selected_videos=("${videos[0]}")
    else
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
            clear
            echo -e "${YELLOW}📼 Select video(s) to compress (Space to mark, Enter to confirm)${NC}"
            for i in "${!videos[@]}"; do
                marker=" "
                [ "$i" -eq "$current_selection" ] && marker=">"
                if [ -n "${marked_videos[$i]}" ]; then
                    echo "$marker $(($i+1))) ${videos[$i]} ✅"
                else
                    echo "$marker $(($i+1))) ${videos[$i]}"
                fi
            done
            echo -e "\n[Press 'a' to select all, 'Enter' to continue]"

            key=$(read_char)
            case "$key" in
                $'\e[A') ((current_selection > 0)) && ((current_selection--)) ;;
                $'\e[B') ((current_selection < ${#videos[@]} - 1)) && ((current_selection++)) ;;
                " ")
                    if [ -n "${marked_videos[$current_selection]}" ]; then
                        unset marked_videos[$current_selection]
                    else
                        marked_videos[$current_selection]=1
                    fi ;;
                a|A)
                    for i in "${!videos[@]}"; do marked_videos[$i]=1; done ;;
                "")
                    if [ ${#marked_videos[@]} -eq 0 ]; then
                        echo -e "${RED}Please select at least one video.${NC}"
                        sleep 1
                    else
                        break
                    fi ;;
            esac
        done

        selected_videos=()
        for i in "${!marked_videos[@]}"; do
            selected_videos+=("${videos[$i]}")
        done
    fi

    OUTPUT_DIR="compressed_low_quality"
    mkdir -p "$OUTPUT_DIR"

    echo -e "\n🌀 Starting compression of ${#selected_videos[@]} video(s)..."
    for file in "${selected_videos[@]}"; do
        echo -e "\n🔧 Compressing: $file"
        orig_size=$(du -m "$file" | cut -f1)
        start=$(date +%s)

        output_file="$OUTPUT_DIR/low_${file}"
        ffmpeg -i "$file" -vf "scale=160:120" -r 10 -crf 51 -preset ultrafast -c:a copy -c:v libx264 -b:v 50k -y "$output_file" -loglevel error

        end=$(date +%s)
        new_size=$(du -m "$output_file" | cut -f1)
        saved=$((orig_size - new_size))
        elapsed=$((end - start))
        mins=$((elapsed / 60))
        secs=$((elapsed % 60))

        echo "✅ Done: $file"
        echo "    Original size : ${orig_size}MB"
        echo "    Compressed size: ${new_size}MB"
        echo "    Saved space   : ${saved}MB"
        echo "    Time taken    : ${mins} min ${secs} sec"
    done

    read -p $'\n📂 Move compressed videos to /sdcard/DCIM/Compressed? (y/n): ' move_choice
    if [[ "$move_choice" =~ ^[Yy]$ ]]; then
        DEST="/sdcard/DCIM/Compressed"
        suffix=""
        while [ -d "$DEST$suffix" ]; do
            suffix=$((suffix+1))
        done
        DEST="$DEST$suffix"
        mkdir -p "$DEST"
        mv "$OUTPUT_DIR"/* "$DEST/"
        echo "📁 Moved videos to: $DEST"
        rmdir "$OUTPUT_DIR"

        read -p "🗑️  Delete original files? (y/n): " del_orig
        if [[ "$del_orig" =~ ^[Yy]$ ]]; then
            for file in "${selected_videos[@]}"; do
                rm -f "$file"
            done
            echo "🧹 Original files deleted."
        fi
    else
        read -p "🗑️  Do you still want to delete the original files? (y/n): " del_orig
        if [[ "$del_orig" =~ ^[Yy]$ ]]; then
            for file in "${selected_videos[@]}"; do
                rm -f "$file"
            done
            echo "🧹 Original files deleted."
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
        echo "5. Video Compression Tool"
        echo "6. Compress (Low Quality, Keep Audio)"
        echo "7. Exit"
        echo ""
        read -p "Choose an option (1-7): " choice
        case "$choice" in
            1) check_root
               merge_by_time 
               ;;
            2) check_root
               merge_by_marking 
               ;;
            3) smart_audio_mix ;;
            4) volume_booster ;;
            5) compress_video ;;
            6) compress_low_quality ;;   # 🔥 This is the newly added function
            7) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option. Try again.${NC}"; sleep 1 ;;
        esac
    done
}

# Start the tool
check_ffmpeg
main_menu
