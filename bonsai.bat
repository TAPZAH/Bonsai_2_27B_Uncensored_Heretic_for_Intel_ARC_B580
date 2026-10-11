@echo off
setlocal EnableDelayedExpansion
title Ternary Bonsai 2 27B PQ2_0 launcher

rem =====================================================================
rem  Ternary-Bonsai-2-27B-Uncensored-Heretic (PQ2_0)
rem  Portable launcher: downloads the engine and the model, then runs
rem  llama-server with a tested configuration.
rem
rem  Why a custom engine: this model stores its weights with ggml type 142
rem  (PQ2_0). Stock llama.cpp rejects it with
rem      tensor 'output.weight' has invalid ggml type 142
rem  Only the PrismML llama.cpp fork has the ternary kernels.
rem =====================================================================

set "HERE=%~dp0"
set "ENGINE_DIR=%HERE%engine"
set "EXE=%ENGINE_DIR%\llama-server.exe"
rem also accept the older folder name used by the first release
if not exist "%EXE%" if exist "%HERE%prism-llama\llama-server.exe" set "EXE=%HERE%prism-llama\llama-server.exe"

rem ---- what to download -------------------------------------------------
set "MODEL_REPO=OS-Software/Ternary-Bonsai-2-27B-Uncensored-Heretic-GGUF"
set "MODEL_FILE=Ternary-Bonsai-2-27B-Uncensored-Heretic-PQ2_0.gguf"
set "MMPROJ_FILE=mmproj-BF16.gguf"
set "ENGINE_REPO=PrismML-Eng/llama.cpp"
rem leave empty to resolve the newest release, or pin a tag here
set "ENGINE_TAG="

rem ---- server settings --------------------------------------------------
set "PORT=18098"
set "THREADS=12"
set "PARALLEL=1"

rem allow bonsai.bat 65k-q8_0 to start directly (used by the shortcuts)
if not "%~1"=="" goto :run_named

:menu
set "S_ENGINE=not installed"
set "S_MODEL=not installed"
set "S_VISION=not installed"
if exist "%EXE%" set "S_ENGINE=INSTALLED"
if exist "%HERE%%MODEL_FILE%" set "S_MODEL=INSTALLED"
if exist "%HERE%%MMPROJ_FILE%" set "S_VISION=INSTALLED"

cls
echo ============================================================
echo   Ternary Bonsai 2 27B PQ2_0
echo ============================================================
echo.
echo   DOWNLOAD
echo      1   engine     [%S_ENGINE%]    PrismML llama.cpp fork, required
echo      2   model      [%S_MODEL%]    7.2 GB
echo      3   vision     [%S_VISION%]   0.93 GB, only for image input
echo.
echo   RUN   tested configurations
echo      4   32k  f16     best quality
echo      5   32k  q8_0
echo      6   65k  f16     tight VRAM
echo      7   65k  q8_0    recommended
echo      8   96k  q8_0    intermediate, 1 GB VRAM headroom
echo      9   131k q4_0
echo      0   262k q4_0    max context, lower KV quality
echo.
echo   SERVER   active values
echo      port     = %PORT%
echo      threads  = %THREADS%
echo      slots    = %PARALLEL%
echo.
echo      S   change settings
echo      T   test a running server
echo      Q   quit
echo.
set "CH="
set /p CH="Select: "

if /i "%CH%"=="1" goto :dl_engine
if /i "%CH%"=="2" goto :dl_model
if /i "%CH%"=="3" goto :dl_vision
if /i "%CH%"=="4" goto :run_32k_f16
if /i "%CH%"=="5" goto :run_32k_q8_0
if /i "%CH%"=="6" goto :run_65k_f16
if /i "%CH%"=="7" goto :run_65k_q8_0
if /i "%CH%"=="8" goto :run_96k_q8_0
if /i "%CH%"=="9" goto :run_131k_q4_0
if /i "%CH%"=="0" goto :run_262k_q4_0
if /i "%CH%"=="S" goto :settings
if /i "%CH%"=="T" goto :test
if /i "%CH%"=="Q" goto :eof
echo.
echo [?] Unknown option
pause
goto :menu


rem =====================================================================
rem  DOWNLOAD
rem =====================================================================

