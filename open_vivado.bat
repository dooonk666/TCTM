@echo off
setlocal
set "K7_ROOT=%~dp0"
set "TEMP=%K7_ROOT%temp"
set "TMP=%K7_ROOT%temp"
if not exist "%TEMP%" mkdir "%TEMP%"
cd /d "%K7_ROOT%build"
call "E:\software\vivado\Vivado\2020.2\bin\vivado.bat" "%K7_ROOT%build\k7_clean.xpr"
endlocal
