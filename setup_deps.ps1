param (
    [string]$TargetDir = "assets\bin"
)

# Ensure the target directory exists
if (-not (Test-Path -Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir | Out-Null
}

Write-Host "Setting up EZ-AV1 dependencies in $TargetDir..."

# This script creates the folder structure for the portable binaries.
# Due to the complexity of VapourSynth portable environments and the varying
# release structures of these tools, we recommend downloading the specific builds:

$Instructions = @"

================================================================================
REQUIRED DEPENDENCIES FOR EZ-AV1
================================================================================
Please download the following portable binaries and extract them directly into 
the '$TargetDir' folder in the root of the EZ-AV1 project.

1. FFmpeg & FFprobe (Windows Portable)
   - Download from: https://github.com/GyanD/codexffmpeg/releases
   - Ensure `ffmpeg.exe` and `ffprobe.exe` are in $TargetDir

2. Av1an
   - Download the latest Windows release from: https://github.com/master-of-zen/Av1an/releases
   - Ensure `av1an.exe` is in $TargetDir

3. SVT-AV1
   - Download the Windows binary from: https://gitlab.com/AOMediaCodec/SVT-AV1/-/releases
   - Ensure `SvtAv1EncApp.exe` is in $TargetDir

4. Shinchiro MPV (with VapourSynth support)
   - Download from: https://sourceforge.net/projects/mpv-player-windows/files/
   - Ensure `mpv.exe` and `mpv-2.dll` are in $TargetDir
   - NOTE: We will copy this mpv-2.dll over the media_kit one during runtime.

5. Portable Python & VapourSynth
   - Install VapourSynth Portable (which includes Python) 
   - Ensure the python executable is at `$TargetDir\python\python.exe`
   - Install KNLMeansCL plugin into the VapourSynth environment.
================================================================================
"@

Write-Host $Instructions -ForegroundColor Cyan

# Create dummy files for UI development/testing so the EnvironmentService doesn't crash
$Dummies = @(
    "ffmpeg.exe", "ffprobe.exe", "av1an.exe", "SvtAv1EncApp.exe", "mpv-2.dll"
)

foreach ($dummy in $Dummies) {
    $path = Join-Path $TargetDir $dummy
    if (-not (Test-Path $path)) {
        New-Item -ItemType File -Path $path -Force | Out-Null
        Write-Host "Created placeholder for $dummy" -ForegroundColor Yellow
    }
}

# Create dummy python
$PythonDir = Join-Path $TargetDir "python"
if (-not (Test-Path $PythonDir)) {
    New-Item -ItemType Directory -Path $PythonDir | Out-Null
}
$PythonExe = Join-Path $PythonDir "python.exe"
if (-not (Test-Path $PythonExe)) {
    New-Item -ItemType File -Path $PythonExe -Force | Out-Null
    Write-Host "Created placeholder for python.exe" -ForegroundColor Yellow
}

Write-Host "Done. Replace the placeholder 0-byte files with real binaries before running a real encode." -ForegroundColor Green
