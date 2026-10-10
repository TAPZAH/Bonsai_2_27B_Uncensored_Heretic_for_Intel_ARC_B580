@echo off
rem Default launcher: context 65536 tokens, fastest measured setting.
set "CTX=65536"
call "%~dp0run-server.bat" %*
