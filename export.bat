@echo off
echo Exporting...

"C:\Users\camde\Downloads\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64.exe" --headless --export-debug "Windows Desktop" "builds/windows/Project Jack Sparrow.exe"

echo Organizing DLLs...

mkdir "builds\windows\addons\godotsteam\win64" 2>nul

move "builds\windows\libgodotsteam.windows.template_debug.x86_64.dll" "builds\windows\addons\godotsteam\win64\" >nul
move "builds\windows\libgodotsteam.windows.template_release.x86_64.dll" "builds\windows\addons\godotsteam\win64\" >nul
move "builds\windows\steam_api64.dll" "builds\windows\addons\godotsteam\win64\" >nul

echo Copying steam_appid.txt...
copy "steam_appid.txt" "builds\windows\" >nul

echo Done!
pause