:dl_engine
echo.
echo [INFO] Resolving latest engine release...
set "TAG=%ENGINE_TAG%"
if defined TAG goto :engine_have_tag
set "FULLURL="
for /f "tokens=*" %%A in ('curl.exe -sI -o NUL -w "%%{redirect_url}" https://github.com/%ENGINE_REPO%/releases/latest') do set "FULLURL=%%A"
if not defined FULLURL (
  echo [ERROR] Could not resolve the release tag. Check your connection.
  echo         You can pin a tag by setting ENGINE_TAG in this file.
  pause
  goto :menu
)
for %%A in ("!FULLURL!") do set "TAG=%%~nxA"
:engine_have_tag
echo [INFO] Release tag: %TAG%
set "ZIP=llama-%TAG%-bin-win-vulkan-x64.zip"
set "URL=https://github.com/%ENGINE_REPO%/releases/download/%TAG%/%ZIP%"
echo [INFO] %URL%
if exist "%HERE%%ZIP%" (
  echo [INFO] Archive already downloaded, skipping download.
) else (
  curl.exe -L -C - --retry 5 --progress-bar -o "%HERE%%ZIP%" "%URL%"
  if errorlevel 1 (
    echo [ERROR] Download failed.
    pause
    goto :menu
  )
)
echo [INFO] Extracting to engine\ ...
if exist "%ENGINE_DIR%" rmdir /s /q "%ENGINE_DIR%" 2>nul
mkdir "%ENGINE_DIR%" 2>nul
tar.exe -xf "%HERE%%ZIP%" -C "%ENGINE_DIR%"
if errorlevel 1 (
  echo [ERROR] Could not extract the archive.
  pause
  goto :menu
)
rem some archives have a top level folder, flatten it
if not exist "%EXE%" (
  for /f "delims=" %%D in ('dir /b /ad "%ENGINE_DIR%"') do (
    if exist "%ENGINE_DIR%\%%D\llama-server.exe" (
      for /f "delims=" %%F in ('dir /b "%ENGINE_DIR%\%%D"') do move /y "%ENGINE_DIR%\%%D\%%F" "%ENGINE_DIR%\" >nul 2>&1
      rmdir /s /q "%ENGINE_DIR%\%%D" 2>nul
    )
  )
)
if not exist "%EXE%" (
  echo [ERROR] llama-server.exe not found after extraction.
  pause
  goto :menu
)
del /q "%HERE%%ZIP%" 2>nul
echo [OK] Engine ready: %EXE%
pause
goto :menu

:dl_model
echo.
if exist "%HERE%%MODEL_FILE%" (
  echo [INFO] Model already present: %HERE%%MODEL_FILE%
  pause
  goto :menu
)
echo [INFO] Downloading %MODEL_FILE% (~7.2 GB, resumable)
curl.exe -L -C - --retry 5 --progress-bar -o "%HERE%%MODEL_FILE%" "https://huggingface.co/%MODEL_REPO%/resolve/main/%MODEL_FILE%"
if errorlevel 1 (
  echo [ERROR] Download failed. Re-run to resume.
) else (
  echo [OK] Model ready.
)
pause
goto :menu

:dl_vision
echo.
if exist "%HERE%%MMPROJ_FILE%" (
  echo [INFO] Vision tower already present.
  pause
  goto :menu
)
echo [INFO] Downloading %MMPROJ_FILE% (~0.93 GB)
curl.exe -L -C - --retry 5 --progress-bar -o "%HERE%%MMPROJ_FILE%" "https://huggingface.co/%MODEL_REPO%/resolve/main/%MMPROJ_FILE%"
if errorlevel 1 ( echo [ERROR] Download failed. ) else ( echo [OK] Vision tower ready. )
pause
goto :menu


rem =====================================================================
rem  SETTINGS
rem =====================================================================

:settings
cls
echo ============================================================
echo   Server settings
echo ============================================================
echo.
echo   Active values used when the server starts:
echo.
echo      1   port       = %PORT%
echo      2   threads    = %THREADS%
echo      3   slots      = %PARALLEL%
echo.
echo   4  run a custom context (choose size and KV type)
echo   B  back to menu
echo.
set "CH="
set /p CH="Select: "
if /i "%CH%"=="1" goto :set_port
if /i "%CH%"=="2" goto :set_threads
if /i "%CH%"=="3" goto :set_slots
if /i "%CH%"=="4" goto :custom
if /i "%CH%"=="B" goto :menu
goto :settings

:set_port
set /p PORT="New port: "
goto :settings

:set_threads
set /p THREADS="New thread count: "
goto :settings

:set_slots
set /p PARALLEL="New slot count: "
goto :settings

:custom
echo.
set /p "CTXIN=Context size in tokens (1024..262144): "
echo   KV cache type:
echo     f16   best quality, needs the most VRAM
echo     q8_0  good quality, half the VRAM
echo     q4_0  smallest, fits the largest contexts
set /p "KVIN=KV type [f16/q8_0/q4_0]: "
set "CTX=%CTXIN%"
if /i "%KVIN%"=="f16"  set "KVARGS="
if /i "%KVIN%"=="q8_0" set "KVARGS=-ctk q8_0 -ctv q8_0"
if /i "%KVIN%"=="q4_0" set "KVARGS=-ctk q4_0 -ctv q4_0 -b 512 -ub 128"
goto :start


rem =====================================================================
rem  TEST
rem =====================================================================

