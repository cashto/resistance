@echo off

IF NOT EXIST release\node_modules call build
call coffee -j release\Test.js -c server\Room.coffee server\Game.coffee server\Player.coffee server\Database.coffee server\Lobby.coffee server\Test.coffee
node release\Test.js
