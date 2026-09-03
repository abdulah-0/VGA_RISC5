@echo off
REM ==============================================================================
REM Universal Bitstream Generator for Digilent Nexys Video (Artix-7 XC7A200T)
REM Automatically detects any installed Vivado version (2020.x, 2021.x, 2022.x, 2023.x, etc.)
REM Usage:
REM   make_bitstream.bat
REM ==============================================================================

setlocal enabledelayedexpansion
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM 1. Locate Vivado executable
set "VIVADO_BIN="
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
echo [INFO] Generating Nexys Video Bitstream within existing project...
cd /d "%SCRIPT_DIR%"
call "%VIVADO_BIN%" -mode batch -source "%SCRIPT_DIR%\make_bitstream.tcl"

endlocal
