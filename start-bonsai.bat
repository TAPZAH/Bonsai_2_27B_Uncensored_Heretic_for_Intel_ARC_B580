@echo off
setlocal
title Bonsai 2 27B PQ2_0 (PrismML llama-server)

rem ===== portable: all paths relative to this script =====
set "HERE=%~dp0"
set "MODEL=%HERE%Ternary-Bonsai-2-27B-Uncensored-Heretic-PQ2_0.gguf"
set "CTX=65536"
set "THREADS=12"
rem -np 1 is twice as fast: with 4 slots decode drops from 23 to 10 tok/s.
rem Set 2-4 only if you need parallel requests.
set "PARALLEL=1"
set "PORT=18098"
rem =====================================================

if not exist "%MODEL%" (
  echo [ERROR] Model not found: "%MODEL%"
  echo Put the GGUF next to this script.
  pause
  exit /b 1
)

if not exist "%HERE%prism-llama\llama-server.exe" (
  echo [ERROR] Engine not found: "%HERE%prism-llama\llama-server.exe"
  echo Keep the prism-llama folder next to this script.
  pause
  exit /b 1
)

netstat -ano | find "127.0.0.1:%PORT%" | find "LISTENING" >nul
if not errorlevel 1 (
  echo [ERROR] Port %PORT% is already busy. Close the other server or change PORT in this script.
  pause
  exit /b 1
)

cd /d "%HERE%prism-llama"

echo [INFO] Model   : %MODEL%
if exist "%HERE%mmproj-BF16.gguf" echo [INFO] Vision  : mmproj-BF16.gguf (add --mmproj "%HERE%mmproj-BF16.gguf" for images)
echo [INFO] Context : %CTX% tokens (model max 262144)
echo [INFO] Threads : %THREADS%
echo [INFO] Slots   : %PARALLEL%
echo [INFO] API     : http://127.0.0.1:%PORT%/v1  (OpenAI compatible, localhost only)
echo [INFO] Stop    : close this window or Ctrl+C
echo.

llama-server.exe -m "%MODEL%" -ngl 99 -fa on -c %CTX% -t %THREADS% -np %PARALLEL% --port %PORT% --host 127.0.0.1 %*

echo.
echo [INFO] Server stopped.
pause