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
rem KVARGS is set by the caller (ctx-*.bat). Model weights take 6540 MiB,
rem VRAM gives about 11199 MiB free, so the KV cache must fit in ~4 GiB:
rem   f16   32768 = 2048 MiB   65536 = 4096 MiB  (marginal, spills if busy)
rem   q8_0  32768 = 1024 MiB   65536 = 2048 MiB   131072 = 4096 MiB
rem   q4_0 131072 = 2048 MiB  196608 = 3264 MiB   262144 = 4352 MiB
rem -ub 128 -b 512 shrinks the compute buffer (~390 -> ~150 MiB).
rem Do NOT use -nkvo: KV cache in system RAM costs 8x decode.
if not defined KVARGS set "KVARGS="

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

rem KV cache type is shown above; empty means f16 (default, best quality).

llama-server.exe -m "%MODEL%" -ngl 99 -fa on -c %CTX% -t %THREADS% -np %PARALLEL% %KVARGS% --port %PORT% --host 127.0.0.1 %*

echo.
echo [INFO] Server stopped.
pause