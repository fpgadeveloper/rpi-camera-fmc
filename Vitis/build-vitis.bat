@ECHO OFF

setlocal ENABLEDELAYEDEXPANSION
SET vitis=C:\Xilinx\Vitis\2024.1\bin\vitis.bat
cmd /c "%vitis% -s py\build-vitis.py py\args.json ..\docs\source\data.json"
pause
