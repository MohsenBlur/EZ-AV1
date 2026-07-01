try {
    $r1 = Invoke-RestMethod -Uri "https://api.github.com/repos/Khanattila/KNLMeansCL/releases"
    Write-Host "KNLMeansCL Releases:"
    $r1 | Select-Object tag_name -First 3
} catch {
    Write-Host "KNLMeansCL Failed: $_"
}
