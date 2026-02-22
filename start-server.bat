@echo off
REM ── Shadow Hunter – Serveur local ──────────────────────────────────────────
REM  Modifie GODOT_EXE ci-dessous avec le chemin de ton Godot_v4.6-stable_win64.exe
set "GODOT_EXE=C:\chemin\vers\Godot_v4.6-stable_win64.exe"

REM ── Ne pas modifier en dessous ──────────────────────────────────────────────
set "PROJECT_PATH=%~dp0"
echo Demarrage du serveur Shadow Hunter sur le port 9080...
echo.
"%GODOT_EXE%" --headless --path "%PROJECT_PATH%"
pause