:test
echo.
curl.exe -s http://127.0.0.1:%PORT%/props | findstr /i "n_ctx model_path"
if errorlevel 1 echo [ERROR] No server answering on port %PORT%
pause
goto :menu


rem =====================================================================
rem  PRESETS
rem =====================================================================

:run_32k_f16
set "CTX=32768" & set "KVARGS="
goto :start
:run_32k_q8_0
set "CTX=32768" & set "KVARGS=-ctk q8_0 -ctv q8_0"
goto :start
:run_65k_f16
set "CTX=65536" & set "KVARGS="
goto :start
:run_65k_q8_0
set "CTX=65536" & set "KVARGS=-ctk q8_0 -ctv q8_0"
goto :start
:run_96k_q8_0
set "CTX=98304"  & set "KVARGS=-ctk q8_0 -ctv q8_0"
goto :start
rem 131k uses q4_0 KV on purpose. q8_0 needs 4352 MiB and then needs
rem -ub 128 to fit, which cuts prompt eval to 120 tok/s and lost the
rem Vulkan device on long prompts. q4_0 needs 2176 MiB, keeps the full
rem ubatch, fits with 2 GB of headroom and runs 27 tok/s.
:run_131k_q4_0
set "CTX=131072" & set "KVARGS=-ctk q4_0 -ctv q4_0"
goto :start
:run_262k_q4_0
set "CTX=262144" & set "KVARGS=-ctk q4_0 -ctv q4_0 -b 512 -ub 128"
goto :start

:run_named
set "CFGNAME=%~1"
if /i "%CFGNAME%"=="32k-f16"   ( set "CTX=32768"  & set "KVARGS=" & goto :start )
if /i "%CFGNAME%"=="32k-q8_0"  ( set "CTX=32768"  & set "KVARGS=-ctk q8_0 -ctv q8_0" & goto :start )
if /i "%CFGNAME%"=="65k-f16"   ( set "CTX=65536"  & set "KVARGS=" & goto :start )
if /i "%CFGNAME%"=="65k-q8_0"  ( set "CTX=65536"  & set "KVARGS=-ctk q8_0 -ctv q8_0" & goto :start )
if /i "%CFGNAME%"=="96k-q8_0"  ( set "CTX=98304"  & set "KVARGS=-ctk q8_0 -ctv q8_0" & goto :start )
rem 131k-q8_0 is accepted as an alias, but it maps to the q4_0 preset:
rem q8_0 there needs -ub 128 to fit in VRAM, which dropped prompt eval to
rem 120 tok/s and lost the Vulkan device on long prompts.
if /i "%CFGNAME%"=="131k-q4_0" ( set "CTX=131072" & set "KVARGS=-ctk q4_0 -ctv q4_0" & goto :start )
if /i "%CFGNAME%"=="131k-q8_0" ( set "CTX=131072" & set "KVARGS=-ctk q4_0 -ctv q4_0" & goto :start )
if /i "%CFGNAME%"=="262k-q4_0" ( set "CTX=262144" & set "KVARGS=-ctk q4_0 -ctv q4_0 -b 512 -ub 128" & goto :start )
echo [ERROR] Unknown configuration "%CFGNAME%"
echo         Use: 32k-f16 32k-q8_0 65k-f16 65k-q8_0 96k-q8_0 131k-q4_0 262k-q4_0
pause
goto :eof


rem =====================================================================
rem  START
rem =====================================================================

:start
if not exist "%EXE%" (
  echo [ERROR] Engine missing. Run option 1 from the menu first.
  pause
  goto :menu
)
if not exist "%HERE%%MODEL_FILE%" (
  echo [ERROR] Model missing. Run option 2 from the menu first.
  pause
  goto :menu
)
netstat -ano | find "127.0.0.1:%PORT%" | find "LISTENING" >nul
if not errorlevel 1 (
  echo [ERROR] Port %PORT% is already busy. Change it in Settings.
  pause
  goto :menu
)

echo.
echo [INFO] Model   : %HERE%%MODEL_FILE%
echo [INFO] Context : %CTX% tokens
echo [INFO] KV      : %KVARGS%  (empty means f16)
echo [INFO] Threads : %THREADS%
echo [INFO] Slots   : %PARALLEL%
echo [INFO] API     : http://127.0.0.1:%PORT%/v1   (OpenAI compatible)
echo [INFO] Stop    : close this window or Ctrl+C
echo.

rem -ngl 99 keeps all 65 layers in VRAM, -np 1 keeps the context in one
rem slot. Both measured: auto-fit costs 4-5x decode, 4 slots halve it.
"%EXE%" -m "%HERE%%MODEL_FILE%" -ngl 99 -fa on -c %CTX% -t %THREADS% -np %PARALLEL% %KVARGS% --port %PORT% --host 127.0.0.1

echo.
echo [INFO] Server stopped.
pause
goto :menu