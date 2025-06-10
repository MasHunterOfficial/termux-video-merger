#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display header
header() {
    clear
    echo -e "${GREEN}"
    echo "=============================================="
    echo "          TERMUX ADVANCED VIDEO MERGER        "
    echo "=============================================="
    echo -e "${NC}"
}

# Check if ffmpeg and ffprobe are installed
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

# Function to merge by time order
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

# Merge videos by manual marking
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
        stty -icanon -echo
        dd bs=1 count=1 2>/dev/null
        stty icanon echo
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
        if [[ "$key" == $'\033' ]]; then
            read -rsn2 -t 0.1 tmp
            key+="$tmp"
        fi

        case "$key" in
            $'\033[A') ((current_selection > 0)) && ((current_selection--)) ;;
            $'\033[B') ((current_selection < ${#videos[@]} - 1)) && ((current_selection++)) ;;
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

# Main menu
main_menu() {
    while true; do
        header
        echo -e "${YELLOW}Main Menu${NC}"
        echo "----------"
        echo "1. Auto merge by time"
        echo "2. Merge by marking videos"
        echo "3. Exit"
        echo ""
        read -p "Choose an option (1-3): " choice
        case "$choice" in
            1) merge_by_time ;;
            2) merge_by_marking ;;
            3) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
            *) echo -e "${RED}Invalid option. Try again.${NC}"; sleep 1 ;;
        esac
    done
}

# Start
check_ffmpeg
main_menu
