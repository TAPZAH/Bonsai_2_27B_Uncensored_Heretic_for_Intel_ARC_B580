@echo off
setlocal
title Bonsai 2 27B PQ2_0 (PrismML llama-server)

rem ===== engine launcher, all settings come from the environment =====
if not defined CTX      set "CTX=65536"
if not defined THREADS  set "THREADS=12"
if not defined PARALLEL set "PARALLEL=1"
if not defined PORT     set "PORT=18098"
rem -ngl 99 keeps all 65 layers in VRAM, -np 1 keeps the whole context in
rem one slot. Both were measured: auto-fit costs 4-5x decode, 4 slots halve it.
if not defined KVARGS (
  if %CTX% GEQ 131072 set "KVARGS=-ctk q8_0 -ctv q8_0"
)

set "HERE=%~dp0"
set "MODEL=%HERE%Ternary-Bonsai-2-27B-Uncensored-Heretic-PQ2_0.gguf"
set "MMPROJ=%HERE%mmproj-BF16.gguf"
rem =====================================================================

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
  echo [ERROR] Port %PORT% is already busy. Close the other server or change PORT.
  pause
  exit /b 1
)

cd /d "%HERE%prism-llama"

echo [INFO] Model   : %MODEL%
if exist "%MMPROJ%" echo [INFO] Vision  : mmproj-BF16.gguf (add --mmproj "%MMPROJ%" for images)
echo [INFO] Context : %CTX% tokens (model max 262144)
echo [INFO] KV cache: %KVARGS%  (empty means f16)
echo [INFO] Threads : %THREADS%
echo [INFO] Slots   : %PARALLEL%
echo [INFO] API     : http://127.0.0.1:%PORT%/v1  (OpenAI compatible, localhost only)
echo [INFO] Stop    : close this window or Ctrl+C
echo.

if %CTX% GTR 65536 (
  echo [WARNING] Context above 65536 is unusable on this machine.
  echo [WARNING] The KV cache stops fitting in 12 GB of VRAM and prompt
  echo [WARNING] processing drops from 134 tok/s to under 30 tok/s.
  echo [WARNING] Measured: 98304 and 262144 both time out on a 27k prompt.
  echo [WARNING] Use ctx-32768.bat or ctx-65536.bat instead.
  echo.
)

llama-server.exe -m "%MODEL%" -ngl 99 -fa on -c %CTX% -t %THREADS% -np %PARALLEL% %KVARGS% --port %PORT% --host 127.0.0.1 %*

echo.
echo [INFO] Server stopped.
pause