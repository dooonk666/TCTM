@echo off
setlocal
set "K7_ROOT=%~dp0.."
set "TEMP=%K7_ROOT%\temp"
set "TMP=%K7_ROOT%\temp"
if "%~1"=="" (echo Usage: run_batch.bat create_project^|check_project^|synthesize^|prepare_dttl_sim & exit /b 2)
if not exist "%K7_ROOT%\scripts\%~1.tcl" (echo Script not found: %~1 & exit /b 2)
if not exist "%TEMP%" mkdir "%TEMP%"
if not exist "%K7_ROOT%\reports" mkdir "%K7_ROOT%\reports"
if not exist "%K7_ROOT%\build" mkdir "%K7_ROOT%\build"
cd /d "%K7_ROOT%\build" || exit /b 1
call "E:\software\vivado\Vivado\2020.2\bin\vivado.bat" -mode batch -notrace -source "%K7_ROOT%\scripts\%~1.tcl" -log "%K7_ROOT%\reports\%~1.log" -journal "%K7_ROOT%\reports\%~1.jou"
exit /b %errorlevel%
