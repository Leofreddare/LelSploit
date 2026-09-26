@echo off
setlocal

set "OUTPUT=LelSploit.msi"

rem Remove stale output before building
if exist "%OUTPUT%" del /f /q "%OUTPUT%"

wix build -arch x64 installer.wxs -o "%OUTPUT%"
set "EXITCODE=%ERRORLEVEL%"

rem Clean common WiX temporary/intermediate files
for %%F in (*.wixobj *.wixpdb *.wixout) do (
    if exist "%%F" del /f /q "%%F"
)

for %%D in (obj bin) do (
    if exist "%%D" rmdir /s /q "%%D"
)

if not "%EXITCODE%"=="0" (
    echo MSI build failed with exit code %EXITCODE%.
    exit /b %EXITCODE%
)

echo Built %OUTPUT% successfully.
exit /b 0