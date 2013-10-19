@echo off
call coffee -j Test.js -c Room.coffee Lobby.coffee Game.coffee Player.coffee Database.coffee Test.coffee
node Test.js
