@echo off
setlocal
set RELDIR=%1
if "%RELDIR%"=="" set RELDIR=c:\temp\resistance\release
rmdir /s /q %RELDIR% > nul
mkdir %RELDIR% > nul
call coffee -j %RELDIR%\Server.js -c Room.coffee Game.coffee Player.coffee Database.coffee Lobby.coffee Main.coffee
xcopy /e /i ..\client %RELDIR%\client > nul
xcopy /e /i node_modules %RELDIR%\node_modules > nul
copy runtest.cmd %RELDIR% > nul
copy runprod.cmd %RELDIR% > nul