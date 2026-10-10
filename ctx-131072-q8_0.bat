@echo off
set "CTX=131072"
set "KVARGS=-ctk q8_0 -ctv q8_0"
call "%~dp0run-server.bat" %*
