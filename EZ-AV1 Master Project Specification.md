# **Master Project Specification: AV1 Batch Optimizer (Av1an Engine)**

## **1. Project Overview & Architecture**

**Goal:** Develop a native Windows desktop application (called: EZ-AV1) that automates and optimizes batch video encoding to the AV1 codec within an MKV container. The application acts as a high-level visual orchestrator for the **Av1an** encoding framework. It features a "Two-Phase Visual Picker" to help users isolate texture (denoising) from bitrate efficiency (VMAF) before committing to massive batch encodes.

**Tech Stack & Rationale:**

* **Frontend / GUI:** Flutter (Dart) for native Windows UI, hierarchical state management, and hardware-accelerated media playback.
* **Video Player Backend:** `mpv` (via Flutter wrapper like `media_kit`). Chosen specifically for its ability to natively play VapourSynth (`.vpy`) scripts in real-time and toggle AV1 grain metadata on the fly via command flags.
* **Backend Orchestrator:** Av1an (CLI). The Flutter app spawns child processes to run Av1an, passing constructed command-line arguments.
* **Underlying Dependencies:** SVT-AV1 (encoder), VapourSynth + KNLMeansCL (GPU Denoising), FFmpeg (Audio/Demuxing), and PySceneDetect.

---

## **2. The Core Video Pipeline (Av1an Automation)**

The backend relies entirely on Av1an to abstract the complexities of modern AV1 encoding. The app generates commands for Av1an, which natively handles:

* **Scene-Aware Chunking:** Scans the file, splits it cleanly at scene changes using PySceneDetect, and processes chunks in parallel to maximize CPU thread utilization without visual cutting artifacts.
* **Target Quality (Dynamic CRF):** Utilizes Av1an's `--target-quality` flag to probe video chunks. It dynamically adjusts the bitrate frame-by-frame to guarantee the exact VMAF quality score requested by the user, maximizing space savings.
* **Native Crash Recovery:** Tracks progress chunk-by-chunk. If the app closes or crashes, re-running the exact same Av1an command resumes the encode instantly from the last finished chunk.
* **Metadata & Track Passthrough:** Automatically copies all subtitle tracks, audio streams, and original MKV metadata flags directly to the output container.

---

## **3. The Two-Phase "Visual Picker" UX/UI**

To prevent "Variable Overload," the visual testing suite strictly isolates texture management from bitrate compression. The UI guides the user through two distinct steps.

### **Smart Bypass (The Clean Digital Profile)**

* Before Phase 1, the user selects the source type: **[Film / Grainy Source]** or **[Clean Digital / Animation]**.
* If "Clean Digital" is selected, Phase 1 is bypassed entirely, Denoise is set to 0, and Av1an's `--photon-noise` is set to 0. The user proceeds directly to Phase 2 to pick their VMAF target.

### **Phase 1: Texture Lock (Zero-Encode VapourSynth Denoising)**

* **Objective:** Find the maximum grain removal threshold before underlying fine textures (like skin pores or fabric) look unnatural or "waxy."
* **Technical Mechanics (Zero-Latency Preview):** SVT-AV1's internal denoiser requires a physical video encode to see results. To bypass this waiting time, the app uses VapourSynth (`KNLMeansCL`). The GUI generates a temporary `.vpy` script. The `mpv` video player backend plays this script natively. This provides a real-time, pre-AV1-compression preview directly from the source file using the user's GPU.
* **UI:** A Side-by-Side view comparing the uncompressed source video to the live VapourSynth-denoised feed, complete with a synchronized magnifier tool. Adjusting the "Denoise Strength" slider updates the script's `h` parameter, updating the video instantly.

### **Phase 2: Bitrate Efficiency & Grain Synthesis (Post-Encode)**

* **Objective:** Find the lowest acceptable VMAF threshold (highest space savings) using synthetic grain as a perceptual mask to hide compression artifacts.
* **Mechanics (Predictive Inversion):** The app takes the locked Denoise strength from Phase 1 and mathematically calculates a baseline Synthetic Grain level (e.g., if Denoise is Heavy, calculate `--photon-noise 5`).
* **UI (The Quad-Split View):** The backend uses Av1an to generate four physical 5-second encoded `.mkv` files. **All 4 quadrants use the exact same calculated photon noise level**, but test varying VMAF targets (e.g., VMAF 90, 93, 95, 97).
* **Playback Sync Controller:** The GUI must implement a master-slave playback controller to ensure all 4 `mpv` instances in the Quad-Split view remain perfectly frame-synced during playback and seeking.
* **The "Smart Reveal" Guardrail Toggle:** A UI toggle that temporarily forces the video player (`--vd-lavc-film-grain=no`) to hide the synthetic grain. This allows the user to peek at the raw AV1 compression artifacts underneath. To prevent users from making bad bitrate decisions based on the unmasked video, this toggle **auto-resets to ON (Grain Visible)** the moment the user clicks a new setting or navigates away.

