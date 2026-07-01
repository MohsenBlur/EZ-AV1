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
    if (Test-Path $FfmpegExe) { Remove-Item $FfmpegExe -Force -ErrorAction SilentlyContinue }
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
    if (Test-Path $Av1anExe) { Remove-Item $Av1anExe -Force -ErrorAction SilentlyContinue }
    Write-Host "Fetching latest Av1an release URL..." -ForegroundColor Yellow
    $Av1anReleases = Invoke-RestMethod -Uri "https://api.github.com/repos/rust-av/Av1an/releases"
    $Av1anUrl = $null
    foreach ($release in $Av1anReleases) {
        $asset = $release.assets | Where-Object { $_.name -match "windows" }
        if ($asset) {
            $Av1anUrl = $asset.browser_download_url
            break
        }
    }
    if ($null -eq $Av1anUrl) { throw "Could not find a Windows release for Av1an." }
    Write-Host "Downloading Av1an..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $Av1anUrl -OutFile $Av1anZip
    Write-Host "Extracting Av1an..." -ForegroundColor Yellow
    Expand-Archive -Path $Av1anZip -DestinationPath $TargetDir -Force
    Remove-Item $Av1anZip -Force
}

# 3. SVT-AV1
$SvtZip = Join-Path $TargetDir "svt-av1.7z"
$SvtExe = Join-Path $TargetDir "SvtAv1EncApp.exe"
if (-not (Test-Path $SvtExe) -or (Get-Item $SvtExe).Length -eq 0) {
    if (Test-Path $SvtExe) { Remove-Item $SvtExe -Force -ErrorAction SilentlyContinue }
    Write-Host "Fetching latest SVT-AV1 (PSY) release URL..." -ForegroundColor Yellow
    $SvtReleases = Invoke-RestMethod -Uri "https://api.github.com/repos/psy-ex/svt-av1-psy/releases"
    $SvtUrl = $null
    foreach ($release in $SvtReleases) {
        $asset = $release.assets | Where-Object { $_.name -match "Windows" }
        if ($asset) {
            $SvtUrl = $asset.browser_download_url
            break
        }
    }
    if ($null -eq $SvtUrl) { throw "Could not find a Windows release for SVT-AV1." }
    Write-Host "Downloading SVT-AV1 (PSY)..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $SvtUrl -OutFile $SvtZip
    Write-Host "Extracting SVT-AV1..." -ForegroundColor Yellow
    & $SevenZipExe x $SvtZip -o$TargetDir -y | Out-Null
    # Move binary to root of bin
    Get-ChildItem -Path $TargetDir -Filter "SvtAv1EncApp.exe" -Recurse | Move-Item -Destination $TargetDir -Force
    Get-ChildItem -Path $TargetDir -Directory -Filter "SvtAv1EncApp-*" | Remove-Item -Recurse -Force
    Remove-Item $SvtZip -Force
}

# 4. VapourSynth Portable & Python Embeddable
$VsZip = Join-Path $TargetDir "vapoursynth.zip"
$PythonZip = Join-Path $TargetDir "python_embed.zip"
$PythonDir = Join-Path $TargetDir "python"
$PythonExe = Join-Path $PythonDir "python.exe"

if (-not (Test-Path $PythonDir) -or ((Test-Path $PythonExe) -and ((Get-Item $PythonExe).Length -eq 0))) {
    if (Test-Path $PythonExe) { Remove-Item $PythonExe -Force -ErrorAction SilentlyContinue }
    Write-Host "Downloading Python Embeddable for VapourSynth..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://www.python.org/ftp/python/3.11.8/python-3.11.8-embed-amd64.zip" -OutFile $PythonZip
    Write-Host "Extracting Python..." -ForegroundColor Yellow
    Expand-Archive -Path $PythonZip -DestinationPath $PythonDir -Force
    Remove-Item $PythonZip -Force

    Write-Host "Downloading VapourSynth Portable..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://github.com/vapoursynth/vapoursynth/releases/download/R65/VapourSynth64-Portable-R65.zip" -OutFile $VsZip
    Write-Host "Extracting VapourSynth directly over Python..." -ForegroundColor Yellow
    Expand-Archive -Path $VsZip -DestinationPath $PythonDir -Force
    Remove-Item $VsZip -Force
}

Write-Host "=================================================" -ForegroundColor Green
Write-Host " IMPORTANT MANUAL STEPS REMAINING:" -ForegroundColor Yellow
Write-Host "=================================================" -ForegroundColor Green
Write-Host "1. KNLMeansCL: Download KNLMeansCL-v1.1.1-win64.zip from https://github.com/Khanattila/KNLMeansCL/releases"
Write-Host "   -> Extract it, open the 'x64' folder inside, and place that specific 'KNLMeansCL.dll' directly into the 'assets\bin\python' folder."
Write-Host ""
Write-Host "2. MPV: Download 'mpv-dev-x86_64-v3' from https://sourceforge.net/projects/mpv-player-windows/files/libmpv/"
Write-Host "   -> (Be sure to download the 'v3' version for AVX2 performance, not the generic one!)"
Write-Host "   -> Extract it, find 'libmpv-2.dll', and place it in the 'assets\bin' folder. Then RENAME it to 'mpv-2.dll'."
Write-Host "=================================================" -ForegroundColor Cyan

Write-Host "=================================================" -ForegroundColor Cyan

# Verify files for the user
Write-Host "`nVerifying downloaded files in $TargetDir :" -ForegroundColor Cyan
Get-ChildItem -Path $TargetDir -File | Select-Object Name, @{Name="Size(MB)";Expression={[math]::Round($_.Length / 1MB, 2)}} | Format-Table -AutoSize
Write-Host "Verifying Python Environment ($PythonDir) :" -ForegroundColor Cyan
Get-ChildItem -Path $PythonDir -File | Where-Object { $_.Name -match "python.exe|VapourSynth.dll" } | Select-Object Name, @{Name="Size(MB)";Expression={[math]::Round($_.Length / 1MB, 2)}} | Format-Table -AutoSize

# Open the bin folder to make it easy for the user
Start-Process "explorer.exe" -ArgumentList (Resolve-Path $TargetDir).Path
Read-Host "Press Enter once you have placed the two DLLs to finish setup..."
