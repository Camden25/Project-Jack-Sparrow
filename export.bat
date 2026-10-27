@echo off
setlocal
cd /d "%~dp0" || exit /b 1

if not "%~1"=="" set "GODOT_EXE=%~1"

if not defined GODOT_EXE set "GODOT_EXE=C:\Users\camde\Documents\GameDev\Godot Installations\4.7.2-stable\Godot_v4.7.2-stable_win64.exe"
if exist "%GODOT_EXE%" goto :godot_found
if "%GODOT_EXE%"=="C:\Users\camde\Documents\GameDev\Godot Installations\4.7.2-stable\Godot_v4.7.2-stable_win64.exe" set "GODOT_EXE="

if not defined GODOT_EXE (
	for %%G in (godot.exe godot4.exe) do (
		for /f "delims=" %%P in ('where.exe %%G 2^>nul') do (
			set "GODOT_EXE=%%P"
			goto :godot_found
		)
	)
)

:godot_found
if not defined GODOT_EXE goto :godot_not_found
if not exist "%GODOT_EXE%" (
	where.exe "%GODOT_EXE%" >nul 2>&1
	if errorlevel 1 goto :godot_not_found
)

set "OUTPUT_DIR=%~dp0builds\windows"
if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
if errorlevel 1 goto :output_directory_failed

echo Exporting Windows Desktop build...
"%GODOT_EXE%" --headless --export-debug "Windows Desktop" "%OUTPUT_DIR%\Project Jack Sparrow.exe"
if errorlevel 1 goto :export_failed

if not exist "%OUTPUT_DIR%\Project Jack Sparrow.exe" goto :missing_output
if not exist "%OUTPUT_DIR%\Project Jack Sparrow.pck" goto :missing_output
if not exist "%OUTPUT_DIR%\steam_appid.txt" goto :missing_output
if not exist "%OUTPUT_DIR%\addons\godotsteam\win64\libgodotsteam.windows.template_debug.x86_64.dll" goto :missing_output
if not exist "%OUTPUT_DIR%\addons\godotsteam\win64\steam_api64.dll" goto :missing_output

echo Done! Export created at "%OUTPUT_DIR%".
pause
exit /b 0

:godot_not_found
echo ERROR: Godot was not found. Add godot.exe to PATH, set GODOT_EXE, or pass its path as the first argument.
pause
exit /b 1

:output_directory_failed
echo ERROR: Could not create the export directory "%OUTPUT_DIR%".
pause
exit /b 1

:export_failed
echo ERROR: Godot failed to export the Windows Desktop build.
pause
exit /b 1

:missing_output
echo ERROR: Export finished but expected build files are missing from "%OUTPUT_DIR%".
pause
exit /b 1
