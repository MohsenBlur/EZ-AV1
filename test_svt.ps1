if (Test-Path assets\bin\SvtAv1EncApp.exe) { Remove-Item assets\bin\SvtAv1EncApp.exe -Force }
$SvtZip = 'assets\bin\svt-av1.7z'
$SevenZipExe = 'assets\bin\7zr.exe'
Invoke-WebRequest -Uri 'https://github.com/psy-ex/svt-av1-psy/releases/download/v2.2.0/SvtAv1EncApp-Windows-x86_64.7z' -OutFile $SvtZip
& $SevenZipExe x $SvtZip -o"assets\bin" -y | Out-Null

Get-ChildItem -Path "assets\bin" -Filter "SvtAv1EncApp.exe" -Recurse | Move-Item -Destination "assets\bin" -Force

Get-ChildItem "assets\bin\SvtAv1EncApp.exe" | Select-Object Name, Length
