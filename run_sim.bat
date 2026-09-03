@echo off
REM ==============================================================================
REM Universal One-Click Vivado Simulation Launcher for Windows
REM Automatically detects any installed Vivado version (2020.x, 2021.x, 2022.x, 2023.x, etc.)
REM Usage:
REM   run_sim.bat          (launches Vivado GUI with curated waveform viewer)
REM   run_sim.bat -batch   (runs automated simulation in batch mode)
REM ==============================================================================

setlocal enabledelayedexpansion
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM 1. Find Vivado executable
set "VIVADO_BIN="

REM Check if vivado is already in system PATH (e.g. Vivado Command Prompt)
where vivado >nul 2>nul
if %errorlevel% equ 0 (
    set "VIVADO_BIN=vivado"
) else (
    REM Search all installed Vivado versions on C: and D: drives
    for /d %%D in (C:\Xilinx\Vivado D:\Xilinx\Vivado) do (
        if exist "%%D" (
            for /d %%V in ("%%D\*") do (
                if exist "%%V\bin\vivado.bat" (
                    set "VIVADO_BIN=%%V\bin\vivado.bat"
                )
            )
        )
    )
)

if "%VIVADO_BIN%"=="" (
    echo [ERROR] Could not find Vivado in PATH or in C:\Xilinx\Vivado\ or D:\Xilinx\Vivado\!
    echo Please ensure Vivado is installed, or launch this script from the Vivado Command Prompt.
    pause
    exit /b 1
)

echo [INFO] Found Vivado: %VIVADO_BIN%

REM 2. Determine mode (GUI by default, or batch if passed)
set "MODE=gui"
if /i "%~1"=="-batch" set "MODE=batch"
if /i "%~1"=="batch"  set "MODE=batch"

echo [INFO] Launching Vivado simulation in %MODE% mode...
cd /d "%SCRIPT_DIR%"
call "%VIVADO_BIN%" -mode %MODE% -source "%SCRIPT_DIR%\run_sim.tcl"

endlocal
