$env:VSSCRIPT_PATH = "$PSScriptRoot\assets\bin\python\VSScript.dll"

Write-Host "Starting EZ-AV1 in debug mode..." -ForegroundColor Yellow
flutter run -d windows
