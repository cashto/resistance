@echo off

REM Wipe release directory.
IF "%1"=="clean" rmdir /s /q release > nul
mkdir release 2> nul

REM Install dependencies.
cd release
copy ..\package.json > nul
call npm install
del package.json
cd ..

REM Compile the server.
call coffee -j release\Server.js -c server\Room.coffee server\Game.coffee server\Player.coffee server\Database.coffee server\Lobby.coffee server\Main.coffee

REM Copy client files.
xcopy /y /e /i client release\client > nul
