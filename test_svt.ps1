$r = Invoke-RestMethod -Uri 'https://api.github.com/repos/psy-ex/svt-av1-psy/releases'
foreach ($release in $r) {
    $asset = $release.assets | Where-Object { $_.name -match 'Windows' }
    if ($asset) {
        $url = $asset.browser_download_url
        break
    }
}
Write-Host "URL: $url"
Invoke-WebRequest -Uri $url -OutFile 'test_svt.7z'
.\assets\bin\7zr.exe x test_svt.7z -otest_svt -y
Get-ChildItem -Path test_svt -Recurse | Select-Object Name, Length
