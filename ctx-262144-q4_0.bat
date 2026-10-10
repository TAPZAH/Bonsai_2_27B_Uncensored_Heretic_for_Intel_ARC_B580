@echo off
set "CTX=262144"
set "KVARGS=-ctk q4_0 -ctv q4_0 -b 512 -ub 128"
call "%~dp0run-server.bat" %*
