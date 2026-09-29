@echo off
cd /d "%~dp0"
echo Building the Yoerger Renovations site...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" %*
if errorlevel 1 (
  echo.
  echo BUILD FAILED - read the message above.
) else (
  echo.
  echo Done. The finished site is in the "docs" folder. Open docs\index.html to preview.
)
pause