---

## **4. Dynamic Audio Optimization**

Audio compression defaults to `libopus` for maximum transparency-to-size ratio.

* **Automated Source Detection:** Upon file import, the backend silently runs `ffprobe -v error -show_entries stream=channels -of json` to detect the exact audio channel count (Mono, Stereo, 5.1, 7.1) and populates the UI state.
* **Dynamic 4-Step Target Slider:** Based on the channel count, the UI presents a semantic 4-step slider. The underlying bitrates adapt automatically per standard Opus guidelines:
* **Mono (1.0):** Space Saver (24k) | Transparent (48k) | Audiophile (64k) | Archival (96k)
* **Stereo (2.0):** Space Saver (64k) | Transparent (96k) | Audiophile (128k) | Archival (192k)
* **5.1 Surround:** Space Saver (192k) | Transparent (256k) | Audiophile (384k) | Archival (512k)
* **7.1 Surround:** Space Saver (256k) | Transparent (384k) | Audiophile (512k) | Archival (768k)


* **Downmix Toggle:** A "Downmix to Stereo" toggle automatically injects `-ac 2` into the audio pipeline and snaps the UI slider to the Stereo (2.0) bitrate tier to prevent data waste.

---

## **5. Deep Hierarchical Batch Queue & State Management**

Designed for massive TV series workflows, utilizing a strict parent-child recursive inheritance model.

* **Recursive Directory Parsing:** Importing a master folder (e.g., `Show > Season > Episodes`) recursively parses the entire underlying directory structure (N-levels deep). The UI displays this as a nested, collapsible tree view.
* **Recursive Cascade & Override:** * **Cascade:** Assigning a Preset to a parent folder instantly and recursively cascades to all nested sub-folders and files, color-mapping the rows to match the preset's UI theme.
* **Override:** Assigning a Preset to a specific child file or sub-folder safely overrides the parent inheritance for that node and its children only.
* **Mixed State Bubble-Up:** If a folder contains mixed presets due to user overrides, a "Mixed State" visual badge must bubble up to all parent folders above it, ensuring the user is warned at the highest level.


* **Shareable Presets:** All Phase 1, Phase 2, and Audio settings are saved as holistic, named Presets. These must be exportable as structured JSON files for community sharing.
* **Output Directory Mirroring:** When "Convert Batch" is pressed, the user selects a target destination folder. The app must automatically recreate the exact internal folder hierarchy of the source files inside the new destination folder before routing Av1an's output paths.
* **Sequential Execution:** The batch manager walks the tree top-to-bottom, passing commands to Av1an sequentially one file at a time. Because Av1an inherently chunks files and processes those chunks concurrently, sequential file execution is the optimal default to prevent system RAM overflow while maxing out CPU thread usage.

---

## **6. Packaging & Deployment Strategy**

Because this app relies on heavy CLI tools that are difficult for casual users to install manually, the architecture must support bundled dependencies.

* **Portable Binaries:** The compiled Windows application must rely on an `assets/bin/` directory containing portable, pre-compiled Windows binaries for:
    * `ffmpeg.exe` and `ffprobe.exe`
    * `av1an.exe`
    * `SvtAv1EncApp.exe` (SVT-AV1-PSY version recommended)
    * `mpv-2.dll` (libmpv from Shinchiro for the Flutter wrapper, specifically the `x86_64-v3` build for AVX2 performance)

* **VapourSynth Portable Environment:** The app must include a portable Python environment (`assets/bin/python/python.exe`) with VapourSynth Portable and the `KNLMeansCL.dll` plugin (x64 version) pre-installed. The Flutter backend must explicitly route the Av1an command execution paths to utilize these bundled binaries rather than relying on the user's system PATH variables.

### **Automated Dependency Downloader (`setup_deps.ps1`)**

To facilitate easy developer setup and user installations, the project includes a `setup_deps.ps1` PowerShell script that automatically:
1. Queries the GitHub API to dynamically fetch the absolute latest release URLs for **Av1an** and **SVT-AV1-PSY**.
2. Downloads and natively extracts the binaries into `assets/bin/`.
3. Downloads the official **Python 3.11 Embeddable** and seamlessly overlays the **VapourSynth Portable** release on top of it inside `assets/bin/python/`.

**Manual Steps Required After Script:**
Due to licensing and distribution constraints, two `.dll` files must be downloaded and placed manually:
1. **KNLMeansCL.dll (x64)**: Download the `win64` release from `https://github.com/Khanattila/KNLMeansCL/releases`, open the `x64` folder inside the zip, and place the `.dll` in `assets/bin/python/`.
2. **mpv-2.dll (v3)**: Download the `mpv-dev-x86_64-v3` release from `https://sourceforge.net/projects/mpv-player-windows/files/libmpv/`. Extract it, find `libmpv-2.dll`, place it in `assets/bin/`, and **rename** it to `mpv-2.dll` (Flutter's media_kit specifically looks for this filename).