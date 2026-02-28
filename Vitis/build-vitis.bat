@ECHO OFF

setlocal ENABLEDELAYEDEXPANSION
SET vitis=C:\AMDDesignTools\2025.2\Vitis\bin\vitis.bat
cmd /c "%vitis% -s py\build-vitis.py py\args.json ..\docs\source\data.json"
pause
