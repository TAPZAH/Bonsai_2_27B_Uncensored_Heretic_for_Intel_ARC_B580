@echo off
rem Usage: serve.bat [32768^|65536^|98304^|131072^|196608^|262144] [extra llama args]
set "CTX=%~1"
if "%CTX%"=="" set "CTX=65536"
call "%~dp0run-server.bat"
