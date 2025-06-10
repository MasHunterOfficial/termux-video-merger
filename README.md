
# 🎥 Termux Advanced Video Merger

**Termux Advanced Video Merger** is a powerful and interactive command-line tool for Android (Termux) that allows you to easily merge multiple video files. It provides two flexible merging modes — automatic sorting by time and manual selection by marking videos in your desired order.

---

## ✨ Features

- ✅ **Auto Merge by Time**
  - Automatically detects and sorts video files based on their creation or modification time.
  - Merges them in chronological order using `ffmpeg`.

- ✅ **Manual Merge by Marking**
  - Navigate through available video files with arrow keys.
  - Mark videos in custom order with real-time terminal UI.
  - Perfect for selective merging.

- ✅ **Interactive Terminal UI**
  - Minimal and clean navigation with arrow keys and live feedback.
  
- ✅ **FFmpeg Integration**
  - Uses `ffmpeg` for high-speed, lossless merging.
  - Automatically installs `ffmpeg` if not found.

- ✅ **Smart Video Detection**
  - Supports various formats: `.mp4`, `.mkv`, `.mov`, `.avi`, `.flv`
  - Sorts files using metadata or file timestamps.

---

## 🚀 Installation

Make sure you have **Termux** installed and updated:

```bash
pkg update && pkg upgrade
pkg install git
git clone https://github.com/mashunteroffical/termux-video-merger.git
cd termux-video-merger
chmod +x video-merger.sh
````

---

## 🧠 Usage

Run the tool using:

```bash
./video-merger.sh
```

Then follow the on-screen instructions.

---

## 📜 How to Use

### Option 1: Auto Merge by Time

1. Select **Option 1** from the menu.
2. The tool will:

   * Scan your current folder.
   * Sort all video files by creation/modification time.
   * Merge them into one file named `merged_output.mp4`.

### Option 2: Merge by Marking Videos

1. Select **Option 2** from the menu.
2. Navigate the video list using:

   * 🔼 `UP Arrow`: Move up
   * 🔽 `DOWN Arrow`: Move down
   * ⬜ `SPACE`: Mark or unmark a file
   * ⏎ `ENTER`: Start merging
3. Mark files in the order you want them merged.
4. The merged output will be named with a timestamp, e.g., `merged_20250610_152400.mp4`.

---

## 🛠 Requirements

* **Termux**
* **FFmpeg** (installed automatically if not present)
* Some supported video files in your current directory.

---

## 🧾 License

This tool is open-source and free to use. Modify or distribute it as you like.

---

## ❤️ Credits

Developed by [Your Name](https://github.com/MasHunterOdficial)
Inspired by the need to merge videos efficiently on mobile terminals.

---

## 📷 Screenshot

```
