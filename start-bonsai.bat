@echo off
rem Default: 65536 context, KV q8_0 (best speed/quality balance).
set "CTX=65536"
set "KVARGS=-ctk q8_0 -ctv q8_0"
call "%~dp0run-server.bat" %*
