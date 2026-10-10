@echo off
rem Launches the server with a fixed context length: %1 = tokens.
rem Examples:  serve-ctx.bat 32768   /   serve-ctx.bat 131072
call "%~dp0serve-ctx.bat" %1