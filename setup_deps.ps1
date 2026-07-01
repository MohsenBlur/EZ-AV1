param (
    [string]$TargetDir = "assets\bin"
)

# Ensure the target directory exists
if (-not (Test-Path -Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir | Out-Null
}

$ProgressPreference = 'SilentlyContinue' # Speeds up Invoke-WebRequest significantly

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host " AUTOMATED DEPENDENCY DOWNLOADER FOR EZ-AV1" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan

# 0. Download 7-Zip standalone to extract .7z files
$SevenZipExe = Join-Path $TargetDir "7zr.exe"
if (-not (Test-Path $SevenZipExe)) {
    Write-Host "Downloading 7-Zip Standalone..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://www.7-zip.org/a/7zr.exe" -OutFile $SevenZipExe
}

# 1. FFmpeg
$FfmpegZip = Join-Path $TargetDir "ffmpeg.zip"
$FfmpegExe = Join-Path $TargetDir "ffmpeg.exe"
if (-not (Test-Path $FfmpegExe) -or (Get-Item $FfmpegExe).Length -eq 0) {
    Write-Host "Downloading FFmpeg..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip" -OutFile $FfmpegZip
    Write-Host "Extracting FFmpeg..." -ForegroundColor Yellow
    Expand-Archive -Path $FfmpegZip -DestinationPath $TargetDir -Force
    # Move binaries to root of bin
    Get-ChildItem -Path $TargetDir -Filter "ffmpeg.exe" -Recurse | Move-Item -Destination $TargetDir -Force
    Get-ChildItem -Path $TargetDir -Filter "ffprobe.exe" -Recurse | Move-Item -Destination $TargetDir -Force
    Remove-Item $FfmpegZip -Force
}

# 2. Av1an
$Av1anZip = Join-Path $TargetDir "av1an.zip"
$Av1anExe = Join-Path $TargetDir "av1an.exe"
if (-not (Test-Path $Av1anExe) -or (Get-Item $Av1anExe).Length -eq 0) {
    Write-Host "Fetching latest Av1an release URL..." -ForegroundColor Yellow
    $Av1anRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/master-of-zen/Av1an/releases/latest"
    $Av1anUrl = ($Av1anRelease.assets | Where-Object { $_.name -match "x86_64-pc-windows-msvc.zip" }).browser_download_url
    Write-Host "Downloading Av1an..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $Av1anUrl -OutFile $Av1anZip
    Write-Host "Extracting Av1an..." -ForegroundColor Yellow
    Expand-Archive -Path $Av1anZip -DestinationPath $TargetDir -Force
    Remove-Item $Av1anZip -Force
}

# 3. SVT-AV1
$SvtZip = Join-Path $TargetDir "svt-av1.zip"
$SvtExe = Join-Path $TargetDir "SvtAv1EncApp.exe"
if (-not (Test-Path $SvtExe) -or (Get-Item $SvtExe).Length -eq 0) {
    Write-Host "Fetching latest SVT-AV1 (PSY) release URL..." -ForegroundColor Yellow
    $SvtRelease = Invoke-RestMethod -Uri "https://api.github.com/repos/gianni-rosato/svt-av1-psy/releases/latest"
    $SvtUrl = ($SvtRelease.assets | Where-Object { $_.name -match "SVT-AV1-PSY-Windows.zip" }).browser_download_url
    Write-Host "Downloading SVT-AV1 (PSY)..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $SvtUrl -OutFile $SvtZip
    Write-Host "Extracting SVT-AV1..." -ForegroundColor Yellow
    Expand-Archive -Path $SvtZip -DestinationPath $TargetDir -Force
    Remove-Item $SvtZip -Force
}

# 4. VapourSynth Portable
$VsZip = Join-Path $TargetDir "vapoursynth.zip"
$PythonDir = Join-Path $TargetDir "python"
$PythonExe = Join-Path $PythonDir "python.exe"
if (-not (Test-Path $PythonDir) -or ((Test-Path $PythonExe) -and ((Get-Item $PythonExe).Length -eq 0))) {
    Write-Host "Downloading VapourSynth Portable..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://github.com/vapoursynth/vapoursynth/releases/download/R65/VapourSynth64-Portable-R65.zip" -OutFile $VsZip
    Write-Host "Extracting VapourSynth..." -ForegroundColor Yellow
    # Extract directly to the python/ root folder as expected by the environment service
    Expand-Archive -Path $VsZip -DestinationPath $PythonDir -Force
    Remove-Item $VsZip -Force
}

Write-Host "=================================================" -ForegroundColor Green
Write-Host " IMPORTANT MANUAL STEPS REMAINING:" -ForegroundColor Yellow
Write-Host "=================================================" -ForegroundColor Green
Write-Host "1. VapourSynth's KNLMeansCL plugin is not bundled by default. You need to install it manually into the python directory."
Write-Host "2. Shinchiro MPV (mpv-2.dll) links change weekly. Please download 'mpv-dev-x86_64' from https://sourceforge.net/projects/mpv-player-windows/files/libmpv/ and place 'mpv-2.dll' inside $TargetDir."
Write-Host "=================================================" -ForegroundColor Cyan
